# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::PackSanity

module Kumi::Codegen::RubyV3::Pipeline::PackSanity
  module_function
  
  def run(pack)
    raise KeyError, "declarations missing" unless pack["declarations"].is_a?(Array)
    raise KeyError, "inputs missing"       unless pack["inputs"].is_a?(Array)
    true
  end
end