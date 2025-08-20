# frozen_string_literal: true

class ErrorInspector
  def initialize
    @captured_errors = []
  end

  def capture_error
    yield
    nil
  rescue StandardError => e
    @captured_errors << e
    e
  end

  def last_error
    @captured_errors.last
  end

  def error_count
    @captured_errors.size
  end

  def clear_errors
    @captured_errors.clear
  end

  def has_error_matching?(pattern)
    @captured_errors.any? { |error| error.message =~ pattern }
  end
end

# Helper matchers for error testing
RSpec::Matchers.define :include_error_pattern do |pattern|
  match do |error_result|
    error_result.respond_to?(:message) && error_result.message.include?(pattern)
  end

  failure_message do |error_result|
    if error_result.nil?
      "Expected an error containing '#{pattern}', but no error was raised"
    elsif error_result.respond_to?(:message)
      "Expected error message to include '#{pattern}', but got: '#{error_result.message}'"
    else
      "Expected an error object, but got: #{error_result.class}"
    end
  end
end

RSpec::Matchers.define :exceed_memory_limit do |limit_bytes|
  match do |block|
    initial_memory = memory_usage
    block.call
    final_memory = memory_usage
    (final_memory - initial_memory) > limit_bytes
  end

  private

  def memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i * 1024 # Convert KB to bytes
  end
end

# Helper methods for DSL breakage testing
module DSLBreakageHelpers
  def build_schema(&block)
    Class.new do
      extend Kumi::Schema

      schema(&block)
    end
  end

  def schema(&)
    Kumi.schema(&)
  end

  def expect_syntax_error
    yield
    raise "Expected SyntaxError but none was raised"
  rescue Kumi::Core::Errors::SyntaxError => e
    e
  rescue SyntaxError => e
    # Handle Ruby syntax errors as well
    e
  end

  def expect_semantic_error
    yield
    raise "Expected SemanticError but none was raised"
  rescue Kumi::Core::Errors::SemanticError => e
    e
  end

  def expect_type_error
    yield
    raise "Expected TypeError but none was raised"
  rescue Kumi::Core::Errors::TypeError => e
    e
  end

  def expect_runtime_error(schema, input_data)
    schema.from(input_data)
    yield if block_given?
    # If we get here without an error, fail the test
    raise "Expected runtime error but none was raised"
  rescue Kumi::Core::Errors::RuntimeError,
         Kumi::Core::Errors::InputValidationError,
         Kumi::Core::Errors::DomainViolationError => e
    e
  end

  def expect_ruby_syntax_error
    yield
    raise "Expected Ruby SyntaxError but none was raised"
  rescue SyntaxError => e
    e
  end

  def expect_performance_degradation
    start_time = Time.now
    result = yield
    end_time = Time.now

    PerformanceResult.new(result, end_time - start_time)
  end

  def expect_no_stack_overflow
    yield
    true
  rescue SystemStackError
    false
  end

  def expect_no_error
    yield
    true
  rescue StandardError => e
    raise "Expected no error but got: #{e.class}: #{e.message}"
  end

  class PerformanceResult
    attr_reader :result, :execution_time

    def initialize(result, execution_time)
      @result = result
      @execution_time = execution_time
    end

    def not_matching?(matcher)
      !matcher.matches?(self)
    end
  end
end

# Include the helpers in RSpec
RSpec.configure do |config|
  config.include DSLBreakageHelpers
end
