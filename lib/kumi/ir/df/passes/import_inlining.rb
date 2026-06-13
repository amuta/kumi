# frozen_string_literal: true

module Kumi
  module IR
    module DF
      module Passes
        class ImportInlining < Kumi::IR::Passes::Base
          def initialize(loader: nil)
            @loader = loader
          end

          def run(graph:, context: {})
            loader = @loader || build_loader(context)
            return graph unless loader

            @plans = context[:input_plans] || {}
            functions = graph.functions.values.map { |fn| rewrite_function(fn, loader) }
            Kumi::IR::DF::Graph.new(name: graph.name, functions: functions)
          end

          private

          attr_reader :loader

          def build_loader(context)
            imported = context[:imported_schemas]
            return nil unless imported && !imported.empty?

            Kumi::IR::DF::ImportLoader.new(imported)
          end

          def rewrite_function(fn, loader)
            reg_gen = RegGenerator.new(fn)
            defs = {}
            new_blocks = fn.blocks.map { |block| rewrite_block(block, loader, reg_gen, defs) }
            Kumi::IR::DF::Function.new(
              name: fn.name,
              parameters: fn.parameters,
              blocks: new_blocks,
              return_stamp: fn.return_stamp
            )
          end

          def rewrite_block(block, loader, reg_gen, defs)
            replacements = {}
            new_instructions = []

            record = lambda do |new_instr|
              new_instructions << new_instr
              result = new_instr.defs.first
              defs[result] = new_instr if result
            end

            block.each do |instr|
              new_inputs = instr.uses.map { |reg| replacements.fetch(reg, reg) }

              if instr.opcode == :import_call
                inlined, result_reg = inline_import(instr, new_inputs, loader, reg_gen, defs)
                if inlined
                  inlined.each(&record)
                  if (result = instr.defs.first)
                    replacements[result] = result_reg
                  end
                  next
                end
              end

              record.call(Support::InstructionCloner.clone(instr, new_inputs))
            end

            Kumi::IR::Base::Block.new(name: block.name, instructions: new_instructions)
          end

          def inline_import(instr, resolved_inputs, loader, reg_gen, caller_defs)
            attrs = instr.attributes || {}
            fn_name = attrs[:fn_name]&.to_sym
            return skip(nil, "import_call has no fn_name") unless fn_name

            callee = loader.function(fn_name)
            # Not-yet-available / unresolved imports legitimately stay as an
            # import_call for the interpreter path — these are expected skips.
            return skip(fn_name, "callee not found in loader") unless callee
            return skip(fn_name, "callee references declarations (not self-contained)") if references_declarations?(callee)

            mapping_keys = Array(attrs[:mapping_keys]).map(&:to_sym)
            unless mapping_keys.length == resolved_inputs.length
              return skip(fn_name, "arg count mismatch: #{mapping_keys.length} keys vs #{resolved_inputs.length} inputs")
            end

            call_axes = Array(instr.axes).map(&:to_sym)
            arg_map = mapping_keys.zip(resolved_inputs).to_h

            chain_axes_map, caller_fqns = derive_chain_mappings(callee, arg_map, caller_defs)
            axes_map = build_axis_map(function_output_axes(callee), call_axes).merge(chain_axes_map)
            extra_axes = call_axes.reject { |ax| axes_map.value?(ax) }

            inliner = Kumi::IR::DF::ImportInliner.new(axis_map: axes_map, extra_axes: extra_axes)
            remapped_fn = inliner.remap_function(callee)

            # Past this point we have committed to inlining: the callee resolved,
            # is self-contained, and arity matched. Any failure here is a broken
            # IR contract, not a benign "can't inline this" — fail loudly rather
            # than silently dropping to a slower (and likely also-broken) path.
            block = remapped_fn.entry_block or
              abort_inline(fn_name, "remapped callee has no entry block")

            value_map = {}
            emitted = []

            block.instructions.each do |callee_instr|
              if callee_instr.opcode == :load_input
                key = callee_instr.attributes[:key]&.to_sym
                arg_reg = arg_map[key] or
                  abort_inline(fn_name, "load_input #{key.inspect} has no matching argument")

                value_map[callee_instr.defs.first] = arg_reg
                next
              end

              new_inputs = callee_instr.uses.map do |reg|
                value_map.fetch(reg) do
                  abort_inline(fn_name, "use #{reg.inspect} unmapped while inlining #{callee_instr.opcode}")
                end
              end

              callee_result = callee_instr.defs.first
              new_result = callee_result ? reg_gen.next : nil
              cloned_attrs = callee_instr.attributes
              if cloned_attrs && cloned_attrs[:plan_ref] && (fqn = caller_fqns[callee_result])
                cloned_attrs = cloned_attrs.merge(plan_ref: fqn)
              end
              cloned = Support::InstructionCloner.clone(
                callee_instr,
                new_inputs,
                metadata: callee_instr.metadata,
                attributes: cloned_attrs,
                result: new_result
              )
              emitted << cloned
              value_map[callee_result] = new_result if callee_result
            end

            final_reg = value_map[block.instructions.reverse.find { |instr| instr.defs.any? }&.defs&.first] or
              abort_inline(fn_name, "no final result register after inlining")

            [emitted, final_reg]
          end

          # Benign skip: the import legitimately can't be inlined and stays as an
          # import_call. Logged (KUMI_DEBUG_IMPORT_INLINING=1) so a lost fusion
          # opportunity is never silent. Returns nil so the caller leaves the op.
          def skip(fn_name, reason)
            if ENV["KUMI_DEBUG_IMPORT_INLINING"] == "1"
              warn "[ImportInlining] skip #{fn_name.inspect}: #{reason} (left as import_call)"
            end
            nil
          end

          # Contract violation: inlining was committed and then hit an
          # impossible state. Raising beats a silent slow path that would also
          # be wrong — surfaces the real bug at compile time.
          def abort_inline(fn_name, reason)
            raise Kumi::Core::Errors::SemanticError,
                  "ImportInlining failed for #{fn_name.inspect}: #{reason}. " \
                  "This indicates malformed IR at the import boundary; please report it."
          end

          # Canonicalizes axis identity at the inlining boundary: every callee
          # axis that is reachable through an argument's load chain is mapped
          # to the axis name the caller's input plan mints for the same
          # carrier, so downstream IRs never see callee-named axes.
          def derive_chain_mappings(callee, arg_map, caller_defs)
            callee_defs = {}
            callee.blocks.each do |block|
              block.each { |i| callee_defs[i.defs.first] = i if i.defs.first }
            end

            axis_map = {}
            fqns = {}

            callee_defs.each_value do |instr|
              next unless %i[load_input load_field].include?(instr.opcode)

              segments = callee_chain_segments(instr, callee_defs)
              next unless segments

              arg_reg = arg_map[segments.first.to_sym]
              next unless arg_reg

              root = caller_chain(arg_reg, caller_defs)
              next unless root

              fqn = (root[:segments] + segments[1..]).join(".")
              fqns[instr.defs.first] = fqn

              plan = @plans[fqn]
              next unless plan

              caller_axes = Array(plan[:loop_axes]).map(&:to_sym).drop(root[:axes].size)
              Array(instr.axes).map(&:to_sym).zip(caller_axes).each do |from, to|
                next unless from && to

                existing = axis_map[from]
                if existing && existing != to
                  raise ArgumentError,
                        "import inlining maps callee axis #{from.inspect} to both #{existing.inspect} and #{to.inspect}"
                end
                axis_map[from] = to
              end
            end

            [axis_map, fqns]
          end

          def callee_chain_segments(instr, defs)
            segments = []
            while instr
              case instr.opcode
              when :load_field
                segments.unshift(instr.attributes[:field].to_s)
                instr = defs[instr.uses.first]
              when :load_input
                segments.unshift(instr.attributes[:key].to_s)
                return segments
              else
                return nil
              end
            end
            nil
          end

          def caller_chain(reg, defs)
            segments = []
            axes = nil
            instr = defs[reg]
            while instr
              axes ||= Array(instr.axes).map(&:to_sym)
              case instr.opcode
              when :load_field
                segments.unshift(instr.attributes[:field].to_s)
                instr = defs[instr.uses.first]
              when :load_input
                segments.unshift(instr.attributes[:key].to_s)
                return { segments: segments, axes: axes }
              else
                return nil
              end
            end
            nil
          end

          def build_axis_map(callee_axes, target_axes)
            axis_pairs = callee_axes.zip(target_axes)
            axis_pairs.each_with_object({}) do |(from, to), memo|
              break memo unless from && to

              memo[from] = to
            end
          end

          def function_output_axes(function)
            function.blocks.flat_map(&:instructions).reverse_each do |instr|
              next unless instr.result

              return Array(instr.axes).map(&:to_sym)
            end
            []
          end

          def references_declarations?(function)
            function.blocks.any? do |block|
              block.any? { |instr| instr.opcode == :decl_ref }
            end
          end

          class RegGenerator
            def initialize(function)
              @counter = extract_highest(function)
            end

            def next
              @counter += 1
              :"v#{@counter}"
            end

            private

            def extract_highest(function)
              regs = function.blocks.flat_map(&:instructions).map(&:result).compact
              nums = regs.filter_map do |reg|
                match = reg.to_s.match(/^v(\d+)$/)
                match && match[1].to_i
              end
              nums.max || 0
            end
          end
        end
      end
    end
  end
end
