#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

class SimpleDeadCodeFinder
  COVERAGE_JSON = "coverage/.resultset.json"

  def run
    unless File.exist?(COVERAGE_JSON)
      puts "❌ No coverage data found. Run tests first:"
      puts "   COVERAGE=true bundle exec rspec"
      exit 1
    end

    puts "🔍 Analyzing SimpleCov data for dead code..."

    coverage_data = JSON.parse(File.read(COVERAGE_JSON))
    coverage = coverage_data.values.first["coverage"]

    find_dead_files(coverage)
    find_low_coverage_files(coverage)

    puts "\n💡 Next steps:"
    puts "   1. Open coverage/index.html to see detailed line-by-line coverage"
    puts "   2. Review uncovered files to see if they can be removed"
    puts "   3. Look at uncovered methods in low-coverage files"
  end

  private

  def find_dead_files(coverage)
    puts "\n🚨 COMPLETELY UNCOVERED FILES (potential dead code):"
    puts "=" * 60

    dead_files = []

    coverage.each do |file, line_data|
      next unless file.include?("/lib/")

      # Extract lines array from SimpleCov format
      lines = line_data["lines"]
      next unless lines

      total_lines = lines.count { |hits| !hits.nil? }
      covered_lines = lines.count { |hits| hits && hits > 0 }

      if total_lines > 0 && covered_lines == 0
        relative_path = file.sub("#{Dir.pwd}/", "")
        dead_files << relative_path
      end
    end

    if dead_files.empty?
      puts "✅ No completely uncovered files found!"
    else
      puts "Found #{dead_files.length} completely uncovered files:"
      dead_files.sort.each { |f| puts "  📄 #{f}" }

      puts "\n⚠️  These files are candidates for removal, but verify:"
      puts "   • Check if they're loaded via autoloading/zeitwerk"
      puts "   • Look for usage in examples/ or external code"
      puts "   • Consider if they're part of public API"
    end
  end

  def find_low_coverage_files(coverage)
    puts "\n🔍 LOW COVERAGE FILES (<20% - check for dead methods):"
    puts "=" * 20

    low_coverage = []

    coverage.each do |file, line_data|
      next unless file.include?("/lib/")

      # Extract lines array from SimpleCov format
      lines = line_data["lines"]
      next unless lines

      total_lines = lines.count { |hits| !hits.nil? }
      covered_lines = lines.count { |hits| hits && hits > 0 }

      next if total_lines == 0

      coverage_percent = (covered_lines.to_f / total_lines * 100)

      next unless coverage_percent > 0 && coverage_percent < 20

      relative_path = file.sub("#{Dir.pwd}/", "")
      low_coverage << {
        file: relative_path,
        percent: coverage_percent,
        covered: covered_lines,
        total: total_lines
      }
    end

    if low_coverage.empty?
      puts "✅ No files with very low coverage found!"
    else
      low_coverage.sort_by { |f| f[:percent] }.each do |info|
        printf "  📄 %-50s %5.1f%% (%d/%d lines)\n",
               info[:file], info[:percent], info[:covered], info[:total]
      end

      puts "\n💡 These files likely contain dead methods:"
      puts "   • Open coverage/index.html and click on these files"
      puts "   • Red lines are uncovered - potential dead code"
      puts "   • Look for entire uncovered methods/classes"
    end
  end
end

SimpleDeadCodeFinder.new.run if __FILE__ == $0
