#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "pathname"
require "set"

class UnusedCodeAnalyzer
  def initialize(project_root = Dir.pwd)
    @project_root = Pathname.new(project_root)
    @lib_path = @project_root / "lib"
    @coverage_path = @project_root / "coverage"
    @spec_path = @project_root / "spec"

    @uncovered_lines = {}
    @file_usage_map = {}
    @method_usage_map = {}
    @class_usage_map = {}
  end

  def analyze
    puts "🔍 Analyzing unused code in #{@project_root}"
    puts "=" * 50

    # Step 1: Parse coverage data
    parse_coverage_data

    # Step 2: Analyze actual usage in codebase
    analyze_code_usage

    # Step 3: Generate report
    generate_report
  end

  private

  def parse_coverage_data
    coverage_file = @coverage_path / ".resultset.json"

    unless coverage_file.exist?
      puts "❌ No coverage data found. Run tests first with: bundle exec rspec"
      return
    end

    puts "📊 Parsing coverage data..."

    coverage_data = JSON.parse(File.read(coverage_file))
    rspec_data = coverage_data["RSpec"] || coverage_data.values.first

    return unless rspec_data&.dig("coverage")

    rspec_data["coverage"].each do |file_path, coverage_info|
      next unless file_path.include?("/lib/") && file_path.end_with?(".rb")

      rel_path = Pathname.new(file_path).relative_path_from(@project_root)
      uncovered = []

      # Handle both old and new SimpleCov formats
      line_coverage = coverage_info.is_a?(Hash) ? coverage_info["lines"] : coverage_info

      line_coverage.each_with_index do |hits, index|
        line_num = index + 1
        # nil means not executable, 0 means not covered, >0 means covered
        uncovered << line_num if hits.zero?
      end

      @uncovered_lines[rel_path.to_s] = uncovered if uncovered.any?
    end

    puts "✅ Found #{@uncovered_lines.size} files with uncovered code"
  end

  def analyze_code_usage
    puts "🔎 Analyzing code usage across the project..."

    # Get all Ruby files to analyze
    all_files = Dir.glob(@project_root / "**/*.rb").map { |f| Pathname.new(f) }
    lib_files = all_files.select { |f| f.to_s.include?("/lib/") }

    # Build usage maps
    all_files.each do |file|
      content = File.read(file)
      analyze_file_content(file, content, lib_files)
    end
  end

  def analyze_file_content(file, content, lib_files)
    # Track require/require_relative statements
    content.scan(/(?:require|require_relative)\s+['"]([^'"]+)['"]/) do |match|
      required_file = match[0]
      track_file_usage(file, required_file, lib_files)
    end

    # Track class/module references
    content.scan(/(?:^|\s)([A-Z][A-Za-z0-9_:]+)/) do |match|
      class_name = match[0]
      next if class_name.length < 3 # Skip short names

      @class_usage_map[class_name] ||= Set.new
      @class_usage_map[class_name] << file.to_s
    end

    # Track method calls (simplified detection)
    content.scan(/\.([a-z_][a-zA-Z0-9_?!]*[?!]?)[\s\(]/) do |match|
      method_name = match[0]
      next if method_name.length < 3 # Skip short method names

      @method_usage_map[method_name] ||= Set.new
      @method_usage_map[method_name] << file.to_s
    end
  end

  def track_file_usage(from_file, required_file, lib_files)
    # Try to resolve the required file to actual lib files
    possible_matches = lib_files.select do |lib_file|
      lib_file.to_s.include?(required_file) ||
        lib_file.basename(".rb").to_s == required_file ||
        lib_file.to_s.end_with?("#{required_file}.rb")
    end

    possible_matches.each do |matched_file|
      rel_path = matched_file.relative_path_from(@project_root).to_s
      @file_usage_map[rel_path] ||= Set.new
      @file_usage_map[rel_path] << from_file.to_s
    end
  end

  def generate_report
    puts "\n📋 UNUSED CODE ANALYSIS REPORT"
    puts "=" * 50

    if @uncovered_lines.empty?
      puts "🎉 Great! No uncovered code found."
      return
    end

    # Categorize files
    potentially_unused_files = []
    files_with_uncovered_lines = []

    @uncovered_lines.each do |file_path, uncovered_lines|
      file_content = File.read(@project_root / file_path)

      # Check if the entire file might be unused
      if file_completely_uncovered?(file_path, file_content)
        if file_appears_unused?(file_path)
          potentially_unused_files << {
            path: file_path,
            reason: determine_unused_reason(file_path),
            lines: uncovered_lines.size
          }
        end
      else
        files_with_uncovered_lines << {
          path: file_path,
          uncovered_lines: uncovered_lines,
          analysis: analyze_uncovered_methods(file_path, file_content, uncovered_lines)
        }
      end
    end

    # Report potentially unused files
    if potentially_unused_files.any?
      puts "\n🗑️  POTENTIALLY UNUSED FILES (consider removal):"
      puts "-" * 40
      potentially_unused_files.each do |file_info|
        puts(file_info[:path])
        puts "  Reason: #{file_info[:reason]}"
        puts "  Uncovered lines: #{file_info[:lines]}"
        puts
      end
    end

    # Report files with uncovered methods/lines
    if files_with_uncovered_lines.any?
      puts "\n⚠️  FILES WITH UNCOVERED CODE:"
      puts "-" * 40
      files_with_uncovered_lines.each do |file_info|
        puts(file_info[:path])
        puts "  Uncovered lines: #{file_info[:uncovered_lines].join(', ')}"
        if file_info[:analysis][:unused_methods].any?
          puts "  Potentially unused methods: #{file_info[:analysis][:unused_methods].join(', ')}"
        end
        puts
      end
    end

    # Summary
    puts "\n📈 SUMMARY:"
    puts "-" * 20
    puts "Potentially unused files: #{potentially_unused_files.size}"
    puts "Files with uncovered code: #{files_with_uncovered_lines.size}"
    puts "Total uncovered files: #{@uncovered_lines.size}"

    return unless potentially_unused_files.any?

    puts "\n💡 RECOMMENDATIONS:"
    puts "- Review the potentially unused files listed above"
    puts "- Consider removing files that are truly unused"
    puts "- For files with uncovered methods, check if those methods are actually needed"
    puts "- Run tests again after any removals to ensure nothing breaks"
  end

  def file_completely_uncovered?(file_path, content)
    return false if content.lines.size < 5 # Skip very small files

    # Count executable lines (rough heuristic)
    executable_lines = content.lines.count do |line|
      line.strip.length.positive? &&
        !line.strip.start_with?("#") &&
        !line.strip.match?(/^\s*(end|else|elsif|when|rescue|ensure)\s*$/)
    end

    uncovered_count = @uncovered_lines[file_path]&.size || 0

    # Consider "completely uncovered" if >80% of executable lines are uncovered
    return false if executable_lines.zero?

    (uncovered_count.to_f / executable_lines) > 0.8
  end

  def file_appears_unused?(file_path)
    # Check if file is referenced anywhere
    @file_usage_map[file_path].nil? || @file_usage_map[file_path].empty?
  end

  def determine_unused_reason(file_path)
    reasons = []

    reasons << "not explicitly required" unless @file_usage_map[file_path]&.any?
    reasons << "no coverage" if @uncovered_lines[file_path]&.any?

    # Check if it's in a specific category that might indicate purpose
    if file_path.include?("/passes/")
      reasons << "analyzer pass (check if used in analyzer.rb)"
    elsif file_path.include?("/function_registry/")
      reasons << "function registry component (check if loaded)"
    elsif file_path.include?("/export/")
      reasons << "export functionality (might be optional)"
    end

    reasons.empty? ? "analysis inconclusive" : reasons.join(", ")
  end

  def analyze_uncovered_methods(_file_path, content, uncovered_lines)
    unused_methods = []

    # Simple method detection in uncovered lines
    content.lines.each_with_index do |line, index|
      line_num = index + 1
      next unless uncovered_lines.include?(line_num)

      next unless line.match?(/def\s+([a-zA-Z_][a-zA-Z0-9_?!]*)/)

      method_name = line.match(/def\s+([a-zA-Z_][a-zA-Z0-9_?!]*)/)[1]

      # Check if method appears to be unused
      unused_methods << method_name if !@method_usage_map[method_name] || @method_usage_map[method_name].size <= 1
    end

    { unused_methods: unused_methods }
  end
end

# Run the analyzer if this script is called directly
if __FILE__ == $PROGRAM_NAME
  analyzer = UnusedCodeAnalyzer.new
  analyzer.analyze
end
