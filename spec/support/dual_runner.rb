# frozen_string_literal: true

require "tempfile"
require "json"
require "open3"

# Dual execution runner that tests Ruby and JavaScript implementations side-by-side
class DualRunner
  # Global metrics for dual mode execution
  @@metrics = {
    schemas_compiled: 0,
    comparisons_made: 0,
    mismatches_found: 0,
    last_reset: Time.now
  }
  attr_reader :ruby_runner, :js_runner, :schema_class, :input_data

  def initialize(schema_class, input_data)
    @schema_class = schema_class
    @input_data = input_data
    # Create Ruby runner directly without dual mode to avoid recursion
    @ruby_runner = Kumi::Core::SchemaInstance.new(
      schema_class.__compiled_schema__,
      schema_class.__analyzer_result__.state,
      input_data
    )
    @js_runner = JavaScriptRunner.new(schema_class, input_data)

    # Track schema compilation
    @@metrics[:schemas_compiled] += 1
  end

  def fetch(key)
    ruby_result = @ruby_runner[key]
    js_result = @js_runner.fetch(key)
    @@metrics[:comparisons_made] += 1

    # Debug output to confirm both platforms are executing
    # if debug_mode?
    # puts "🔍 DUAL MODE DEBUG - Key: #{key}"
    # puts "  🟥 Ruby result:  #{ruby_result.inspect}"
    # puts "  🟨 JS result:    #{js_result.inspect}"
    # puts "  ✅ Match:       #{values_equal?(ruby_result, js_result)}"
    # puts
    # end

    compare_results!(key, ruby_result, js_result)
    ruby_result
  end

  def slice(*keys)
    ruby_result = @ruby_runner.slice(*keys)
    js_result = @js_runner.slice(*keys)
    @@metrics[:comparisons_made] += keys.length

    # if debug_mode?
    #   puts "DUAL MODE DEBUG - Slice: #{keys.inspect}"
    #   puts "  🟥 Ruby result:  #{ruby_result.inspect}"
    #   puts "  🟨 JS result:    #{js_result.inspect}"
    #   puts
    # end

    keys.each do |key|
      compare_results!(key, ruby_result[key], js_result[key.to_s])
    end

    ruby_result
  end

  def [](key)
    fetch(key)
  end

  def explain(key)
    # JavaScript doesn't support explain yet, so just use Ruby
    @schema_class.explain(@input_data, key)
  end

  def update(**changes)
    # Update the Ruby runner
    @ruby_runner.update(**changes)

    # Update our input data for JS runner recreation
    @input_data = @input_data.merge(changes)

    # Recreate JS runner with updated input data
    @js_runner = JavaScriptRunner.new(@schema_class, @input_data)

    self
  end

  def compiled_schema
    @ruby_runner.compiled_schema
  end

  # Execute block with dual mode enabled
  def self.with_dual_mode
    # Dual mode is now globally enabled in specs, just execute the block
    yield
  end

  # Enable debug mode to see both execution results
  def self.enable_debug!
    Thread.current[:kumi_dual_debug] = true
  end

  def self.disable_debug!
    Thread.current[:kumi_dual_debug] = false
  end

  def self.with_debug
    old_value = Thread.current[:kumi_dual_debug]
    Thread.current[:kumi_dual_debug] = true
    yield
  ensure
    Thread.current[:kumi_dual_debug] = old_value
  end

  # Metrics collection and reporting
  def self.metrics
    @@metrics.dup
  end

  def self.reset_metrics!
    @@metrics = {
      schemas_compiled: 0,
      comparisons_made: 0,
      mismatches_found: 0,
      last_reset: Time.now
    }
  end

  def self.print_metrics
    elapsed = Time.now - @@metrics[:last_reset]
    puts "\n=== Dual Mode Execution Metrics ==="
    puts " Schemas compiled:    #{@@metrics[:schemas_compiled]}"
    puts " Comparisons made:    #{@@metrics[:comparisons_made]}"
    puts " Mismatches found:    #{@@metrics[:mismatches_found]}"
    puts " Success rate:        #{success_rate}%"
    puts " Elapsed time:        #{elapsed.round(2)}s"
    puts "=================================="
  end

  def self.success_rate
    return 100.0 if @@metrics[:comparisons_made] == 0

    ((@@metrics[:comparisons_made] - @@metrics[:mismatches_found]).to_f / @@metrics[:comparisons_made] * 100).round(2)
  end

  private

  def debug_mode?
    ENV["KUMI_DUAL_DEBUG"] == "true" || Thread.current[:kumi_dual_debug]
  end

  def compare_results!(key, ruby_result, js_result)
    return if values_equal?(ruby_result, js_result)

    # Track mismatch
    @@metrics[:mismatches_found] += 1

    # Format a detailed comparison error
    raise DualExecutionMismatchError.new(
      key: key,
      ruby_result: ruby_result,
      js_result: js_result,
      input_data: @input_data
    )
  end

  def values_equal?(ruby_val, js_val)
    # Handle numeric precision differences
    return (ruby_val - js_val).abs < 0.0001 if ruby_val.is_a?(Float) && js_val.is_a?(Numeric)

    # Handle arrays
    if ruby_val.is_a?(Array) && js_val.is_a?(Array)
      return ruby_val.size == js_val.size &&
             ruby_val.zip(js_val).all? { |r, j| values_equal?(r, j) }
    end

    # Standard comparison
    ruby_val == js_val
  end

  # JavaScript execution wrapper
  class JavaScriptRunner
    def initialize(schema_class, input_data)
      @schema_class = schema_class
      @input_data = input_data
      @js_runner_instance = create_js_runner
    end

    def fetch(key)
      execute_js("runner.fetch('#{key}')")
    end

    def slice(*keys)
      key_list = keys.map { |k| "'#{k}'" }.join(", ")
      execute_js("runner.slice(#{key_list})")
    end

    private

    def create_js_runner
      # Check if Node.js is available
      raise "Node.js not available for dual mode testing" unless node_available?

      # Compile schema to JavaScript
      require_relative "../../lib/kumi/js"
      @js_code = Kumi::Js.compile(@schema_class)

      # Create the runner instance in JavaScript context
      setup_code = <<~JS
        const input = #{@input_data.to_json};
        const runner = schema.from(input);
      JS

      execute_js_setup(setup_code)
      true
    end

    def execute_js_setup(setup_code)
      Tempfile.create(["kumi_setup", ".js"]) do |file|
        file.write(@js_code)
        file.write("\n\n")
        file.write(setup_code)
        file.flush

        _, stderr, status = Open3.capture3("node", file.path)

        raise "JavaScript setup failed: #{stderr}" unless status.success?
      end
    end

    def execute_js(expression)
      Tempfile.create(["kumi_eval", ".js"]) do |file|
        file.write(@js_code)
        file.write("\n\n")
        file.write(<<~JS)
          try {
            const input = #{@input_data.to_json};
            const runner = schema.from(input);
            const result = #{expression};
            console.log(JSON.stringify(result));
          } catch (error) {
            console.log(JSON.stringify({ __error__: error.message }));
          }
        JS
        file.flush

        stdout, stderr, status = Open3.capture3("node", file.path)

        raise "JavaScript execution failed: #{stderr}" unless status.success?

        begin
          result = JSON.parse(stdout.strip)
          raise "JavaScript runtime error: #{result['__error__']}" if result.is_a?(Hash) && result["__error__"]

          result
        rescue JSON::ParserError
          raise "Invalid JSON from JavaScript: #{stdout}"
        end
      end
    end

    def node_available?
      _, _, status = Open3.capture3("node", "--version")
      status.success?
    rescue Errno::ENOENT
      false
    end
  end
end

# Custom error for dual execution mismatches
class DualExecutionMismatchError < StandardError
  attr_reader :key, :ruby_result, :js_result, :input_data

  def initialize(key:, ruby_result:, js_result:, input_data:)
    @key = key
    @ruby_result = ruby_result
    @js_result = js_result
    @input_data = input_data

    super(build_message)
  end

  private

  def build_message
    <<~MESSAGE
      Dual execution mismatch for key '#{@key}':

      Ruby result:       #{@ruby_result.inspect}
      JavaScript result: #{@js_result.inspect}

      Input data: #{@input_data.inspect}

      This indicates the JavaScript transpiler is not producing identical results to the Ruby implementation.
    MESSAGE
  end
end

# Auto-print metrics when any dual mode execution happened
at_exit do
  DualRunner.print_metrics if DualRunner.metrics[:schemas_compiled] > 0
end
