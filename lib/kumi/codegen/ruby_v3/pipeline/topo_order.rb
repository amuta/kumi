# frozen_string_literal: true

# Deterministic topological ordering for CGIR ops.
# :depth may be negative (global prelude). Phases: :pre < :body < :post.

module Kumi
  module Codegen
    module RubyV3
      module Pipeline
        module TopoOrder
          module_function

          PHASE_RANK = { pre: 0, body: 1, post: 2 }.freeze

          def order(ops)
            nodes = ops.each_with_index.to_h { |op, i| [i, op] }

            edges = Hash.new { |h, k| h[k] = [] }
            indeg = Hash.new(0)
            add_edge = lambda do |from, to, reason|
              return if from.nil? || to.nil? || from == to
              return if edges[from].any? { |(t, _)| t == to }
              edges[from] << [to, reason]
              indeg[to] += 1
            end

            # Index by depth/phase and locate loop open/close per depth
            by_depth_phase = Hash.new { |h, k| h[k] = [] }
            open_at_d  = {}
            close_at_d = {}

            nodes.each do |i, op|
              d = op[:depth] || 0
              p = op[:phase] || :body
              by_depth_phase[[d, p]] << i
              case op[:k]
              when :OpenLoop  then open_at_d[d]  = i
              when :CloseLoop then close_at_d[d] = i
              end
            end

            depths = (by_depth_phase.keys.map(&:first) + open_at_d.keys + close_at_d.keys).uniq.sort
            max_depth = depths.max || 0

            # 1) Loop structure: chain opens/closes; parent open encloses deeper work
            0.upto(max_depth - 1) do |d|
              add_edge.call(open_at_d[d], open_at_d[d + 1], :open_chain) if open_at_d[d] && open_at_d[d + 1]
              add_edge.call(close_at_d[d + 1], close_at_d[d], :close_chain) if close_at_d[d] && close_at_d[d + 1]
            end

            depths.each do |d|
              pre  = by_depth_phase[[d, :pre]]
              body = by_depth_phase[[d, :body]]
              post = by_depth_phase[[d, :post]]
              o    = open_at_d[d]
              c    = close_at_d[d]

              (pre + body + post).each do |i|
                add_edge.call(o, i, :open_fence)  if o && i != o
                add_edge.call(i, c, :close_fence) if c && i != c
              end

              pre.product(body).each { |a, b| add_edge.call(a, b, :pre_before_body) } if pre.any? && body.any?
              body.product(post).each { |a, b| add_edge.call(a, b, :body_before_post) } if body.any? && post.any?

              if o && open_at_d[d + 1]
                (%i[pre body post].flat_map { |ph| by_depth_phase[[d + 1, ph]] }).each do |i|
                  add_edge.call(o, i, :open_encloses_deeper)
                end
              end

          # Inner loop must close before parent's post (only for non-negative depths)
          if d >= 0 && close_at_d[d + 1] && post.any?
            post.each { |pid| add_edge.call(close_at_d[d + 1], pid, :inner_close_before_post) }
          end

            end

            # 2) Reduction discipline: reset → adds → bind
            resets = nodes.select { |_, op| (op[:defines] || []).any? { |d| d.to_s.start_with?("acc_") } && op[:op_type].nil? }
            adds   = nodes.select { |_, op| op[:op_type] == :acc_apply }

            resets.each do |reset_i, reset_op|
              acc_name = reset_op[:defines].first
              adds_for_acc = adds.select { |_, add_op| (add_op[:uses] || []).include?(acc_name) }
              adds_for_acc.each_key { |add_i| add_edge.call(reset_i, add_i, :reset_before_add) }
            end

            nodes.each do |i, op|
              next unless op[:k] == :Emit && op[:op_type] == :acc_bind
              used_acc = (op[:uses] || []).find { |u| u.start_with?("acc_") }
              next unless used_acc
              nodes.each do |j, op2|
                next unless op2[:k] == :Emit && op2[:op_type] == :acc_apply && (op2[:defines] || []).include?(used_acc)
                add_edge.call(j, i, :all_adds_before_bind)
              end
            end

            # 2.5) Finalization: all loops must close before global-scope ops (d<0)
            close_d0 = close_at_d[0]
            if close_d0
              prelude_ops = nodes.keys.select { |i| (nodes[i][:depth] || 0) < 0 && nodes[i][:phase] == :post }

              prelude_ops.each do |p_idx|
                add_edge.call(close_d0, p_idx, :loops_close_before_global)
              end
            end

            # 3) Def→use
            defs = {}
            uses = Hash.new { |h, k| h[k] = [] }
            nodes.each do |i, op|
              (op[:defines] || []).each do |s|
                # Accumulators are handled by reduction discipline rules
                next if s.to_s.start_with?("acc_")
                defs[s] ||= i
              end
              (op[:uses] || []).each { |s| uses[s] << i }
            end
            uses.each do |sym, consumers|
              di = defs[sym]
              next unless di
              consumers.each { |ui| add_edge.call(di, ui, :def_before_use) }
            end

            # 4) Deterministic Kahn topo
            q = nodes.keys.select { |i| indeg[i].zero? }
            q.sort_by! { |i| [nodes[i][:depth] || 0, PHASE_RANK[nodes[i][:phase] || :body], nodes[i][:within_depth_sched] || 0, i] }

            out = []
            until q.empty?
              v = q.shift
              out << v
              edges[v].each do |(to, _)|
                indeg[to] -= 1
                if indeg[to].zero?
                  q << to
                  q.sort_by! { |j| [nodes[j][:depth] || 0, PHASE_RANK[nodes[j][:phase] || :body], nodes[j][:within_depth_sched] || 0, j] }
                end
              end
            end

            if out.size != nodes.size
              warn topo_cycle_debug(nodes, edges, indeg)
              raise "TopoOrder cycle"
            end

            out.map { |i| nodes[i] }
          end

          def topo_cycle_debug(nodes, edges, indeg)
            rem = nodes.keys.select { |i| indeg[i].positive? }
            s = +"=== TOPO ORDER CYCLE DEBUG ===\n"
            s << "Total nodes: #{nodes.size}, Remaining with indegree>0: #{rem.size}\n"
            rem.sort.each do |i|
              op = nodes[i]
              s << fmt_node(i, op, indeg[i])
              incoming = edges.select { |_from, tos| tos.any? { |(to, _)| to == i } }
              incoming.each do |from, tos|
                tos.select { |(to, _)| to == i }.each do |(_to, reason)|
                  s << "    <- #{fmt_head(from, nodes[from])}  [#{reason}]\n"
                end
              end
            end
            s << "=== END DEBUG ===\n"
            s
          end

          def fmt_head(node_idx, op) = "##{node_idx} #{op[:k]} d=#{op[:depth]} #{op[:phase]}"
          def fmt_node(node_idx, op, indegree)
            defs = (op[:defines] || []).to_a.join(" ")
            uses = (op[:uses] || []).to_a.join(" ")
            code = op[:code] || op[:name] || op[:expr] || ""
            "#{fmt_head(node_idx, op)} #{code}\n      defines:[#{defs}] uses:[#{uses}] indegree:#{indegree}\n"
          end
        end
      end
    end
  end
end
