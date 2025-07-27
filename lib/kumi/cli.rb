# frozen_string_literal: true

require "json"
require "yaml"
require "optparse"
require "irb"

module Kumi
  module CLI
    class Application
      def initialize
        @options = {
          interactive: false,
          schema_file: nil,
          input_file: nil,
          output_format: :pretty,
          keys: [],
          explain: false
        }
      end

      def run(args = ARGV)
        parse_options(args)

        if @options[:interactive]
          start_repl
        elsif @options[:schema_file]
          execute_schema_file
        else
          show_help_and_exit
        end
      rescue StandardError => e
        puts "Error: #{e.message}"
        exit 1
      end

      private

      def parse_options(args)
        parser = OptionParser.new do |opts|
          opts.banner = "Usage: kumi [options]"
          opts.separator ""
          opts.separator "Options:"

          opts.on("-i", "--interactive", "Start interactive REPL mode") do
            @options[:interactive] = true
          end

          opts.on("-f", "--file FILE", "Load schema from Ruby file") do |file|
            @options[:schema_file] = file
          end

          opts.on("-d", "--data FILE", "Load input data from JSON/YAML file") do |file|
            @options[:input_file] = file
          end

          opts.on("-k", "--keys KEY1,KEY2", Array, "Extract specific keys (comma-separated)") do |keys|
            @options[:keys] = keys.map(&:to_sym)
          end

          opts.on("-e", "--explain KEY", "Explain how a specific key is computed") do |key|
            @options[:explain] = key.to_sym
          end

          opts.on("-o", "--format FORMAT", %i[pretty json yaml], "Output format: pretty, json, yaml") do |format|
            @options[:output_format] = format
          end

          opts.on("-h", "--help", "Show this help message") do
            puts opts
            exit
          end
        end

        parser.parse!(args)
      end

      def show_help_and_exit
        puts <<~HELP
          Kumi CLI - Declarative decision modeling for Ruby

          Usage:
            kumi -i                              # Start interactive mode
            kumi -f schema.rb -d data.json       # Execute schema with data
            kumi -f schema.rb -k key1,key2       # Extract specific keys
            kumi -f schema.rb -e key_name        # Explain computation

          Examples:
            # Interactive mode for rapid testing
            kumi -i

            # Execute schema file with JSON data
            kumi -f my_schema.rb -d input.json

            # Get specific values in JSON format
            kumi -f my_schema.rb -d input.yaml -k salary,bonus -o json

            # Debug a specific computation
            kumi -f my_schema.rb -d input.json -e total_compensation

          For more information, see: https://github.com/amuta/kumi
        HELP
        exit
      end

      def start_repl
        puts "🚀 Kumi Interactive REPL"
        puts "Type 'help' for commands, 'exit' to quit"
        puts

        repl = InteractiveREPL.new
        repl.start
      end

      def execute_schema_file
        schema_module = load_schema_file(@options[:schema_file])
        input_data = load_input_data(@options[:input_file])

        runner = schema_module.from(input_data)

        if @options[:explain]
          result = schema_module.explain(input_data, @options[:explain])
          puts result
        elsif @options[:keys].any?
          result = runner.slice(*@options[:keys])
          output_result(result)
        else
          # Show available keys if no specific keys requested
          puts "Schema loaded successfully!"
          available_bindings = schema_module.__compiled_schema__.bindings.keys
          puts "Available keys: #{available_bindings.join(', ')}"
          puts "Use -k to extract specific keys or -e to explain computations"
        end
      end

      def load_schema_file(file_path)
        raise "Schema file not found: #{file_path}" unless File.exist?(file_path)

        # Load the file and extract the module
        require_relative File.expand_path(file_path)

        # Find the module name from the file
        module_name = extract_module_name_from_file(file_path)

        raise "Could not find module extending Kumi::Schema in #{file_path}" unless module_name

        # Get the module constant
        schema_module = Object.const_get(module_name)

        raise "Module #{module_name} does not have a compiled schema" unless schema_module.__compiled_schema__

        schema_module
      end

      def extract_module_name_from_file(file_path)
        content = File.read(file_path)

        # Look for "module ModuleName" pattern
        if (match = content.match(/^\s*module\s+(\w+)/))
          match[1]
        end
      end

      def load_input_data(file_path)
        return {} unless file_path

        raise "Input file not found: #{file_path}" unless File.exist?(file_path)

        case File.extname(file_path).downcase
        when ".json"
          JSON.parse(File.read(file_path), symbolize_names: true)
        when ".yml", ".yaml"
          YAML.safe_load_file(file_path, symbolize_names: true)
        else
          raise "Unsupported input file format. Use .json or .yaml"
        end
      end

      def output_result(result)
        case @options[:output_format]
        when :json
          puts JSON.pretty_generate(result)
        when :yaml
          puts result.to_yaml
        else
          output_pretty(result)
        end
      end

      def output_pretty(result)
        case result
        when Hash
          result.each do |key, value|
            puts "#{key}: #{format_value(value)}"
          end
        when Kumi::Explain::Result
          puts "Explanation for: #{result.key}"
          puts "Value: #{format_value(result.value)}"
          puts
          puts "Computation trace:"
          result.trace.each do |step|
            puts "  #{step[:operation]} -> #{format_value(step[:result])}"
          end
        else
          puts format_value(result)
        end
      end

      def format_value(value)
        case value
        when String
          value.inspect
        when Numeric
          value.is_a?(Float) ? value.round(2) : value
        when Array, Hash
          value.inspect
        else
          value.to_s
        end
      end
    end

    class InteractiveREPL
      def initialize
        @schema_module = nil
        @runner = nil
        @input_data = {}
      end

      def start
        loop do
          print "kumi> "
          input = gets&.chomp
          break if input.nil? || input == "exit"

          execute_command(input)
        end
        puts "Goodbye!"
      end

      private

      def execute_command(input)
        case input.strip
        when "help"
          show_help
        when /^schema\s+(.+)/
          load_schema_command(::Regexp.last_match(1))
        when /^data\s+(.+)/
          load_data_command(::Regexp.last_match(1))
        when /^set\s+(\w+)\s+(.+)/
          set_data_command(::Regexp.last_match(1), ::Regexp.last_match(2))
        when /^get\s+(.+)/
          get_value_command(::Regexp.last_match(1))
        when /^explain\s+(.+)/
          explain_command(::Regexp.last_match(1))
        when /^slice\s+(.+)/
          slice_command(::Regexp.last_match(1))
        when "keys"
          show_keys
        when "clear"
          clear_data
        when ""
          # ignore empty input
        else
          puts "Unknown command. Type 'help' for available commands."
        end
      rescue StandardError => e
        puts "Error: #{e.message}"
        puts e.backtrace.first if ENV["DEBUG"]
      end

      def show_help
        puts <<~HELP
          Available commands:

          Schema management:
            schema <file>          Load schema from Ruby file
            schema { ... }         Define schema inline (experimental)

          Data management:
            data <file>           Load input data from JSON/YAML file
            set <key> <value>     Set individual input value
            clear                 Clear all input data

          Evaluation:
            get <key>             Get computed value for key
            explain <key>         Show detailed computation trace
            slice <key1,key2>     Get multiple values
            keys                  Show available keys

          General:
            help                  Show this help
            exit                  Exit REPL

          Examples:
            schema examples/tax_2024.rb
            data test_input.json
            get total_tax
            explain effective_rate
            slice income,deductions,total_tax
        HELP
      end

      def load_schema_command(file_path)
        file_path = file_path.strip.gsub(/^["']|["']$/, "") # Remove quotes

        unless File.exist?(file_path)
          puts "Schema file not found: #{file_path}"
          return
        end

        @schema_module = Module.new
        @schema_module.extend(Kumi::Schema)

        schema_content = File.read(file_path)
        @schema_module.module_eval(schema_content, file_path)

        puts "✅ Schema loaded from #{file_path}"
        refresh_runner
      rescue StandardError => e
        puts "❌ Failed to load schema: #{e.message}"
      end

      def load_data_command(file_path)
        file_path = file_path.strip.gsub(/^["']|["']$/, "") # Remove quotes

        unless File.exist?(file_path)
          puts "Data file not found: #{file_path}"
          return
        end

        case File.extname(file_path).downcase
        when ".json"
          @input_data = JSON.parse(File.read(file_path), symbolize_names: true)
        when ".yml", ".yaml"
          @input_data = YAML.safe_load_file(file_path, symbolize_names: true)
        else
          puts "Unsupported file format. Use .json or .yaml"
          return
        end

        puts "✅ Data loaded from #{file_path}"
        puts "Keys: #{@input_data.keys.join(', ')}"
        refresh_runner
      rescue StandardError => e
        puts "❌ Failed to load data: #{e.message}"
      end

      def set_data_command(key, value)
        # Try to parse value as JSON first, then as literal
        parsed_value = begin
          JSON.parse(value)
        rescue JSON::ParserError
          # If not valid JSON, treat as string unless it looks like a number/boolean
          case value
          when /^\d+$/ then value.to_i
          when /^\d+\.\d+$/ then value.to_f
          when "true" then true
          when "false" then false
          else value
          end
        end

        @input_data[key.to_sym] = parsed_value
        puts "✅ Set #{key} = #{parsed_value.inspect}"
        refresh_runner
      end

      def get_value_command(key)
        ensure_runner_ready

        key_sym = key.strip.to_sym
        result = @runner[key_sym]
        puts "#{key_sym}: #{format_value(result)}"
      rescue StandardError => e
        puts "❌ Error getting #{key}: #{e.message}"
      end

      def explain_command(key)
        ensure_runner_ready

        key_sym = key.strip.to_sym
        puts @schema_module.explain(@input_data, key_sym)
      rescue StandardError => e
        puts "❌ Error explaining #{key}: #{e.message}"
      end

      def slice_command(keys_str)
        ensure_runner_ready

        keys = keys_str.split(",").map { |k| k.strip.to_sym }
        result = @runner.slice(*keys)

        result.each do |key, value|
          puts "#{key}: #{format_value(value)}"
        end
      rescue StandardError => e
        puts "❌ Error getting slice: #{e.message}"
      end

      def show_keys
        if @schema_module
          available_bindings = @schema_module.__compiled_schema__.bindings.keys
          puts "Available keys: #{available_bindings.join(', ')}"
        else
          puts "No schema loaded. Use 'schema <file>' to load a schema."
        end
      end

      def clear_data
        @input_data = {}
        @runner = nil
        puts "✅ Input data cleared"
      end

      def ensure_runner_ready
        raise "No schema loaded. Use 'schema <file>' to load a schema." unless @schema_module

        return if @runner

        raise "No runner available. Load data with 'data <file>' or set values with 'set <key> <value>'"
      end

      def refresh_runner
        return unless @schema_module

        @runner = @schema_module.from(@input_data)
        puts "✅ Runner refreshed with current data"
      rescue StandardError => e
        puts "⚠️  Runner refresh failed: #{e.message}"
        @runner = nil
      end

      def format_value(value)
        case value
        when String
          value.inspect
        when Numeric
          value.is_a?(Float) ? value.round(2) : value
        when Array, Hash
          value.inspect
        else
          value.to_s
        end
      end
    end
  end
end
