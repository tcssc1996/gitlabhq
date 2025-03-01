# frozen_string_literal: true

module Gitlab
  module BitbucketServerImport
    module Importers
      class RepositoryImporter
        include Loggable

        def initialize(project)
          @project = project
        end

        def execute
          log_info(import_stage: 'import_repository', message: 'starting import')

          if project.empty_repo?
            project.repository.import_repository(project.import_url)
            project.repository.fetch_as_mirror(project.import_url, refmap: refmap)

            update_clone_time
          end

          log_info(import_stage: 'import_repository', message: 'finished import')

          true
        rescue ::Gitlab::Git::CommandError => e
          Gitlab::ErrorTracking.log_exception(
            e, import_stage: 'import_repository', message: 'failed import', error: e.message
          )

          # Expire cache to prevent scenarios such as:
          # 1. First import failed, but the repo was imported successfully, so +exists?+ returns true
          # 2. Retried import, repo is broken or not imported but +exists?+ still returns true
          project.repository.expire_content_cache if project.repository_exists?

          raise
        end

        private

        attr_reader :project

        def refmap
          # We omit :heads and :tags since these are fetched in the import_repository
          ['+refs/pull-requests/*/to:refs/merge-requests/*/head']
        end

        def update_clone_time
          project.touch(:last_repository_updated_at)
        end
      end
    end
  end
end
