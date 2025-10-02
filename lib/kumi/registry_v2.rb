# frozen_string_literal: true

require "json"
require "digest"
require_relative "registry_v2/loader" # Assuming loader is in a sub-file

module Kumi
  module RegistryV2
    DEFAULT_FUNCTIONS_DIR = File.expand_path("../../data/functions", __dir__)
    DEFAULT_KERNELS_DIR = File.expand_path("../../data/kernels", __dir__)
    SELECT_ID = "__select__"

    # --- NEW: Define the Function struct ---
    Function = Struct.new(:id, :kind, :dtype, :aliases, :params, :options, :expand, :folding_class_method, :reduction_strategy,
                          keyword_init: true) do
      def reduce? = kind == :reduce
      def select? = id == SELECT_ID
      def elementwise? = kind == :elementwise

      def param_names
        @param_names ||= params.map { |p| p["name"].to_sym }
      end

      def dtype_rule
        @dtype_rule ||= Core::Functions::TypeRules.compile_dtype_rule(dtype, param_names)
      end
    end

    Kernel = Struct.new(:id, :fn_id, :target, :impl, :identity, :inline, :fold_inline, keyword_init: true)

    class Instance
      def initialize(functions_by_id, kernels_by_key)
        @functions = functions_by_id                         # "core.mul" => Function<...>
        @alias     = build_alias(@functions)                 # "count" => "agg.count"
        @kernels   = kernels_by_key                          # [fn_id, target_sym] => Kernel
        @by_id     = @kernels.values.to_h { |k| [k.id, k] }
      end

      # -------- functions --------
      def function(id)
        @functions.fetch(resolve_function(id))
      end

      def resolve_function(id)
        s = id.to_s
        return s if @functions.key?(s)

        @alias.fetch(s) do
          raise "unknown function #{id}"
        end
      end

      def function_kind(id)        = function(id).kind
      def function_reduce?(id)     = function(id).reduce?
      def function_elementwise?(id) = function(id).elementwise?
      def function_select?(id)      = resolve_function(id) == SELECT_ID

      # -------- kernels (no changes here) --------
      def kernel_for(id, target:)
        fid = resolve_function(id)
        @kernels[[fid, target.to_sym]] or raise "no kernel for #{fid} on #{target}"
      end

      def kernel_id_for(id, target:)
        fid = resolve_function(id)
        k = @kernels[[fid, target.to_sym]] or raise "no kernel for #{fid} on #{target}"
        k.id
      end

      def kernel_identity_for(id, dtype:, target:)
        fid = resolve_function(id)
        k = @kernels[[fid, target.to_sym]] or raise "no kernel for #{fid} on #{target}"

        map = k.identity or raise "no identity for #{fid} on #{target}"

        identity = map[dtype.to_s] || map["any"]

        return identity if identity

        raise "no identity for dtype #{dtype} on #{fid}"
      end

      def impl_for(kernel_id)
        (@by_id[kernel_id] or raise "unknown kernel #{kernel_id}").impl
      end

      def registry_ref
        # ... (implementation is fine, but needs to access struct attributes) ...
        stable = {
          kernels: @by_id.values.map do |k|
            { "id" => k.id, "fn" => k.fn_id, "target" => k.target.to_s, "impl" => k.impl }
          end.sort_by { _1["id"] },
          functions: @functions.transform_values do |f|
            { "kind" => f.kind.to_s, "aliases" => f.aliases, "params" => f.params }
          end
        }
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(stable))}"
      end

      private

      def build_alias(functions)
        functions.values.each_with_object({}) do |func, acc|
          func.aliases.each { |al| acc[al] = func.id }
        end
      end
    end

    module_function

    def load(functions_dir: DEFAULT_FUNCTIONS_DIR, kernels_root: DEFAULT_KERNELS_DIR)
      # Pass the new struct to the loader.
      fn_map = Loader.load_functions(functions_dir, Function)
      kn_map = Loader.load_kernels(kernels_root, Kernel)
      Instance.new(fn_map, kn_map)
    end
  end
end
