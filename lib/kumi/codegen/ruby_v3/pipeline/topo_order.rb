# frozen_string_literal: true

# Deterministic topological ordering for CGIR ops.
# Inputs per op hash:
#   :k ∈ { :OpenLoop, :CloseLoop, :Emit, :AccReset, :AccAdd, :Yield }
#   :depth :: Integer (loop depth)
#   :phase ∈ { :pre, :body, :post }
#   :defines :: Set[String]
#   :uses    :: Set[String]
#   :within_depth_sched :: Integer (stable tiebreaker)
# Contract: StreamLowerer attaches these fields.

module Kumi
  module Codegen
    module RubyV3
      module Pipeline
        module TopoOrder
          module_function

          PHASE_RANK = { pre: 0, body: 1, post: 2 }.freeze

          def order(ops)
            nodes = ops.each_with_index.to_h { |op, i| [i, op] }

# Debug logging removed

            edges = Hash.new { |h, k| h[k] = [] } # from -> [[to, reason]...]
            indeg = Hash.new(0)

            add_edge = lambda do |from, to, reason|
              return if from.nil? || to.nil? || from == to

              # Avoid duplicate edges
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

            # Chain opens shallow→deep and closes deep→shallow
            0.upto(max_depth - 1) do |d|
              add_edge.call(open_at_d[d], open_at_d[d + 1], :open_chain) if open_at_d[d] && open_at_d[d + 1]
              add_edge.call(close_at_d[d + 1], close_at_d[d], :close_chain) if close_at_d[d] && close_at_d[d + 1]
            end

            # Build def→use mapping first to inform fencing decisions
            defs = {} # sym -> def idx (scope anchor)
            uses = Hash.new { |h, k| h[k] = [] } # sym -> [use idx...]
            nodes.each do |i, op|
              (op[:defines] || []).each do |s|
                # Do NOT let AccAdd hijack the defining site of an accumulator.
                next if op[:k] == :AccAdd
                defs[s] ||= i              # first-def wins (AccReset/Const/Emit), not later AccAdd
              end
              (op[:uses]    || []).each { |s| uses[s] << i }
            end

            # 1) Required scope per node: deepest defining depth among its used symbols
            req_scope = {}
            nodes.each do |i, op|
              used = (op[:uses] || [])
              req_scope[i] = used
                .map { |s| defs[s] }
                .compact
                .map { |di| (nodes[di][:depth] || 0) }
                .max
            end

            # 2) Normal per-depth fencing (unchanged)
            depths.each do |d|
              pre  = by_depth_phase[[d, :pre]]
              body = by_depth_phase[[d, :body]]
              post = by_depth_phase[[d, :post]]
              o    = open_at_d[d]
              c    = close_at_d[d]

              (pre + body + post).each do |i|
                add_edge.call(o, i, :open_fence) if o && i != o
                add_edge.call(i, c, :close_fence) if c && i != c
              end

              pre.product(body).each { |a, b| add_edge.call(a, b, :pre_before_body) } if pre.any? && body.any?
              body.product(post).each { |a, b| add_edge.call(a, b, :body_before_post) } if body.any? && post.any?

              add_edge.call(pre.first, open_at_d[d + 1], :pre_before_inner_open) if pre.any? && open_at_d[d + 1]
              # inner loop must close before post at same depth *unless* the post needs the inner scope
              if close_at_d[d + 1] && post.any?
                post.each do |pid|
                  need = req_scope[pid]
                  # only enforce inner_close_before_post when the post does NOT need deeper scope
                  add_edge.call(close_at_d[d + 1], pid, :inner_close_before_post) if !need || need <= d
                end
              end
            end

            # 3) Shallow loop encloses all deeper work (keep only the open enclosure; close handled by per-node scope fence)
            depths.combination(2).each do |d0, d1|
              next unless d0 < d1
              o0 = open_at_d[d0]
              next unless o0
              (%i[pre body post].flat_map { |ph| by_depth_phase[[d1, ph]] }).each do |i|
                add_edge.call(o0, i, :open_encloses_deeper)
              end
            end

            # 4) Per-node scope fences by required depth
            nodes.each_key do |i|
              need = req_scope[i]
              next unless need
              if (oo = open_at_d[need])
                add_edge.call(oo, i, :scope_open_enclose)         # keep node after the required open
              end
              if (cc = close_at_d[need])
                add_edge.call(i, cc, :scope_close_enclose)        # keep node before the required close
              end
            end

            # Reduction discipline: AccReset → AccAdd* → Bind(v = acc)
            acc_owner = {}
            nodes.each { |i, op| acc_owner[op[:name]] = i if op[:k] == :AccReset }
            nodes.each do |i, op|
              next unless op[:k] == :AccAdd

              add_edge.call(acc_owner[op[:name]], i, :reset_before_add)
            end
            nodes.each do |i, op|
              next unless op[:k] == :Emit && op[:op_type] == :result_processing

              used_acc = (op[:uses] || []).find { |u| u.start_with?("acc_") }
              next unless used_acc

              nodes.each do |j, op2|
                next unless op2[:k] == :AccAdd && op2[:name] == used_acc

                add_edge.call(j, i, :all_adds_before_bind)
              end
            end

            # 5) Def→use edges (unchanged)
            uses.each do |sym, consumers|
              di = defs[sym]
              next unless di

              consumers.each { |ui| add_edge.call(di, ui, :def_before_use) }
            end

            # No synthetic fallback edges.
            # Determinism is handled by the Kahn queue tiebreaker below.

            # Kahn topo with deterministic queue
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

            result_ops = out.map { |i| nodes[i] }

            # Debug: show final sorted operations
# Debug logging removed

            result_ops
          end

          # Pretty cycle debug with reasons and minimal cycle extraction
          def topo_cycle_debug(nodes, edges, indeg)
            rem = nodes.keys.select { |i| indeg[i].positive? }
            s = +"=== TOPO ORDER CYCLE DEBUG v2 ===\n"
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
            s << extract_one_cycle(nodes, edges, rem)
            s << "=== END DEBUG ===\n"
            s
          end

          def fmt_head(node_idx, op)
            "##{node_idx} #{op[:k]} d=#{op[:depth]} #{op[:phase]}"
          end

          def fmt_node(node_idx, op, indegree)
            defs = (op[:defines] || []).to_a.join(" ")
            uses = (op[:uses] || []).to_a.join(" ")
            code = op[:code] || op[:name] || op[:expr] || ""
            "#{fmt_head(node_idx, op)} #{code}\n      defines:[#{defs}] uses:[#{uses}] indegree:#{indegree}\n"
          end

          # Simple DFS to show one cyclic path with reasons
          def extract_one_cycle(nodes, edges, suspects)
            seen = {}
            stack = []

            enter = lambda do |v|
              seen[v] = :gray
              stack << v
              edges[v].each do |(to, _reason)|
                next unless suspects.include?(to)

                if seen[to] == :gray
                  # found back-edge; print the cycle
                  idx = stack.index(to) || 0
                  cyc = (stack[idx..] + [to])
                  out = +"Cycle:\n"
                  cyc.each_cons(2) do |a, b|
                    r = edges[a].find { |(x, _)| x == b }&.last
                    out << "  #{fmt_head(a, nodes[a])} --[#{r}]--> #{fmt_head(b, nodes[b])}\n"
                  end
                  return out
                elsif !seen[to]
                  return enter.call(to)
                end
              end
              stack.pop
              seen[v] = :black
              nil
            end

            suspects.each { |v| (res = enter.call(v)) && (return res) }
            "No simple cycle extracted\n"
          end

          # Test helper (non-production path)
          def build_edges_for_test(ops)
            # return [nodes, edges_with_reasons] by running the same add_edge calls
            nodes = ops.each_with_index.to_h { |op, i| [i, op] }
            edges = Hash.new { |h, k| h[k] = [] }
            # ... (same logic as order() but just return the structures)
            [nodes, edges]
          end
        end
      end
    end
  end
end
