# frozen_string_literal: true

module Kumi
  module Frontends
    def self.load(path:, inputs: {})
      mode = (ENV["KUMI_PARSER"] || "auto") # auto|text|ruby
      ext  = File.extname(path)

      # Explicit mode selection
      return Text.load(path:, inputs:) if mode == "text"
      return Ruby.load(path:, inputs:) if mode == "ruby"
      
      # Auto mode: prefer .kumi if present
      if mode == "auto" && ext == ".rb"
        kumi_path = path.sub(/\.rb\z/, ".kumi")
        if File.exist?(kumi_path)
          return Text.load(path: kumi_path, inputs: inputs)
        end
      end
      
      # File extension based selection
      return Text.load(path:, inputs:) if ext == ".kumi"
      return Ruby.load(path:, inputs:) if ext == ".rb"
      
      # Default fallback
      Ruby.load(path:, inputs:)
    end
  end
end