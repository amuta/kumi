# frozen_string_literal: true

require "tmpdir"
require "digest"

module Kumi
  # Holds the configuration state for the Kumi compiler and runtime.
  # This object is yielded to the user in the `Kumi.configure` block.
  class Configuration
    # The directory where compiled schemas are stored as cached Ruby files.
    # On file-based systems, this is crucial for performance.
    attr_accessor :cache_path

    # The compilation strategy.
    #   :jit (Just-in-Time): Compiles schemas on-the-fly at boot time if the
    #     source has changed. Ideal for development.
    #   :aot (Ahead-of-Time): Expects schemas to be precompiled via a build
    #     task. Raises an error at runtime if a compiled file is missing.
    #     Ideal for production and test environments.
    attr_accessor :compilation_mode

    # A master switch to bypass the cache and force recompilation on every run.
    # Useful for debugging the compiler itself.
    attr_accessor :force_recompile

    # Decimal coercion behavior for inputs declared as `decimal` type.
    # :automatic (default): Automatically coerce inputs to BigDecimal in Ruby
    # :explicit: User must explicitly call to_decimal() in the schema
    attr_accessor :decimal_coercion_mode

    def initialize
      # Set smart, environment-aware defaults.
      @cache_path = default_cache_path
      @compilation_mode = default_compilation_mode
      @force_recompile = false
      @decimal_coercion_mode = :automatic
      @code_version = nil
    end

    # A fingerprint of the COMPILER itself, folded into cache keys so that a
    # change to the analyzer/codegen invalidates cached generated code even when
    # the schema (and thus its digest) is unchanged. Without this, editing the
    # compiler and re-running silently reuses stale generated code from
    # `cache_path` — a debugging trap. Override (e.g. to the gem version in
    # production) via `Kumi.configure { |c| c.code_version = ... }`.
    def code_version
      @code_version ||= compute_code_version
    end

    attr_writer :code_version

    private

    # Hash the mtimes of the gem's Ruby sources. Cheap, requires no build step,
    # and changes whenever any compiler file is edited. Falls back to the gem
    # version string if the source tree can't be read (e.g. packaged gem).
    def compute_code_version
      env = ENV.fetch("KUMI_CODE_VERSION", nil)
      return env if env && !env.strip.empty?

      lib_dir = File.expand_path("..", __dir__) # .../lib/kumi -> .../lib
      files = Dir.glob(File.join(lib_dir, "**", "*.rb"))
      raise "no sources" if files.empty?

      stamp = files.sort.map { |f| "#{f}:#{File.mtime(f).to_i}" }.join("\n")
      "#{Kumi::VERSION}-#{Digest::SHA256.hexdigest(stamp)[0, 12]}"
    rescue StandardError
      Kumi::VERSION
    end

    # Provides a sensible default cache path.
    # It prefers the Rails cache directory if available, otherwise uses the
    # system's temporary directory.
    def default_cache_path
      if defined?(Rails) && Rails.root
        Rails.root.join("tmp", "cache", "kumi")
      else
        File.join(Dir.tmpdir, "kumi_cache")
      end
    end

    # Determines the best compilation mode based on the environment.
    # The convention is to use JIT for development for a seamless "save and
    # refresh" experience, and AOT for production to ensure fast boots
    # and catch precompilation errors in CI.
    def default_compilation_mode
      override = ENV.fetch("KUMI_COMPILATION_MODE", nil)
      if override && !override.strip.empty?
        normalized = override.strip.downcase.to_sym
        return normalized if %i[jit aot].include?(normalized)

        warn "[kumi] Ignoring invalid KUMI_COMPILATION_MODE=#{override.inspect}; falling back to environment-based default"
      end

      :jit
    end
  end
end
