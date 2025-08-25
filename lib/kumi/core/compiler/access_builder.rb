module Kumi
  module Core
    module Compiler
      class AccessBuilder
        class << self
          attr_accessor :yjit
        end
        self.yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?

        def self.build(plans, strategy: nil)
          strategy ||= yjit ? :interp : :codegen
          accessors = {}

          plans.each_value do |variants|
            variants.each do |plan|
              accessors[plan.accessor_key] =
                case strategy
                when :codegen then AccessCodegen.fetch_or_compile(plan)
                else
                  build_proc_for(
                    mode: plan.mode,
                    path_key: plan.path,
                    missing: (plan.on_missing || :error).to_sym,
                    key_policy: (plan.key_policy || :indifferent).to_sym,
                    operations: plan.operations
                  )
                end
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
