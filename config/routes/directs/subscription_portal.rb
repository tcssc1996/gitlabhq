# frozen_string_literal: true

direct :subscription_portal_staging do
  ENV.fetch('STAGING_CUSTOMER_PORTAL_URL', 'https://customers.staging.gitlab.com')
end

direct :subscription_portal do
  default_subscriptions_url = if ::Gitlab.dev_or_test_env?
                                subscription_portal_staging_url
                              else
                                'https://customers.gitlab.com'
                              end

  ENV.fetch('CUSTOMER_PORTAL_URL', default_subscriptions_url)
end

direct :subscription_portal_instance_review do
  Addressable::URI.join(subscription_portal_url, '/instance_review').to_s
end
