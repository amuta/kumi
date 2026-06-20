# frozen_string_literal: true

require "json"
require "digest"
require_relative "function_registry/loader"

module Kumi
  # The function registry: the single source of truth for the functions a schema
  # may call and the per-target kernels that implement them. Loaded once from the
  # `data/functions` and `data/kernels` YAML and queried by the analyzer (overload
  # resolution, dimensional analysis) and the codegen/binder (kernel lookup).
  #
  # Public surface:
  #   FunctionRegistry.load                       -> Instance
  #   FunctionRegistry::SELECT_ID                  -> the synthetic select function id
  #   FunctionRegistry::Function / ::Kernel        -> the loaded record structs
  #
  # Instance API (see Instance):
  #   function(id) / function?(id)                 -> look up / test a function
  #   resolve(id, arg_types)                       -> overload resolution by arg types
  #   resolve_id(id)                               -> alias/id -> canonical function id
  #   select?(id) / reduce?(id)                     -> kind predicates
  #   kernel_for / kernel_id_for / kernel_identity_for / impl_for
  #   registry_ref                                 -> stable content hash
  module FunctionRegistry
    DEFAULT_FUNCTIONS_DIR = File.expand_path("../../data/functions", __dir__)
    DEFAULT_KERNELS_DIR = File.expand_path("../../data/kernels", __dir__)
    SELECT_ID = "__select__"

    Function = Struct.new(:id, :kind, :dtype, :aliases, :params, :options, :expand, :folding_class_method, :reduction_strategy,
                          keyword_init: true) do
      def reduce? = kind == :reduce
      def select? = id == SELECT_ID
      def elementwise? = kind == :elementwise

      def param_names
        @param_names ||= params.map { |p| p["name"].to_sym }
      end

      def dtype_rule
        @dtype_rule ||= Loader.build_dtype_rule_from_yaml(dtype)
      end
    end

    Kernel = Struct.new(:id, :fn_id, :target, :impl, :identity, :inline, :fold_inline, keyword_init: true)

    # A loaded, queryable registry. Construct via FunctionRegistry.load.
    class Instance
      def initialize(functions_by_id, kernels_by_key)
        @functions = functions_by_id                         # "core.mul" => Function<...>
        @alias     = build_alias(@functions)                 # "count" => "agg.count"
        @overload_resolver = Core::Functions::OverloadResolver.new(@functions)
        @kernels   = kernels_by_key                          # [fn_id, target_sym] => Kernel
        @by_id     = @kernels.values.to_h { |k| [k.id, k] }
      end

      # ---- functions ----------------------------------------------------------

      # The Function record for an alias or id. Assumes the function exists (it
      # has passed validation); a miss is an internal bug, not a user error.
      def function(id)
        @functions.fetch(resolve_id(id))
      end

      # Non-raising existence check. Validation uses this to report an unknown
      # function as a located user error before any resolve_* is attempted.
      def function?(id)
        s = id.to_s
        @functions.key?(s) || @alias.key?(s)
      end

      # Resolve an alias or id to its canonical function id. Assumes existence
      # (validation runs first); an unresolved id here is a CompilerBug.
      def resolve_id(id)
        s = id.to_s
        return s if @functions.key?(s)

        @alias.fetch(s) do
          raise Kumi::Core::Errors::CompilerBug, "unknown function #{id} (should be rejected during validation)"
        end
      end

      # Type-aware overload resolution: pick the function id whose parameter
      # constraints best match the given argument types. Raises
      # OverloadResolver::ResolutionError on a type/arity mismatch, which the
      # dimensional analyzer turns into a located user error.
      def resolve(alias_or_id, arg_types)
        @overload_resolver.resolve(alias_or_id, arg_types)
      end

      def select?(id) = resolve_id(id) == SELECT_ID
      def reduce?(id) = function(id).reduce?

      # ---- kernels ------------------------------------------------------------
      # A function that resolved must have a backend kernel; a miss here is an
      # invariant violation (CompilerBug), never a user error.

      def kernel_for(id, target:)
        fid = resolve_id(id)
        @kernels[[fid, target.to_sym]] or raise Kumi::Core::Errors::CompilerBug, "no kernel for #{fid} on #{target}"
      end

      def kernel_id_for(id, target:)
        kernel_for(id, target: target).id
      end

      def kernel_identity_for(id, dtype:, target:)
        kernel = kernel_for(id, target: target)
        map = kernel.identity or raise Kumi::Core::Errors::CompilerBug, "no identity for #{kernel.fn_id} on #{target}"

        map[dtype.to_s] || map["any"] or
          raise Kumi::Core::Errors::CompilerBug, "no identity for dtype #{dtype} on #{kernel.fn_id}"
      end

      def impl_for(kernel_id)
        (@by_id[kernel_id] or raise Kumi::Core::Errors::CompilerBug, "unknown kernel #{kernel_id}").impl
      end

      # ---- identity -----------------------------------------------------------

      # Stable content hash of the loaded functions + kernels, used to detect
      # drift between a compiled artifact and the registry it was built against.
      def registry_ref
        kernels = @by_id.values
                        .map { |k| { "id" => k.id, "fn" => k.fn_id, "target" => k.target.to_s, "impl" => k.impl } }
                        .sort_by { _1["id"] }
        functions = @functions.transform_values do |f|
          { "kind" => f.kind.to_s, "aliases" => f.aliases, "params" => f.params }
        end
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(kernels: kernels, functions: functions))}"
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
      fn_map = Loader.load_functions(functions_dir, Function)
      kn_map = Loader.load_kernels(kernels_root, Kernel)
      Instance.new(fn_map, kn_map)
    end
  end
end
