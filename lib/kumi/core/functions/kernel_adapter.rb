# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      KernelHandle = Struct.new(:kind, :callable, :null_policy, :options, keyword_init: true)

      module KernelAdapter
        module_function

        def build_for(function, backend_entry)
          impl = backend_entry.impl
          mod = ruby_module_for(function)

          raise Kumi::Core::Errors::CompilationError, "Missing Ruby kernel #{impl} for #{function.name}" unless mod.respond_to?(impl)

          kind = function.class_sym
          KernelHandle.new(
            kind: kind,
            callable: mod.method(impl),
            null_policy: function.null_policy,
            options: function.options || {}
          )
        end

        def ruby_module_for(function)
          case function.domain.to_sym
          when :core
            function.class_sym == :aggregate ? Kumi::Kernels::Ruby::AggregateCore : Kumi::Kernels::Ruby::ScalarCore
          when :string
            Kumi::Kernels::Ruby::StringScalar
          when :datetime
            Kumi::Kernels::Ruby::DatetimeScalar
          when :struct
            Kumi::Kernels::Ruby::VectorStruct
          when :mask
            Kumi::Kernels::Ruby::MaskScalar
          else
            raise Kumi::Core::Errors::CompilationError, "Unknown domain #{function.domain}"
          end
        end
      end
    end
  end
end