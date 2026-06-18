# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        # Base class for analyzer passes with simple immutable state
        class PassBase
          include Kumi::Syntax
          include Kumi::Core::ErrorReporting

          class << self
            def reads(*keys)
              keys.each do |key|
                own_reads << key
                define_method(key) { get_state(key) }
              end
              mark_contract!
            end

            def optional_reads(*keys)
              keys.each do |key|
                own_optional_reads << key
                define_method(key) { state[key] }
              end
              mark_contract!
            end

            def writes(*keys)
              own_writes.concat(keys)
              mark_contract!
            end

            def declared_reads
              inherited_contract(:declared_reads) + own_reads
            end

            def declared_optional_reads
              inherited_contract(:declared_optional_reads) + own_optional_reads
            end

            def declared_writes
              inherited_contract(:declared_writes) + own_writes
            end

            def contract_declared?
              return true if defined?(@contract_declared) && @contract_declared

              superclass.respond_to?(:contract_declared?) && superclass.contract_declared?
            end

            private

            def mark_contract!
              @contract_declared = true
            end

            def own_reads = @own_reads ||= []
            def own_optional_reads = @own_optional_reads ||= []
            def own_writes = @own_writes ||= []

            def inherited_contract(method_name)
              superclass.respond_to?(method_name) ? superclass.public_send(method_name) : []
            end
          end

          # @param schema [Syntax::Root] The schema to analyze
          # @param state [AnalysisState] Current analysis state
          def initialize(schema, state)
            @schema = schema
            @state = state
          end

          # Sentinel thrown by halt_pass! to stop a pass after a user error has
          # been recorded, without raising an exception (which PassManager would
          # otherwise wrap as a second, internal-looking error).
          HALT = :kumi_pass_halt

          # Main pass execution - subclasses implement this
          # @param errors [Array] Error accumulator array
          # @return [AnalysisState] New state after pass execution
          def run(errors)
            raise NotImplementedError, "#{self.class.name} must implement #run"
          end

          # Debug helpers - automatic pattern based on pass class name
          # InputIndexTablePass -> DEBUG_INPUT_INDEX_TABLE=1
          # ScopeResolutionPass -> DEBUG_SCOPE_RESOLUTION=1
          def debug_enabled?
            class_name = self.class.name.split("::").last
            env_name = "DEBUG_#{to_underscore(class_name.gsub(/Pass$/, '')).upcase}"
            ENV[env_name] == "1"
          end

          def debug(message)
            class_name = self.class.name.split("::").last.gsub(/Pass$/, "")
            puts "[#{class_name}] #{message}" if debug_enabled?
          end

          protected

          attr_reader :schema, :state

          # Iterate over all declarations (values and traits) in the schema
          # @yield [Syntax::Attribute|Syntax::Trait] Each declaration
          def each_decl(&)
            schema.values.each(&)
            schema.traits.each(&)
          end

          # Get state value - compatible with old interface
          def get_state(key, required: true)
            raise StandardError, "Required state key '#{key}' not found" if required && !state.key?(key)

            state[key]
          end

          # Record a user-facing error in the accumulator. This is the ONE
          # channel for problems with the user's schema: report it (located) and
          # let the pass finish or halt — never also `raise`, which would surface
          # the same error a second time through PassManager's exception capture.
          # @param errors [Array] the accumulator passed to #run
          def report(errors, message, location: nil, node: nil, type: :semantic)
            add_error(errors, location || node&.loc, message, type: type)
          end

          # Report a user error and stop the pass cleanly. Use when the pass
          # cannot meaningfully continue past the error (e.g. a later step would
          # dereference a value the failed step never produced). Returns nothing;
          # PassManager turns the recorded errors into a located failure.
          def halt_pass!(errors, message, location: nil, node: nil, type: :semantic)
            report(errors, message, location: location, node: node, type: type)
            throw HALT
          end

          def add_error(errors, location, message, type: :semantic)
            errors << ErrorReporter.create_error(message, location: location, type: type)
          end

          private

          def to_underscore(str)
            str.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
               .gsub(/([a-z\d])([A-Z])/, '\1_\2')
               .downcase
          end
        end
      end
    end
  end
end
