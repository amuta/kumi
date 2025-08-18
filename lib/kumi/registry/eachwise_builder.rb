# frozen_string_literal: true

module Kumi
  module Registry
    class EachwiseBuilder < BaseBuilder
      DEFAULTS = {
        signatures:  ["()->()", "(i)->(i)"],
        zip_policy:  :zip,
        null_policy: :propagate,
        dtypes:      { "result" => "T" }
      }.freeze

      def build!
        finalize_entry(kind: :eachwise, defaults: DEFAULTS)
      end
    end
  end
end