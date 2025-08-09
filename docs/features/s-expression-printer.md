# S-Expression Printer

Debug and inspect Kumi AST structures with readable S-expression notation output.

## Overview

The S-Expression Printer provides a clean, structured way to visualize Kumi's Abstract Syntax Tree (AST) nodes in traditional Lisp-style S-expression format. This is particularly useful for debugging schema parsing, understanding AST structure, and analyzing complex expressions.

## Usage

```ruby
require 'kumi/support/s_expression_printer'

# Print any AST node
Kumi::Support::SExpressionPrinter.print(node)

# Print a complete schema AST
module MySchema
  extend Kumi::Schema
  
  schema do
    input do
      integer :age
      string :name
    end
    
    trait :adult, (input.age >= 18)
    value :greeting, fn(:concat, "Hello ", input.name)
  end
end

puts Kumi::Support::SExpressionPrinter.print(MySchema.__syntax_tree__)
```

## Output Format

The printer produces indented S-expressions that clearly show the hierarchical structure:

```lisp
(Root
  inputs: [
    (InputDeclaration :age :integer)
    (InputDeclaration :name :string)
  ]
  values: [
    (ValueDeclaration :greeting
      (CallExpression :concat
        (Literal "Hello ")
        (InputReference :name)
      )
    )
  ]
  traits: [
    (TraitDeclaration :adult
      (CallExpression :>=
        (InputReference :age)
        (Literal 18)
      )
    )
  ]
)
```

## Supported Node Types

The printer handles all Kumi AST node types:

- **Root** - Schema container with inputs, values, and traits
- **Declarations** - InputDeclaration, ValueDeclaration, TraitDeclaration
- **Expressions** - CallExpression, ArrayExpression, CascadeExpression, CaseExpression
- **References** - InputReference, InputElementReference, DeclarationReference
- **Literals** - Literal values (strings, numbers, booleans)
- **Collections** - Arrays and HashExpression nodes

## Implementation

Built as a visitor pattern class that traverses AST nodes recursively, with each node type having its own specialized formatting method. The printer preserves proper indentation and handles nested structures gracefully.