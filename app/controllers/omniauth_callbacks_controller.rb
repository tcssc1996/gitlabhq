# frozen_string_literal: true

class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include AuthenticatesWithTwoFactorForAdminMode
  include Devise::Controllers::Rememberable
  include AuthHelper
  include InitializesCurrentUserMode
  include KnownSignIn
  include AcceptsPendingInvitations

  after_action :verify_known_sign_in

  protect_from_forgery except: [:failure] + AuthHelper.saml_providers, with: :exception, prepend: true

  feature_category :system_access

  def handle_omniauth
    omniauth_flow(Gitlab::Auth::OAuth)
  end

  AuthHelper.providers_for_base_controller.each do |provider|
    alias_method provider, :handle_omniauth
  end

  # overridden in EE
  def openid_connect
    handle_omniauth
  end

  # Extend the standard implementation to also increment
  # the number of failed sign in attempts
  def failure
    if params[:username].present? && AuthHelper.form_based_provider?(failed_strategy.name)
      user = User.find_by_login(params[:username])

      user&.increment_failed_attempts!
      log_failed_login(params[:username], failed_strategy.name)
    end

    super
  end

  # Extend the standard message generation to accept our custom exception
  def failure_message
    exception = request.env["omniauth.error"]
    error = exception.error_reason if exception.respond_to?(:error_reason)
    error ||= exception.error        if exception.respond_to?(:error)
    error ||= exception.message      if exception.respond_to?(:message)
    error ||= request.env["omniauth.error.type"].to_s

    error.to_s.humanize if error
  end

  def saml
    omniauth_flow(Gitlab::Auth::Saml)
  rescue Gitlab::Auth::Saml::IdentityLinker::UnverifiedRequest
    redirect_unverified_saml_initiation
  end

  def auth0
    if oauth['uid'].blank?
      fail_auth0_login
    else
      handle_omniauth
    end
  end

  def salesforce
    if oauth.dig('extra', 'email_verified')
      handle_omniauth
    else
      fail_salesforce_login
    end
  end

  def atlassian_oauth2
    omniauth_flow(Gitlab::Auth::Atlassian)
  end

  private

  def log_failed_login(user, provider)
    # overridden in EE
  end

  def after_omniauth_failure_path_for(scope)
    if Gitlab::CurrentSettings.admin_mode
      return new_admin_session_path if current_user_mode.admin_mode_requested?
    end

    super
  end

  def omniauth_flow(auth_module, identity_linker: nil)
    if fragment = request.env.dig('omniauth.params', 'redirect_fragment').presence
      store_redirect_fragment(fragment)
    end

    if current_user
      return render_403 unless link_provider_allowed?(oauth['provider'])

      log_audit_event(current_user, with: oauth['provider'])

      if Gitlab::CurrentSettings.admin_mode
        return admin_mode_flow(auth_module::User) if current_user_mode.admin_mode_requested?
      end

      identity_linker ||= auth_module::IdentityLinker.new(current_user, oauth, session)
      link_identity(identity_linker)
      set_remember_me(current_user)

      if identity_linker.changed?
        redirect_identity_linked
      elsif identity_linker.failed?
        redirect_identity_link_failed(identity_linker.error_message)
      else
        redirect_identity_exists
      end
    else
      sign_in_user_flow(auth_module::User)
    end
  end

  def link_identity(identity_linker)
    identity_linker.link
  end

  def redirect_identity_exists
    redirect_to after_sign_in_path_for(current_user)
  end

  def redirect_identity_link_failed(error_message)
    redirect_to profile_account_path, notice: _("Authentication failed: %{error_message}") % { error_message: error_message }
  end

  def redirect_identity_linked
    redirect_to profile_account_path, notice: _('Authentication method updated')
  end

  def build_auth_user(auth_user_class)
    auth_user_class.new(oauth)
  end

  def sign_in_user_flow(auth_user_class)
    auth_user = build_auth_user(auth_user_class)
    new_user = auth_user.new?
    user = auth_user.find_and_update!

    if auth_user.valid_sign_in?
      # In this case the `#current_user` would not be set. So we can't fetch it
      # from that in `#context_user`. Pushing it manually here makes the information
      # available in the logs for this request.
      Gitlab::ApplicationContext.push(user: user)
      log_audit_event(user, with: oauth['provider'])
      Gitlab::Tracking.event(self.class.name, "#{oauth['provider']}_sso", user: user) if new_user

      set_remember_me(user)

      if user.two_factor_enabled? && !auth_user.bypass_two_factor?
        prompt_for_two_factor(user)
      else
        if user.deactivated?
          user.activate
          flash[:notice] = _('Welcome back! Your account had been deactivated due to inactivity but is now reactivated.')
        end

        accept_pending_invitations(user: user) if new_user
        persist_accepted_terms_if_required(user) if new_user

        perform_registration_tasks(user, oauth['provider']) if intent_to_register?
        sign_in_and_redirect_or_verify_identity(user, auth_user, new_user)
      end
    else
      fail_login(user)
    end
  rescue Gitlab::Auth::OAuth::User::SigninDisabledForProviderError
    handle_disabled_provider
  rescue Gitlab::Auth::OAuth::User::SignupDisabledError
    handle_signup_error
  end

  def handle_signup_error
    label = Gitlab::Auth::OAuth::Provider.label_for(oauth['provider'])
    message = [_("Signing in using your %{label} account without a pre-existing GitLab account is not allowed.") % { label: label }]

    if Gitlab::CurrentSettings.allow_signup?
      message << _("Create a GitLab account first, and then connect it to your %{label} account.") % { label: label }
    end

    flash[:alert] = message.join(' ')
    redirect_to new_user_session_path
  end

  def oauth
    @oauth ||= request.env['omniauth.auth']
  end

  def fail_login(user)
    log_failed_login(user.username, oauth['provider'])

    @provider = Gitlab::Auth::OAuth::Provider.label_for(params[:action])
    @error = user.errors.full_messages.to_sentence

    render 'errors/omniauth_error', layout: "oauth_error", status: :unprocessable_entity
  end

  def fail_auth0_login
    fail_login_with_message(_('Wrong extern UID provided. Make sure Auth0 is configured correctly.'))
  end

  def fail_salesforce_login
    fail_login_with_message(_('Email not verified. Please verify your email in Salesforce.'))
  end

  def fail_login_with_message(message)
    flash[:alert] = message

    redirect_to new_user_session_path
  end

  def redirect_unverified_saml_initiation
    redirect_to profile_account_path, notice: _('Request to link SAML account must be authorized')
  end

  def handle_disabled_provider
    label = Gitlab::Auth::OAuth::Provider.label_for(oauth['provider'])
    flash[:alert] = _("Signing in using %{label} has been disabled") % { label: label }

    redirect_to new_user_session_path
  end

  def log_audit_event(user, options = {})
    AuditEventService.new(user, user, options)
      .for_authentication.security_event
  end

  def set_remember_me(user)
    return unless remember_me?

    if user.two_factor_enabled?
      params[:remember_me] = '1'
    else
      remember_me(user)
    end
  end

  def remember_me?
    request_params = request.env['omniauth.params']
    (request_params['remember_me'] == '1') if request_params.present?
  end

  def intent_to_register?
    request_params = request.env['omniauth.params']
    (request_params['intent'] == 'register') if request_params.present?
  end

  def store_redirect_fragment(redirect_fragment)
    key = stored_location_key_for(:user)
    location = session[key]
    if uri = parse_uri(location)
      uri.fragment = redirect_fragment
      store_location_for(:user, uri.to_s)
    end
  end

  def admin_mode_flow(auth_user_class)
    auth_user = build_auth_user(auth_user_class)

    return fail_admin_mode_invalid_credentials unless omniauth_identity_matches_current_user?

    if current_user.two_factor_enabled? && !auth_user.bypass_two_factor?
      admin_mode_prompt_for_two_factor(current_user)
    else
      # Can only reach here if the omniauth identity matches current user
      # and current_user is an admin that requested admin mode
      current_user_mode.enable_admin_mode!(skip_password_validation: true)

      redirect_to stored_location_for(:redirect) || admin_root_path, notice: _('Admin mode enabled')
    end
  end

  def omniauth_identity_matches_current_user?
    current_user.matches_identity?(oauth['provider'], oauth['uid'])
  end

  def fail_admin_mode_invalid_credentials
    redirect_to new_admin_session_path, alert: _('Invalid login or password')
  end

  def persist_accepted_terms_if_required(user)
    return unless user.persisted?
    return unless Gitlab::CurrentSettings.current_application_settings.enforce_terms?

    terms = ApplicationSetting::Term.latest
    Users::RespondToTermsService.new(user, terms).execute(accepted: true)
  end

  def perform_registration_tasks(_user, _provider)
    store_location_for(:user, after_sign_up_path)
  end

  def after_sign_up_path
    users_sign_up_welcome_path
  end

  # overridden in EE
  def sign_in_and_redirect_or_verify_identity(user, _, _)
    sign_in_and_redirect(user, event: :authentication)
  end
end

OmniauthCallbacksController.prepend_mod_with('OmniauthCallbacksController')
