require "yaml"
require "json"
require "digest"

module Kumi
  class KernelRegistry
    Entry = Struct.new(:id, :fn, :impl, keyword_init: true)

    def self.load_dir(dir) # e.g., "data/kernels/ruby"
      files = Dir.glob(File.join(dir, "**", "*.y{a,}ml")).sort
      entries = files.flat_map { |p| (YAML.load_file(p) || {}).fetch("kernels", []) }
                     .map { |h| Entry.new(id: h["id"], fn: h["fn"], impl: h["impl"]) }
      new(entries)
    end

    def initialize(entries)
      @by_fn = Hash.new { |h,k| h[k] = [] }
      @by_id = {}
      entries.each { |e| (@by_fn[e.fn] << e) && (@by_id[e.id] = e) }
      @by_fn.each { |fn, arr| raise "multiple kernels for #{fn}" if arr.size > 1 } # keep it simple
    end

    def pick(fn) 
      (@by_fn[fn]&.first || raise("no kernel for #{fn}")).id
    end

    def registry_ref
      stable = { kernels: @by_id.values.map { |e| { "id"=>e.id, "fn"=>e.fn, "impl"=>e.impl } }.sort_by{ _1["id"] } }
      "sha256:#{Digest::SHA256.hexdigest(JSON.generate(stable))}"
    end

    # Late-bind the Ruby implementation
    # Returns implementation structure for the kernel
    def impl_for(kernel_id)
      e = @by_id[kernel_id] or raise "unknown kernel id #{kernel_id}"
      
      if e.impl.is_a?(Hash)
        # New format with init/step/finalize
        {
          init: resolve_method(e.impl["init"]),
          step: resolve_method(e.impl["step"]),
          finalize: resolve_method(e.impl["finalize"])
        }
      else
        # Legacy format - single method
        resolve_method(e.impl)
      end
    end

    private

    def resolve_method(impl_string)
      mod_path, meth = impl_string.split(".", 2)
      raise "impl must be Module.path.method, got #{impl_string}" unless meth
      receiver = constantize(mod_path)
      [receiver, meth.to_sym]
    end

    def constantize(path)
      path.split("::").inject(Object) { |ctx, name| ctx.const_get(name) }
    end
  end
end