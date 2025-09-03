# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::LoopPlanner

module Kumi::Codegen::RubyV3::Pipeline::LoopPlanner
  module_function
  
  def run(ctx)
    loops = ctx[:axis_carriers].each_with_index.map { |c, d| 
      { depth: d, via_path: c.fetch("via_path") } 
    }
    { rank: ctx[:axes].length, loops: loops }
  end
end