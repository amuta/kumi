module SimpleSchema
  extend Kumi::Schema

  schema skip_compiler: true do
    input do
      float :just_a_float
    end

    value :just_a_value_plus_10, input.just_a_float + 10
  end
end

ast = SimpleSchema.__syntax_tree__

analyzer = Kumi::Analyzer.analyze!(ast)

state = analyzer.state
ir = state.ir

puts "=== IR ==="
puts ir.inspect

compiled_bindings = Kumi::RubyCompiler.compile(ir)

compiled_bindings[:just_a_value_plus_10].call({ just_a_float: 5.0 })
# => 15.0
