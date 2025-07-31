# frozen_string_literal: true

require "spec_helper"

# Test cascade expressions with do/end blocks
class SimpleCascadeSchema
  extend Kumi::Schema
  
  schema do
    input do
      integer :age
      string :membership, domain: %w[bronze silver gold platinum]
    end

    trait :adult, input.age >= 18
    trait :senior, input.age >= 65
    trait :gold_member, input.membership == "gold"
    trait :platinum_member, input.membership == "platinum"

    value :discount_rate do
      on platinum_member, 0.25
      on gold_member, 0.15
      on senior, 0.10
      on adult, 0.05
      base 0.0
    end
  end
end

class NestedCascadeSchema
  extend Kumi::Schema
  
  schema do
    input do
      float :performance_score, domain: 0.0..100.0
      float :salary, domain: 0.0..Float::INFINITY
    end

    trait :high_performer, input.performance_score >= 90.0
    trait :avg_performer, input.performance_score >= 60.0
    trait :poor_performer, input.performance_score < 60.0
    trait :high_earner, input.salary >= 100_000.0

    value :performance_category do
      on high_performer, "Outstanding"
      on avg_performer, "Good"
      on poor_performer, "Needs Improvement"
      base "Not Evaluated"
    end

    value :bonus_percentage do
      on high_performer, 0.20
      on avg_performer, 0.10
      base 0.05
    end
  end
end

RSpec.describe "Text Parser: Cascade Expressions" do
  def compare_asts(ruby_schema_class, text_dsl)
    ruby_ast = ruby_schema_class.__syntax_tree__
    text_ast = Kumi::TextParser.parse(text_dsl)
    
    expect(normalize_ast(text_ast)).to eq(normalize_ast(ruby_ast))
  end
  
  def normalize_ast(ast)
    normalize_node(ast)
  end
  
  def normalize_node(node)
    case node
    when Array
      node.map { |item| normalize_node(item) }
    when Hash
      node.except(:loc, :location).transform_values { |v| normalize_node(v) }
    when Struct
      members = node.class.members
      result = {}
      
      members.each do |member|
        next if [:loc, :location].include?(member)
        
        value = node.public_send(member)
        result[member] = normalize_node(value)
      end
      
      result.merge(node_type: node.class.name)
    else
      node
    end
  end

  it "produces identical AST for simple cascade expressions" do
    text_dsl = <<~KUMI
      schema do
        input do
          integer :age
          string :membership, domain: %w[bronze silver gold platinum]
        end

        trait :adult, input.age >= 18
        trait :senior, input.age >= 65
        trait :gold_member, input.membership == "gold"
        trait :platinum_member, input.membership == "platinum"

        value :discount_rate do
          on platinum_member, 0.25
          on gold_member, 0.15
          on senior, 0.10
          on adult, 0.05
          base 0.0
        end
      end
    KUMI

    compare_asts(SimpleCascadeSchema, text_dsl)
  end

  it "produces identical AST for cascade expressions without base" do
    text_dsl = <<~KUMI
      schema do
        input do
          float :performance_score, domain: 0.0..100.0
          float :salary, domain: 0.0..Float::INFINITY
        end

        trait :high_performer, input.performance_score >= 90.0
        trait :avg_performer, input.performance_score >= 60.0
        trait :poor_performer, input.performance_score < 60.0
        trait :high_earner, input.salary >= 100_000.0

        value :performance_category do
          on high_performer, "Outstanding"
          on avg_performer, "Good"
          on poor_performer, "Needs Improvement"
          base "Not Evaluated"
        end

        value :bonus_percentage do
          on high_performer, 0.20
          on avg_performer, 0.10
          base 0.05
        end
      end
    KUMI

    compare_asts(NestedCascadeSchema, text_dsl)
  end
end