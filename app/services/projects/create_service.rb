# frozen_string_literal: true

module Projects
  class CreateService < BaseService
    include ValidatesClassificationLabel

    ImportSourceDisabledError = Class.new(StandardError)
    INTERNAL_IMPORT_SOURCES = %w[gitlab_custom_project_template gitlab_project_migration].freeze

    def initialize(user, params)
      @current_user = user
      @params = params.dup
      @skip_wiki = @params.delete(:skip_wiki)
      @initialize_with_sast = Gitlab::Utils.to_boolean(@params.delete(:initialize_with_sast))
      @initialize_with_readme = Gitlab::Utils.to_boolean(@params.delete(:initialize_with_readme))
      @import_data = @params.delete(:import_data)
      @relations_block = @params.delete(:relations_block)
      @default_branch = @params.delete(:default_branch)
      @readme_template = @params.delete(:readme_template)

      build_topics
    end

    def execute
      params[:wiki_enabled] = params[:wiki_access_level] if params[:wiki_access_level]
      params[:builds_enabled] = params[:builds_access_level] if params[:builds_access_level]
      params[:snippets_enabled] = params[:snippets_access_level] if params[:snippets_access_level]
      params[:merge_requests_enabled] = params[:merge_requests_access_level] if params[:merge_requests_access_level]
      params[:issues_enabled] = params[:issues_access_level] if params[:issues_access_level]

      if create_from_template?
        return ::Projects::CreateFromTemplateService.new(current_user, params).execute
      end

      @project = Project.new(params.merge(creator: current_user))

      validate_import_source_enabled!

      @project.visibility_level = @project.group.visibility_level unless @project.visibility_level_allowed_by_group?

      # If a project is newly created it should have shared runners settings
      # based on its group having it enabled. This is like the "default value"
      @project.shared_runners_enabled = false if !params.key?(:shared_runners_enabled) && @project.group && @project.group.shared_runners_setting != 'enabled'

      # Make sure that the user is allowed to use the specified visibility level
      if project_visibility.restricted?
        deny_visibility_level(@project, project_visibility.visibility_level)
        return @project
      end

      set_project_name_from_path

      # get namespace id
      namespace_id = params[:namespace_id] || current_user.namespace_id
      @project.namespace_id = namespace_id.to_i

      @project.check_personal_projects_limit
      return @project if @project.errors.any?

      validate_create_permissions
      validate_import_permissions
      return @project if @project.errors.any?

      @relations_block&.call(@project)
      yield(@project) if block_given?

      validate_classification_label(@project, :external_authorization_classification_label)

      # If the block added errors, don't try to save the project
      return @project if @project.errors.any?

      @project.creator = current_user

      save_project_and_import_data

      Gitlab::ApplicationContext.with_context(project: @project) do
        after_create_actions if @project.persisted?

        import_schedule
      end

      @project
    rescue ActiveRecord::RecordInvalid => e
      message = "Unable to save #{e.inspect}: #{e.record.errors.full_messages.join(", ")}"
      fail(error: message)
    rescue ImportSourceDisabledError => e
      @project.errors.add(:import_source_disabled, e.message) if @project
      fail(error: e.message)
    rescue StandardError => e
      @project.errors.add(:base, e.message) if @project
      fail(error: e.message)
    end

    protected

    def validate_create_permissions
      return if current_user.can?(:create_projects, parent_namespace)

      @project.errors.add(:namespace, "is not valid")
    end

    def validate_import_permissions
      return unless @project.import?
      return if current_user.can?(:import_projects, parent_namespace)

      @project.errors.add(:user, 'is not allowed to import projects')
    end

    def after_create_actions
      log_info("#{current_user.name} created a new project \"#{@project.full_name}\"")

      if @project.import?
        Gitlab::Tracking.event(self.class.name, 'import_project', user: current_user)
      else
        # Skip writing the config for project imports/forks because it
        # will always fail since the Git directory doesn't exist until
        # a background job creates it (see Project#add_import_job).
        @project.set_full_path
      end

      unless @project.gitlab_project_import?
        @project.create_wiki unless skip_wiki?
      end

      @project.track_project_repository

      create_project_settings

      yield if block_given?

      event_service.create_project(@project, current_user)
      system_hook_service.execute_hooks_for(@project, :create)

      setup_authorizations

      project.invalidate_personal_projects_count_of_owner

      Projects::PostCreationWorker.perform_async(@project.id)

      create_readme if @initialize_with_readme
      create_sast_commit if @initialize_with_sast

      publish_event
    end

    def create_project_settings
      @project.project_setting.save if @project.project_setting.changed?
    end

    # Add an authorization for the current user authorizations inline
    # (so they can access the project immediately after this request
    # completes), and any other affected users in the background
    def setup_authorizations
      if @project.group
        group_access_level = @project.group.max_member_access_for_user(
          current_user,
          only_concrete_membership: true
        )

        if group_access_level > GroupMember::NO_ACCESS
          current_user.project_authorizations.safe_find_or_create_by!(
            project: @project,
            access_level: group_access_level)
        end

        AuthorizedProjectUpdate::ProjectRecalculateWorker.perform_async(@project.id)
        # AuthorizedProjectsWorker uses an exclusive lease per user but
        # specialized workers might have synchronization issues. Until we
        # compare the inconsistency rates of both approaches, we still run
        # AuthorizedProjectsWorker but with some delay and lower urgency as a
        # safety net.
        @project.group.refresh_members_authorized_projects(
          priority: UserProjectAccessChangedService::LOW_PRIORITY
        )
      else
        owner_user = @project.namespace.owner
        owner_member = @project.add_owner(owner_user, current_user: current_user)

        # There is a possibility that the sidekiq job to refresh the authorizations of the owner_user in this project
        # isn't picked up (or finished) by the time the user is redirected to the newly created project's page.
        # If that happens, the user will hit a 404. To avoid that scenario, we manually create a `project_authorizations` record for the user here.
        if owner_member.persisted?
          owner_user.project_authorizations.safe_find_or_create_by(
            project: @project,
            access_level: ProjectMember::OWNER
          )
        end
        # During the process of adding a project owner, a check on permissions is made on the user which caches
        # the max member access for that user on this project.
        # Since that is `0` before the member is created - and we are still inside the request
        # cycle when we need to do other operations that might check those permissions (e.g. write a commit)
        # we need to purge that cache so that the updated permissions is fetched instead of using the outdated cached value of 0
        # from before member creation
        @project.team.purge_member_access_cache_for_user_id(owner_user.id)
      end
    end

    def create_readme
      commit_attrs = {
        branch_name: default_branch,
        commit_message: 'Initial commit',
        file_path: 'README.md',
        file_content: readme_content
      }

      Files::CreateService.new(@project, current_user, commit_attrs).execute
    end

    def create_sast_commit
      ::Security::CiConfiguration::SastCreateService.new(@project, current_user, { initialize_with_sast: true }, commit_on_default: true).execute
    end

    def readme_content
      readme_attrs = {
        default_branch: default_branch
      }

      @readme_template.presence || ReadmeRendererService.new(@project, current_user, readme_attrs).execute
    end

    def skip_wiki?
      !@project.feature_available?(:wiki, current_user) || @skip_wiki
    end

    def save_project_and_import_data
      Project.transaction do
        @project.create_or_update_import_data(data: @import_data[:data], credentials: @import_data[:credentials]) if @import_data

        if @project.save
          Integration.create_from_active_default_integrations(@project, :project_id)

          @project.create_labels unless @project.gitlab_project_import?

          break if @project.import?

          unless @project.create_repository(default_branch: default_branch)
            raise 'Failed to create repository'
          end
        end
      end
    end

    def fail(error:)
      message = "Unable to save project. Error: #{error}"
      log_message = message.dup

      log_message << " Project ID: #{@project.id}" if @project&.id
      Gitlab::AppLogger.error(log_message)

      if @project && @project.persisted? && @project.import_state
        @project.import_state.mark_as_failed(message)
      end

      @project
    end

    def set_project_name_from_path
      # if both name and path set - everything is ok
      return if @project.name.present? && @project.path.present?

      if @project.path.present?
        # Set project name from path
        @project.name = @project.path.dup
      elsif @project.name.present?
        # For compatibility - set path from name
        @project.path = @project.name.dup

        # TODO: Retained for backwards compatibility. Remove in API v5.
        #       When removed, validation errors will get bubbled up automatically.
        #       See https://gitlab.com/gitlab-org/gitlab/-/merge_requests/52725
        unless @project.path.match?(Gitlab::PathRegex.project_path_format_regex)
          @project.path = @project.path.parameterize
        end
      end
    end

    def extra_attributes_for_measurement
      {
        current_user: current_user&.name,
        project_full_path: "#{parent_namespace&.full_path}/#{@params[:path]}"
      }
    end

    private

    def default_branch
      @default_branch.presence || @project.default_branch_or_main
    end

    def validate_import_source_enabled!
      return unless @params[:import_type]

      import_type = @params[:import_type].to_s

      return if INTERNAL_IMPORT_SOURCES.include?(import_type)

      # Skip validation when creating project from a built in template
      return if @params[:import_export_upload].present? && import_type == 'gitlab_project'

      unless ::Gitlab::CurrentSettings.import_sources&.include?(import_type)
        raise ImportSourceDisabledError, "#{import_type} import source is disabled"
      end
    end

    def parent_namespace
      @parent_namespace ||= Namespace.find_by_id(@params[:namespace_id]) || current_user.namespace
    end

    def create_from_template?
      @params[:template_name].present? || @params[:template_project_id].present?
    end

    def import_schedule
      if @project.errors.empty?
        @project.import_state.schedule if @project.import? && !@project.gitlab_project_migration?
      else
        fail(error: @project.errors.full_messages.join(', '))
      end
    end

    def project_visibility
      @project_visibility ||= Gitlab::VisibilityLevelChecker
        .new(current_user, @project, project_params: { import_data: @import_data })
        .level_restricted?
    end

    def build_topics
      topics = params.delete(:topics)
      tag_list = params.delete(:tag_list)
      topic_list = topics || tag_list

      params[:topic_list] ||= topic_list if topic_list
    end

    def publish_event
      event = Projects::ProjectCreatedEvent.new(data: {
        project_id: project.id,
        namespace_id: project.namespace_id,
        root_namespace_id: project.root_namespace.id
      })

      Gitlab::EventStore.publish(event)
    end
  end
end

Projects::CreateService.prepend_mod_with('Projects::CreateService')
