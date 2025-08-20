# frozen_string_literal: true

require "bundler/setup"
require "kumi"
require "pry"
require "open3"

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"

  add_group "AnalyzerDebug", ["lib/kumi/core/analyzer/debug/*.rb", "lib/kumi/core/analyzer/debug.rb"]
  add_group "Analyzer", ["lib/kumi/core/analyzer/**/*.rb", "lib/kumi/analyzer.rb"]
  add_group "Compiler", ["lib/kumi/compiler.rb", "lib/kumi/core/compiler/**/*.rb"]
  add_group "IR", ["lib/kumi/core/ir/**/*.rb"]
  add_group "Other", ["lib/**/*.rb"]

  minimum_coverage 0
  track_files "lib/**/*.rb"
end

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec::Expectations.configuration.on_potential_false_positives = :nothing

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Suppress warnings about potentially false-positive raise_error matchers

module SchemaHelper
  extend Kumi::Schema
end

module Kumi
  def self.schema(&)
    SchemaHelper.schema(&)
  end
end

# ENV["DUAL_MODE_ENABLED"] ||= "true" # Disabled for element access mode testing

return unless ENV["DUAL_MODE_ENABLED"] == "true"

# Override Schema from to use dual mode for all specs
# module Kumi
#   module Schema
#     def from(context)
#       raise("No schema defined") unless @__compiled_schema__

#       # Validate input types and domain constraints
#       input_meta = @__analyzer_result__.state[:input_metadata] || {}
#       violations = Core::Input::Validator.validate_context(context, input_meta)

#       raise Errors::InputValidationError, violations unless violations.empty?

#       require_relative "support/dual_runner"
#       DualRunner.new(self, context)
#     end
#   end
# end
