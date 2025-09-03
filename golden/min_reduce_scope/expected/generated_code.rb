# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT

module SchemaModule
  PACK_HASH = "79b847752d77166f6f78d47ca560b648da524bff6204e1ce65d4731897190203:d4bc6dd3023e133e672e77fc85ca219cb0a3f0de2060773cfd247620fa6a4e6d:95ccb7df5aadfc90e63b52740208a475b02424743078f5fd761d988c405d0252:30a0d72ec88ee01757c1654c7057f1183dc29aae6ec8cc4b390651ecf1e3257a".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :dept_total then (@memo[:dept_total] ||= _eval_dept_total)
                  when :company_total then (@memo[:company_total] ||= _eval_company_total)
                  when :big_team then (@memo[:big_team] ||= _eval_big_team)
                  when :dept_total_masked then (@memo[:dept_total_masked] ||= _eval_dept_total_masked)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

                def _eval_dept_total
                  input = @input
            
                  out = []
    __each_array__(input, "depts") do |a_depts|
      acc = 0
        a_depts.each_with_index do |a_teams, _idx|
            cursors = { "depts"=>a_depts,"teams"=>a_teams }
            inl_inline_v0 = __walk__(CHAIN_DEPTS_TEAMS_HEADCOUNT, input, cursors)
            acc += inl_inline_v0
        end
      out << acc
    end
    
                  out
                end
    
        def _eval_company_total
          input = @input
    
          acc = 0
          __each_array__(input, "depts") do |a_depts|
    a_depts.each_with_index do |a_teams, _idx|
        cursors = { "depts"=>a_depts,"teams"=>a_teams }
        inl_inline_v0 = __walk__(CHAIN_DEPTS_TEAMS_HEADCOUNT, input, cursors)
        acc += inl_inline_v0
      end
    end
    
          acc
        end
    
                  def _eval_big_team
                    input = @input
                  v1 = 10
                    out = []
    __each_array__(input, "depts") do |a_depts|
      row_0 = []
    a_depts.each_with_index do |a_teams, _idx|
          cursors = { "depts"=>a_depts,"teams"=>a_teams }
            v0 = __walk__(CHAIN_DEPTS_TEAMS_HEADCOUNT, input, cursors)
            v2 = __call_kernel__("core.gt", v0, v1)
          row_0 << v2
        end
        out << row_0
      end
                    out
                  end
    
                def _eval_dept_total_masked
                  input = @input
                v2 = 0
                  out = []
    __each_array__(input, "depts") do |a_depts|
      acc = 0
        a_depts.each_with_index do |a_teams, _idx|
            cursors = { "depts"=>a_depts,"teams"=>a_teams }
            inl_big_team_v0 = __walk__(CHAIN_DEPTS_TEAMS_HEADCOUNT, input, cursors)
            inl_big_team_v1 = 10
            inl_big_team_v2 = __call_kernel__("core.gt", inl_big_team_v0, inl_big_team_v1)
            inl_inline_v1 = __walk__(CHAIN_DEPTS_TEAMS_HEADCOUNT, input, cursors)
            inl_inline_v3 = (inl_big_team_v2 ? inl_inline_v1 : 0)
            acc += inl_inline_v3
        end
      out << acc
    end
    
                  out
                end

    # === PRIVATE RUNTIME HELPERS (cursor-based, strict) ===
    MISSING_POLICY = {}.freeze
    
    private
    
    def __fetch_key__(obj, key)
      return nil if obj.nil?
      if obj.is_a?(Hash)
        obj.key?(key) ? obj[key] : obj[key.to_sym]
      else
        obj.respond_to?(key) ? obj.public_send(key) : nil
      end
    end
    
    def __array_of__(obj, key)
      arr = __fetch_key__(obj, key)
      return arr if arr.is_a?(Array)
      policy = MISSING_POLICY.fetch(key) { raise "No missing data policy defined for key '#{key}' in pack capabilities" }
      case policy
      when :empty then []
      when :skip  then nil
      else
        raise KeyError, "expected Array at #{key.inspect}, got #{arr.class}"
      end
    end
    
    def __each_array__(obj, key)
      arr = __array_of__(obj, key)
      return if arr.nil?
      i = 0
      while i < arr.length
        yield arr[i]
        i += 1
      end
    end
    
    def __walk__(steps, root, cursors)
      cur = root
      steps.each do |s|
        case s["kind"]
        when "array_field"
          if (ax = s["axis"]) && cursors.key?(ax)
            cur = cursors[ax]
          else
            cur = __fetch_key__(cur, s["key"])
            raise KeyError, "missing key #{s["key"].inspect}" if cur.nil?
          end
        when "field_leaf"
          cur = __fetch_key__(cur, s["key"])
          raise KeyError, "missing key #{s["key"].inspect}" if cur.nil?
        when "array_element"
          ax = s["axis"]; raise KeyError, "missing cursor for #{ax}" unless cursors.key?(ax)
          cur = cursors[ax]
        when "element_leaf"
          # no-op
        else
          raise KeyError, "unknown step kind: #{s["kind"]}"
        end
      end
      cur
    end
    CHAIN_DEPTS = [{"axis"=>"depts", "key"=>"depts", "kind"=>"array_field"}].freeze
    CHAIN_DEPTS_TEAMS = [{"axis"=>"depts", "key"=>"depts", "kind"=>"array_field"}, {"axis"=>"teams", "key"=>"teams", "kind"=>"array_field"}].freeze
    CHAIN_DEPTS_TEAMS_HEADCOUNT = [{"axis"=>"depts", "key"=>"depts", "kind"=>"array_field"}, {"axis"=>"teams", "key"=>"teams", "kind"=>"array_field"}, {"key"=>"headcount", "kind"=>"field_leaf"}].freeze

    KERNELS = {}
    KERNELS["agg.sum"] = ( ->(a,b) { a + b } )
    KERNELS["core.gt"] = ( ->(a, b) { a > b } )
    
    def __call_kernel__(key, *args)
      fn = KERNELS[key]
      raise NotImplementedError, "kernel not found: #{key}" unless fn
      fn.call(*args)
    end
  end

  def self.from(data) = Program.new(data)
end
