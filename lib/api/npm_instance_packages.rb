# frozen_string_literal: true
module API
  class NpmInstancePackages < ::API::Base
    helpers ::API::Helpers::Packages::Npm

    feature_category :package_registry
    urgency :low

    rescue_from ActiveRecord::RecordInvalid do |e|
      render_api_error!(e.message, 400)
    end

    helpers do
      def endpoint_scope
        :instance
      end
    end

    namespace 'packages/npm' do
      include ::API::Concerns::Packages::NpmEndpoints
    end
  end
end
