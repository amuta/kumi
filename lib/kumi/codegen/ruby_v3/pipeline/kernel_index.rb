# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::KernelIndex

module Kumi::Codegen::RubyV3::Pipeline::KernelIndex
  module_function

  def run(pack, target: "ruby")
    kernels = Array(pack.dig("bindings", target, "kernels"))
    impls = kernels.to_h { |k| [k.fetch("kernel_id"), k.fetch("impl")] }
    identities = kernels.to_h { |k| [k.fetch("kernel_id"), k.dig("attrs", "identity")] }
    { impls:, identities: }
  end
end
