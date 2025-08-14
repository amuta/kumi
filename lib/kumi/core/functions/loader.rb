require "yaml"
module Kumi::Core::Functions
  Function = Data.define(:name, :domain, :opset, :class_sym, :signatures,
                         :type_vars, :dtypes, :null_policy, :algebra, :vectorization,
                         :options, :traits, :shape_fn, :kernels)

  KernelEntry = Data.define(:backend, :impl, :priority, :when_)

  class Loader
    def self.load_file(path)
      doc = YAML.load_file(path)
      functions = doc.map { |h| build_function(h) }
      validate!(functions)
      functions.freeze
    end

    def self.build_function(h)
      sigs = Array(h.fetch("signature")).map { |s| parse_signature(s) }
      kernels = Array(h.fetch("kernels", [])).map do |k|
        KernelEntry.new(backend: k.fetch("backend").to_sym,
                        impl: k.fetch("impl").to_sym,
                        priority: k.fetch("priority", 0).to_i,
                        when_: k["when"]&.transform_keys!(&:to_sym))
      end
      Function.new(
        name: h.fetch("name"),
        domain: h.fetch("domain"),
        opset: h.fetch("opset").to_i,
        class_sym: h.fetch("class").to_sym,
        signatures: sigs,
        type_vars: h["type_vars"] || {},
        dtypes: h["dtypes"] || {},
        null_policy: (h["null_policy"] || "propagate").to_sym,
        algebra: (h["algebra"] || {}).transform_keys!(&:to_sym),
        vectorization: (h["vectorization"] || {}).transform_keys!(&:to_sym),
        options: h["options"] || {},
        traits: (h["traits"] || {}).transform_keys!(&:to_sym),
        shape_fn: h["shape_fn"],
        kernels: kernels
      )
    end

    # " (i),(j)->(i,j)@product " → Signature
    def self.parse_signature(s)
      lhs, rhs = s.split("->").map(&:strip)
      out_axes, policy = rhs.split("@").map(&:strip)
      in_shapes = lhs.split(",").map { |t| parse_axes(t) }
      Signature.new(in_shapes: in_shapes,
                    out_shape: parse_axes(out_axes),
                    join_policy: policy&.to_sym)
    end

    def self.parse_axes(txt)
      txt = txt.strip
      return [] if txt == "()" || txt.empty?

      inner = txt.sub("(", "").sub(")", "")
      inner.empty? ? [] : inner.split(",").map { |a| a.strip.to_sym }
    end

    def self.validate!(fns)
      names = {}
      fns.each do |f|
        key = [f.domain, f.name, f.opset]
        raise "duplicate function #{key}" if names[key]

        names[key] = true
        raise "no kernels for #{f.name}" if f.kernels.empty?
      end
    end
  end
end
