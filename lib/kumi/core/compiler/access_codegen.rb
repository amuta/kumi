# frozen_string_literal: true

require "digest/sha1"

module Kumi
  module Core
    module Compiler
      class AccessCodegen
        CACHE = {}
        CACHE_MUTEX = Mutex.new

        def self.fetch_or_compile(plan)
          key = Digest::SHA1.hexdigest(Marshal.dump([plan.mode, plan.operations, plan.on_missing, plan.key_policy, plan.path]))
          CACHE_MUTEX.synchronize do
            CACHE[key] ||= compile(plan).tap(&:freeze)
          end
        end

        def self.compile(plan)
          case plan.mode
          when :read         then gen_read(plan)
          when :materialize  then gen_materialize(plan)
          when :ravel        then gen_ravel(plan)
          when :each_indexed then gen_each_indexed(plan)
          else
            raise "Unknown accessor mode: #{plan.mode.inspect}"
          end
        end

        private_class_method def self.gen_read(plan)
          code = AccessEmit::Read.build(plan)
          debug_code(code, plan, "READ") if ENV["DEBUG_CODEGEN"]
          eval(code, TOPLEVEL_BINDING)
        end

        private_class_method def self.gen_materialize(plan)
          code = AccessEmit::Materialize.build(plan)
          debug_code(code, plan, "MATERIALIZE") if ENV["DEBUG_CODEGEN"]
          eval(code, TOPLEVEL_BINDING)
        end

        private_class_method def self.gen_ravel(plan)
          code = AccessEmit::Ravel.build(plan)
          debug_code(code, plan, "RAVEL") if ENV["DEBUG_CODEGEN"]
          eval(code, TOPLEVEL_BINDING)
        end

        private_class_method def self.gen_each_indexed(plan)
          code = AccessEmit::EachIndexed.build(plan)
          debug_code(code, plan, "EACH_INDEXED") if ENV["DEBUG_CODEGEN"]
          eval(code, TOPLEVEL_BINDING)
        end

        private_class_method def self.debug_code(code, plan, mode_name)
          puts "=== Generated #{mode_name} code for #{plan.path}:#{plan.mode} ==="
          puts code
        end
      end
    end
  end
end
