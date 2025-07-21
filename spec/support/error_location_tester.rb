# frozen_string_literal: true

class ErrorLocationTester
  def initialize(file_name = "test_schema.rb")
    @file_name = file_name
    @line_number = 1
    @content_lines = []
  end

  # Define the "file" content line by line
  def define_schema(&block)
    @content_lines = extract_lines_from_block(&block)
    @line_number = 1
  end

  # Execute the schema and capture the exact error with location
  def expect_error_at_line(expected_line, pattern: nil, type: Kumi::Errors::SemanticError)
    # Create a temporary file-like construct for error reporting
    schema_code = @content_lines.join("\n")

    # Execute the schema in a way that preserves line numbers
    eval(schema_code, binding, @file_name, 1)

    # If we get here, no error was raised
    raise "Expected #{type} but no error was raised"
  rescue type => e
    # Verify the error occurred at the expected line
    raise "Expected error at line #{expected_line}, but got line #{e.location&.line || 'unknown'}" if e.location&.line != expected_line

    # Verify the error message contains expected pattern
    raise "Expected error message to include '#{pattern}', but got: '#{e.message}'" if pattern && !e.message.include?(pattern)

    # Return the error for further inspection
    ErrorLocationResult.new(e, @content_lines, expected_line)
  end

  private

  def extract_line_from_message(message)
    # Try to extract line number from various error message formats
    case message
    when /line=(\d+)/ # Struct format: #<struct ... line=4 ...>
      ::Regexp.last_match(1).to_i
    when /inline_test\.rb:(\d+)/ # Simple format: file.rb:line
      ::Regexp.last_match(1).to_i
    when /at.*?:(\d+):/ # Format: "at file.rb:line:column:"
      ::Regexp.last_match(1).to_i
    end
  end

  def extract_lines_from_block
    # This is a simplified approach - in practice, we'd want to inspect
    # the block source code more carefully
    source = yield
    source.split("\n")
  end
end

class ErrorLocationResult
  attr_reader :error, :content_lines, :expected_line

  def initialize(error, content_lines, expected_line)
    @error = error
    @content_lines = content_lines
    @expected_line = expected_line
  end

  def actual_line
    @error.location&.line
  end

  def line_content
    return "Line not found" unless actual_line && actual_line <= @content_lines.length

    @content_lines[actual_line - 1]
  end

  def error_summary
    {
      type: @error.class.name,
      message: @error.message,
      expected_line: @expected_line,
      actual_line: actual_line,
      line_content: line_content.strip,
      location_correct: actual_line == @expected_line
    }
  end

  def location_correct?
    actual_line == @expected_line
  end
end

# Helper for creating inline schemas with known line numbers
class InlineSchemaBuilder
  def self.extract_line_from_message(message)
    # Try to extract line number from various error message formats
    case message
    when /line=(\d+)/ # Struct format: #<struct ... line=4 ...>
      ::Regexp.last_match(1).to_i
    when /inline_test\.rb:(\d+)/ # Simple format: file.rb:line
      ::Regexp.last_match(1).to_i
    when /at.*?:(\d+):/ # Format: "at file.rb:line:column:"
      ::Regexp.last_match(1).to_i
    end
  end

  def self.test_error(schema_string, expected_error_line:, expected_pattern: nil, expected_type: Kumi::Errors::SemanticError)
    lines = schema_string.split("\n")

    begin
      # Execute with a fake filename for testing
      eval(schema_string, binding, "inline_test.rb", 1)

      raise "Expected #{expected_type} but no error was raised"
    rescue expected_type => e
      # Extract location from error message since compound errors embed location in message
      actual_line = extract_line_from_message(e.message) || e.location&.line

      result = {
        success: actual_line == expected_error_line,
        expected_line: expected_error_line,
        actual_line: actual_line,
        error_type: e.class.name,
        error_message: e.message,
        line_content: actual_line && actual_line <= lines.length ? lines[actual_line - 1]&.strip : "Line not found",
        pattern_match: expected_pattern ? e.message.include?(expected_pattern) : true
      }

      unless result[:success]
        puts "❌ Line mismatch! Expected line #{expected_error_line}, got #{actual_line}"
        puts "   Line content: '#{result[:line_content]}'"
        puts "   Error: #{e.message}"
      end

      unless result[:pattern_match]
        puts "❌ Pattern mismatch! Expected '#{expected_pattern}' in message"
        puts "   Actual message: #{e.message}"
      end

      result
    end
  end
end

# RSpec helper methods
module ErrorLocationHelpers
  def test_error_location(schema_string, expected_line:, pattern: nil, type: Kumi::Errors::SemanticError)
    InlineSchemaBuilder.test_error(
      schema_string,
      expected_error_line: expected_line,
      expected_pattern: pattern,
      expected_type: type
    )
  end

  def expect_error_at_line(line_number)
    ErrorLocationMatcher.new(line_number)
  end
end

class ErrorLocationMatcher
  def initialize(expected_line)
    @expected_line = expected_line
    @expected_pattern = nil
    @expected_type = Kumi::Errors::SemanticError
  end

  def with_message(pattern)
    @expected_pattern = pattern
    self
  end

  def of_type(type)
    @expected_type = type
    self
  end

  def matches?(proc_or_string)
    if proc_or_string.is_a?(String)
      test_with_string(proc_or_string)
    else
      test_with_proc(proc_or_string)
    end
  end

  def failure_message
    "Expected error at line #{@expected_line} but got line #{@actual_line}"
  end

  private

  def test_with_string(schema_string)
    result = InlineSchemaBuilder.test_error(
      schema_string,
      expected_error_line: @expected_line,
      expected_pattern: @expected_pattern,
      expected_type: @expected_type
    )

    @actual_line = result[:actual_line]
    result[:success] && result[:pattern_match]
  end

  def test_with_proc(proc)
    proc.call
    false # No error raised
  rescue @expected_type => e
    @actual_line = e.location&.line
    line_correct = @actual_line == @expected_line
    pattern_correct = @expected_pattern ? e.message.include?(@expected_pattern) : true

    line_correct && pattern_correct
  rescue StandardError
    false # Wrong error type
  end
end

RSpec.configure do |config|
  config.include ErrorLocationHelpers
end
