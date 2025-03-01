# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SidekiqMiddleware::DeferJobs, feature_category: :scalability do
  let(:job) { { 'jid' => 123, 'args' => [456] } }
  let(:queue) { 'test_queue' }
  let(:worker) do
    Class.new do
      def self.name
        'TestDeferredWorker'
      end
      include ApplicationWorker
    end
  end

  let(:worker2) do
    Class.new do
      def self.name
        'UndeferredWorker'
      end
      include ApplicationWorker
    end
  end

  subject { described_class.new }

  before do
    stub_const('TestDeferredWorker', worker)
    stub_const('UndeferredWorker', worker2)
  end

  describe '#call' do
    context 'when sidekiq_defer_jobs feature flag is enabled for a worker' do
      before do
        stub_feature_flags("defer_sidekiq_jobs:#{TestDeferredWorker.name}": true)
        stub_feature_flags("defer_sidekiq_jobs:#{UndeferredWorker.name}": false)
      end

      context 'for the affected worker' do
        it 'defers the job' do
          expect(TestDeferredWorker).to receive(:perform_in).with(described_class::DELAY, *job['args'])
          expect(Sidekiq.logger).to receive(:info).with(
            class: TestDeferredWorker.name,
            job_id: job['jid'],
            message: "Deferring #{TestDeferredWorker.name} for #{described_class::DELAY} s with arguments " \
                     "(#{job['args'].inspect})"
          )
          expect { |b| subject.call(TestDeferredWorker.new, job, queue, &b) }.not_to yield_control
        end
      end

      context 'for other workers' do
        it 'runs the job normally' do
          expect { |b| subject.call(UndeferredWorker.new, job, queue, &b) }.to yield_control
        end
      end
    end

    context 'when sidekiq_defer_jobs feature flag is disabled' do
      before do
        stub_feature_flags("defer_sidekiq_jobs:#{TestDeferredWorker.name}": false)
        stub_feature_flags("defer_sidekiq_jobs:#{UndeferredWorker.name}": false)
      end

      it 'runs the job normally' do
        expect { |b| subject.call(TestDeferredWorker.new, job, queue, &b) }.to yield_control
        expect { |b| subject.call(UndeferredWorker.new, job, queue, &b) }.to yield_control
      end
    end
  end
end
