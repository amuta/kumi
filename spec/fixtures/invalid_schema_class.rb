class InvalidSchema
  extend Kumi::Parser::Dsl

  schema do
    # this line should trigger our “missing expr” error
    value :name
  end
end
