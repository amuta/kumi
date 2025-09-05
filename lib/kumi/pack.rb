# frozen_string_literal: true

module Kumi
  module Pack
    module_function

    def build(schema:, out_dir:, targets: %w[ruby], include_ir: false)
      Builder.build(schema: schema, out_dir: out_dir, targets: targets, include_ir: include_ir)
    end

    def print(schema:, targets: %w[ruby], include_ir: false)
      Builder.print(schema: schema, targets: targets, include_ir: include_ir)
    end

  end
end
