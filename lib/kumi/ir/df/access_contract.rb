# frozen_string_literal: true

module Kumi
  module IR
    module DF
      class AccessContract
        def initialize(input_table)
          @plan_refs = build_plan_refs(input_table)
        end

        def plans?
          !@plan_refs.empty?
        end

        def plan_ref_for!(path_segments)
          return nil unless plans?

          key = fqn(path_segments)
          @plan_refs.fetch(key) do
            raise ArgumentError, "DFIR access contract missing input plan for #{key.inspect}"
          end
        end

        # DFIR owns path structure explicitly:
        # - load_input opens the root input key only
        # - load_field instructions represent every remaining path segment
        # Any SNAST key_chain is frontend/access-planner context and must not be
        # duplicated into load_input once DFIR emits the field chain.
        def load_input_chain_for(_node)
          []
        end

        private

        def build_plan_refs(table)
          refs = {}

          each_entry(table) do |key, entry|
            ref = extract_plan_ref(entry) || normalize_fqn_key(key)
            next unless ref

            raise ArgumentError, "DFIR access contract has ambiguous input plan for #{ref.inspect}" if refs.key?(ref)

            refs[ref] = ref
          end

          refs
        end

        def each_entry(table, &)
          case table
          when Hash
            table.each(&)
          when Array
            table.each { |entry| yield nil, entry }
          end
        end

        def extract_plan_ref(entry)
          return entry.path_fqn.to_s if entry.respond_to?(:path_fqn) && entry.path_fqn

          return nil unless entry.respond_to?(:[]) && entry.respond_to?(:key?)

          return entry[:path_fqn].to_s if entry.key?(:path_fqn)
          return entry["path_fqn"].to_s if entry.key?("path_fqn")
          return entry[:fqn].to_s if entry.key?(:fqn)
          return entry["fqn"].to_s if entry.key?("fqn")

          nil
        end

        def normalize_fqn_key(key)
          return nil if key.nil?
          return key.to_s if key.is_a?(String) || key.is_a?(Symbol)

          key.respond_to?(:to_str) ? key.to_str : key.to_s
        end

        def fqn(path_segments)
          Array(path_segments).map(&:to_s).join(".")
        end
      end
    end
  end
end
