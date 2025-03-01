# frozen_string_literal: true

# Interface to the Redis-backed cache store to keep track of complete cache keys
# for a ReactiveCache resource.
module Gitlab
  class ReactiveCacheSetCache < Gitlab::SetCache
    attr_reader :expires_in

    def initialize(expires_in: 10.minutes)
      @expires_in = expires_in
    end

    def clear_cache!(key)
      with do |redis|
        keys = read(key).map { |value| "#{cache_namespace}:#{value}" }
        keys << cache_key(key)

        Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
          if ::Feature.enabled?(:use_pipeline_over_multikey)
            keys.each_slice(1000) do |subset|
              redis.pipelined do |pipeline|
                subset.each { |key| pipeline.unlink(key) }
              end
            end
          else
            redis.pipelined do |pipeline|
              keys.each_slice(1000) { |subset| pipeline.unlink(*subset) }
            end
          end
        end
      end
    end
  end
end
