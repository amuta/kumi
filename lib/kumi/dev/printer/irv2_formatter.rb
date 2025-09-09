# frozen_string_literal: true

module Kumi
  module Dev
    module Printer
      class IRV2Formatter
        def initialize(irv2_data)
          @irv2 = irv2_data
        end

        def format
          output = []

          output += format_header
          output << ""
          output += format_declarations
          output += format_analysis_details

          output.join("\n")
        end

        private

        def format_header
          output = []
          output << "Schema: #{@irv2['$schema']}" if @irv2["$schema"]
          output << "Version: #{@irv2['version']}" if @irv2["version"]
          output << "Module: #{@irv2['module']}"
          output << "Declarations: #{@irv2['declarations'].keys.join(', ')}"
          output << "Inputs: #{@irv2['analysis']['inputs'].size}"
          output
        end

        def format_declarations
          output = []
          @irv2["declarations"].each do |name, decl|
            output += format_declaration(name, decl)
            output << ""
          end
          output
        end

        def format_declaration(name, decl)
          output = []
          output << "## #{name}"

          # Format parameters
          params = decl["parameters"].map do |param|
            case param["type"]
            when "input"
              "#{param['name']}: #{param['path'].join('.')} (#{param['dtype']})"
            else
              "#{param['name']}: #{param['type']}"
            end
          end
          output << "  Parameters: #{params.join(', ')}"

          # Format operations
          output << "  Operations:"
          decl["operations"].each_with_index do |op, idx|
            output << "    #{format_operation(idx, op)}"
          end

          output << "  Result: %#{decl['result']}"
          output
        end

        def format_operation(idx, op)
          base_op = case op["op"]
                    when "LoadInput"
                      "LoadInput(#{op['args'].first.join('.')})"
                    when "Const"
                      "Const(#{op['args'].first})"
                    when "Map"
                      op_name = op.dig("attrs", "op") || "unknown"
                      args_str = format_operation_args(op["args"])
                      "Map(#{op_name}) <- #{args_str}"
                    when "ConstructTuple"
                      args_str = format_operation_args(op["args"])
                      "ConstructTuple(#{args_str})"
                    else
                      args_str = format_operation_args(op["args"])
                      "#{op['op']}(#{args_str})"
                    end

          # Add attributes if present and not just 'op'
          attrs = op["attrs"] || {}
          extra_attrs = attrs.reject { |k, _| ["op", :op].include?(k) }
          attr_str = extra_attrs.empty? ? "" : " [#{extra_attrs.map { |k, v| "#{k}: #{v}" }.join(', ')}]"

          "%#{idx} = #{base_op}#{attr_str}"
        end

        def format_operation_args(args)
          return "" unless args

          args.map do |arg|
            if arg.respond_to?(:id) && arg.respond_to?(:op)
              "%#{arg.id}"
            elsif arg.is_a?(Array)
              arg.join(".")
            else
              arg.to_s
            end
          end.join(", ")
        end

        def format_analysis_details
          output = []
          output << ""
          output << "## Analysis"

          defaults = @irv2["analysis"]["defaults"]
          if defaults
            output << "  Defaults:"
            defaults.each { |k, v| output << "    #{k}: #{v}" }
          end

          # Add input plans within analysis section
          output << ""
          output << "  Input Plans:"
          @irv2["analysis"]["inputs"].each do |input|
            path_str = input["path"].join(".")
            axes_info = input["axes"].empty? ? "(scalar)" : "(axes: #{input['axes'].join(', ')})"

            output << "    #{path_str}: #{input['dtype']} #{axes_info}"

            # Add policy information if different from defaults
            output << "      key_policy: #{input['key_policy']}" if input["key_policy"] != defaults["key_policy"]
            output << "      on_missing: #{input['on_missing']}" if input["on_missing"] != defaults["on_missing"]

            # Add access chain details
            if input["chain"] && !input["chain"].empty?
              chain_str = input["chain"].map { |link| format_chain_link(link) }.join(" -> ")
              output << "      chain: #{chain_str}"
            end
          end

          output
        end

        def format_chain_link(link)
          case link["kind"]
          when "scalar_leaf"
            "scalar(#{link['key']})"
          when "array_element"
            alias_info = link["alias"] ? ":#{link['alias']}" : ""
            axis_info = link["axis"] ? "@#{link['axis']}" : ""
            "element(#{link['key'] || 'item'}#{alias_info}#{axis_info})"
          when "array_field"
            axis_info = link["axis"] ? "@#{link['axis']}" : ""
            "array_field(#{link['key']}#{axis_info})"
          when "hash_value"
            "hash[#{link['key']}]"
          else
            key_info = link["key"] ? "(#{link['key']})" : ""
            "#{link['kind']}#{key_info}"
          end
        end
      end
    end
  end
end
