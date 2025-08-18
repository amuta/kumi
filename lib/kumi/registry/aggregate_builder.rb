# frozen_string_literal: true

module Kumi
  module Registry
    class AggregateBuilder < BaseBuilder
      DEFAULTS = {
        signatures:  ["(i)->()"],
        zip_policy:  :zip,
        null_policy: :skip,
        dtypes:      { "result" => "float" }
      }.freeze

      def build!
        missing = []
        missing << :identity if @identity.nil?
        build_error!(missing) unless missing.empty?
        finalize_entry(kind: :aggregate, defaults: DEFAULTS)
      end
    end
  end
end