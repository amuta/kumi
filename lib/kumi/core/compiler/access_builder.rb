module Kumi
  module Core
    module Compiler
      class AccessBuilder
        def self.build(plans)
          accessors = {}
          plans.each_value do |variants|
            variants.each do |plan|
              accessors[plan.accessor_key] = build_proc_for(
                mode: plan.mode,
                path_key: plan.path,
                missing: (plan.on_missing || :error).to_sym,
                key_policy: (plan.key_policy || :indifferent).to_sym,
                operations: plan.operations
              )
            end
          end
          accessors.freeze
        end

        def self.build_proc_for(mode:, path_key:, missing:, key_policy:, operations:)
          case mode
          when :read        then Accessors::ReadAccessor.build(operations, path_key, missing, key_policy)
          when :materialize then Accessors::MaterializeAccessor.build(operations, path_key, missing, key_policy)
          when :ravel       then Accessors::RavelAccessor.build(operations, path_key, missing, key_policy)
          when :each_indexed then Accessors::EachIndexedAccessor.build(operations, path_key, missing, key_policy, true)
          else
            raise "Unknown accessor mode: #{mode.inspect}"
          end
        end
      end
    end
  end
end
