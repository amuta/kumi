# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # InliningPolicy decides whether a consumer should inline a producer
      # (LoadDeclaration) or call it as a separate method.
      #
      # Key rule: inline if producer.result_axes == consumer_use_site_axes
      # where use_site_axes is the stamp.axes of the LoadDeclaration op
      #
      # Interface:
      #   .build(module_spec:) -> InliningPolicy
      #   #decision(producer_decl:, consumer_use_site_axes:) -> :inline | :call
      class InliningPolicy
        def self.build(module_spec:)
          new(module_spec)
        end

        def initialize(mod)
          @mod = mod
        end

        # @param producer_decl [DeclSpec] The declaration being loaded
        # @param consumer_use_site_axes [Array<Symbol>] The stamp.axes of the LoadDeclaration op
        def decision(producer_decl:, consumer_use_site_axes:)
          producer_axes = Array(producer_decl.axes).map(&:to_sym)
          use_site_axes = Array(consumer_use_site_axes).map(&:to_sym)
          producer_axes == use_site_axes ? :inline : :call
        end
      end
    end
  end
end
