require "yaml"
module Kumi::Core::Functions
  Function = Data.define(:name, :domain, :opset, :class_sym, :signatures,
                         :type_vars, :dtypes, :null_policy, :algebra, :semantics, :vectorization,
                         :options, :traits, :shape_fn, :kernels, :monotonicity)

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
        semantics: (h["semantics"] || {}).transform_keys(&:to_sym),
        vectorization: (h["vectorization"] || {}).transform_keys!(&:to_sym),
        options: h["options"] || {},
        traits: (h["traits"] || {}).transform_keys!(&:to_sym),
        shape_fn: h["shape_fn"],
        kernels: kernels,
        monotonicity: (h["monotonicity"] || {}).transform_keys(&:to_sym)
      )
    end

    # " (i),(j)->(i,j)@product " → Signature
    def self.parse_signature(s)
      lhs, rhs = s.split("->").map(&:strip)
      out_axes, policy = rhs.split("@").map(&:strip)
      
      # Parse input shapes by splitting on commas between parentheses
      in_shapes = parse_input_shapes(lhs)
      
      Signature.new(in_shapes: in_shapes,
                    out_shape: parse_axes(out_axes),
                    join_policy: policy&.to_sym)
    end

    # Parse "(i),(j)" or "(i,j),(k,l)" properly
    def self.parse_input_shapes(lhs)
      # Find all parenthesized groups
      shapes = []
      current_pos = 0
      
      while current_pos < lhs.length
        # Find the next opening parenthesis
        start_paren = lhs.index('(', current_pos)
        break unless start_paren
        
        # Find the matching closing parenthesis
        paren_count = 0
        end_paren = start_paren
        
        (start_paren..lhs.length-1).each do |i|
          case lhs[i]
          when '('
            paren_count += 1
          when ')'
            paren_count -= 1
            if paren_count == 0
              end_paren = i
              break
            end
          end
        end
        
        # Extract the shape
        shape_str = lhs[start_paren..end_paren]
        shapes << parse_axes(shape_str)
        current_pos = end_paren + 1
      end
      
      shapes
    end

    def self.parse_axes(txt)
      txt = txt.strip
      return [] if txt == "()" || txt.empty?

      inner = txt.sub("(", "").sub(")", "")
      if inner.empty?
        []
      else
        inner.split(",").map do |a|
          dim_name = a.strip.to_sym
          Dimension.new(dim_name)  # Convert to Dimension objects
        end
      end
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
