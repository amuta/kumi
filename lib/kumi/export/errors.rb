# frozen_string_literal: true

module Kumi
  module Export
    class ExportError < StandardError; end
    class SerializationError < ExportError; end
    class DeserializationError < ExportError; end
    class VersionMismatchError < ExportError; end
  end
end
