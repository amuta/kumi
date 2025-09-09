# frozen_string_literal: true

require "json"

module Kumi
  module Dev
    module IR
      module_function

      def to_text(ir_module)
        raise "nil IR" unless ir_module

        lines = []
        lines << "IR Module"
        lines << "decls: #{ir_module.decls.size}"

        ir_module.decls.each_with_index do |decl, i|
          lines << "decl[#{i}] #{decl.kind}:#{decl.name} shape=#{decl.shape} ops=#{decl.ops.size}"

          decl.ops.each_with_index do |op, j|
            # Sort attribute keys for deterministic output
            sorted_attrs = op.attrs.keys.sort.map { |k| "#{k}=#{format_value(op.attrs[k])}" }.join(" ")
            args_str = op.args.inspect
            lines << "  #{j}: #{op.tag} #{sorted_attrs} #{args_str}".rstrip
          end
        end

        lines.join("\n") + "\n"
      end

      private

      def self.format_value(val)
        case val
        when true, false
          val.to_s
        when Symbol
          ":#{val}"
        when Array
          val.inspect
        else
          val.to_s
        end
      end

      def to_json(ir_module, pretty: true)
        raise "nil IR" unless ir_module

        data = {
          inputs: ir_module.inputs,
          decls: ir_module.decls.map do |decl|
            {
              name: decl.name,
              kind: decl.kind,
              shape: decl.shape,
              ops: decl.ops.map do |op|
                {
                  tag: op.tag,
                  attrs: op.attrs,
                  args: op.args
                }
              end
            }
          end
        }

        if pretty
          JSON.pretty_generate(data)
        else
          JSON.generate(data)
        end
      end
    end
  end
end
