# frozen_string_literal: true

require 'rspec-parameterized'
require_relative '../../support/helpers/stub_env'

require_relative '../../../tooling/rspec_flaky/config'

RSpec.describe RspecFlaky::Config, :aggregate_failures do
  include StubENV

  before do
    # Stub these env variables otherwise specs don't behave the same on the CI
    stub_env('FLAKY_RSPEC_GENERATE_REPORT', nil)
    stub_env('FLAKY_RSPEC_SUITE_REPORT_PATH', nil)
    stub_env('FLAKY_RSPEC_REPORT_PATH', nil)
    stub_env('NEW_FLAKY_RSPEC_REPORT_PATH', nil)
    # Ensure the behavior is the same locally and on CI (where Rails is defined since we run this test as part of the whole suite), i.e. Rails isn't defined
    allow(described_class).to receive(:rails_path).and_wrap_original do |method, path|
      path
    end
  end

  describe '.generate_report?' do
    context "when ENV['FLAKY_RSPEC_GENERATE_REPORT'] is not set" do
      it 'returns false' do
        expect(described_class).not_to be_generate_report
      end
    end

    context "when ENV['FLAKY_RSPEC_GENERATE_REPORT'] is set" do
      using RSpec::Parameterized::TableSyntax

      where(:env_value, :result) do
        '1'      | true
        'true'   | true
        'foo'    | false
        '0'      | false
        'false'  | false
      end

      with_them do
        before do
          stub_env('FLAKY_RSPEC_GENERATE_REPORT', env_value)
        end

        it 'returns false' do
          expect(described_class.generate_report?).to be(result)
        end
      end
    end
  end

  describe '.suite_flaky_examples_report_path' do
    context "when ENV['FLAKY_RSPEC_SUITE_REPORT_PATH'] is not set" do
      it 'returns the default path' do
        expect(described_class.suite_flaky_examples_report_path).to eq('rspec/flaky/suite-report.json')
      end
    end

    context "when ENV['FLAKY_RSPEC_SUITE_REPORT_PATH'] is set" do
      before do
        stub_env('FLAKY_RSPEC_SUITE_REPORT_PATH', 'foo/suite-report.json')
      end

      it 'returns the value of the env variable' do
        expect(described_class.suite_flaky_examples_report_path).to eq('foo/suite-report.json')
      end
    end
  end

  describe '.flaky_examples_report_path' do
    context "when ENV['FLAKY_RSPEC_REPORT_PATH'] is not set" do
      it 'returns the default path' do
        expect(described_class.flaky_examples_report_path).to eq('rspec/flaky/report.json')
      end
    end

    context "when ENV['FLAKY_RSPEC_REPORT_PATH'] is set" do
      before do
        stub_env('FLAKY_RSPEC_REPORT_PATH', 'foo/report.json')
      end

      it 'returns the value of the env variable' do
        expect(described_class.flaky_examples_report_path).to eq('foo/report.json')
      end
    end
  end

  describe '.new_flaky_examples_report_path' do
    context "when ENV['NEW_FLAKY_RSPEC_REPORT_PATH'] is not set" do
      it 'returns the default path' do
        expect(described_class.new_flaky_examples_report_path).to eq('rspec/flaky/new-report.json')
      end
    end

    context "when ENV['NEW_FLAKY_RSPEC_REPORT_PATH'] is set" do
      before do
        stub_env('NEW_FLAKY_RSPEC_REPORT_PATH', 'foo/new-report.json')
      end

      it 'returns the value of the env variable' do
        expect(described_class.new_flaky_examples_report_path).to eq('foo/new-report.json')
      end
    end
  end
end
