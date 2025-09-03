# AUTOGEN: from kumi pack v0.1 — DO NOT EDIT

module SchemaModule
  PACK_HASH = "0a34965cab469dd0d47da509e8dda32d6d385c5a97ca786d0ec12b3bb3416e1b:144f411868b975a04a236a53fc6588972b19a3410d20b038ac36594a9c477df3:62bf4ad04ec171964d14d920ce093c9d00016befb325c8c62f5863728b5331bb".freeze

  class Program
    def self.from(data) = new(data)
    def initialize(data) = (@input = data; @memo = {})

    def [](name)
      case name
                      when :employee_bonus then (@memo[:employee_bonus] ||= _eval_employee_bonus)
                  when :high_performer then (@memo[:high_performer] ||= _eval_high_performer)
                  when :senior_level then (@memo[:senior_level] ||= _eval_senior_level)
                  when :top_team then (@memo[:top_team] ||= _eval_top_team)
      else
        raise ArgumentError, "unknown declaration: #{name}"
      end
    end

                  def _eval_employee_bonus
                    input = @input
                  v6 = 0.3
        v11 = 0.2
        v13 = 0.05
                    out = []
    __each_array__(input, "regions") do |a_regions|
      row_0 = []
    a_regions.each_with_index do |a_offices, _idx|
        row_1 = []
    a_offices.each_with_index do |a_teams, _idx|
          row_2 = []
    a_teams.each_with_index do |a_employees, _idx|
              cursors = { "regions"=>a_regions,"offices"=>a_offices,"teams"=>a_teams,"employees"=>a_employees }
                v0 = _eval_high_performer
                v1 = _eval_senior_level
                v2 = _eval_top_team
                v3 = __call_kernel__("core.and", v1, v2)
                v4 = __call_kernel__("core.and", v0, v3)
                v5 = __walk__(CHAIN_REGIONS_OFFICES_TEAMS_EMPLOYEES_SALARY, input, cursors)
                v7 = __call_kernel__("core.mul", v5, v6)
                v10 = __call_kernel__("core.and", v0, v2)
                v12 = __call_kernel__("core.mul", v5, v11)
                v14 = __call_kernel__("core.mul", v5, v13)
                v15 = (v10 ? v12 : v14)
                v16 = (v4 ? v7 : v15)
              row_2 << v16
            end
            row_1 << row_2
          end
          row_0 << row_1
        end
        out << row_0
      end
                    out
                  end
    
                  def _eval_high_performer
                    input = @input
                  v1 = 4.5
                    out = []
    __each_array__(input, "regions") do |a_regions|
      row_0 = []
    a_regions.each_with_index do |a_offices, _idx|
        row_1 = []
    a_offices.each_with_index do |a_teams, _idx|
          row_2 = []
    a_teams.each_with_index do |a_employees, _idx|
              cursors = { "regions"=>a_regions,"offices"=>a_offices,"teams"=>a_teams,"employees"=>a_employees }
                v0 = __walk__(CHAIN_REGIONS_OFFICES_TEAMS_EMPLOYEES_RATING, input, cursors)
                v2 = __call_kernel__("core.gte", v0, v1)
              row_2 << v2
            end
            row_1 << row_2
          end
          row_0 << row_1
        end
        out << row_0
      end
                    out
                  end
    
                  def _eval_senior_level
                    input = @input
                  v1 = "senior"
                    out = []
    __each_array__(input, "regions") do |a_regions|
      row_0 = []
    a_regions.each_with_index do |a_offices, _idx|
        row_1 = []
    a_offices.each_with_index do |a_teams, _idx|
          row_2 = []
    a_teams.each_with_index do |a_employees, _idx|
              cursors = { "regions"=>a_regions,"offices"=>a_offices,"teams"=>a_teams,"employees"=>a_employees }
                v0 = __walk__(CHAIN_REGIONS_OFFICES_TEAMS_EMPLOYEES_LEVEL, input, cursors)
                v2 = __call_kernel__("core.eq", v0, v1)
              row_2 << v2
            end
            row_1 << row_2
          end
          row_0 << row_1
        end
        out << row_0
      end
                    out
                  end
    
                  def _eval_top_team
                    input = @input
                  v1 = 0.9
                    out = []
    __each_array__(input, "regions") do |a_regions|
      row_0 = []
    a_regions.each_with_index do |a_offices, _idx|
        row_1 = []
    a_offices.each_with_index do |a_teams, _idx|
            cursors = { "regions"=>a_regions,"offices"=>a_offices,"teams"=>a_teams }
              v0 = __walk__(CHAIN_REGIONS_OFFICES_TEAMS_PERFORMANCE_SCORE, input, cursors)
              v2 = __call_kernel__("core.gte", v0, v1)
            row_1 << v2
          end
          row_0 << row_1
        end
        out << row_0
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
    CHAIN_REGIONS = [{"axis"=>"regions", "key"=>"regions", "kind"=>"array_field"}].freeze
    CHAIN_REGIONS_OFFICES = [{"axis"=>"regions", "key"=>"regions", "kind"=>"array_field"}, {"axis"=>"offices", "key"=>"offices", "kind"=>"array_field"}].freeze
    CHAIN_REGIONS_OFFICES_TEAMS = [{"axis"=>"regions", "key"=>"regions", "kind"=>"array_field"}, {"axis"=>"offices", "key"=>"offices", "kind"=>"array_field"}, {"axis"=>"teams", "key"=>"teams", "kind"=>"array_field"}].freeze
    CHAIN_REGIONS_OFFICES_TEAMS_PERFORMANCE_SCORE = [{"axis"=>"regions", "key"=>"regions", "kind"=>"array_field"}, {"axis"=>"offices", "key"=>"offices", "kind"=>"array_field"}, {"axis"=>"teams", "key"=>"teams", "kind"=>"array_field"}, {"key"=>"performance_score", "kind"=>"field_leaf"}].freeze
    CHAIN_REGIONS_OFFICES_TEAMS_EMPLOYEES = [{"axis"=>"regions", "key"=>"regions", "kind"=>"array_field"}, {"axis"=>"offices", "key"=>"offices", "kind"=>"array_field"}, {"axis"=>"teams", "key"=>"teams", "kind"=>"array_field"}, {"axis"=>"employees", "key"=>"employees", "kind"=>"array_field"}].freeze
    CHAIN_REGIONS_OFFICES_TEAMS_EMPLOYEES_SALARY = [{"axis"=>"regions", "key"=>"regions", "kind"=>"array_field"}, {"axis"=>"offices", "key"=>"offices", "kind"=>"array_field"}, {"axis"=>"teams", "key"=>"teams", "kind"=>"array_field"}, {"axis"=>"employees", "key"=>"employees", "kind"=>"array_field"}, {"key"=>"salary", "kind"=>"field_leaf"}].freeze
    CHAIN_REGIONS_OFFICES_TEAMS_EMPLOYEES_RATING = [{"axis"=>"regions", "key"=>"regions", "kind"=>"array_field"}, {"axis"=>"offices", "key"=>"offices", "kind"=>"array_field"}, {"axis"=>"teams", "key"=>"teams", "kind"=>"array_field"}, {"axis"=>"employees", "key"=>"employees", "kind"=>"array_field"}, {"key"=>"rating", "kind"=>"field_leaf"}].freeze
    CHAIN_REGIONS_OFFICES_TEAMS_EMPLOYEES_LEVEL = [{"axis"=>"regions", "key"=>"regions", "kind"=>"array_field"}, {"axis"=>"offices", "key"=>"offices", "kind"=>"array_field"}, {"axis"=>"teams", "key"=>"teams", "kind"=>"array_field"}, {"axis"=>"employees", "key"=>"employees", "kind"=>"array_field"}, {"key"=>"level", "kind"=>"field_leaf"}].freeze

    KERNELS = {}
    KERNELS["core.gte"] = ( ->(a, b) { a >= b } )
    KERNELS["core.eq"] = ( ->(a, b) { a == b } )
    KERNELS["core.and"] = ( ->(a, b) { a && b } )
    KERNELS["core.mul"] = ( ->(a, b) { a * b } )
    
    def __call_kernel__(key, *args)
      fn = KERNELS[key]
      raise NotImplementedError, "kernel not found: #{key}" unless fn
      fn.call(*args)
    end
  end

  def self.from(data) = Program.new(data)
end
