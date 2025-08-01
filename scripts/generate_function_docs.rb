#!/usr/bin/env ruby
# frozen_string_literal: true

# This script loads the Kumi library and introspects the FunctionRegistry
# to generate a Markdown reference for the standard function library.

require "bundler/setup"
require "kumi"

# Helper to format the type information for display.
def format_type(type)
  Kumi::Core::Types.type_to_s(type)
end

# Helper to generate a signature string for a function.
def generate_signature(name, signature)
  params = if signature[:arity].negative?
             # Variadic function (e.g., add, concat)
             param_type = format_type(signature[:param_types].first || :any)
             "#{param_type}1, #{param_type}2, ..."
           else
             # Fixed arity function
             signature[:param_types].map.with_index { |type, i| "#{format_type(type)} arg#{i + 1}" }.join(", ")
           end

  return_type = format_type(signature[:return_type])
  "`fn(:#{name}, #{params})` → `#{return_type}`"
end

# Main documentation generation logic.
def generate_docs
  output = []
  add_header(output)
  add_function_categories(output)
  output.join("\n")
end

def add_header(output)
  output << "# Kumi Standard Function Library Reference"
  output << "\nKumi provides a rich library of built-in functions for use within `value` and `trait` expressions via `fn(...)`."
end

def add_function_categories(output)
  function_categories.each do |title, functions|
    output << "\n## #{title}\n"
    add_functions_for_category(output, functions)
  end
end

def function_categories
  {
    "Logical Functions" => Kumi::Registry.logical_operations,
    "Comparison Functions" => Kumi::Registry.comparison_operators,
    "Math Functions" => Kumi::Registry.math_operations,
    "String Functions" => Kumi::Registry.string_operations,
    "Collection Functions" => Kumi::Registry.collection_operations,
    "Conditional Functions" => Kumi::Registry.conditional_operations,
    "Type & Hash Functions" => Kumi::Registry.type_operations
  }
end

def add_functions_for_category(output, functions)
  functions.sort.each do |name|
    signature = Kumi::Registry.signature(name)
    output << "* **`#{name}`**: #{signature[:description]}"
    output << "  * **Usage**: #{generate_signature(name, signature)}"
  end
end

# Execute the script and print the documentation.
puts generate_docs
