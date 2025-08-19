# frozen_string_literal: true

module GoldenHelper
  # Execute schema using ExecutionEngine directly and return raw results
  def execute_schema_raw(schema_block, input_data)
    # Get full analysis state
    state = analyze_up_to(:ir_module, &schema_block)
    
    # Get the compiled IR and accessors
    ir_module = state[:ir_module]
    access_plans = state[:access_plans]
    
    # Build accessors using the correct method
    accessors = Kumi::Core::Compiler::AccessBuilder.build(access_plans)
    
    # Execute with ExecutionEngine
    ctx = { input: input_data }
    result = Kumi::Core::IR::ExecutionEngine.run(ir_module, ctx, accessors: accessors)
    
    # Return the raw slot results
    result
  end
  
  # Print detailed structure of execution results
  def inspect_results(results, title = "Results")
    puts "\n=== #{title} ==="
    results.each do |name, value|
      case value
      when Hash
        if value[:k] == :scalar
          puts "#{name}: scalar(#{value[:v].inspect})"
        elsif value[:k] == :vec
          scope = value[:scope] || []
          rows = value[:rows] || []
          puts "#{name}: vec(scope=#{scope.inspect}, rows=#{rows.length}) #{rows.map { |r| r[:v] }.inspect}"
        else
          puts "#{name}: hash(#{value.keys.inspect})"
        end
      else
        puts "#{name}: #{value.class}(#{value.inspect})"
      end
    end
    puts
  end
end