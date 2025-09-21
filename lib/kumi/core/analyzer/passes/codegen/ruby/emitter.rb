# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Ruby
            # Emitter is responsible for turning the final LIR into a Ruby source code string.
            class Emitter
              KernelInfo = Struct.new(:id, :fn_id, :impl, :attrs, keyword_init: true)
              BindsInfo = Struct.new(:op_result_reg, :fn_id, keyword_init: true)

              def initialize(kernels_data, binds_data)
                @all_kernels_inlined = true
                @kernels = kernels_data.map { |k| KernelInfo.new(**k.slice("id", "fn_id", "impl", "attrs").transform_keys(&:to_sym)) }
                                       .to_h { |k| [k.fn_id, k] }

                @binds = binds_data.map { |b| BindsInfo.new(**b.slice("op_result_reg", "fn_id").transform_keys(&:to_sym)) }
                                   .to_h { |b| [b.op_result_reg, b] }
                @buffer = OutputBuffer.new
              end

              def emit(declarations, schema_digest:)
                @buffer.reset!
                @buffer.emit_header(schema_digest)
                @buffer.emit_class_methods(declarations.keys)

                declarations.each do |name, payload|
                  emit_declaration(name, Array(payload[:operations]))
                end

                emit_private_helpers
                @buffer.emit_footer
                @buffer.to_s
              end

              private

              def emit_declaration(name, ops)
                DeclarationEmitter.new(@buffer, @binds, @kernels).emit(name, ops)
              end

              def emit_private_helpers
                all_kernels_inlined = true
                to_write = []
                sorted_kernels = @kernels.values.sort_by(&:id)
                sorted_kernels.each do |kernel|
                  # --- ADD THIS CHECK ---
                  # If the kernel has an inline template, we don't need a separate method for it.
                  next if kernel.attrs["inline"]

                  fn_name = kernel_method_name(kernel.fn_id)
                  @all_kernels_inlined = false
                  # The `impl` might be nil or empty for inline-only kernels, so protect against that.
                  next unless kernel.impl && !kernel.impl.strip.empty?

                  impl_lines = kernel.impl.strip.split("\n", 2)
                  args = impl_lines.first.gsub(/[()]/, "").strip
                  body = impl_lines[1..].join("\n").strip

                  to_write << ["def #{fn_name}(#{args})", 1]
                  to_write << [body, 2]
                  to_write << ["end\n", 1]
                end

                return if all_kernels_inlined

                @buffer.section("private") do
                  to_write.each_value do |text, ident|
                    @buffer.write text, ident
                  end
                end
              end

              def kernel_method_name(fn_id)
                "__#{fn_id.tr('.', '_')}"
              end
            end
          end
        end
      end
    end
  end
end
