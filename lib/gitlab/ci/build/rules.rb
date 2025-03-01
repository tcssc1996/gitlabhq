# frozen_string_literal: true

module Gitlab
  module Ci
    module Build
      class Rules
        include ::Gitlab::Utils::StrongMemoize

        Result = Struct.new(:when, :start_in, :allow_failure, :variables, :needs, :errors) do
          def build_attributes
            {
              when: self.when,
              options: { start_in: start_in }.compact,
              allow_failure: allow_failure,
              scheduling_type: (:dag if needs),
              needs_attributes: needs&.[](:job)
            }.compact
          end

          def pass?
            self.when != 'never'
          end
        end

        def initialize(rule_hashes, default_when:)
          @rule_list    = Rule.fabricate_list(rule_hashes)
          @default_when = default_when
        end

        def evaluate(pipeline, context)
          if @rule_list.nil?
            Result.new(@default_when)
          elsif matched_rule = match_rule(pipeline, context)
            Result.new(
              matched_rule.attributes[:when] || @default_when,
              matched_rule.attributes[:start_in],
              matched_rule.attributes[:allow_failure],
              matched_rule.attributes[:variables],
              (matched_rule.attributes[:needs] if Feature.enabled?(:introduce_rules_with_needs, pipeline.project))
            )
          else
            Result.new('never')
          end
        rescue Rule::Clause::ParseError => e
          Result.new('never', nil, nil, nil, nil, [e.message])
        end

        private

        def match_rule(pipeline, context)
          @rule_list.find { |rule| rule.matches?(pipeline, context) }
        end
      end
    end
  end
end
