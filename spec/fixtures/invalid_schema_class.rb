class InvalidSchema
  extend Kumi::Schema

  schema do
    # this line should trigger our “missing expr” error
    value :name
  end
end
