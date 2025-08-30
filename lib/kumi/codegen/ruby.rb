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

        planner      = RubyV2::Planner.new(ir_data, binding_manifest)
        plans        = planner.plan_all_declarations

        ruby_emitter = RubyV2::Emitter.new(@options)
        ruby_emitter.emit_program(plans, ir_data["analysis"])
      end
    end
  end
end
