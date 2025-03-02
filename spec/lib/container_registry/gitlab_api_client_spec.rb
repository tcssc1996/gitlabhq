# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ContainerRegistry::GitlabApiClient, feature_category: :container_registry do
  using RSpec::Parameterized::TableSyntax

  include_context 'container registry client'
  include_context 'container registry client stubs'

  let(:path) { 'namespace/path/to/repository' }
  let(:import_token) { 'import_token' }
  let(:options) { { token: token, import_token: import_token } }

  describe '#supports_gitlab_api?' do
    subject { client.supports_gitlab_api? }

    where(:registry_gitlab_api_enabled, :is_on_dot_com, :container_registry_features, :expect_registry_to_be_pinged, :expected_result) do
      false | true  | [described_class::REGISTRY_GITLAB_V1_API_FEATURE] | false | true
      true  | false | [described_class::REGISTRY_GITLAB_V1_API_FEATURE] | true  | true
      true  | true  | []                                                | true  | true
      true  | false | []                                                | true  | true
      false | true  | [described_class::REGISTRY_GITLAB_V1_API_FEATURE] | false | true
      false | false | [described_class::REGISTRY_GITLAB_V1_API_FEATURE] | true  | false
      false | true  | []                                                | true  | false
      false | false | []                                                | true  | false
    end

    with_them do
      before do
        allow(::Gitlab).to receive(:com?).and_return(is_on_dot_com)
        stub_registry_gitlab_api_support(registry_gitlab_api_enabled)
        stub_application_setting(container_registry_features: container_registry_features)
      end

      it 'returns the expected result' do
        if expect_registry_to_be_pinged
          expect(Faraday::Connection).to receive(:new).and_call_original
        else
          expect(Faraday::Connection).not_to receive(:new)
        end

        expect(subject).to be expected_result
      end
    end

    context 'with 401 response' do
      before do
        allow(::Gitlab).to receive(:com?).and_return(false)
        stub_application_setting(container_registry_features: [])
        stub_request(:get, "#{registry_api_url}/gitlab/v1/")
          .to_return(status: 401, body: '')
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#pre_import_repository' do
    subject { client.pre_import_repository(path) }

    where(:status_code, :expected_result) do
      200 | :already_imported
      202 | :ok
      400 | :bad_request
      401 | :unauthorized
      404 | :not_found
      409 | :already_being_imported
      418 | :error
      424 | :pre_import_failed
      425 | :already_being_imported
      429 | :too_many_imports
    end

    with_them do
      before do
        stub_pre_import(path, status_code, pre: true)
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#import_repository' do
    subject { client.import_repository(path) }

    where(:status_code, :expected_result) do
      200 | :already_imported
      202 | :ok
      400 | :bad_request
      401 | :unauthorized
      404 | :not_found
      409 | :already_being_imported
      418 | :error
      424 | :pre_import_failed
      425 | :already_being_imported
      429 | :too_many_imports
    end

    with_them do
      before do
        stub_pre_import(path, status_code, pre: false)
      end

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '#cancel_repository_import' do
    let(:force) { false }

    subject { client.cancel_repository_import(path, force: force) }

    where(:status_code, :expected_result) do
      200 | :already_imported
      202 | :ok
      400 | :bad_request
      401 | :unauthorized
      404 | :not_found
      409 | :already_being_imported
      418 | :error
      424 | :pre_import_failed
      425 | :already_being_imported
      429 | :too_many_imports
    end

    with_them do
      before do
        stub_import_cancel(path, status_code, force: force)
      end

      it { is_expected.to eq({ status: expected_result, migration_state: nil }) }
    end

    context 'bad request' do
      let(:status) { 'this_is_a_test' }

      before do
        stub_import_cancel(path, 400, status: status, force: force)
      end

      it { is_expected.to eq({ status: :bad_request, migration_state: status }) }
    end

    context 'force cancel' do
      let(:force) { true }

      before do
        stub_import_cancel(path, 202, force: force)
      end

      it { is_expected.to eq({ status: :ok, migration_state: nil }) }
    end
  end

  describe '#import_status' do
    subject { client.import_status(path) }

    context 'with successful response' do
      before do
        stub_import_status(path, status)
      end

      context 'with a status' do
        let(:status) { 'this_is_a_test' }

        it { is_expected.to eq(status) }
      end

      context 'with no status' do
        let(:status) { nil }

        it { is_expected.to eq('error') }
      end
    end

    context 'with non successful response' do
      before do
        stub_import_status(path, nil, status_code: 404)
      end

      it { is_expected.to eq('pre_import_failed') }
    end
  end

  describe '#repository_details' do
    let(:path) { 'namespace/path/to/repository' }
    let(:response) { { foo: :bar, this: :is_a_test } }

    subject { client.repository_details(path, sizing: sizing) }

    [:self, :self_with_descendants, nil].each do |size_type|
      context "with sizing #{size_type}" do
        let(:sizing) { size_type }

        before do
          stub_repository_details(path, sizing: sizing, respond_with: response)
        end

        it { is_expected.to eq(response.stringify_keys.deep_transform_values(&:to_s)) }
      end
    end

    context 'with non successful response' do
      let(:sizing) { nil }

      before do
        stub_repository_details(path, sizing: sizing, status_code: 404)
      end

      it { is_expected.to eq({}) }
    end
  end

  describe '#tags' do
    let(:path) { 'namespace/path/to/repository' }
    let(:page_size) { 100 }
    let(:last) { nil }
    let(:response) do
      [
        {
          name: '0.1.0',
          digest: 'sha256:1234567890',
          media_type: 'application/vnd.oci.image.manifest.v1+json',
          size_bytes: 1234567890,
          created_at: 5.minutes.ago
        },
        {
          name: 'latest',
          digest: 'sha256:1234567892',
          media_type: 'application/vnd.oci.image.manifest.v1+json',
          size_bytes: 1234567892,
          created_at: 10.minutes.ago
        }
      ]
    end

    subject { client.tags(path, page_size: page_size, last: last) }

    context 'with valid parameters' do
      let(:expected) do
        {
          pagination: {},
          response_body: ::Gitlab::Json.parse(response.to_json)
        }
      end

      before do
        stub_tags(path, page_size: page_size, respond_with: response)
      end

      it { is_expected.to eq(expected) }
    end

    context 'with a response with a link header' do
      let(:next_page_url) { 'http://sandbox.org/test?last=b' }
      let(:expected) do
        {
          pagination: { next: { uri: URI(next_page_url) } },
          response_body: ::Gitlab::Json.parse(response.to_json)
        }
      end

      before do
        stub_tags(path, page_size: page_size, next_page_url: next_page_url, respond_with: response)
      end

      it { is_expected.to eq(expected) }
    end

    context 'with a large page size set' do
      let(:page_size) { described_class::MAX_TAGS_PAGE_SIZE + 1000 }

      let(:expected) do
        {
          pagination: {},
          response_body: ::Gitlab::Json.parse(response.to_json)
        }
      end

      before do
        stub_tags(path, page_size: described_class::MAX_TAGS_PAGE_SIZE, respond_with: response)
      end

      it { is_expected.to eq(expected) }
    end

    context 'with a last parameter set' do
      let(:last) { 'test' }

      let(:expected) do
        {
          pagination: {},
          response_body: ::Gitlab::Json.parse(response.to_json)
        }
      end

      before do
        stub_tags(path, page_size: page_size, last: last, respond_with: response)
      end

      it { is_expected.to eq(expected) }
    end

    context 'with non successful response' do
      before do
        stub_tags(path, page_size: page_size, status_code: 404)
      end

      it 'logs an error and returns an empty hash' do
        expect(Gitlab::ErrorTracking)
          .to receive(:log_exception).with(
            instance_of(described_class::UnsuccessfulResponseError),
            class: described_class.name,
            url: "/gitlab/v1/repositories/#{path}/tags/list/",
            status_code: 404
          )
        expect(subject).to eq({})
      end
    end
  end

  describe '#sub_repositories_with_tag' do
    let(:path) { 'namespace/path/to/repository' }
    let(:page_size) { 100 }
    let(:last) { nil }
    let(:response) do
      [
        {
          "name": "docker-alpine",
          "path": "gitlab-org/build/cng/docker-alpine",
          "created_at": "2022-06-07T12:11:13.633+00:00",
          "updated_at": "2022-06-07T14:37:49.251+00:00"
        },
        {
          "name": "git-base",
          "path": "gitlab-org/build/cng/git-base",
          "created_at": "2022-06-07T12:11:13.633+00:00",
          "updated_at": "2022-06-07T14:37:49.251+00:00"
        }
      ]
    end

    let(:result_with_no_pagination) do
      {
        pagination: {},
        response_body: ::Gitlab::Json.parse(response.to_json)
      }
    end

    subject { client.sub_repositories_with_tag(path, page_size: page_size, last: last) }

    context 'with valid parameters' do
      before do
        stub_sub_repositories_with_tag(path, page_size: page_size, respond_with: response)
      end

      it { is_expected.to eq(result_with_no_pagination) }
    end

    context 'with a response with a link header' do
      let(:next_page_url) { 'http://sandbox.org/test?last=c' }
      let(:expected) do
        {
          pagination: { next: { uri: URI(next_page_url) } },
          response_body: ::Gitlab::Json.parse(response.to_json)
        }
      end

      before do
        stub_sub_repositories_with_tag(path, page_size: page_size, next_page_url: next_page_url, respond_with: response)
      end

      it { is_expected.to eq(expected) }
    end

    context 'with a large page size set' do
      let(:page_size) { described_class::MAX_TAGS_PAGE_SIZE + 1000 }

      before do
        stub_sub_repositories_with_tag(path, page_size: described_class::MAX_TAGS_PAGE_SIZE, respond_with: response)
      end

      it { is_expected.to eq(result_with_no_pagination) }
    end

    context 'with a last parameter set' do
      let(:last) { 'test' }

      before do
        stub_sub_repositories_with_tag(path, page_size: page_size, last: last, respond_with: response)
      end

      it { is_expected.to eq(result_with_no_pagination) }
    end

    context 'with non successful response' do
      before do
        stub_sub_repositories_with_tag(path, page_size: page_size, status_code: 404)
      end

      it 'logs an error and returns an empty hash' do
        expect(Gitlab::ErrorTracking)
          .to receive(:log_exception).with(
            instance_of(described_class::UnsuccessfulResponseError),
            class: described_class.name,
            url: "/gitlab/v1/repository-paths/#{path}/repositories/list/",
            status_code: 404
          )
        expect(subject).to eq({})
      end
    end
  end

  describe '.supports_gitlab_api?' do
    subject { described_class.supports_gitlab_api? }

    where(:registry_gitlab_api_enabled, :is_on_dot_com, :container_registry_features, :expect_registry_to_be_pinged, :expected_result) do
      true  | true  | [described_class::REGISTRY_GITLAB_V1_API_FEATURE] | false | true
      true  | false | [described_class::REGISTRY_GITLAB_V1_API_FEATURE] | true  | true
      false | true  | [described_class::REGISTRY_GITLAB_V1_API_FEATURE] | false | true
      false | false | [described_class::REGISTRY_GITLAB_V1_API_FEATURE] | true  | false
      true  | true  | []                                                | true  | true
      true  | false | []                                                | true  | true
      false | true  | []                                                | true  | false
      false | false | []                                                | true  | false
    end

    with_them do
      before do
        allow(::Gitlab).to receive(:com?).and_return(is_on_dot_com)
        stub_container_registry_config(enabled: true, api_url: registry_api_url, key: 'spec/fixtures/x509_certificate_pk.key')
        stub_registry_gitlab_api_support(registry_gitlab_api_enabled)
        stub_application_setting(container_registry_features: container_registry_features)
      end

      it 'returns the expected result' do
        if expect_registry_to_be_pinged
          expect(Faraday::Connection).to receive(:new).and_call_original
        else
          expect(Faraday::Connection).not_to receive(:new)
        end

        expect(subject).to be expected_result
      end
    end

    context 'with the registry disabled' do
      before do
        stub_container_registry_config(enabled: false, api_url: 'http://sandbox.local', key: 'spec/fixtures/x509_certificate_pk.key')
      end

      it 'returns false' do
        expect(Faraday::Connection).not_to receive(:new)

        expect(subject).to be_falsey
      end
    end

    context 'with a blank registry url' do
      before do
        stub_container_registry_config(enabled: true, api_url: '', key: 'spec/fixtures/x509_certificate_pk.key')
      end

      it 'returns false' do
        expect(Faraday::Connection).not_to receive(:new)

        expect(subject).to be_falsey
      end
    end
  end

  describe '.deduplicated_size' do
    let(:path) { 'foo/bar' }
    let(:response) { { 'size_bytes': 555 } }
    let(:registry_enabled) { true }

    subject { described_class.deduplicated_size(path) }

    before do
      stub_container_registry_config(enabled: registry_enabled, api_url: registry_api_url, key: 'spec/fixtures/x509_certificate_pk.key')
    end

    context 'with successful response' do
      before do
        expect(Auth::ContainerRegistryAuthenticationService).to receive(:pull_nested_repositories_access_token).with(path).and_return(token)
        stub_repository_details(path, sizing: :self_with_descendants, status_code: 200, respond_with: response)
      end

      it { is_expected.to eq(555) }
    end

    context 'with unsuccessful response' do
      before do
        expect(Auth::ContainerRegistryAuthenticationService).to receive(:pull_nested_repositories_access_token).with(path).and_return(token)
        stub_repository_details(path, sizing: :self_with_descendants, status_code: 404, respond_with: response)
      end

      it { is_expected.to eq(nil) }
    end

    context 'with the registry disabled' do
      let(:registry_enabled) { false }

      it { is_expected.to eq(nil) }
    end

    context 'with a nil path' do
      let(:path) { nil }
      let(:token) { nil }

      before do
        expect(Auth::ContainerRegistryAuthenticationService).not_to receive(:pull_nested_repositories_access_token)
        stub_repository_details(path, sizing: :self_with_descendants, status_code: 401, respond_with: response)
      end

      it { is_expected.to eq(nil) }
    end

    context 'with uppercase path' do
      let(:path) { 'foo/Bar' }

      before do
        expect(Auth::ContainerRegistryAuthenticationService).to receive(:pull_nested_repositories_access_token).with(path.downcase).and_return(token)
        expect_next_instance_of(described_class) do |client|
          expect(client).to receive(:repository_details).with(path.downcase, sizing: :self_with_descendants).and_return(response.with_indifferent_access).once
        end
      end

      it { is_expected.to eq(555) }
    end
  end

  describe '.one_project_with_container_registry_tag' do
    let(:path) { 'build/cng/docker-alpine' }
    let(:response_body) do
      [
        {
          "name" => "docker-alpine",
          "path" => path,
          "created_at" => "2022-06-07T12:11:13.633+00:00",
          "updated_at" => "2022-06-07T14:37:49.251+00:00"
        }
      ]
    end

    let(:response) do
      {
        pagination: { next: { uri: URI('http://sandbox.org/test?last=x') } },
        response_body: ::Gitlab::Json.parse(response_body.to_json)
      }
    end

    let_it_be(:group) { create(:group, path: 'build') }
    let_it_be(:project) { create(:project, path: 'cng', namespace: group) }
    let_it_be(:container_repository) { create(:container_repository, project: project, name: "docker-alpine") }

    shared_examples 'fetching the project from container repository and path' do
      it 'fetches the project from the given path details' do
        expect(ContainerRegistry::Path).to receive(:new).with(path).and_call_original
        expect(ContainerRepository).to receive(:find_by_path).and_call_original

        expect(subject).to eq(project)
      end

      it 'returns nil when path is invalid' do
        registry_path = ContainerRegistry::Path.new('invalid')
        expect(ContainerRegistry::Path).to receive(:new).with(path).and_return(registry_path)
        expect(registry_path.valid?).to eq(false)

        expect(subject).to eq(nil)
      end

      it 'returns nil when there is no container_repository matching the path' do
        expect(ContainerRegistry::Path).to receive(:new).with(path).and_call_original
        expect(ContainerRepository).to receive(:find_by_path).and_return(nil)

        expect(subject).to eq(nil)
      end
    end

    subject { described_class.one_project_with_container_registry_tag(path) }

    before do
      expect(Auth::ContainerRegistryAuthenticationService).to receive(:pull_nested_repositories_access_token).with(path.downcase).and_return(token)
      stub_container_registry_config(enabled: true, api_url: registry_api_url, key: 'spec/fixtures/x509_certificate_pk.key')
    end

    context 'with successful response' do
      before do
        stub_sub_repositories_with_tag(path, page_size: 1, respond_with: response_body)
      end

      it_behaves_like 'fetching the project from container repository and path'
    end

    context 'with unsuccessful response' do
      before do
        stub_sub_repositories_with_tag(path, page_size: 1, status_code: 404, respond_with: {})
      end

      it { is_expected.to eq(nil) }
    end

    context 'with uppercase path' do
      let(:path) { 'BuilD/CNG/docker-alpine' }

      before do
        expect_next_instance_of(described_class) do |client|
          expect(client).to receive(:sub_repositories_with_tag).with(path.downcase, page_size: 1).and_return(response.with_indifferent_access).once
        end
      end

      it_behaves_like 'fetching the project from container repository and path'
    end
  end

  describe '#each_sub_repositories_with_tag_page' do
    let(:page_size) { 100 }
    let(:project_path) { 'repo/project' }

    shared_examples 'iterating through a page' do |expected_tags: true|
      it 'iterates through one page' do
        expect_next_instance_of(described_class) do |client|
          expect(client).to receive(:sub_repositories_with_tag).with(project_path, page_size: page_size, last: nil).and_return(client_response)
        end

        expect { |b| described_class.each_sub_repositories_with_tag_page(path: project_path, page_size: page_size, &b) }
          .to yield_with_args(expected_tags ? client_response_repositories : [])
      end
    end

    context 'when no block is given' do
      it 'raises an Argument error' do
        expect do
          described_class.each_sub_repositories_with_tag_page(path: project_path, page_size: page_size)
        end.to raise_error(ArgumentError, 'block not given')
      end
    end

    context 'when a block is given' do
      before do
        expect(Auth::ContainerRegistryAuthenticationService).to receive(:pull_nested_repositories_access_token).with(project_path).and_return(token)
        stub_container_registry_config(enabled: true, api_url: registry_api_url, key: 'spec/fixtures/x509_certificate_pk.key')
      end

      context 'with an empty page' do
        let(:client_response) { { pagination: {}, response_body: [] } }

        it_behaves_like 'iterating through a page', expected_tags: false
      end

      context 'with one page' do
        let(:client_response) { { pagination: {}, response_body: client_response_repositories } }
        let(:client_response_repositories) do
          [
            {
              "name": "docker-alpine",
              "path": "gitlab-org/build/cng/docker-alpine",
              "created_at": "2022-06-07T12:11:13.633+00:00",
              "updated_at": "2022-06-07T14:37:49.251+00:00"
            },
            {
              "name": "git-base",
              "path": "gitlab-org/build/cng/git-base",
              "created_at": "2022-06-07T12:11:13.633+00:00",
              "updated_at": "2022-06-07T14:37:49.251+00:00"
            }
          ]
        end

        it_behaves_like 'iterating through a page'
      end

      context 'with two pages' do
        let(:client_response1) { { pagination: { next: { uri: URI('http://localhost/next?last=latest') } }, response_body: client_response_repositories1 } }
        let(:client_response_repositories1) do
          [
            {
              "name": "docker-alpine",
              "path": "gitlab-org/build/cng/docker-alpine",
              "created_at": "2022-06-07T12:11:13.633+00:00",
              "updated_at": "2022-06-07T14:37:49.251+00:00"
            },
            {
              "name": "git-base",
              "path": "gitlab-org/build/cng/git-base",
              "created_at": "2022-06-07T12:11:13.633+00:00",
              "updated_at": "2022-06-07T14:37:49.251+00:00"
            }
          ]
        end

        let(:client_response2) { { pagination: {}, response_body: client_response_repositories2 } }
        let(:client_response_repositories2) do
          [
            {
              "name": "docker-alpine1",
              "path": "gitlab-org/build/cng/docker-alpine",
              "created_at": "2022-06-07T12:11:13.633+00:00",
              "updated_at": "2022-06-07T14:37:49.251+00:00"
            },
            {
              "name": "git-base1",
              "path": "gitlab-org/build/cng/git-base",
              "created_at": "2022-06-07T12:11:13.633+00:00",
              "updated_at": "2022-06-07T14:37:49.251+00:00"
            }
          ]
        end

        it 'iterates through two pages' do
          expect_next_instance_of(described_class) do |client|
            expect(client).to receive(:sub_repositories_with_tag).with(project_path, page_size: page_size, last: nil).and_return(client_response1)
            expect(client).to receive(:sub_repositories_with_tag).with(project_path, page_size: page_size, last: 'latest').and_return(client_response2)
          end

          expect { |b| described_class.each_sub_repositories_with_tag_page(path: project_path, page_size: page_size, &b) }
            .to yield_successive_args(client_response_repositories1, client_response_repositories2)
        end
      end

      context 'when max pages is reached' do
        let(:client_response) { { pagination: {}, response_body: [] } }

        before do
          stub_const('ContainerRegistry::GitlabApiClient::MAX_REPOSITORIES_PAGE_SIZE', 0)
          expect_next_instance_of(described_class) do |client|
            expect(client).to receive(:sub_repositories_with_tag).with(project_path, page_size: page_size, last: nil).and_return(client_response)
          end
        end

        it 'raises an error' do
          expect { described_class.each_sub_repositories_with_tag_page(path: project_path, page_size: page_size) {} } # rubocop:disable Lint/EmptyBlock
            .to raise_error(StandardError, 'too many pages requested')
        end
      end

      context 'without a page size set' do
        let(:client_response) { { pagination: {}, response_body: [] } }

        it 'uses a default size' do
          expect_next_instance_of(described_class) do |client|
            expect(client).to receive(:sub_repositories_with_tag).with(project_path, page_size: page_size, last: nil).and_return(client_response)
          end

          expect { |b| described_class.each_sub_repositories_with_tag_page(path: project_path, &b) }.to yield_with_args([])
        end
      end

      context 'with an empty client response' do
        let(:client_response) { {} }

        it 'breaks the loop' do
          expect_next_instance_of(described_class) do |client|
            expect(client).to receive(:sub_repositories_with_tag).with(project_path, page_size: page_size, last: nil).and_return(client_response)
          end

          expect { |b| described_class.each_sub_repositories_with_tag_page(path: project_path, page_size: page_size, &b) }.not_to yield_control
        end
      end

      context 'with a nil page' do
        let(:client_response) { { pagination: {}, response_body: nil } }

        it_behaves_like 'iterating through a page', expected_tags: false
      end
    end
  end

  def stub_pre_import(path, status_code, pre:)
    import_type = pre ? 'pre' : 'final'
    stub_request(:put, "#{registry_api_url}/gitlab/v1/import/#{path}/?import_type=#{import_type}")
      .with(headers: { 'Accept' => described_class::JSON_TYPE, 'Authorization' => "bearer #{import_token}" })
      .to_return(status: status_code, body: '')
  end

  def stub_registry_gitlab_api_support(supported = true)
    status_code = supported ? 200 : 404
    stub_request(:get, "#{registry_api_url}/gitlab/v1/")
      .with(headers: { 'Accept' => described_class::JSON_TYPE })
      .to_return(status: status_code, body: '')
  end

  def stub_import_status(path, status, status_code: 200)
    stub_request(:get, "#{registry_api_url}/gitlab/v1/import/#{path}/")
      .with(headers: { 'Accept' => described_class::JSON_TYPE, 'Authorization' => "bearer #{import_token}" })
      .to_return(
        status: status_code,
        body: { status: status }.to_json,
        headers: { content_type: 'application/json' }
      )
  end

  def stub_import_cancel(path, http_status, status: nil, force: false)
    body = {}

    if http_status == 400
      body = { status: status }
    end

    headers = {
      'Accept' => described_class::JSON_TYPE,
      'Authorization' => "bearer #{import_token}",
      'User-Agent' => "GitLab/#{Gitlab::VERSION}",
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3'
    }

    params = force ? '?force=true' : ''

    stub_request(:delete, "#{registry_api_url}/gitlab/v1/import/#{path}/#{params}")
      .with(headers: headers)
      .to_return(
        status: http_status,
        body: body.to_json,
        headers: { content_type: 'application/json' }
      )
  end

  def stub_repository_details(path, sizing: nil, status_code: 200, respond_with: {})
    url = "#{registry_api_url}/gitlab/v1/repositories/#{path}/"
    url += "?size=#{sizing}" if sizing

    headers = { 'Accept' => described_class::JSON_TYPE }
    headers['Authorization'] = "bearer #{token}" if token

    stub_request(:get, url)
      .with(headers: headers)
      .to_return(status: status_code, body: respond_with.to_json, headers: { 'Content-Type' => described_class::JSON_TYPE })
  end

  def stub_tags(path, page_size: nil, last: nil, next_page_url: nil, status_code: 200, respond_with: {})
    params = { n: page_size, last: last }.compact

    url = "#{registry_api_url}/gitlab/v1/repositories/#{path}/tags/list/"

    if params.present?
      url += "?#{params.map { |param, val| "#{param}=#{val}" }.join('&')}"
    end

    request_headers = { 'Accept' => described_class::JSON_TYPE }
    request_headers['Authorization'] = "bearer #{token}" if token

    response_headers = { 'Content-Type' => described_class::JSON_TYPE }
    if next_page_url
      response_headers['Link'] = "<#{next_page_url}>; rel=\"next\""
    end

    stub_request(:get, url)
      .with(headers: request_headers)
      .to_return(
        status: status_code,
        body: respond_with.to_json,
        headers: response_headers
      )
  end

  def stub_sub_repositories_with_tag(path, page_size: nil, last: nil, next_page_url: nil, status_code: 200, respond_with: {})
    params = { n: page_size, last: last }.compact

    url = "#{registry_api_url}/gitlab/v1/repository-paths/#{path}/repositories/list/"

    if params.present?
      url += "?#{params.map { |param, val| "#{param}=#{val}" }.join('&')}"
    end

    request_headers = { 'Accept' => described_class::JSON_TYPE }
    request_headers['Authorization'] = "bearer #{token}" if token

    response_headers = { 'Content-Type' => described_class::JSON_TYPE }
    if next_page_url
      response_headers['Link'] = "<#{next_page_url}>; rel=\"next\""
    end

    stub_request(:get, url)
      .with(headers: request_headers)
      .to_return(
        status: status_code,
        body: respond_with.to_json,
        headers: response_headers
      )
  end
end
