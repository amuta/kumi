module Kumi::Core::Functions
  DType = Struct.new(:name, keyword_init: true)
  module DTypes
    BOOL = DType.new(name: :bool)
    INT = DType.new(name: :int)
    FLOAT = DType.new(name: :float)
    STRING = DType.new(name: :string)
    DATETIME = DType.new(name: :datetime)
    ANY = DType.new(name: :any)
  end

  module Promotion
    # super simple table; extend later
    TABLE = {
      %i[int int] => :int,  %i[int float] => :float, %i[float int] => :float, %i[float float] => :float,
      %i[bool int] => :int, %i[bool float] => :float, %i[bool bool] => :bool
    }
    def self.promote(a, b) = TABLE[[a, b]] || TABLE[[b, a]] || :any
  end
end
