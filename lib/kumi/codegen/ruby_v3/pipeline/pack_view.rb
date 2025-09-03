# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::PackView

class Kumi::Codegen::RubyV3::Pipeline::PackView
  def initialize(pack)
    @pack = pack
    @decls = pack.fetch("declarations")
    @inputs = pack.fetch("inputs")
    @by_name = @decls.to_h { |d| [d.fetch("name"), d] }
    @chain_index = build_chain_index(@inputs)
  end

  def declarations_in_order
    @decls.map { _1.fetch("name") }
  end

  def decl_spec(name)
    d = @by_name.fetch(name)
    { operations: d.fetch("operations"), result_op_id: d.fetch("result_op_id") }
  end

  def decl_plan(name)
    d = @by_name.fetch(name)
    {
      axes: d.fetch("axes"),
      axis_carriers: d.fetch("axis_carriers", []),
      reduce_plans: d.fetch("reduce_plans", []),
      site_schedule: d.fetch("site_schedule"),
      inlining_decisions: d.fetch("inlining_decisions", {})
    }
  end

  def axes_of_decl(name) = decl_plan(name)[:axes]

  def producer_axes(name) = axes_of_decl(name)

  def input_chain_by_path(path)
    @chain_index.fetch(path) do
      raise KeyError, "Chain not found for path: #{path.inspect}"
    end
  end

  private

  def build_chain_index(inputs)
    idx = {}
    inputs.each do |inp|
      # The LoadInput operation uses the path from the input name
      # e.g. "cube.layer.cell" becomes ["cube", "layer", "cell"]
      path_parts = inp.fetch("name").split(".")
      idx[path_parts] = inp.fetch("chain")
    end
    idx
  end
end