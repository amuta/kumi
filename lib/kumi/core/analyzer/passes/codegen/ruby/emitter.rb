# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Ruby
            # Emitter is responsible for turning the final LIR into a Ruby source code string.
            class Emitter
              KernelInfo = Struct.new(:id, :fn_id, :impl, keyword_init: true)
              BindsInfo = Struct.new(:op_result_reg, :fn_id, keyword_init: true)

              def initialize(kernels_data, binds_data)
                @kernels = kernels_data.map { |k| KernelInfo.new(**k.slice("id", "fn_id", "impl").transform_keys(&:to_sym)) }
                                       .to_h { |k| [k.fn_id, k] }

                @binds = binds_data.map { |b| BindsInfo.new(**b.slice("op_result_reg", "fn_id").transform_keys(&:to_sym)) }
                                   .to_h { |b| [b.op_result_reg, b] }
                @buffer = OutputBuffer.new
              end

              def emit(declarations)
                @buffer.reset!
                @buffer.emit_header
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
                @buffer.section("private") do
                  sorted_kernels = @kernels.values.sort_by(&:id)
                  sorted_kernels.each do |kernel|
                    fn_name = kernel_method_name(kernel.fn_id)
                    impl_lines = kernel.impl.strip.split("\n", 2)
                    args = impl_lines.first.gsub(/[()]/, "").strip
                    body = impl_lines[1..].join("\n").strip

                    @buffer.write "def #{fn_name}(#{args})", 1
                    @buffer.write body, 2
                    @buffer.write "end\n", 1
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
