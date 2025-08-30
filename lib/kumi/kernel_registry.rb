require "yaml"
require "json"
require "digest"

module Kumi
  class KernelRegistry
    KERNEL_DIRS = {
      ruby: "data/kernels/ruby"
    }
    Entry = Struct.new(:id, :fn, :impl, :identity, keyword_init: true)

    def self.load_ruby
      load_dir(KERNEL_DIRS[:ruby])
    end

    def self.load_dir(dir)
      files = Dir.glob(File.join(dir, "**", "*.y{a,}ml")).sort
      entries = files.flat_map { |p| (YAML.load_file(p) || {}).fetch("kernels", []) }
                     .map { |h| Entry.new(id: h["id"], fn: h["fn"], impl: h["impl"], identity: h["identity"]) }
      new(entries)
    end

    def initialize(entries)
      @by_fn = Hash.new { |h, k| h[k] = [] }
      @by_id = {}
      entries.each { |e| (@by_fn[e.fn] << e) && (@by_id[e.id] = e) }
      @by_fn.each { |fn, arr| raise "multiple kernels for #{fn}" if arr.size > 1 }
    end

    def pick(fn)
      (@by_fn[fn]&.first || raise("no kernel for #{fn}")).id
    end

    def registry_ref
      stable = { kernels: @by_id.values.map { |e| { "id" => e.id, "fn" => e.fn, "impl" => e.impl } }.sort_by { _1["id"] } }
      "sha256:#{Digest::SHA256.hexdigest(JSON.generate(stable))}"
    end

    def identity(kernel_id, dtype)
      e = @by_id[kernel_id] or raise "unknown kernel id #{kernel_id}"
      identity_map = e.identity or raise "no identity map for #{kernel_id}"

      identity_map[dtype.to_s] or raise "no identity with dtype `#{dtype}` for #{kernel_id}"
    end

    # Late-bind the Ruby implementation
    # Returns implementation structure for the kernel
    def impl_for(kernel_id)
      e = @by_id[kernel_id] or raise "unknown kernel id #{kernel_id}"
      e.impl
    end

    private

    def constantize(path)
      path.split("::").inject(Object) { |ctx, name| ctx.const_get(name) }
    end
  end
end
