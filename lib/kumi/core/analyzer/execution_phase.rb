# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      class ExecutionPhase
        attr_reader :pass_class, :index

        def initialize(pass_class:, index:)
          @pass_class = pass_class
          @index = index
        end

        def pass_name
          @pass_class.name.split("::").last
        end

        def to_s
          "Phase #{index}: #{pass_name}"
        end
      end
    end
  end
end
