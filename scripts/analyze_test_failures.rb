#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'fileutils'

class TestFailureAnalyzer
  def initialize
    @output_dir = 'test_failure_analysis'
    @timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    FileUtils.mkdir_p(@output_dir)
  end

  def analyze_failures
    puts "🔍 Analyzing test failures..."
    
    # Run tests and capture structured output
    failure_data = run_tests_with_structured_output
    
    if failure_data[:failures].empty?
      puts "✅ No test failures found!"
      return
    end
    
    # Group and analyze failures
    grouped_failures = group_failures(failure_data[:failures])
    
    # Generate reports
    generate_summary_report(grouped_failures, failure_data[:stats])
    generate_detailed_reports(grouped_failures)
    generate_action_plan(grouped_failures)
    
    puts "\n📊 Analysis complete! Reports generated in #{@output_dir}/"
    puts "📋 Start with: #{@output_dir}/SUMMARY_#{@timestamp}.md"
  end

  private

  def run_tests_with_structured_output
    puts "Running test suite with structured output..."
    
    # Use JSON formatter for structured data
    cmd = "bundle exec rspec --format json --out /tmp/rspec_results.json --format failures --failure-exit-code=0"
    system(cmd)
    
    # Parse JSON results
    results = JSON.parse(File.read('/tmp/rspec_results.json'))
    
    {
      stats: {
        total: results['summary']['example_count'],
        passed: results['summary']['example_count'] - results['summary']['failure_count'],
        failed: results['summary']['failure_count'],
        duration: results['summary']['duration']
      },
      failures: extract_failure_details(results['examples'])
    }
  rescue => e
    puts "⚠️  Error parsing test results: #{e.message}"
    { stats: {}, failures: [] }
  end

  def extract_failure_details(examples)
    examples.select { |ex| ex['status'] == 'failed' }.map do |example|
      {
        description: example['full_description'],
        file_path: example['file_path'],
        line_number: example['line_number'],
        error_message: example.dig('exception', 'message'),
        error_class: example.dig('exception', 'class'),
        backtrace: example.dig('exception', 'backtrace') || [],
        duration: example['run_time']
      }
    end
  end

  def group_failures(failures)
    groups = {
      'Type System' => [],
      'Function Resolution' => [],
      'Broadcasting/Vectorization' => [],
      'Input Validation' => [],
      'Compilation' => [],
      'Runtime Execution' => [],
      'Other' => []
    }

    failures.each do |failure|
      category = categorize_failure(failure)
      groups[category] << failure
    end

    groups.reject { |_, failures| failures.empty? }
  end

  def categorize_failure(failure)
    error_msg = failure[:error_message]&.downcase || ''
    file_path = failure[:file_path]
    backtrace = failure[:backtrace].join(' ').downcase

    case
    when error_msg.include?('type') || error_msg.include?('dtype') || backtrace.include?('type_checker')
      'Type System'
    when error_msg.include?('ambiguous') || error_msg.include?('function') || error_msg.include?('signature')
      'Function Resolution'
    when error_msg.include?('broadcast') || error_msg.include?('vectoriz') || error_msg.include?('dimension')
      'Broadcasting/Vectorization'
    when error_msg.include?('input') || error_msg.include?('metadata') || error_msg.include?('field')
      'Input Validation'
    when backtrace.include?('compiler') || backtrace.include?('analyzer')
      'Compilation'
    when error_msg.include?('runtime') || error_msg.include?('execution') || backtrace.include?('runner')
      'Runtime Execution'
    else
      'Other'
    end
  end

  def generate_summary_report(grouped_failures, stats)
    filename = "#{@output_dir}/SUMMARY_#{@timestamp}.md"
    
    File.open(filename, 'w') do |f|
      f.puts "# Test Failure Analysis Summary"
      f.puts "Generated: #{Time.now}"
      f.puts ""
      
      f.puts "## Overall Statistics"
      f.puts "- **Total Tests**: #{stats[:total]}"
      f.puts "- **Passed**: #{stats[:passed]}"
      f.puts "- **Failed**: #{stats[:failed]}"
      f.puts "- **Duration**: #{stats[:duration]}s"
      f.puts ""
      
      f.puts "## Failure Categories"
      grouped_failures.each do |category, failures|
        f.puts "### #{category} (#{failures.length} failures)"
        f.puts ""
        
        # Common error patterns
        error_patterns = analyze_error_patterns(failures)
        if error_patterns.any?
          f.puts "**Common Patterns:**"
          error_patterns.each { |pattern| f.puts "- #{pattern}" }
          f.puts ""
        end
        
        # Sample failures
        f.puts "**Sample Failures:**"
        failures.first(3).each do |failure|
          f.puts "- `#{File.basename(failure[:file_path])}:#{failure[:line_number]}` - #{failure[:description]}"
        end
        f.puts ""
        
        f.puts "📋 *See detailed analysis: [#{category.gsub(' ', '_').upcase}_#{@timestamp}.md](#{category.gsub(' ', '_').upcase}_#{@timestamp}.md)*"
        f.puts ""
      end
      
      f.puts "## Recommended Actions"
      f.puts "1. Review [ACTION_PLAN_#{@timestamp}.md](ACTION_PLAN_#{@timestamp}.md) for prioritized fixes"
      f.puts "2. Start with the category with the most failures"
      f.puts "3. Use debug environment variables for detailed analysis"
      f.puts ""
    end
    
    puts "📋 Summary report: #{filename}"
  end

  def generate_detailed_reports(grouped_failures)
    grouped_failures.each do |category, failures|
      filename = "#{@output_dir}/#{category.gsub(' ', '_').gsub('/', '_').upcase}_#{@timestamp}.md"
      
      File.open(filename, 'w') do |f|
        f.puts "# #{category} Failures - Detailed Analysis"
        f.puts "Generated: #{Time.now}"
        f.puts ""
        
        f.puts "## Error Patterns"
        patterns = analyze_error_patterns(failures)
        patterns.each { |pattern| f.puts "- #{pattern}" }
        f.puts ""
        
        f.puts "## Affected Files"
        file_summary = failures.group_by { |f| f[:file_path] }
        file_summary.each do |file, file_failures|
          f.puts "### #{file.gsub(/.*\/spec\//, 'spec/')}"
          f.puts "**Failures**: #{file_failures.length}"
          f.puts ""
        end
        f.puts ""
        
        f.puts "## Individual Failures"
        failures.each_with_index do |failure, i|
          f.puts "### Failure #{i + 1}: #{failure[:description]}"
          f.puts ""
          f.puts "**Location**: `#{failure[:file_path]}:#{failure[:line_number]}`"
          f.puts "**Error**: `#{failure[:error_class]}` - #{failure[:error_message]}"
          f.puts ""
          
          # Extract relevant backtrace
          relevant_trace = extract_relevant_backtrace(failure[:backtrace])
          if relevant_trace.any?
            f.puts "**Key Stack Trace**:"
            f.puts "```"
            relevant_trace.each { |line| f.puts line }
            f.puts "```"
            f.puts ""
          end
          
          # Suggest debugging commands
          debug_cmds = suggest_debug_commands(failure)
          if debug_cmds.any?
            f.puts "**Debug Commands**:"
            debug_cmds.each { |cmd| f.puts "```bash\n#{cmd}\n```" }
            f.puts ""
          end
          
          f.puts "---"
          f.puts ""
        end
      end
      
      puts "📄 Detailed report: #{filename}"
    end
  end

  def generate_action_plan(grouped_failures)
    filename = "#{@output_dir}/ACTION_PLAN_#{@timestamp}.md"
    
    File.open(filename, 'w') do |f|
      f.puts "# Test Failure Action Plan"
      f.puts "Generated: #{Time.now}"
      f.puts ""
      
      f.puts "## Prioritized Fix Order"
      
      # Sort by impact and frequency
      sorted_categories = grouped_failures.sort_by do |category, failures|
        [-failures.length, -calculate_impact_score(category, failures)]
      end
      
      sorted_categories.each_with_index do |(category, failures), i|
        f.puts "### #{i + 1}. #{category} (#{failures.length} failures)"
        f.puts ""
        
        # Impact assessment
        impact = calculate_impact_score(category, failures)
        f.puts "**Impact**: #{impact_description(impact)}"
        f.puts "**Effort**: #{estimate_effort(category, failures)}"
        f.puts ""
        
        # Specific actions
        actions = generate_specific_actions(category, failures)
        f.puts "**Actions**:"
        actions.each { |action| f.puts "- #{action}" }
        f.puts ""
        
        # Quick wins
        quick_wins = identify_quick_wins(failures)
        if quick_wins.any?
          f.puts "**Quick Wins**:"
          quick_wins.each { |win| f.puts "- #{win}" }
          f.puts ""
        end
        
        f.puts "---"
        f.puts ""
      end
      
      f.puts "## Debug Environment Variables"
      f.puts "Use these for detailed analysis:"
      f.puts "```bash"
      f.puts "DEBUG_TYPE_CHECKER=1    # Type system issues"
      f.puts "DEBUG_NORMALIZE=1       # Function resolution"
      f.puts "DEBUG_BROADCAST=1       # Broadcasting/vectorization"
      f.puts "DEBUG_LOWER=1          # Compilation issues"
      f.puts "DEBUG_VM=1             # Runtime execution"
      f.puts "DUMP_IR=/tmp/debug.txt # IR analysis"
      f.puts "```"
    end
    
    puts "🎯 Action plan: #{filename}"
  end

  def analyze_error_patterns(failures)
    patterns = Hash.new(0)
    
    failures.each do |failure|
      msg = failure[:error_message] || ''
      
      # Extract patterns
      case msg
      when /undefined method `(\w+)'/
        patterns["Undefined method: #{$1}"] += 1
      when /wrong number of arguments/
        patterns["Argument count mismatch"] += 1
      when /ambiguous function (\w+)/
        patterns["Ambiguous function: #{$1}"] += 1
      when /missing input metadata/i
        patterns["Missing input metadata"] += 1
      when /type mismatch/i
        patterns["Type mismatch"] += 1
      when /no implicit conversion/
        patterns["Type conversion error"] += 1
      else
        # Extract first meaningful word
        words = msg.split(/\s+/).first(3).join(' ')
        patterns[words] += 1 if words.length > 5
      end
    end
    
    patterns.sort_by { |_, count| -count }.first(5).map { |pattern, count| "#{pattern} (#{count}x)" }
  end

  def extract_relevant_backtrace(backtrace)
    return [] if backtrace.empty?
    
    # Filter to project files and key system files
    relevant = backtrace.select do |line|
      line.include?('/lib/kumi/') || 
      line.include?('/spec/') ||
      line.include?('analyzer') ||
      line.include?('compiler')
    end
    
    relevant.first(8)
  end

  def suggest_debug_commands(failure)
    commands = []
    
    file_path = failure[:file_path]
    line_number = failure[:line_number]
    error_msg = failure[:error_message]&.downcase || ''
    
    # Base test command
    test_cmd = "bundle exec rspec #{file_path}:#{line_number} --format=documentation"
    
    # Add debug flags based on error type
    if error_msg.include?('type') || error_msg.include?('ambiguous')
      commands << "DEBUG_TYPE_CHECKER=1 #{test_cmd}"
    end
    
    if error_msg.include?('function') || error_msg.include?('signature')
      commands << "DEBUG_NORMALIZE=1 #{test_cmd}"
    end
    
    if error_msg.include?('broadcast') || error_msg.include?('vectoriz')
      commands << "DEBUG_BROADCAST=1 #{test_cmd}"
    end
    
    if error_msg.include?('input') || error_msg.include?('metadata')
      commands << "DEBUG_INPUT_COLLECTOR=1 #{test_cmd}"
    end
    
    # Always suggest IR dump for complex issues
    commands << "DUMP_IR=/tmp/debug_#{line_number}.txt #{test_cmd}"
    
    commands.uniq
  end

  def calculate_impact_score(category, failures)
    base_score = failures.length
    
    # Weight by category importance
    multiplier = case category
    when 'Type System' then 3
    when 'Function Resolution' then 2.5
    when 'Compilation' then 2.0
    when 'Broadcasting/Vectorization' then 1.5
    when 'Input Validation' then 1.5
    when 'Runtime Execution' then 1.0
    else 0.5
    end
    
    (base_score * multiplier).to_i
  end

  def impact_description(score)
    case score
    when 0..5 then "Low"
    when 6..15 then "Medium"
    when 16..30 then "High"
    else "Critical"
    end
  end

  def estimate_effort(category, failures)
    case category
    when 'Type System' then "Medium (requires analyzer changes)"
    when 'Function Resolution' then "Low-Medium (registry updates)"
    when 'Compilation' then "High (complex compiler changes)"
    when 'Broadcasting/Vectorization' then "Medium (metadata analysis)"
    when 'Input Validation' then "Low (validation logic)"
    when 'Runtime Execution' then "Medium (kernel implementations)"
    else "Unknown"
    end
  end

  def generate_specific_actions(category, failures)
    case category
    when 'Type System'
      [
        "Review TypeInferencerPass for missing type annotations",
        "Check CallTypeValidator input metadata navigation",
        "Verify function signature matching in RegistryV2"
      ]
    when 'Function Resolution'
      [
        "Update function signatures in config/functions.yaml",
        "Check AmbiguityResolver metadata usage",
        "Verify qualified function name resolution"
      ]
    when 'Broadcasting/Vectorization'
      [
        "Review BroadcastDetector function class assignments",
        "Check dimensional analysis in ScopeResolutionPass",
        "Verify array element access patterns"
      ]
    when 'Input Validation'
      [
        "Fix InputCollectorPass metadata generation",
        "Update nested hash navigation logic",
        "Check input type validation rules"
      ]
    when 'Compilation'
      [
        "Review IR lowering passes",
        "Check kernel implementations",
        "Verify VM operation generation"
      ]
    when 'Runtime Execution'
      [
        "Implement missing kernel functions",
        "Check VM operation execution",
        "Verify data type conversions"
      ]
    else
      ["Investigate error patterns and root causes"]
    end
  end

  def identify_quick_wins(failures)
    wins = []
    
    # Look for simple patterns
    failures.each do |failure|
      msg = failure[:error_message] || ''
      
      case msg
      when /undefined method/
        wins << "Add missing method implementation"
      when /wrong number of arguments.*given (\d+), expected (\d+)/
        wins << "Fix method signature: given #{$1}, expected #{$2}"
      when /missing input metadata for (\w+)/
        wins << "Add input metadata for #{$1}"
      end
    end
    
    wins.uniq.first(3)
  end
end

# Command line interface
if __FILE__ == $0
  analyzer = TestFailureAnalyzer.new
  analyzer.analyze_failures
end