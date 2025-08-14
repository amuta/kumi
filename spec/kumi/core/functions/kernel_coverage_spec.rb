# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Kernel Coverage", type: :integration do
  before do
    skip unless ENV["KUMI_FN_REGISTRY_V2"] == "1"
  end

  describe "Ruby kernel coverage" do
    it "ensures every registry function has a Ruby kernel implementation" do
      registry = Kumi::Core::Functions::RegistryV2.load_from_file
      functions = registry.all_functions

      missing_kernels = []

      functions.each do |fn|
        ruby_kernels = fn.kernels.select { |k| k.backend.to_s == "ruby" }
        
        ruby_kernels.each do |kernel|
          begin
            mod = Kumi::Core::Functions::KernelAdapter.ruby_module_for(fn)
            unless mod.respond_to?(kernel.impl)
              missing_kernels << "Missing Ruby kernel #{kernel.impl} for #{fn.name} in #{mod}"
            end
          rescue => e
            missing_kernels << "Error resolving module for #{fn.name}: #{e.message}"
          end
        end
      end

      if missing_kernels.any?
        fail "Missing Ruby kernel implementations:\n" + missing_kernels.join("\n")
      end
    end

    it "ensures kernel adapter can build handles for all functions" do
      registry = Kumi::Core::Functions::RegistryV2.load_from_file
      functions = registry.all_functions

      functions.each do |fn|
        ruby_kernels = fn.kernels.select { |k| k.backend.to_s == "ruby" }
        
        ruby_kernels.each do |kernel|
          begin
            handle = Kumi::Core::Functions::KernelAdapter.build_for(fn, kernel)
            expect([:scalar, :aggregate, :vector, :structure]).to include(handle.kind)
            expect(handle.callable).to respond_to(:call)
            expect(handle.null_policy).to be_a(Symbol)
            expect(handle.options).to be_a(Hash)
          rescue => e
            fail "Failed to build kernel handle for #{fn.name}: #{e.message}\n#{e.backtrace.first(3).join("\n")}"
          end
        end
      end
    end

    it "ensures all kernel methods have correct arity" do
      registry = Kumi::Core::Functions::RegistryV2.load_from_file
      functions = registry.all_functions

      functions.each do |fn|
        ruby_kernels = fn.kernels.select { |k| k.backend.to_s == "ruby" }
        
        ruby_kernels.each do |kernel|
          mod = Kumi::Core::Functions::KernelAdapter.ruby_module_for(fn)
          next unless mod.respond_to?(kernel.impl)

          method = mod.method(kernel.impl)
          
          case fn.class_sym
          when :scalar
            expect(method.arity).to be > 0, "Scalar kernel #{kernel.impl} for #{fn.name} should accept arguments"
          when :aggregate
            # Aggregate methods may have keyword arguments, so check parameters
            params = method.parameters
            pos_args = params.count { |type, _| [:req, :opt].include?(type) }
            expect(pos_args).to be >= 1, "Aggregate kernel #{kernel.impl} for #{fn.name} should accept at least enum argument"
          when :vector, :structure
            expect(method.arity.abs).to be >= 1, "Vector/structure kernel #{kernel.impl} for #{fn.name} should accept at least one argument"
          end
        end
      end
    end
  end
end