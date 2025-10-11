# frozen_string_literal: true

require "tmpdir"

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

    def initialize
      # Set smart, environment-aware defaults.
      @cache_path = default_cache_path
      @compilation_mode = default_compilation_mode
      @force_recompile = false
    end

    private

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
      # RACK_ENV is a common standard, but Rails.env is more specific.
      env = defined?(Rails) ? Rails.env.to_s : ENV.fetch("RACK_ENV", nil)

      if env == "development"
        :jit
      else
        :aot
      end
    end
  end
end
