# frozen_string_literal: true

require "bundler/setup"
require "kumi"
require "pry"
require "open3"

# require "simplecov"
# SimpleCov.start do
#   add_filter "/spec/"
#   add_filter "/vendor/"

#   add_group "Parser", "lib/kumi/ruby_parser"
#   add_group "Core", ["lib/kumi/schema.rb", "lib/kumi/types.rb", "lib/kumi/function_registry.rb"]
#   add_group "Analyzer", "lib/kumi/analyzer"
#   add_group "Compiler", "lib/kumi/compiler"
#   add_group "Syntax", "lib/kumi/syntax"
#   add_group "Input", "lib/kumi/input"
#   add_group "Domain", "lib/kumi/domain"
#   add_group "Text Parser", "lib/kumi/text_parser"

#   minimum_coverage 0
#   track_files "lib/**/*.rb"
# end

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec::Expectations.configuration.on_potential_false_positives = :nothing

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include DualModeHelpers
end

ENV["DUAL_MODE_ENABLED"] = "true"

return unless ENV["DUAL_MODE_ENABLED"] == "true"

# Override Schema from to use dual mode for all specs
module Kumi
  module Schema
    def from(context)
      raise("No schema defined") unless @__compiled_schema__

      # Validate input types and domain constraints
      input_meta = @__analyzer_result__.state[:inputs] || {}
      violations = Core::Input::Validator.validate_context(context, input_meta)

      raise Errors::InputValidationError, violations unless violations.empty?

      require_relative "support/dual_runner"
      DualRunner.new(self, context)
    end
  end
end

# Suppress warnings about potentially false-positive raise_error matchers
