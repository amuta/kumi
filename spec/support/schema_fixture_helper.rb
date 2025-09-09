# frozen_string_literal: true

module SchemaFixtureHelper
  def require_schema(name)
    require_relative "../fixtures/schemas/#{name}"
  end
end
