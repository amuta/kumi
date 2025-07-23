#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "fileutils"

class UnusedCodeHelper
  def initialize(project_root = Dir.pwd)
    @project_root = Pathname.new(project_root)
  end

  def help
    puts <<~HELP
      🛠️  Unused Code Helper

      This script helps you safely identify and remove unused code based on coverage analysis.

      USAGE:
        ruby #{__FILE__} <command> [args]

      COMMANDS:
        analyze                    - Run full unused code analysis
        show-uncovered FILE        - Show uncovered lines in a specific file
        remove-method FILE METHOD  - Remove a specific method from a file
        backup-file FILE           - Create backup before modifying
        test-removal FILE          - Test if removing file breaks tests

      EXAMPLES:
        ruby #{__FILE__} analyze
        ruby #{__FILE__} show-uncovered lib/kumi/runner.rb
        ruby #{__FILE__} remove-method lib/kumi/runner.rb explain_execution
        ruby #{__FILE__} test-removal lib/kumi/unused_file.rb

      SAFETY:
        - Always run tests after any removal
        - This script creates backups automatically
        - Use git to track changes and rollback if needed
    HELP
  end

  def analyze
    puts "🔍 Running unused code analysis..."
    system("ruby #{@project_root}/scripts/analyze_unused_code.rb")
  end

  def show_uncovered(file_path)
    return puts "❌ File not found: #{file_path}" unless File.exist?(file_path)

    puts "📄 Showing uncovered lines in #{file_path}"
    puts "=" * 50

    coverage_data = load_coverage_data
    return puts "❌ No coverage data found" unless coverage_data

    abs_path = File.expand_path(file_path)
    file_coverage = coverage_data.dig("RSpec", "coverage", abs_path)

    unless file_coverage
      puts "❌ No coverage data for this file"
      return
    end

    line_coverage = file_coverage.is_a?(Hash) ? file_coverage["lines"] : file_coverage
    content_lines = File.readlines(file_path)

    puts "Legend: ❌ = uncovered, ✅ = covered, ⚪ = not executable\n\n"

    line_coverage.each_with_index do |hits, index|
      line_num = index + 1
      line_content = content_lines[index]&.chomp || ""

      status = case hits
               when nil then "⚪"
               when 0 then "❌"
               else "✅"
               end

      puts "#{status} #{line_num.to_s.rjust(4)}: #{line_content}" if hits.zero? # Only show uncovered lines
    end
  end

  def remove_method(file_path, method_name)
    return puts "❌ File not found: #{file_path}" unless File.exist?(file_path)

    backup_file(file_path)

    content = File.read(file_path)
    lines = content.lines

    # Find method start and end
    method_start = nil
    method_end = nil
    indent_level = nil

    lines.each_with_index do |line, index|
      next unless line.match?(/^\s*def\s+#{Regexp.escape(method_name)}\b/)

      method_start = index
      indent_level = line[/^\s*/].length
      puts "📍 Found method '#{method_name}' at line #{index + 1}"
      break
    end

    unless method_start
      puts "❌ Method '#{method_name}' not found in #{file_path}"
      return
    end

    # Find method end
    ((method_start + 1)...lines.length).each do |index|
      line = lines[index]
      line_indent = line[/^\s*/].length

      if line.strip == "end" && line_indent == indent_level
        method_end = index
        break
      end
    end

    unless method_end
      puts "❌ Could not find end of method '#{method_name}'"
      return
    end

    puts "📍 Method spans lines #{method_start + 1} to #{method_end + 1}"

    # Remove the method
    new_lines = lines[0...method_start] + lines[(method_end + 1)..]

    File.write(file_path, new_lines.join)
    puts "✅ Removed method '#{method_name}' from #{file_path}"
    puts "💡 Backup saved as #{file_path}.backup"
    puts "⚠️  Remember to run tests: bundle exec rspec"
  end

  def backup_file(file_path)
    backup_path = "#{file_path}.backup"
    FileUtils.cp(file_path, backup_path)
    puts "💾 Created backup: #{backup_path}"
  end

  def test_removal(file_path)
    return puts "❌ File not found: #{file_path}" unless File.exist?(file_path)

    puts "🧪 Testing removal of #{file_path}..."

    # Create backup
    backup_file(file_path)

    # Temporarily rename the file
    temp_path = "#{file_path}.temp_removed"
    FileUtils.mv(file_path, temp_path)

    puts "📋 Running tests without #{file_path}..."

    # Run tests
    test_result = system("bundle exec rspec --format progress 2>/dev/null")

    # Restore file
    FileUtils.mv(temp_path, file_path)

    if test_result
      puts "✅ Tests pass without #{file_path} - it might be safe to remove"
      puts "⚠️  However, this doesn't guarantee the file is completely unused"
    else
      puts "❌ Tests fail without #{file_path} - file is likely needed"
    end

    # Clean up backup
    FileUtils.rm_f("#{file_path}.backup")
  end

  private

  def load_coverage_data
    coverage_file = @project_root / "coverage" / ".resultset.json"
    return nil unless coverage_file.exist?

    require "json"
    JSON.parse(File.read(coverage_file))
  rescue JSON::ParserError
    nil
  end
end

# Command line interface
if __FILE__ == $PROGRAM_NAME
  helper = UnusedCodeHelper.new

  case ARGV[0]
  when "analyze"
    helper.analyze
  when "show-uncovered"
    helper.show_uncovered(ARGV[1]) if ARGV[1]
  when "remove-method"
    helper.remove_method(ARGV[1], ARGV[2]) if ARGV[1] && ARGV[2]
  when "backup-file"
    helper.backup_file(ARGV[1]) if ARGV[1]
  when "test-removal"
    helper.test_removal(ARGV[1]) if ARGV[1]
  else
    helper.help
  end
end
