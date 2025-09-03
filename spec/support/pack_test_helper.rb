# frozen_string_literal: true

require "tempfile"
require "json"

module PackTestHelper
  def pack_for(schema_txt, targets: %w[ruby])
    Tempfile.create(["test_schema", ".kumi"]) do |file|
      file.write(schema_txt)
      file.flush
      
      pack_json = Kumi::Pack.print(schema: file.path, targets: targets, include_ir: false)
      JSON.parse(pack_json)
    end
  end
end