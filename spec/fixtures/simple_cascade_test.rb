#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/kumi"

module SimpleCascadeTest
  extend Kumi::Schema

  schema do
    input do
      float :score, domain: 0.0..100.0
    end

    # Non-overlapping performance traits (mutually exclusive)
    trait :high_performer, input.score >= 90.0
    trait :avg_performer, (input.score >= 60.0) & (input.score < 90.0)
    trait :poor_performer, input.score < 60.0

    # Simple cascade - should each 'on' be independent?
    value :performance_category do
      on :high_performer, "Exceptional"
      on :avg_performer, "Satisfactory"
      on :poor_performer, "Needs Improvement"
      base "Not Evaluated"
    end
  end
end

# Test it
if __FILE__ == $PROGRAM_NAME
  puts "Testing simple cascade with mutually exclusive traits..."

  begin
    # Test high performer
    runner = SimpleCascadeTest.from(score: 95.0)
    puts "Score 95.0: #{runner[:performance_category]}"

    # Test average performer
    runner = SimpleCascadeTest.from(score: 75.0)
    puts "Score 75.0: #{runner[:performance_category]}"

    # Test poor performer
    runner = SimpleCascadeTest.from(score: 50.0)
    puts "Score 50.0: #{runner[:performance_category]}"
  rescue StandardError => e
    puts "ERROR: #{e.class} - #{e.message}"
  end
end
