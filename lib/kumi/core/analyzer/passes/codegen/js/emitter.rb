# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Codegen
          module Js
            class Emitter
              KernelInfo = Struct.new(:id, :fn_id, :impl, :attrs, keyword_init: true)
              BindsInfo = Struct.new(:op_result_reg, :fn_id, keyword_init: true)

              def initialize(kernels_data, binds_data)
                @kernels = kernels_data.map { |k| KernelInfo.new(**k.slice("id", "fn_id", "impl", "attrs").transform_keys(&:to_sym)) }
                                       .to_h { |k| [k.fn_id, k] }

                @binds = binds_data.map { |b| BindsInfo.new(**b.slice("op_result_reg", "fn_id").transform_keys(&:to_sym)) }
                                   .to_h { |b| [b.op_result_reg, b] }
                @buffer = OutputBuffer.new
              end

              def emit(declarations, schema_digest:)
                @buffer.reset!
                # @buffer.emit_header(schema_digest)
                # @buffer.emit_class_methods(declarations.keys)
                emit_private_helpers
                # @buffer.emit_footer

                declarations.each do |name, payload|
                  emit_declaration(name, Array(payload[:operations]))
                end

                @buffer.to_s
              end

              private

              def emit_declaration(name, ops)
                DeclarationEmitter.new(@buffer, @binds, @kernels).emit(name, ops)
              end

              def emit_private_helpers
                kernels_to_write = @kernels.values.reject do |k|
                  (k.attrs["js_inline"] || k.attrs["inline"]) || k.impl.nil? || k.impl.strip.empty?
                end.sort_by(&:id)

                return if kernels_to_write.empty?

                @buffer.section("PRIVATE HELPERS") do
                  kernels_to_write.each do |kernel|
                    fn_name = kernel_method_name(kernel.fn_id)

                    # Assuming the impl is Ruby-like, extract args and body
                    impl_lines = kernel.impl.strip.split("\n", 2)
                    args = impl_lines.first.gsub(/[()]/, "").strip
                    body = impl_lines[1..].join("\n").strip

                    @buffer.write "#{fn_name}(#{args}) {"
                    @buffer.indented do
                      # The body is assumed to be valid JS.
                      @buffer.write body, @buffer.instance_variable_get(:@indent)
                    end
                    @buffer.write "}\n"
                  end
                end
              end

              def kernel_method_name(fn_id) = "__#{fn_id.tr('.', '_')}"
            end
          end
        end
      end
    end
  end
end
