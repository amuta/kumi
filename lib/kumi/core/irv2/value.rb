# frozen_string_literal: true

require "set"

module Kumi
  module Core
    module IRV2
      class Value
        attr_reader :id, :op, :args, :attrs

        def initialize(id, op, args, attrs)
          @id = id
          @op = op
          @args = args
          @attrs = attrs
        end

        def to_s
          a = args.map { |x| x.is_a?(Value) ? "%#{x.id}" : x.inspect }.join(", ")
          attrs_s = attrs.empty? ? "" : " " + attrs.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
          format("%%%d = %s(%s)%s", id, op, a, attrs_s)
        end
      end
    end
  end
end
