# frozen_string_literal: true

module Kumi
  module Codegen
    module Planning
      # InliningPolicy decides whether a consumer should inline a producer
      # (LoadDeclaration) or call it as a separate method.
      #
      # Minimal deterministic rule (good default):
      #   inline if producer.result_axes == consumer_site_axes
      #   otherwise: call
      #
      # Interface:
      #   .build(module_spec:) -> InliningPolicy
      #   #decision(consumer_decl:, producer_decl:) -> :inline | :call
      class InliningPolicy
        def self.build(module_spec:)
          new(module_spec)
        end

        def initialize(mod)
          @mod = mod
        end

        # @param consumer_decl [DeclSpec]
        # @param producer_decl [DeclSpec]
        def decision(consumer_decl:, producer_decl:)
          # NOTE: this is a scaffold. Replace with your exact rule if needed.
          producer_axes = Array(producer_decl.axes)
          consumer_axes = Array(consumer_decl.axes)
          producer_axes == consumer_axes ? :inline : :call
        end
      end
    end
  end
end
