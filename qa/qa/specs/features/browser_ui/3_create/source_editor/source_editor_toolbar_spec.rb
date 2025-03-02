# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'Source editor toolbar preview', product_group: :source_code do
      let(:project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'empty-project-with-md'
          project.initialize_with_readme = true
        end
      end

      let(:edited_readme_content) { 'Here is the edited content.' }

      before do
        Flow::Login.sign_in
      end

      it 'can preview markdown side-by-side while editing',
      testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/367749' do
        project.visit!
        Page::Project::Show.perform do |project|
          project.click_file('README.md')
        end

        Page::File::Show.perform(&:click_edit)

        Page::File::Edit.perform do |file|
          file.remove_content
          file.add_content('# ' + edited_readme_content)
          file.preview
          expect(file.has_markdown_preview?('h1', edited_readme_content)).to be true
          file.commit_changes
        end

        Page::File::Show.perform do |file|
          aggregate_failures 'file details' do
            expect(file).to have_notice('Your changes have been successfully committed.')
            expect(file).to have_file_content(edited_readme_content)
          end
        end
      end
    end
  end
end
