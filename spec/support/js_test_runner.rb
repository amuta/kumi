# frozen_string_literal: true

require "tempfile"
require "json"
require "open3"

module JsTestRunner
  # Helper to execute JavaScript code with Node.js
  class NodeRunner
    def initialize
      @node_available = check_node_availability
    end

    def available?
      @node_available
    end

    def execute_js(js_code, test_data)
      return { error: "Node.js not available for testing" } unless available?

      # Create a temporary file with the JavaScript code and test runner
      Tempfile.create(["kumi_test", ".js"]) do |file|
        # Write the compiled schema and test runner
        file.write(js_code)
        file.write("\n\n")
        file.write(generate_test_runner(test_data))
        file.flush

        # Execute with Node.js
        stdout, stderr, status = Open3.capture3("node", file.path)
        
        if status.success?
          begin
            JSON.parse(stdout)
          rescue JSON::ParserError
            { error: "Invalid JSON output", stdout: stdout, stderr: stderr }
          end
        else
          { error: "Node.js execution failed", stderr: stderr, stdout: stdout }
        end
      end
    end

    private

    def check_node_availability
      _, _, status = Open3.capture3("node", "--version")
      status.success?
    rescue Errno::ENOENT
      false
    end

    def generate_test_runner(test_data)
      <<~JS
        // Test Runner
        try {
          const input = #{test_data.to_json};
          const runner = schema.from(input);
          
          // Get all available bindings
          const bindings = #{test_data.keys.to_json};
          const availableBindings = ['monthly_salary', 'annual_bonus', 'senior', 'adult', 'status', 'total_annual_compensation']; // This should be dynamically determined
          
          const results = {};
          
          // Try to fetch each binding
          try {
            for (const binding of availableBindings) {
              try {
                results[binding] = runner.fetch(binding);
              } catch (e) {
                results[binding] = { error: e.message };
              }
            }
          } catch (e) {
            results.__error__ = e.message;
          }
          
          console.log(JSON.stringify(results));
        } catch (error) {
          console.log(JSON.stringify({ error: error.message, stack: error.stack }));
        }
      JS
    end
  end

  # Test helper that compares Ruby and JavaScript outputs
  def compare_ruby_js_execution(schema_class, input_data, keys_to_test = nil)
    # Get Ruby results
    ruby_runner = schema_class.from(input_data)
    
    # Determine which keys to test
    available_keys = schema_class.__compiled_schema__.bindings.keys
    test_keys = keys_to_test || available_keys
    
    ruby_results = {}
    test_keys.each do |key|
      begin
        ruby_results[key] = ruby_runner.fetch(key)
      rescue => e
        ruby_results[key] = { error: e.class.name, message: e.message }
      end
    end

    # Get JavaScript results
    js_runner = NodeRunner.new
    
    unless js_runner.available?
      skip "Node.js not available for JavaScript testing"
    end

    # Compile to JavaScript
    require_relative "../../lib/kumi/js"
    js_code = Kumi::Js.compile(schema_class)
    
    # Execute JavaScript
    js_results = js_runner.execute_js(js_code, input_data)
    
    if js_results[:error]
      raise "JavaScript execution failed: #{js_results[:error]}"
    end

    # Compare results
    comparison = {
      ruby: ruby_results,
      javascript: js_results,
      matches: {},
      differences: []
    }

    test_keys.each do |key|
      key_str = key.to_s
      ruby_val = ruby_results[key]
      js_val = js_results[key_str]
      
      if values_equal?(ruby_val, js_val)
        comparison[:matches][key] = true
      else
        comparison[:matches][key] = false
        comparison[:differences] << {
          key: key,
          ruby: ruby_val,
          javascript: js_val
        }
      end
    end

    comparison
  end

  private

  def values_equal?(ruby_val, js_val)
    # Handle error cases
    if ruby_val.is_a?(Hash) && ruby_val[:error] && js_val.is_a?(Hash) && js_val["error"]
      return true # Both errored, consider equal for testing
    end

    # Handle numeric precision differences
    if ruby_val.is_a?(Float) && js_val.is_a?(Numeric)
      return (ruby_val - js_val).abs < 0.0001
    end

    # Handle arrays
    if ruby_val.is_a?(Array) && js_val.is_a?(Array)
      return ruby_val.size == js_val.size && 
             ruby_val.zip(js_val).all? { |r, j| values_equal?(r, j) }
    end

    # Standard comparison
    ruby_val == js_val
  end
end