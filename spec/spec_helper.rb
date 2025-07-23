# frozen_string_literal: true

require "simplecov"
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

  minimum_coverage 65
  track_files "lib/**/*.rb"
end

require "bundler/setup"
require "kumi"
require "pry"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
