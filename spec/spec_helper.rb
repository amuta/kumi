# frozen_string_literal: true

require "bundler/setup"
require "kumi"
require "pry"

require "simplecov"
require "simplecov_small_badge"

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/vendor/"

  add_group "Parser", "lib/kumi/parser"
  add_group "Core", ["lib/kumi/schema.rb", "lib/kumi/types.rb", "lib/kumi/function_registry.rb"]
  add_group "Analyzer", "lib/kumi/analyzer"
  add_group "Compiler", "lib/kumi/compiler"
  add_group "Syntax", "lib/kumi/syntax"
  add_group "Input", "lib/kumi/input"
  add_group "Domain", "lib/kumi/domain"

  minimum_coverage 0
  track_files "lib/**/*.rb"

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
                                                                    SimpleCov::Formatter::HTMLFormatter,
                                                                    SimpleCovSmallBadge::Formatter
                                                                  ])
end

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Suppress warnings about potentially false-positive raise_error matchers
RSpec::Expectations.configuration.on_potential_false_positives = :nothing
