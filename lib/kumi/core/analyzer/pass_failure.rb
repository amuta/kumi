# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      class PassFailure
        attr_reader :message, :phase, :pass_name, :location

        def initialize(message:, phase:, pass_name:, location:)
          @message = message
          @phase = phase
          @pass_name = pass_name
          @location = location
        end

        def to_s
          if location
            "#{pass_name} (phase #{phase}) at #{location}: #{message}"
          else
            "#{pass_name} (phase #{phase}): #{message}"
          end
        end
      end
    end
  end
end
