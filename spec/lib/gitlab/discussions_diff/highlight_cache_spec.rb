# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DiscussionsDiff::HighlightCache, :clean_gitlab_redis_cache do
  def fake_file(offset)
    {
      text: 'foo',
      type: 'new',
      index: 2 + offset,
      old_pos: 10 + offset,
      new_pos: 11 + offset,
      line_code: 'xpto',
      rich_text: '<blips>blops</blips>'
    }
  end

  let(:mapping) do
    {
      3 => [
        fake_file(0),
        fake_file(1)
      ],
      4 => [
        fake_file(2)
      ]
    }
  end

  describe '#write_multiple' do
    it 'sets multiple keys serializing content as JSON' do
      described_class.write_multiple(mapping)

      mapping.each do |key, value|
        full_key = described_class.cache_key_for(key)
        found_key = Gitlab::Redis::Cache.with { |r| r.get(full_key) }

        expect(described_class.gzip_decompress(found_key)).to eq(value.to_json)
      end
    end
  end

  describe '#read_multiple' do
    shared_examples 'read multiple keys' do
      it 'reads multiple keys and serializes content into Gitlab::Diff::Line objects' do
        described_class.write_multiple(mapping)

        found = described_class.read_multiple(mapping.keys)

        expect(found.size).to eq(2)
        expect(found.first.size).to eq(2)
        expect(found.first).to all(be_a(Gitlab::Diff::Line))
      end

      it 'returns nil when cached key is not found' do
        described_class.write_multiple(mapping)

        found = described_class.read_multiple([2, 3])

        expect(found.size).to eq(2)

        expect(found.first).to eq(nil)
        expect(found.second.size).to eq(2)
        expect(found.second).to all(be_a(Gitlab::Diff::Line))
      end

      it 'returns lines which rich_text are HTML-safe' do
        described_class.write_multiple(mapping)

        found = described_class.read_multiple(mapping.keys)
        rich_texts = found.flatten.map(&:rich_text)

        expect(rich_texts).to all(be_html_safe)
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(use_pipeline_over_multikey: false)
      end

      it_behaves_like 'read multiple keys'
    end

    it_behaves_like 'read multiple keys'
  end

  describe '#clear_multiple' do
    shared_examples 'delete multiple keys' do
      it 'removes all named keys' do
        described_class.write_multiple(mapping)

        described_class.clear_multiple(mapping.keys)

        expect(described_class.read_multiple(mapping.keys)).to all(be_nil)
      end

      it 'only removed named keys' do
        to_clear, to_leave = mapping.keys

        described_class.write_multiple(mapping)
        described_class.clear_multiple([to_clear])

        cleared, left = described_class.read_multiple([to_clear, to_leave])

        expect(cleared).to be_nil
        expect(left).to all(be_a(Gitlab::Diff::Line))
      end
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(use_pipeline_over_multikey: false)
      end

      it_behaves_like 'delete multiple keys'
    end

    it_behaves_like 'delete multiple keys'
  end
end
