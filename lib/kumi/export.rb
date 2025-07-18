# frozen_string_literal: true

require "json"

module Kumi
  module Export
    # Core interface - only depends on Syntax::Root
    def self.to_json(syntax_root, **options)
      Serializer.new(**options).serialize(syntax_root)
    end

    def self.from_json(json_string, **options)
      Deserializer.new(**options).deserialize(json_string)
    end

    # Convenience methods
    def self.to_file(syntax_root, filepath, **options)
      File.write(filepath, to_json(syntax_root, **options))
    end

    def self.from_file(filepath, **options)
      from_json(File.read(filepath), **options)
    end

    # Validation without import
    def self.valid?(json_string)
      from_json(json_string)
      true
    rescue StandardError
      false
    end
  end
end
