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

        when :high_performer then high_performer
        when :senior_level then senior_level
        when :top_team then top_team
        when :employee_bonus then employee_bonus
  else
    raise "Unknown declaration: #{decl}"
  end
end

private

      def k_core_gte_ruby_v1(a, b)
        a >= b
      end
      
      def k_core_eq_ruby_v1(a, b)
        a == b
      end
      
      def k_core_and_ruby_v1(a, b)
        a && b
      end
      
      def k_core_mul_ruby_v1(a, b)
        a * b
      end

      def high_performer
        # ops: 0:LoadInput, 1:Const, 2:AlignTo, 3:Map
        op_0 = fetch_regions_offices_teams_employees_rating(@d)
        op_1 = 4.5
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_0[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_0[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = k_core_gte_ruby_v1(op_0[i0][i1][i2][i3], op_1)
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_3 = out0
        op_3
      end

      def senior_level
        # ops: 0:LoadInput, 1:Const, 2:AlignTo, 3:Map
        op_0 = fetch_regions_offices_teams_employees_level(@d)
        op_1 = "senior"
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_0[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_0[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = k_core_eq_ruby_v1(op_0[i0][i1][i2][i3], op_1)
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_3 = out0
        op_3
      end

      def top_team
        # ops: 0:LoadInput, 1:Const, 2:AlignTo, 3:Map
        op_0 = fetch_regions_offices_teams_performance_score(@d)
        op_1 = 0.9
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_0[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
              out2[i2] = k_core_gte_ruby_v1(op_0[i0][i1][i2], op_1)
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_3 = out0
        op_3
      end

      def employee_bonus
        # ops: 0:LoadDeclaration, 1:LoadDeclaration, 2:LoadDeclaration, 3:AlignTo, 4:Map, 5:Map, 6:LoadInput, 7:Const, 8:AlignTo, 9:Map, 13:Map, 14:Const, 15:AlignTo, 16:Map, 17:Const, 18:AlignTo, 19:Map, 20:Select, 21:Select
        op_0 = high_performer
        op_1 = senior_level
        op_2 = top_team
        n0 = op_1.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_1[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_1[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_1[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = k_core_and_ruby_v1(op_1[i0][i1][i2][i3], op_2[i0][i1][i2])
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_4 = out0
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_0[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_0[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = k_core_and_ruby_v1(op_0[i0][i1][i2][i3], op_4[i0][i1][i2][i3])
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_5 = out0
        op_6 = fetch_regions_offices_teams_employees_salary(@d)
        op_7 = 0.3
        n0 = op_6.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_6[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_6[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_6[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = k_core_mul_ruby_v1(op_6[i0][i1][i2][i3], op_7)
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_9 = out0
        n0 = op_0.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_0[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_0[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_0[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = k_core_and_ruby_v1(op_0[i0][i1][i2][i3], op_2[i0][i1][i2])
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_13 = out0
        op_14 = 0.2
        n0 = op_6.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_6[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_6[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_6[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = k_core_mul_ruby_v1(op_6[i0][i1][i2][i3], op_14)
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_16 = out0
        op_17 = 0.05
        n0 = op_6.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_6[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_6[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_6[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = k_core_mul_ruby_v1(op_6[i0][i1][i2][i3], op_17)
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_19 = out0
        n0 = op_13.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_13[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_13[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_13[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = (op_13[i0][i1][i2][i3] ? op_16[i0][i1][i2][i3] : op_19[i0][i1][i2][i3])
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_20 = out0
        n0 = op_5.length
        out0 = Array.new(n0)
        i0 = 0
        while i0 < n0
        n1 = op_5[i0].length
        out1 = Array.new(n1)
        i1 = 0
        while i1 < n1
        n2 = op_5[i0][i1].length
        out2 = Array.new(n2)
        i2 = 0
        while i2 < n2
        n3 = op_5[i0][i1][i2].length
        out3 = Array.new(n3)
        i3 = 0
        while i3 < n3
                out3[i3] = (op_5[i0][i1][i2][i3] ? op_9[i0][i1][i2][i3] : op_20[i0][i1][i2][i3])
              i3 += 1
              end
            out2[i2] = out3
            i2 += 1
            end
          out1[i1] = out2
          i1 += 1
          end
        out0[i0] = out1
        i0 += 1
        end
        op_21 = out0
        op_21
      end

      def fetch_regions(data)
        data = (data[:regions] || data["regions"]) || (raise "Missing key: regions")
        data
      end

      def fetch_regions_offices(data)
        data = (data[:regions] || data["regions"]) || (raise "Missing key: regions")
        data = data.map { |it0| (it0[:offices] || it0["offices"]) || (raise "Missing key: offices") }
        data
      end

      def fetch_regions_offices_teams(data)
        data = (data[:regions] || data["regions"]) || (raise "Missing key: regions")
        data = data.map { |it0| (it0[:offices] || it0["offices"]) || (raise "Missing key: offices") }
        data = data.map { |it0| it0.map { |it1| (it1[:teams] || it1["teams"]) || (raise "Missing key: teams") } }
        data
      end

      def fetch_regions_offices_teams_performance_score(data)
        data = (data[:regions] || data["regions"]) || (raise "Missing key: regions")
        data = data.map { |it0| (it0[:offices] || it0["offices"]) || (raise "Missing key: offices") }
        data = data.map { |it0| it0.map { |it1| (it1[:teams] || it1["teams"]) || (raise "Missing key: teams") } }
        data = data.map { |it0| it0.map { |it1| it1.map { |it2| (it2[:performance_score] || it2["performance_score"]) || (raise "Missing key: performance_score") } } }
        data
      end

      def fetch_regions_offices_teams_employees(data)
        data = (data[:regions] || data["regions"]) || (raise "Missing key: regions")
        data = data.map { |it0| (it0[:offices] || it0["offices"]) || (raise "Missing key: offices") }
        data = data.map { |it0| it0.map { |it1| (it1[:teams] || it1["teams"]) || (raise "Missing key: teams") } }
        data = data.map { |it0| it0.map { |it1| it1.map { |it2| (it2[:employees] || it2["employees"]) || (raise "Missing key: employees") } } }
        data
      end

      def fetch_regions_offices_teams_employees_salary(data)
        data = (data[:regions] || data["regions"]) || (raise "Missing key: regions")
        data = data.map { |it0| (it0[:offices] || it0["offices"]) || (raise "Missing key: offices") }
        data = data.map { |it0| it0.map { |it1| (it1[:teams] || it1["teams"]) || (raise "Missing key: teams") } }
        data = data.map { |it0| it0.map { |it1| it1.map { |it2| (it2[:employees] || it2["employees"]) || (raise "Missing key: employees") } } }
        data = data.map { |it0| it0.map { |it1| it1.map { |it2| it2.map { |it3| (it3[:salary] || it3["salary"]) || (raise "Missing key: salary") } } } }
        data
      end

      def fetch_regions_offices_teams_employees_rating(data)
        data = (data[:regions] || data["regions"]) || (raise "Missing key: regions")
        data = data.map { |it0| (it0[:offices] || it0["offices"]) || (raise "Missing key: offices") }
        data = data.map { |it0| it0.map { |it1| (it1[:teams] || it1["teams"]) || (raise "Missing key: teams") } }
        data = data.map { |it0| it0.map { |it1| it1.map { |it2| (it2[:employees] || it2["employees"]) || (raise "Missing key: employees") } } }
        data = data.map { |it0| it0.map { |it1| it1.map { |it2| it2.map { |it3| (it3[:rating] || it3["rating"]) || (raise "Missing key: rating") } } } }
        data
      end

      def fetch_regions_offices_teams_employees_level(data)
        data = (data[:regions] || data["regions"]) || (raise "Missing key: regions")
        data = data.map { |it0| (it0[:offices] || it0["offices"]) || (raise "Missing key: offices") }
        data = data.map { |it0| it0.map { |it1| (it1[:teams] || it1["teams"]) || (raise "Missing key: teams") } }
        data = data.map { |it0| it0.map { |it1| it1.map { |it2| (it2[:employees] || it2["employees"]) || (raise "Missing key: employees") } } }
        data = data.map { |it0| it0.map { |it1| it1.map { |it2| it2.map { |it3| (it3[:level] || it3["level"]) || (raise "Missing key: level") } } } }
        data
      end
    end
  end
end
