# frozen_string_literal: true

require "json"
require_relative "ruby/planner"
require_relative "ruby/template_selector"
require_relative "ruby/emitter"
require_relative "ruby/template_library"

module Kumi
  module Codegen
    class Ruby
      def self.generate(ir_file, binding_manifest_file, options = {})
        new(options).generate(ir_file, binding_manifest_file)
      end

      def self.generate_from_data(ir_data, binding_manifest, options = {})
        new(options).generate_from_data(ir_data, binding_manifest)
      end

      def initialize(options = {})
        @options = {
          visibility: :public,
          error_policy: :raise,
          assertions: true,
          comments: true
        }.merge(options)
      end

      def generate(ir_file, binding_manifest_file)
        ir_data = JSON.parse(File.read(ir_file))
        binding_manifest = JSON.parse(File.read(binding_manifest_file))
        generate_from_data(ir_data, binding_manifest)
      end

      def generate_from_data(ir_data, binding_manifest)
        # 1) Plan declarations (also attaches binding records per op)
        planner = Ruby::Planner.new(ir_data, binding_manifest)
        plans   = planner.plan_all_declarations

        # 2) Determine which kernels are actually used by the IR
        used_kernel_ids = plans.flat_map do |p|
          p.operations.map { |op| (op[:binding] || {})["kernel_id"] }
        end.compact.uniq

        # 3) Build kernel_id → impl string map from bindings (no fallbacks)
        impl_by_id, conflicts = extract_kernel_impls_from_bindings(binding_manifest)

        unless conflicts.empty?
          msg = conflicts.map do |kid, a, b, where|
            "- #{kid.inspect} has conflicting impls:\n    #{a.inspect}\n    #{b.inspect}\n    #{where}"
          end.join("\n")
          raise "Conflicting kernel impl strings found in bindings:\n#{msg}"
        end

        missing = used_kernel_ids.reject { |kid| impl_by_id.key?(kid) }
        unless missing.empty?
          # Help the author by pointing to which decl/op used the missing kernel
          where = locate_kernel_usage(plans, missing)
          raise "Missing kernel impl strings for: #{missing.join(', ')}.\n" \
                "Every kernel used by the IR must appear in the bindings with an 'impl' string " \
                "(e.g. \"->(a,b){ a + b }\").\n\nUsed at:\n#{where}"
        end

        # 4) Emit Ruby with kernels fully inlined from impl strings
        ruby_emitter = Ruby::Emitter.new(@options.merge(kernel_impls: impl_by_id))
        ruby_emitter.emit_program(plans, ir_data["analysis"])
      end

      private

      # Returns [impl_by_id, conflicts]
      # - impl_by_id: { "core.mul:ruby:v1" => "(a,b)\n  a * b", ... }
      # - conflicts:  array of [kid, impl_a, impl_b, where_string]
      def extract_kernel_impls_from_bindings(binding_manifest)
        kernels = binding_manifest["kernels"] or raise "No kernels section in binding manifest"
        impl_by_id = kernels.transform_values(&:strip)
        [impl_by_id, []]
      end

      # Build a helpful “used at” string for missing kernels
      def locate_kernel_usage(plans, missing_ids)
        lines = []
        missing = missing_ids.to_set
        plans.each do |p|
          p.operations.each do |op|
            kid = (op[:binding] || {})["kernel_id"]
            next unless missing.include?(kid)

            lines << "- decl=#{p.name.inspect}, op_id=#{op[:id]}, fn=#{(op[:binding] || {})['fn'].inspect}, kernel_id=#{kid.inspect}"
          end
        end
        lines.join("\n")
      end
    end
  end
end
