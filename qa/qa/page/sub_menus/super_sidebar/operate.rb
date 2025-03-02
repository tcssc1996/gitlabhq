# frozen_string_literal: true

module QA
  module Page
    module SubMenus
      module SuperSidebar
        module Operate
          extend QA::Page::PageConcern

          def go_to_package_registry
            open_operate_submenu('Package Registry')
          end

          def go_to_container_registry
            open_operate_submenu('Container Registry')
          end

          def go_to_dependency_proxy
            open_operate_submenu('Dependency Proxy')
          end

          private

          def open_operate_submenu(sub_menu)
            open_submenu('Operate', sub_menu)
          end
        end
      end
    end
  end
end
