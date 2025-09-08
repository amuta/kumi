# frozen_string_literal: true
require "json"
require "digest"
require_relative "registry_v2/loader"

module Kumi
  module RegistryV2
    Kernel = Struct.new(:id, :fn_id, :target, :impl, :identity, keyword_init: true)

    class Instance
      def initialize(fn_meta, kernels_by_key)
        @fn_meta = fn_meta                                 # "core.mul" => {kind:, aliases:[]}
        @alias   = build_alias(@fn_meta)                   # "core.select" => "__select__"
        @kernels = kernels_by_key                          # [fn_id, target_sym] => Kernel
        @by_id   = {}
        @kernels.values.each { |k| @by_id[k.id] = k }
      end

      # -------- functions --------
      def resolve_function(id)
        s = id.to_s
        return s if @fn_meta.key?(s)
        @alias.fetch(s) { raise "unknown function #{id}" }
      end

      def function_kind(id)        = meta(resolve_function(id))[:kind]
      def function_reduce?(id)     = function_kind(id) == :reduce
      def function_elementwise?(i) = function_kind(i) == :elementwise
      def function_select?(id)     = resolve_function(id) == "__select__" # add alias in data if needed

      # -------- kernels --------
      def kernel_id_for(id, target:)
        fid = resolve_function(id)
        k = @kernels[[fid, target.to_sym]] or raise "no kernel for #{fid} on #{target}"
        k.id
      end

      def kernel_identity_for(id, dtype:, target:)
        fid = resolve_function(id)
        k = @kernels[[fid, target.to_sym]] or raise "no kernel for #{fid} on #{target}"
        map = k.identity or raise "no identity for #{fid} on #{target}"
        map[dtype.to_s] or raise "no identity for dtype #{dtype} on #{fid}"
      end

      def impl_for(kernel_id)
        (@by_id[kernel_id] or raise "unknown kernel #{kernel_id}").impl
      end

      def registry_ref
        stable = {
          kernels: @by_id.values.map { |k|
            { "id" => k.id, "fn" => k.fn_id, "target" => k.target.to_s, "impl" => k.impl }
          }.sort_by { _1["id"] },
          functions: @fn_meta.transform_values { |m| { "kind" => m[:kind].to_s, "aliases" => m[:aliases] } }
        }
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(stable))}"
      end

      private

      def meta(fid) = @fn_meta.fetch(fid)

      def build_alias(meta)
        a = {}
        meta.each { |id, m| m[:aliases].each { |al| a[al] = id } }
        a
      end
    end

    module_function

    def load(functions_dir:, kernels_root:)
      fn_meta = Loader.load_functions(functions_dir)
      kn_map  = Loader.load_kernels(kernels_root, Kernel)
      Instance.new(fn_meta, kn_map)
    end
  end
end