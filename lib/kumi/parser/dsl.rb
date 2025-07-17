# frozen_string_literal: true

module Kumi
  module Parser
    module Dsl
      def self.build_sytax_tree(&block)
        context = DslBuilderContext.new
        proxy   = DslProxy.new(context)
        proxy.instance_eval(&block)
        Syntax::Root.new(
          context.inputs,
          context.attributes,
          context.traits
        )
      end
    end
  end
end
