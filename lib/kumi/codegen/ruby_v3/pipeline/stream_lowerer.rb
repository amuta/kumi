# Zeitwerk: Kumi::Codegen::RubyV3::Pipeline::StreamLowerer

module Kumi::Codegen::RubyV3::Pipeline::StreamLowerer
  module_function
  
  CGIR = Kumi::Codegen::RubyV3::CGIR
  
  def run(view, ctx, loop_shape:, consts:, deps:, identities:)
    ops = []
    rank = loop_shape[:rank]

    loop_shape[:loops].each { |l| ops << CGIR::Op.open_loop(depth: l[:depth], via_path: l[:via_path]) }

    depth_of = {}
    ctx[:site_schedule].fetch("by_depth").each do |dinfo|
      d = dinfo.fetch("depth")
      dinfo.fetch("ops").each { |o| depth_of[o.fetch("id")] = d }
    end

    const_preludes(consts, ctx[:site_schedule]).each { |(code, d)| ops << CGIR::Op.emit(code: code, depth: d) }

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
          reduce_plan = ctx[:reduce_plans].find { |r| r["op_id"] == op["id"] }
          reducer_fn = reduce_plan.fetch("reducer_fn")
          identity_val = identities.fetch(reducer_fn, 0)
          ops << CGIR::Op.acc_reset(name: "acc_#{op['id']}", depth: d, init: identity_val)
        end
      end
    end

    ctx[:reduce_plans].each do |rp|
      val_id = rp.fetch("arg_id")
      red_id = rp.fetch("op_id")
      ops << CGIR::Op.acc_add(name: "acc_#{red_id}", expr: "v#{val_id}", depth: depth_of.fetch(val_id))
      ops << CGIR::Op.emit(code: "v#{red_id} = acc_#{red_id}", depth: depth_of.fetch(red_id))
    end

    result_depth = depth_of.fetch(ctx[:result_id])  
    idxs = (0...rank).map { |k| "i#{k}" }
    res  = "v#{ctx[:result_id]}"
    ops << CGIR::Op.yield(expr: res, indices: idxs, depth: result_depth)

    loop_shape[:loops].reverse_each { |l| ops << CGIR::Op.close_loop(depth: l[:depth]) }

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
    axes_in_chain = chain.count { |s| s["kind"] == "array_field" }
    base = axes_in_chain.zero? ? "@input" : "a#{axes_in_chain - 1}"  
    field_steps = chain.drop(axes_in_chain)
    field_steps.reduce(base) { |acc, step| "#{acc}[#{literal(step['key'])}]" }
  end

  def ref(arg, consts, deps)
    return "c#{arg}" if arg.is_a?(Integer) && consts[:prelude].any? { |c| c[:name] == "c#{arg}" }
    return "v#{arg}" if arg.is_a?(Integer)
    arg
  end

  def literal(x) = x.is_a?(String) ? x.inspect : x
end