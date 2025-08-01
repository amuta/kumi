# frozen_string_literal: true

module Kumi
  module Core
    module Export
      module Errors
        class ExportError < StandardError; end
        class SerializationError < ExportError; end
        class DeserializationError < ExportError; end
        class VersionMismatchError < ExportError; end
      end
    end
  end
end
