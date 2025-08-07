# frozen_string_literal: true

require_relative "../lib/kumi"
require_relative "ir_generator"
require_relative "ir_compiler"

module IRTestHelper
  def self.compile_schema(schema_module, debug: false)
    ast = schema_module.__syntax_tree__
    
    if debug
      puts "=== AST Structure ==="
      first_attr = ast.attributes.first
      if first_attr
        puts "Expression class: #{first_attr.expression.class}"
        if first_attr.expression.respond_to?(:args)
          puts "First arg class: #{first_attr.expression.args.first.class}"
          puts "First arg: #{first_attr.expression.args.first.inspect}"
          puts "Second arg class: #{first_attr.expression.args.last.class}"
          puts "Second arg: #{first_attr.expression.args.last.inspect}"
        end
      end
    end
    
    puts "\n=== Analysis ===" if debug
    analyzer_result = Kumi::Analyzer.analyze!(ast)
    
    if debug
      puts "Topo order: #{analyzer_result.topo_order}"
      puts "Types: #{analyzer_result.decl_types}"
      
      puts "\n=== Input Metadata Debug ==="
      input_metadata = analyzer_result.state[:inputs]
      puts "Input metadata keys: #{input_metadata&.keys}"
      input_metadata&.each do |key, meta|
        puts "#{key}: #{meta}"
      end
      
      puts "\n=== Detector Metadata (Broadcasting Info) ==="
      detector_metadata = analyzer_result.state[:detector_metadata] || {}
      detector_metadata.each do |name, meta|
        puts "#{name}: #{meta}"
      end
    end
    
    puts "\n=== IR Generation ===" if debug
    ir_generator = Kumi::Core::IRGenerator.new(ast, analyzer_result)
    ir = ir_generator.generate
    
    if debug
      puts "Instructions order:"
      ir[:instructions].each_with_index do |instruction, i|
        puts "  #{i + 1}. #{instruction[:name]} (#{instruction[:operation_type]}, #{instruction[:data_type]})"
      end
      
      puts "\n=== Full IR Structure ==="
      puts "Accessors:"
      ir[:accessors].each { |k, v| puts "  #{k}: #{v}" }
      
      puts "\nInstructions:"
      ir[:instructions].each { |instruction| puts "  #{instruction}" }
    end
    
    puts "\n=== IR Compilation ===" if debug
    ir_compiler = Kumi::Core::IRCompiler.new(ir)
    compiled_schema = ir_compiler.compile
    puts "Compiled successfully!" if debug
    
    { compiled_schema: compiled_schema, ir: ir, analyzer_result: analyzer_result }
  end
  
  def self.run_test(schema_module, test_data, expected_results = {}, debug: false)
    result = compile_schema(schema_module, debug: debug)
    compiled_schema = result[:compiled_schema]
    
    puts "\n=== Test Execution ===" if debug
    
    actual_results = {}
    expected_results.each do |value_name, expected_value|
      begin
        actual_value = compiled_schema.bindings[value_name].call(test_data)
        actual_results[value_name] = actual_value
        
        if debug
          puts "#{value_name}: #{actual_value}"
          puts "Expected: #{expected_value}"
          puts "✓ PASS" if actual_value == expected_value
          puts "✗ FAIL" if actual_value != expected_value
        end
      rescue => e
        if debug
          puts "#{value_name}: ERROR - #{e.message}"
          puts "Expected: #{expected_value}"
        end
        raise e
      end
    end
    
    actual_results
  end

  def self.get_analysis(schema_module)
    ast = schema_module.__syntax_tree__
    Kumi::Analyzer.analyze!(ast)
  end
end