# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::StreamLowerer

module Kumi::Codegen::RubyV3::Pipeline::StreamLowerer
  module_function
  
  CGIR = Kumi::Codegen::RubyV3::CGIR
  
  def run(view, ctx, loop_shape:, consts:, deps:, identities:)
    ops = []
    rank = loop_shape[:rank]

    depth_of = {}
    ctx[:site_schedule].fetch("by_depth").each do |dinfo|
      d = dinfo.fetch("depth")
      dinfo.fetch("ops").each { |o| depth_of[o.fetch("id")] = d }
    end

    # Generate all operations first, then sort by depth + type
    
    # AccReset operations
    ctx[:reduce_plans].each do |rp|
      red_id = rp.fetch("op_id")
      reducer_fn = rp.fetch("reducer_fn")
      identity_val = identities.fetch(reducer_fn)
      result_depth = depth_of.fetch(red_id)
      ops << CGIR::Op.acc_reset(name: "acc_#{red_id}", depth: result_depth, init: identity_val)
    end

    # Loop operations
    loop_shape[:loops].each { |l| ops << CGIR::Op.open_loop(depth: l[:depth], via_path: l[:via_path]) }
    loop_shape[:loops].reverse_each { |l| ops << CGIR::Op.close_loop(depth: l[:depth]) }

    # Const preludes
    const_preludes(consts, ctx[:site_schedule]).each { |(code, d)| ops << CGIR::Op.emit(code: code, depth: d) }

    # Site schedule operations
    ctx[:site_schedule].fetch("by_depth").each do |dinfo|
      d = dinfo.fetch("depth")
      dinfo.fetch("ops").each do |sched|
        op = ctx[:ops].find { |o| o["id"] == sched["id"] }
        case sched["kind"]
        when "loadinput"
          path  = op["args"].first
          chain = view.input_chain_by_path(path)
          expr  = emit_chain_access(chain, d, rank)
          ops << CGIR::Op.emit(code: "v#{op['id']} = #{expr}", depth: d)
        when "const"
          next if consts[:inline_ids].include?(op["id"])
          val = op["args"].first
          ops << CGIR::Op.emit(code: "c#{op['id']} = #{literal(val)}", depth: d)
        when "map"
          args = op["args"].map { |a| ref(a, consts, deps) }.join(", ")
          fn   = op["attrs"]["fn"]
          ops << CGIR::Op.emit(code: "v#{op['id']} = __call_kernel__(#{fn.inspect}, #{args})", depth: d)
        when "select"
          a,b,c = op["args"].map { |a| ref(a, consts, deps) }
          ops << CGIR::Op.emit(code: "v#{op['id']} = (#{a} ? #{b} : #{c})", depth: d)
        when "loaddeclaration"
          if deps[:inline_ids].include?(op["id"])
            target = op["args"].first.to_s
            rank = view.producer_axes(target).length  
            idxs = (0...rank).map { |k| "[i#{k}]" }.join
            ops << CGIR::Op.emit(code: "v#{op['id']} = self[:#{target}]#{idxs}", depth: d)
          else
            info = deps[:indexed].fetch(op["id"])
            idxs = (0...info[:rank]).map { |k| "[i#{k}]" }.join
            ops << CGIR::Op.emit(code: "v#{op['id']} = self[:#{info[:name]}]#{idxs}", depth: d)
          end
        when "constructtuple"
          args = op["args"].map { |a| ref(a, consts, deps) }.join(", ")
          ops << CGIR::Op.emit(code: "v#{op['id']} = [#{args}]", depth: d)
        when "reduce"
          # Skip - AccReset already added above
        end
      end
    end

    # Reduce operations (AccAdd)
    ctx[:reduce_plans].each do |rp|
      val_id = rp.fetch("arg_id")
      red_id = rp.fetch("op_id")
      ops << CGIR::Op.acc_add(name: "acc_#{red_id}", expr: "v#{val_id}", depth: depth_of.fetch(val_id))
    end

    # Result processing
    ctx[:reduce_plans].each do |rp|
      red_id = rp.fetch("op_id")
      ops << CGIR::Op.emit(code: "v#{red_id} = acc_#{red_id}", depth: depth_of.fetch(red_id))
    end

    # Yield
    result_depth = depth_of.fetch(ctx[:result_id])  
    idxs = (0...rank).map { |k| "i#{k}" }
    res  = "v#{ctx[:result_id]}"
    ops << CGIR::Op.yield(expr: res, indices: idxs, depth: result_depth)

    # Sort operations by logical stages and depth
    max_depth = ops.map { |op| op[:depth] || 0 }.max
    
    ops.sort_by! do |op|
      depth = op[:depth] || 0
      case op[:k]
      when :AccReset then [0, depth]  # Stage 0: Initialize accumulators
      when :OpenLoop then [1, depth]  # Stage 1: Start loops (outer to inner)
      when :Emit then 
        # Check if this is result processing (v#{id} = acc_#{id})
        if op[:code]&.match?(/^v\d+ = acc_\d+$/)
          [4, depth]  # Stage 4: Result processing (after loops)
        else
          [2, depth]  # Stage 2: Loop body operations
        end
      when :AccAdd then [2, depth]     # Stage 2: Loop body operations  
      when :CloseLoop then [3, max_depth - depth]  # Stage 3: Close loops (inner to outer)
      when :Yield then 
        if depth == 0
          [5, depth]  # Stage 5: Return results (after all loops)
        else
          [2, depth]  # Stage 2: Yield inside loops (for array results)
        end
      else [2, depth]                  # Default: loop body operations
      end
    end

    CGIR::Function.new(name: ctx[:name], rank:, ops:)
  end

  def const_preludes(consts, site_schedule)
    scheduled_depth = {}
    site_schedule["by_depth"].each do |depth_info|
      depth = depth_info["depth"] 
      depth_info["ops"].each do |op|
        scheduled_depth[op["id"]] = depth if op["kind"] == "const"
      end
    end
    
    consts[:prelude].map do |c| 
      const_id = c[:name].sub("c", "").to_i
      depth = scheduled_depth.fetch(const_id, 0)
      ["#{c[:name]} = #{literal(c[:value])}", depth]
    end
  end

  module_function
  
  def emit_chain_access(chain, current_depth, rank)
    # Count array steps (both array_field and array_element) to determine base
    array_steps = chain.count { |s| s["kind"] == "array_field" || s["kind"] == "array_element" }
    base = array_steps.zero? ? "@input" : "a#{array_steps - 1}"
    
    # Process remaining field access steps
    field_steps = chain.drop_while { |s| s["kind"] == "array_field" || s["kind"] == "array_element" }
    field_steps.reduce(base) do |acc, step|
      case step["kind"]
      when "field_leaf"
        "#{acc}[#{literal(step['key'])}]"
      when "element_leaf"
        # element_leaf: "the element itself is the value" - no additional access needed
        acc
      else
        acc
      end
    end
  end

  def ref(arg, consts, deps)
    return "c#{arg}" if arg.is_a?(Integer) && consts[:prelude].any? { |c| c[:name] == "c#{arg}" }
    return "v#{arg}" if arg.is_a?(Integer)
    arg
  end

  def literal(x) = x.is_a?(String) ? x.inspect : x
end