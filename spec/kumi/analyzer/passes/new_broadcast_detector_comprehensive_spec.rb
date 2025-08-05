# frozen_string_literal: true

# Comprehensive test suite for the NewBroadcastDetector
# This file runs all the grouped specs for better organization

require_relative 'new_broadcast_detector/basic_broadcasting_spec'
require_relative 'new_broadcast_detector/reduction_operations_spec'  
require_relative 'new_broadcast_detector/cascade_operations_spec'
require_relative 'new_broadcast_detector/hierarchical_broadcasting_spec'
require_relative 'new_broadcast_detector/dimension_validation_spec'

RSpec.describe NewBroadcastDetector, "comprehensive test suite" do
  it "has organized test coverage for all broadcasting aspects" do
    # This is just a placeholder to ensure the comprehensive spec runs
    expect(true).to eq(true)
  end
end