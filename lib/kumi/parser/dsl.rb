# frozen_string_literal: true

module Kumi
  module Parser
    module Dsl
      def self.build_schema(&block)
        context = DslBuilderContext.new
        proxy   = DslProxy.new(context)
        proxy.instance_eval(&block)
        Syntax::Schema.new(
          context.attributes,
          context.traits
        )
      end

      class << self
        alias schema build_schema
      end

      # –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
      # instance method for classes/modules that `extend Kumi::Parser::Dsl`
      #
      #   class MyThing
      #     extend Kumi::Parser::Dsl
      #     schema { … }
      #   end
      #
      def schema(&block)
        @__schema__ = Kumi::Parser::Dsl.build_schema(&block)
      end

      def generated_schema
        @__schema__
      end
    end
  end
end
