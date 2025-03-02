# frozen_string_literal: true

module ContainerRegistry
  class GitlabApiClient < BaseClient
    include Gitlab::Utils::StrongMemoize

    JSON_TYPE = 'application/json'
    CANCEL_RESPONSE_STATUS_HEADER = 'status'

    IMPORT_RESPONSES = {
      200 => :already_imported,
      202 => :ok,
      400 => :bad_request,
      401 => :unauthorized,
      404 => :not_found,
      409 => :already_being_imported,
      424 => :pre_import_failed,
      425 => :already_being_imported,
      429 => :too_many_imports
    }.freeze

    REGISTRY_GITLAB_V1_API_FEATURE = 'gitlab_v1_api'

    MAX_TAGS_PAGE_SIZE = 1000
    MAX_REPOSITORIES_PAGE_SIZE = 1000
    PAGE_SIZE = 1

    UnsuccessfulResponseError = Class.new(StandardError)

    def self.supports_gitlab_api?
      with_dummy_client(return_value_if_disabled: false) do |client|
        client.supports_gitlab_api?
      end
    end

    def self.deduplicated_size(path)
      with_dummy_client(token_config: { type: :nested_repositories_token, path: path&.downcase }) do |client|
        client.repository_details(path&.downcase, sizing: :self_with_descendants)['size_bytes']
      end
    end

    def self.one_project_with_container_registry_tag(path)
      with_dummy_client(token_config: { type: :nested_repositories_token, path: path&.downcase }) do |client|
        page = client.sub_repositories_with_tag(path&.downcase, page_size: PAGE_SIZE)
        details = page[:response_body]&.first

        break unless details

        path = ContainerRegistry::Path.new(details["path"])

        break unless path.valid?

        ContainerRepository.find_by_path(path)&.project
      end
    end

    def self.each_sub_repositories_with_tag_page(path:, page_size: 100, &block)
      raise ArgumentError, 'block not given' unless block

      # dummy uri to initialize the loop
      next_page_uri = URI('')
      page_count = 0

      with_dummy_client(token_config: { type: :nested_repositories_token, path: path&.downcase }) do |client|
        while next_page_uri
          last = Rack::Utils.parse_nested_query(next_page_uri.query)['last']
          current_page = client.sub_repositories_with_tag(path&.downcase, page_size: page_size, last: last)

          if current_page&.key?(:response_body)
            yield (current_page[:response_body] || [])
            next_page_uri = current_page.dig(:pagination, :next, :uri)
          else
            # no current page. Break the loop
            next_page_uri = nil
          end

          page_count += 1

          raise 'too many pages requested' if page_count >= MAX_REPOSITORIES_PAGE_SIZE
        end
      end
    end

    # https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs-gitlab/api.md#compliance-check
    def supports_gitlab_api?
      strong_memoize(:supports_gitlab_api) do
        registry_features = Gitlab::CurrentSettings.container_registry_features || []
        next true if ::Gitlab.com? && registry_features.include?(REGISTRY_GITLAB_V1_API_FEATURE)

        with_token_faraday do |faraday_client|
          response = faraday_client.get('/gitlab/v1/')
          response.success? || response.status == 401
        end
      end
    end

    # https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs-gitlab/api.md#import-repository
    def pre_import_repository(path)
      response = start_import_for(path, pre: true)
      IMPORT_RESPONSES.fetch(response.status, :error)
    end

    # https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs-gitlab/api.md#import-repository
    def import_repository(path)
      response = start_import_for(path, pre: false)
      IMPORT_RESPONSES.fetch(response.status, :error)
    end

    # https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs-gitlab/api.md#cancel-repository-import
    def cancel_repository_import(path, force: false)
      response = with_import_token_faraday do |faraday_client|
        faraday_client.delete(import_url_for(path)) do |req|
          req.params['force'] = true if force
        end
      end

      status = IMPORT_RESPONSES.fetch(response.status, :error)
      actual_state = response.body[CANCEL_RESPONSE_STATUS_HEADER]

      { status: status, migration_state: actual_state }
    end

    # https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs-gitlab/api.md#get-repository-import-status
    def import_status(path)
      with_import_token_faraday do |faraday_client|
        response = faraday_client.get(import_url_for(path))

        # Temporary solution for https://gitlab.com/gitlab-org/gitlab/-/issues/356085#solutions
        # this will trigger a `retry_pre_import`
        break 'pre_import_failed' unless response.success?

        body_hash = response_body(response)
        body_hash&.fetch('status') || 'error'
      end
    end

    # https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs-gitlab/api.md#get-repository-details
    def repository_details(path, sizing: nil)
      with_token_faraday do |faraday_client|
        req = faraday_client.get("/gitlab/v1/repositories/#{path}/") do |req|
          req.params['size'] = sizing if sizing
        end

        break {} unless req.success?

        response_body(req)
      end
    end

    # https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs-gitlab/api.md#list-repository-tags
    def tags(path, page_size: 100, last: nil)
      limited_page_size = [page_size, MAX_TAGS_PAGE_SIZE].min
      with_token_faraday do |faraday_client|
        url = "/gitlab/v1/repositories/#{path}/tags/list/"
        response = faraday_client.get(url) do |req|
          req.params['n'] = limited_page_size
          req.params['last'] = last if last
        end

        unless response.success?
          Gitlab::ErrorTracking.log_exception(
            UnsuccessfulResponseError.new,
            class: self.class.name,
            url: url,
            status_code: response.status
          )

          break {}
        end

        link_parser = Gitlab::Utils::LinkHeaderParser.new(response.headers['link'])

        {
          pagination: link_parser.parse,
          response_body: response_body(response)
        }
      end
    end

    # https://gitlab.com/gitlab-org/container-registry/-/blob/master/docs-gitlab/api.md#list-sub-repositories
    def sub_repositories_with_tag(path, page_size: 100, last: nil)
      limited_page_size = [page_size, MAX_REPOSITORIES_PAGE_SIZE].min

      with_token_faraday do |faraday_client|
        url = "/gitlab/v1/repository-paths/#{path}/repositories/list/"
        response = faraday_client.get(url) do |req|
          req.params['n'] = limited_page_size
          req.params['last'] = last if last
        end

        unless response.success?
          Gitlab::ErrorTracking.log_exception(
            UnsuccessfulResponseError.new,
            class: self.class.name,
            url: url,
            status_code: response.status
          )

          break {}
        end

        link_parser = Gitlab::Utils::LinkHeaderParser.new(response.headers['link'])

        {
          pagination: link_parser.parse,
          response_body: response_body(response)
        }
      end
    end

    private

    def start_import_for(path, pre:)
      with_import_token_faraday do |faraday_client|
        faraday_client.put(import_url_for(path)) do |req|
          req.params['import_type'] = pre ? 'pre' : 'final'
        end
      end
    end

    def with_token_faraday
      yield faraday
    end

    def with_import_token_faraday
      yield faraday_with_import_token
    end

    def faraday_with_import_token(timeout_enabled: true)
      @faraday_with_import_token ||= faraday_base(timeout_enabled: timeout_enabled) do |conn|
        # initialize the connection with the :import_token instead of :token
        initialize_connection(conn, @options.merge(token: @options[:import_token]), &method(:configure_connection))
      end
    end

    def import_url_for(path)
      "/gitlab/v1/import/#{path}/"
    end

    # overrides the default configuration
    def configure_connection(conn)
      conn.headers['Accept'] = [JSON_TYPE]

      conn.response :json, content_type: JSON_TYPE
    end
  end
end
