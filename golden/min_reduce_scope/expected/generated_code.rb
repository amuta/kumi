# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT
require 'json'

module SchemaModule
  PACK_HASH = "09467c58ec72ad95a54731108cf110ae7d366b149094530c303b2d79bef61f9b:3d495c8cde61d7eb347a1f3032dc9c8a264c8bcaf6e9a336e2f054c4e98873ae:4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945:30a0d72ec88ee01757c1654c7057f1183dc29aae6ec8cc4b390651ecf1e3257a".freeze

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
        cursors = { "depts"=>a_depts }
          v0 = __walk__(CHAIN_DEPTS_TEAMS_HEADCOUNT, input, cursors)
          v1 = nil
          __each_array__(cursors["depts"], "teams") do |a_teams|
            cursors = cursors.merge("teams" => a_teams)
            v1 = v1.nil? ? v0 : __call_kernel__("agg.sum", v1, v0)
          end
        out << v1end
    
          out
        end
    
        def _eval_company_total
          input = @input
          cursors = {}
    
        v0 = __walk__(CHAIN_DEPTS_TEAMS_HEADCOUNT, input, cursors)
        v1 = nil
        __each_array__(cursors["depts"], "teams") do |a_teams|
          cursors = cursors.merge("teams" => a_teams)
          v1 = v1.nil? ? v0 : __call_kernel__("agg.sum", v1, v0)
        end
        v2 = nil
        __each_array__(input, "depts") do |a_depts|
          cursors = cursors.merge("depts" => a_depts)
          v2 = v2.nil? ? v1 : __call_kernel__("agg.sum", v2, v1)
        end
          v2
        end
    
        def _eval_big_team
          input = @input
        v1 = 10
          out = []
    __each_array__(input, "depts") do |a_depts|
      row_0 = []
    __each_array__(a_depts, "teams") do |a_teams|
          cursors = { "depts"=>a_depts,"teams"=>a_teams }
            v0 = __walk__(CHAIN_DEPTS_TEAMS_HEADCOUNT, input, cursors)
            v2 = __call_kernel__("core.gt", v0, v1)
          row_0 << v2    row_0 << 
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
        cursors = { "depts"=>a_depts }
          v0 = _eval_big_team
          v1 = __walk__(CHAIN_DEPTS_TEAMS_HEADCOUNT, input, cursors)
          v3 = (raise NotImplementedError, "Select")
          v4 = nil
          __each_array__(cursors["depts"], "teams") do |a_teams|
            cursors = cursors.merge("teams" => a_teams)
            v4 = v4.nil? ? v3 : __call_kernel__("agg.sum", v4, v3)
          end
        out << v4end
    
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
    CHAIN_DEPTS = JSON.parse("[{\"kind\":\"field_leaf\",\"key\":\"depts\"}]").freeze
    CHAIN_DEPTS_TEAMS = JSON.parse("[{\"kind\":\"array_field\",\"key\":\"depts\",\"axis\":\"depts\"},{\"kind\":\"field_leaf\",\"key\":\"teams\"}]").freeze
    CHAIN_DEPTS_TEAMS_HEADCOUNT = JSON.parse("[{\"kind\":\"array_field\",\"key\":\"depts\",\"axis\":\"depts\"},{\"kind\":\"array_field\",\"key\":\"teams\",\"axis\":\"teams\"},{\"kind\":\"field_leaf\",\"key\":\"headcount\"}]").freeze

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
