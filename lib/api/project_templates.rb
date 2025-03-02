# frozen_string_literal: true

module API
  class ProjectTemplates < ::API::Base
    include PaginationParams

    TEMPLATE_TYPES = %w[dockerfiles gitignores gitlab_ci_ymls licenses metrics_dashboard_ymls issues merge_requests].freeze
    # The regex is needed to ensure a period (e.g. agpl-3.0)
    # isn't confused with a format type. We also need to allow encoded
    # values (e.g. C%2B%2B for C++), so allow % and + as well.
    TEMPLATE_NAMES_ENDPOINT_REQUIREMENTS = API::NAMESPACE_OR_PROJECT_REQUIREMENTS.merge(name: /[\w%.+-]+/)

    before { authenticate_non_get! }

    feature_category :source_code_management

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project'
      requires :type, type: String, values: TEMPLATE_TYPES, desc: 'The type (dockerfiles|gitignores|gitlab_ci_ymls|licenses|metrics_dashboard_ymls|issues|merge_requests) of the template'
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      desc 'Get a list of templates available to this project' do
        detail 'This endpoint was introduced in GitLab 11.4'
        is_array true
        success Entities::TemplatesList
        failure [
          { code: 401, message: 'Unauthorized' },
          { code: 404, message: 'Not found' }
        ]
      end
      params do
        use :pagination
      end
      get ':id/templates/:type' do
        bad_request! if params[:type] == 'metrics_dashboard_ymls' && Feature.enabled?(:remove_monitor_metrics)

        templates = TemplateFinder.all_template_names(user_project, params[:type]).values.flatten

        present paginate(::Kaminari.paginate_array(templates)), with: Entities::TemplatesList
      end

      desc 'Download a template available to this project' do
        detail 'This endpoint was introduced in GitLab 11.4'
        success Entities::License
        failure [
          { code: 401, message: 'Unauthorized' },
          { code: 404, message: 'Not found' }
        ]
      end
      params do
        requires :name, type: String,
                        desc: 'The key of the template, as obtained from the collection endpoint.', documentation: { example: 'MIT' }
        optional :source_template_project_id, type: Integer,
                                              desc: 'The project id where a given template is being stored. This is useful when multiple templates from different projects have the same name',
                                              documentation: { example: 1 }
        optional :project, type: String,
                           desc: 'The project name to use when expanding placeholders in the template. Only affects licenses',
                           documentation: { example: 'GitLab' }
        optional :fullname, type: String,
                            desc: 'The full name of the copyright holder to use when expanding placeholders in the template. Only affects licenses',
                            documentation: { example: 'GitLab B.V.' }
      end

      get ':id/templates/:type/:name', requirements: TEMPLATE_NAMES_ENDPOINT_REQUIREMENTS do
        bad_request! if params[:type] == 'metrics_dashboard_ymls' && Feature.enabled?(:remove_monitor_metrics)

        begin
          template = TemplateFinder.build(
            params[:type],
            user_project,
            {
              name: params[:name],
              source_template_project_id: params[:source_template_project_id]
            }
          ).execute
        rescue ::Gitlab::Template::Finders::RepoTemplateFinder::FileNotFoundError
          not_found!('Template')
        end

        not_found!('Template') unless template.present?

        template.resolve!(
          project_name: params[:project].presence,
          fullname: params[:fullname].presence || current_user&.name
        )

        if template.is_a?(::LicenseTemplate)
          present template, with: Entities::License
        else
          present template, with: Entities::Template
        end
      end
    end
  end
end
