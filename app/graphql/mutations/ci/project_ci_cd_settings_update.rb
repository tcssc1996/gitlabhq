# frozen_string_literal: true

module Mutations
  module Ci
    class ProjectCiCdSettingsUpdate < BaseMutation
      graphql_name 'ProjectCiCdSettingsUpdate'

      include FindsProject

      authorize :admin_project

      argument :full_path, GraphQL::Types::ID,
        required: true,
        description: 'Full Path of the project the settings belong to.'

      argument :keep_latest_artifact, GraphQL::Types::Boolean,
        required: false,
        description: 'Indicates if the latest artifact should be kept for the project.'

      argument :job_token_scope_enabled, GraphQL::Types::Boolean,
        required: false,
        deprecated: {
          reason: 'Outbound job token scope is being removed. This field can now only be set to false',
          milestone: '16.0'
        },
        description: 'Indicates CI/CD job tokens generated in this project ' \
          'have restricted access to other projects.'

      argument :inbound_job_token_scope_enabled, GraphQL::Types::Boolean,
        required: false,
        description: 'Indicates CI/CD job tokens generated in other projects ' \
          'have restricted access to this project.'

      field :ci_cd_settings,
        Types::Ci::CiCdSettingType,
        null: false,
        description: 'CI/CD settings after mutation.'

      def resolve(full_path:, **args)
        project = authorized_find!(full_path)

        if args[:job_token_scope_enabled] && project.frozen_outbound_job_token_scopes?
          raise Gitlab::Graphql::Errors::ArgumentError, 'job_token_scope_enabled can only be set to false'
        end

        settings = project.ci_cd_settings
        settings.update(args)

        {
          ci_cd_settings: settings,
          errors: errors_on_object(settings)
        }
      end
    end
  end
end

Mutations::Ci::ProjectCiCdSettingsUpdate.prepend_mod_with('Mutations::Ci::ProjectCiCdSettingsUpdate')
