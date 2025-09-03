# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::DeclContext

module Kumi::Codegen::RubyV3::Pipeline::DeclContext
  module_function
  
  def run(view, name)
    spec = view.decl_spec(name)
    plan = view.decl_plan(name)
    {
      name: name,
      axes: plan[:axes],
      axis_carriers: plan[:axis_carriers],
      reduce_plans: plan[:reduce_plans],
      site_schedule: plan[:site_schedule],
      inline: plan[:inlining_decisions],
      ops: spec[:operations],
      result_id: spec[:result_op_id]
    }
  end
end