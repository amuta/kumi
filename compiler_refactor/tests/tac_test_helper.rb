# frozen_string_literal: true

require_relative "../../lib/kumi"
require_relative "../tac_ir_generator"
require_relative "../tac_ir_compiler"

module TACTestHelper
  def self.compile_schema(schema_module, debug: false)
    ast = schema_module.__syntax_tree__
    
    puts "=== TAC Analysis ===" if debug
    analysis_result = Kumi::Analyzer.analyze!(ast)
    
    if debug
      puts "Topo order: #{analysis_result.topo_order}"
    end
    
    puts "=== TAC IR Generation ===" if debug
    tac_generator = Kumi::Core::TACIRGenerator.new(ast, analysis_result)
    tac_ir = tac_generator.generate
    
    if debug
      puts "TAC Instructions:"
      tac_ir[:instructions].each_with_index do |instruction, i|
        puts "  #{i + 1}. #{instruction[:name]} (#{instruction[:operation_type]})"
        if instruction[:temp]
          puts "     [TEMP]"
        end
        instruction[:operands].each_with_index do |operand, j|
          puts "     [#{j}] #{operand[:type]}"
        end
      end
    end
    
    puts "=== TAC Compilation ===" if debug
    tac_compiler = Kumi::Core::TACIRCompiler.new(tac_ir)
    compiled_schema = tac_compiler.compile
    
    puts "Compiled successfully!" if debug
    
    {
      compiled_schema: compiled_schema,
      tac_ir: tac_ir,
      analysis_result: analysis_result
    }
  end
end