# frozen_string_literal: true

module Mutations
  module Environments
    class Create < ::Mutations::BaseMutation
      graphql_name 'EnvironmentCreate'
      description 'Create an environment.'

      include FindsProject

      authorize :create_environment

      argument :project_path,
        GraphQL::Types::ID,
        required: true,
        description: 'Full path of the project.'

      argument :name,
        GraphQL::Types::String,
        required: true,
        description: 'Name of the environment.'

      argument :external_url,
        GraphQL::Types::String,
        required: false,
        description: 'External URL of the environment.'

      argument :tier,
        Types::DeploymentTierEnum,
        required: false,
        description: 'Tier of the environment.'

      field :environment,
        Types::EnvironmentType,
        null: true,
        description: 'Created environment.'

      def resolve(project_path:, **kwargs)
        project = authorized_find!(project_path)

        response = ::Environments::CreateService.new(project, current_user, kwargs).execute

        if response.success?
          { environment: response.payload[:environment], errors: [] }
        else
          { environment: response.payload[:environment], errors: response.errors }
        end
      end
    end
  end
end
