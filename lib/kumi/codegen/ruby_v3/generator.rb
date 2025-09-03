# Zeitwerk: Kumi::Codegen::RubyV3::Generator

class Kumi::Codegen::RubyV3::Generator
  def initialize(pack, module_name:)
    @pack = pack
    @module_name = module_name
  end
  
  def render
    Kumi::Codegen::RubyV3::Pipeline::PackSanity.run(@pack)
    view = Kumi::Codegen::RubyV3::Pipeline::PackView.new(@pack)
    kernels_info = Kumi::Codegen::RubyV3::Pipeline::KernelIndex.run(@pack, target: "ruby")
    kernels = kernels_info[:impls]
    identities = kernels_info[:identities]
    
    fns = view.declarations_in_order.map do |name|
      ctx = Kumi::Codegen::RubyV3::Pipeline::DeclContext.run(view, name)
      loop_shape = Kumi::Codegen::RubyV3::Pipeline::LoopPlanner.run(ctx)
      consts = Kumi::Codegen::RubyV3::Pipeline::ConstPlan.run(ctx)
      deps = Kumi::Codegen::RubyV3::Pipeline::DepPlan.run(view, ctx)
      Kumi::Codegen::RubyV3::Pipeline::StreamLowerer.run(view, ctx, loop_shape:, consts:, deps:, identities:)
    end
    
    Kumi::Codegen::RubyV3::RubyRenderer.render(program: fns, module_name: @module_name, pack_hash: pack_hash(@pack), kernels_table: kernels)
  end
  
  private
  
  def pack_hash(pack)
    (pack["hashes"] || {}).values.join(":")
  end
end