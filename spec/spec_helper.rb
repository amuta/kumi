# frozen_string_literal: true

require "bundler/setup"
require "kumi"
require "pry"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# Suppress warnings about potentially false-positive raise_error matchers
RSpec::Expectations.configuration.on_potential_false_positives = :nothing
