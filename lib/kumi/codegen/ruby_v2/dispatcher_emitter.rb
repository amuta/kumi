# frozen_string_literal: true

require_relative "name_mangler"

module Kumi
  module Codegen
    module RubyV2
      module DispatcherEmitter
        module_function

        def render(declaration_order:)
          arms = declaration_order.map do |d|
            "when :#{d} then (@memo[:#{d}] ||= #{NameMangler.eval_method_for(d)})"
          end

          <<~RUBY
            def [](name)
              case name
                #{arms.map { |a| a.prepend(" " * 14) }.join("\n")}
              else
                raise ArgumentError, "unknown declaration: \#{name}"
              end
            end
          RUBY
        end
      end
    end
  end
end