# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Upload a project export archive', :api, :js, feature_category: :projects do
  include_context 'file upload requests helpers'

  let_it_be(:user) { create(:user, :admin) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

  let(:api_path) { '/projects/import' }
  let(:url) { capybara_url(api(api_path, personal_access_token: personal_access_token)) }
  let(:file) { fixture_file_upload('spec/features/projects/import_export/test_project_export.tar.gz') }

  subject do
    HTTParty.post(
      url,
      body: {
        path: 'test-import',
        file: file
      }
    )
  end

  before do
    stub_application_setting(import_sources: ['gitlab_project'])
  end

  RSpec.shared_examples 'for a project export archive' do
    it { expect { subject }.to change { Project.count }.by(1) }

    it { expect(subject.code).to eq(201) }
  end

  it_behaves_like 'handling file uploads', 'for a project export archive'
end
