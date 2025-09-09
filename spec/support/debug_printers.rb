# frozen_string_literal: true

module DebugPrinters
  class << self
    def print(obj)
      # Handle direct object instances first
      return print_class(obj) if obj.is_a?(Class)

      case obj
      # Kumi syntax nodes
      when Kumi::Syntax::Root then print_root(obj)
      when Kumi::Syntax::ValueDeclaration then print_value_declaration(obj)
      when Kumi::Syntax::TraitDeclaration then print_trait_declaration(obj)
      when Kumi::Syntax::InputDeclaration then print_input_declaration(obj)
      when Kumi::Syntax::CallExpression then print_call_expression(obj)
      when Kumi::Syntax::ArrayExpression then print_array_expression(obj)
      when Kumi::Syntax::CascadeExpression then print_cascade_expression(obj)
      when Kumi::Syntax::InputReference then print_input_reference(obj)
      when Kumi::Syntax::InputElementReference then print_input_element_reference(obj)
      when Kumi::Syntax::DeclarationReference then print_declaration_reference(obj)
      when Kumi::Syntax::Literal then print_literal(obj)

      # Analyzer objects and structs
      when Kumi::Core::Analyzer::Passes::NameIndexer then "NameIndexer"
      when Kumi::Core::Analyzer::Passes::TypeChecker then "TypeChecker"
      when Kumi::Core::Analyzer::Passes::BroadcastDetector then "BroadcastDetector"
      when Kumi::Core::Analyzer::Structs::InputMeta then print_input_meta(obj)
      when Kumi::Core::Analyzer::Structs::AccessPlan then print_access_plan(obj)
      when Kumi::Core::Analyzer::Plans::Scope then print_scope_plan(obj)
      when Kumi::Core::Analyzer::Plans::Reduce then print_reduce_plan(obj)
      when Kumi::Core::Analyzer::Plans::Join then print_join_plan(obj)
      when Kumi::Core::Analyzer::Passes::DependencyResolver::DependencyEdge then print_dependency_edge(obj)

      # IR objects
      when Kumi::Core::IR::Module then print_ir_module(obj)
      when Kumi::Core::IR::Decl then print_ir_decl(obj)
      when Kumi::Core::IR::Op then print_ir_op(obj)

      # Collections
      when Set then print_set(obj)
      when Array then print_array(obj)
      when Hash then print_hash(obj)

      # Strings (including object inspections)
      when String then print_string(obj)

      # Basic Ruby types
      when Integer, Float, TrueClass, FalseClass, NilClass, Symbol then obj.inspect

      # Explicitly fail for unhandled types
      else raise "No printer defined for #{obj.class}: #{obj.inspect}"
      end
    end

    private

    def print_root(obj)
      "Root(#{obj.inputs.size} inputs, #{obj.values.size} values, #{obj.traits.size} traits)"
    end

    def print_value_declaration(obj)
      "ValueDeclaration(#{obj.name})"
    end

    def print_trait_declaration(obj)
      "TraitDeclaration(#{obj.name})"
    end

    def print_input_declaration(obj)
      "InputDeclaration(#{obj.name}:#{obj.type})"
    end

    def print_call_expression(obj)
      "CallExpression(#{obj.fn_name})"
    end

    def print_array_expression(obj)
      "ArrayExpression[#{obj.elements.size}]"
    end

    def print_cascade_expression(obj)
      "CascadeExpression[#{obj.cases.size}]"
    end

    def print_input_reference(obj)
      "InputRef(#{obj.name})"
    end

    def print_input_element_reference(obj)
      "InputElementRef(#{obj.path.join('.')})"
    end

    def print_declaration_reference(obj)
      "DeclRef(#{obj.name})"
    end

    def print_literal(obj)
      "Literal(#{obj.value.inspect})"
    end

    def print_input_meta(obj)
      "InputMeta(#{obj.type}:#{obj.container})"
    end

    def print_access_plan(obj)
      "AccessPlan(#{obj.path})"
    end

    def print_scope_plan(obj)
      "ScopePlan(#{obj.scope.inspect})"
    end

    def print_reduce_plan(obj)
      "ReducePlan(#{obj.function})"
    end

    def print_join_plan(obj)
      "JoinPlan(#{obj.policy})"
    end

    def print_dependency_edge(obj)
      "DependencyEdge(#{obj.to})"
    end

    def print_ir_module(obj)
      "IRModule(#{obj.inputs.size} inputs)"
    end

    def print_ir_decl(obj)
      "IRDecl(#{obj.name}:#{obj.kind})"
    end

    def print_ir_op(obj)
      "IROp(#{obj.tag})"
    end

    def print_set(obj)
      if obj.size > 3
        items = obj.first(3).map { |item| print(item) }
        "Set[#{items.join(', ')}, +#{obj.size - 3}]"
      else
        items = obj.map { |item| print(item) }
        "Set[#{items.join(', ')}]"
      end
    end

    def print_array(obj)
      return "[]" if obj.empty?
      return "Array[#{obj.size}]" if obj.size > 5

      items = obj.first(3).map { |item| print(item) }
      suffix = obj.size > 3 ? ", +#{obj.size - 3}" : ""
      "[#{items.join(', ')}#{suffix}]"
    end

    def print_hash(obj)
      return "{}" if obj.empty?
      return "Hash{#{obj.size}}" if obj.size > 3

      pairs = obj.first(2).map { |k, v| "#{print(k)}: #{print(v)}" }
      suffix = obj.size > 2 ? ", +#{obj.size - 2}" : ""
      "{#{pairs.join(', ')}#{suffix}}"
    end

    def print_string(obj)
      # Handle object inspection strings
      case obj
      when /^#<struct Kumi::Syntax::(\w+)/
        type = ::Regexp.last_match(1)
        if obj.include?("name=:")
          name = obj[/name=:(\w+)/, 1]
          "#{type}(#{name})"
        else
          type
        end
      when /^#<Kumi::Core::Analyzer::/
        obj[/::(\w+)/, 1] || "AnalyzerObject"
      when /^#<Set: \{(.*)\}>/
        items_str = ::Regexp.last_match(1)
        items = items_str.split(", ").first(3)
        "Set[#{items.join(', ')}#{'...' if items_str.split(', ').size > 3}]"
      else
        truncate_string(obj)
      end
    end

    def print_class(obj)
      class_name = obj.name&.split("::")&.last || obj.to_s
      "Class(#{class_name})"
    end

    def truncate_string(str, max_length = 50)
      return str if str.length <= max_length

      "#{str[0..max_length - 3]}..."
    end
  end
end
