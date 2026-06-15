# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class IRValidatePass < PassBase
          class << self
            attr_reader :module_key, :validator, :unoptimized_key, :registry_aware

            def validates(module_key, with:, unoptimized_key: nil, registry: false)
              @module_key = module_key
              @validator = with
              @unoptimized_key = unoptimized_key
              @registry_aware = registry
              optional_reads module_key
              optional_reads unoptimized_key if unoptimized_key
              optional_reads :registry if registry
              writes
            end
          end

          def run(_errors)
            config = self.class
            if config.unoptimized_key && (unoptimized = state[config.unoptimized_key])
              config.validator.validate!(unoptimized, allow_fold: true, registry: state[:registry])
            end

            if (ir_module = state[config.module_key])
              if config.registry_aware
                config.validator.validate!(ir_module, registry: state[:registry])
              else
                config.validator.validate!(ir_module)
              end
            end

            state
          end
        end
      end
    end
  end
end
