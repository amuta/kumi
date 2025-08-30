module Generated
  class Program
    def initialize(registry:, assertions: true)
      # registry kept for API compatibility; not used by inlined kernels
      @registry   = registry
      @assertions = assertions
    end

def from(data)
  Bound.new(self, data)
end


class Bound
  def initialize(program, data)
    @p = program
    @d = data
  end

  def [](decl)
    case decl

        when :dept_total then dept_total
        when :company_total then company_total
        when :big_team then big_team
        when :dept_total_masked then dept_total_masked
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_agg_sum_ruby_v1(a,b)
        a + b
      end
      
      def k_core_gt_ruby_v1(a, b)
        a > b
      end

      def dept_total
        # ops: 0:LoadInput, 1:Reduce
        op_0 = fetch_depts_teams_headcount(@d)
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          row = op_0[i0]
          raise "Empty row at reduce op 1" if row.empty?
          acc = row[0]
          j = 1
          while j < row.length
            acc = k_agg_sum_ruby_v1(acc, row[j])
            j += 1
          end
        out0[i0] = acc
        i0 += 1
        end
        op_1 = out0
        op_1
      end

      def company_total
        # ops: 0:LoadInput, 1:Reduce, 2:Reduce
        op_0 = fetch_depts_teams_headcount(@d)
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          row = op_0[i0]
          raise "Empty row at reduce op 1" if row.empty?
          acc = row[0]
          j = 1
          while j < row.length
            acc = k_agg_sum_ruby_v1(acc, row[j])
            j += 1
          end
        out0[i0] = acc
        i0 += 1
        end
        op_1 = out0
        row = op_1
        raise "Empty row at reduce op 2" if row.empty?
        acc = row[0]
        j = 1
        while j < row.length
          acc = k_agg_sum_ruby_v1(acc, row[j])
          j += 1
        end
        op_2 = acc
        op_2
      end

      def big_team
        # ops: 0:LoadInput, 1:Const, 2:AlignTo, 3:Map
        op_0 = fetch_depts_teams_headcount(@d)
        op_1 = 10
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
            out1[i1] = k_core_gt_ruby_v1(op_0[i0][i1], op_1)
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_3 = out0
        op_3
      end

      def dept_total_masked
        # ops: 0:LoadDeclaration, 1:LoadInput, 2:Const, 3:AlignTo, 4:Select, 5:Reduce
        op_0 = big_team
        op_1 = fetch_depts_teams_headcount(@d)
        op_2 = 0
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
            out1[i1] = (op_0[i0][i1] ? op_1[i0][i1] : op_2)
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_4 = out0
        n0 = op_4.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
          row = op_4[i0]
          raise "Empty row at reduce op 5" if row.empty?
          acc = row[0]
          j = 1
          while j < row.length
            acc = k_agg_sum_ruby_v1(acc, row[j])
            j += 1
          end
        out0[i0] = acc
        i0 += 1
        end
        op_5 = out0
        op_5
      end

      def fetch_depts(data)
        data = (data[:depts] || data["depts"]) || (raise "Missing key: depts")
        data
      end

      def fetch_depts_teams(data)
        data = (data[:depts] || data["depts"]) || (raise "Missing key: depts")
        data = data.map { |it0| (it0[:teams] || it0["teams"]) || (raise "Missing key: teams") }
        data
      end

      def fetch_depts_teams_headcount(data)
        data = (data[:depts] || data["depts"]) || (raise "Missing key: depts")
        data = data.map { |it0| (it0[:teams] || it0["teams"]) || (raise "Missing key: teams") }
        data = data.map { |it0| it0.map { |it1| (it1[:headcount] || it1["headcount"]) || (raise "Missing key: headcount") } }
        data
      end
    end
  end
end
