# Zeitwerk: Kumi::Codegen::RubyV3::CGIR

module Kumi::Codegen::RubyV3::CGIR
  Function = Struct.new(:name, :rank, :ops, keyword_init: true)
  
  module Op
    def self.open_loop(depth:, via_path:)
      {k: :OpenLoop, depth:, via_path:}
    end
    
    def self.acc_reset(name:, depth:, init:)
      {k: :AccReset, name:, depth:, init:}
    end
    
    def self.acc_add(name:, expr:, depth:)
      {k: :AccAdd, name:, expr:, depth:}
    end
    
    def self.emit(code:, depth:)
      {k: :Emit, code:, depth:}
    end
    
    def self.yield(expr:, indices:, depth:)
      {k: :Yield, expr:, indices:, depth:}
    end
    
    def self.close_loop(depth:)
      {k: :CloseLoop, depth:}
    end
  end
end