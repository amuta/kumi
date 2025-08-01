#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "open3"
require "json"

class IterativeKumiCoreMigrator
  attr_reader :errors, :metadata, :change_tracker

  def initialize
    @errors = []
    @change_tracker = {}
    @change_thresholds = {
      warning: 10,
      critical: 25,
      suspicious: 50
    }
    @start_time = Time.now
    @phases = []
    @rollback_points = []
    @current_phase = nil
    @stats = {
      files_to_migrate: 0,
      files_updated: 0,
      files_moved: 0,
      total_changes: 0
    }
  end

  def migrate!
    log_phase("🚀 Starting Iterative Kumi to Kumi::Core Migration")

    begin
      # Iterative approach to handle Zeitwerk properly
      run_phase("Phase 1: Setup & Analysis") { phase_1_setup_and_analysis }
      run_phase("Phase 2: Update Module Declarations In-Place") { phase_2_update_modules_in_place }
      run_phase("Phase 3: Move Files to Core") { phase_3_move_files_to_core }
      run_phase("Phase 4: Update External References") { phase_4_update_references }
      run_phase("Phase 5: Final Validation") { phase_5_final_validation }

      finalize_migration
      log_completion_summary
      log_phase("✅ Migration completed successfully!", :success)
    rescue StandardError => e
      log_phase("❌ Migration failed: #{e.message}", :error)
      handle_failure(e)
      restore_to_initial_state
      raise e
    end
  end

  private

  # ====================
  # PHASE MANAGEMENT
  # ====================

  def run_phase(phase_name, &block)
    @current_phase = phase_name
    log_phase("Starting #{phase_name}")

    # Create rollback point before each phase
    create_rollback_point(phase_name)

    begin
      result = yield
      log_phase("✅ #{phase_name} completed successfully")
      @phases << { name: phase_name, status: :success }
      result
    rescue StandardError => e
      log_phase("❌ #{phase_name} FAILED: #{e.message}", :error)
      @phases << { name: phase_name, status: :failed, error: e.message }
      raise e
    end
  end

  def log_phase(message, level = :info)
    timestamp = Time.now.strftime("%H:%M:%S")
    icon = case level
           when :success then "✅"
           when :error then "❌"
           when :warning then "⚠️"
           else "ℹ️"
           end

    puts "[#{timestamp}] #{icon} #{message}"
  end

  def create_rollback_point(phase_name)
    # Store initial commit for potential rollback
    if @rollback_points.empty?
      initial_commit = `git rev-parse HEAD`.strip
      @rollback_points << { phase: "Initial State", commit: initial_commit }
      log_phase("📍 Initial commit stored: #{initial_commit[0..7]}")
    end

    commit_msg = "Rollback point before #{phase_name}"
    system("git add -A && git commit -m '#{commit_msg}' --allow-empty")
    commit_hash = `git rev-parse HEAD`.strip

    @rollback_points << { phase: phase_name, commit: commit_hash }

    log_phase("📍 Created rollback point: #{commit_hash[0..7]} for #{phase_name}")
  end

  # ====================
  # PHASE 1: SETUP & ANALYSIS
  # ====================

  def phase_1_setup_and_analysis
    log_phase("📋 Analyzing current structure...")

    # Analyze current files
    files_to_migrate = analyze_files_to_migrate
    @stats[:files_to_migrate] = files_to_migrate.length
    log_phase("📁 Found #{files_to_migrate.length} files to migrate to core/")

    # Show file breakdown by type
    file_types = files_to_migrate.group_by { |f| f.split("/")[2] || "root" }
    file_types.each do |type, files|
      log_phase("   └─ #{files.length} #{type} files")
    end

    # Analyze Zeitwerk expectations
    expected_constants = analyze_zeitwerk_structure
    log_phase("🔍 Zeitwerk will expect #{expected_constants} new Core:: constants")

    # Create core directory
    FileUtils.mkdir_p("lib/kumi/core")
    log_phase("📂 Created lib/kumi/core/ directory structure")

    # Test that everything still works before changes
    log_phase("🧪 Running pre-migration tests...")
    run_basic_tests("Phase 1 - Pre-migration baseline")
    log_phase("✅ Baseline tests passed - ready to proceed")
  end

  def analyze_files_to_migrate
    exclude_files = [
      "lib/kumi/cli.rb",
      "lib/kumi/version.rb",
      "lib/kumi/schema.rb"
    ]

    Dir.glob("lib/kumi/**/*.rb").reject do |file|
      exclude_files.include?(file) ||
        file.include?("/core/") ||
        File.directory?(file)
    end
  end

  def analyze_zeitwerk_structure
    # Check what constants Zeitwerk will expect after file moves
    expected_count = 0

    Dir.glob("lib/kumi/**/*.rb").each do |file|
      next if file.include?("/core/")
      next if ["cli.rb", "version.rb", "schema.rb"].any? { |skip| file.end_with?(skip) }

      expected_count += 1
    end

    expected_count
  end

  def camelize(string)
    string.split("/").map do |part|
      part.split("_").map(&:capitalize).join
    end.join("::")
  end

  # ====================
  # PHASE 2: UPDATE MODULE DECLARATIONS IN-PLACE
  # ====================

  def phase_2_update_modules_in_place
    log_phase("🔄 Updating module declarations in-place (Zeitwerk compatibility)...")

    files_to_update = Dir.glob("lib/kumi/**/*.rb").reject do |file|
      file.include?("/core/") ||
        ["cli.rb", "version.rb", "schema.rb"].any? { |skip| file.end_with?(skip) }
    end

    log_phase("   Processing #{files_to_update.length} files...")

    files_updated = 0
    files_to_update.each_with_index do |file, index|
      files_updated += 1 if update_file_module_declaration(file)
    end

    @stats[:files_updated] = files_updated
    log_phase("✅ Updated #{files_updated} files: Kumi:: → Kumi::Core::")

    # Critical test - ensure Zeitwerk can load updated modules
    log_phase("🧪 Testing Zeitwerk compatibility...")
    run_basic_tests("Phase 2 - Zeitwerk compatibility check")
    log_phase("✅ Zeitwerk autoloading working correctly")
  end

  def update_file_module_declaration(file)
    content = File.read(file)
    original_content = content.dup

    # Pattern 1: Simple "module Kumi" -> "module Kumi::Core"
    content.gsub!(/^(\s*)module Kumi(\s*$)/) { "#{::Regexp.last_match(1)}module Kumi::Core#{::Regexp.last_match(2)}" }
    content.gsub!(/^(\s*)module Kumi(\s*#.*)$/) { "#{::Regexp.last_match(1)}module Kumi::Core#{::Regexp.last_match(2)}" }

    # Pattern 2: Nested modules "module Kumi::Something" -> "module Kumi::Core::Something"
    content.gsub!(/^(\s*)module Kumi::([A-Z]\w*)/) { "#{::Regexp.last_match(1)}module Kumi::Core::#{::Regexp.last_match(2)}" }

    # INLINE VALIDATION: Fix common issues while reading
    content = apply_inline_fixes(content, file, :namespace_update)

    if content != original_content
      track_file_changes(file, original_content, content, :in_place_module_update)
      File.write(file, content)
      return true
    end

    false
  end

  # ====================
  # PHASE 3: MOVE FILES TO CORE
  # ====================

  def phase_3_move_files_to_core
    log_phase("Moving files to core directory...")

    files_to_move = analyze_files_to_migrate
    moved_count = 0

    files_to_move.each do |file|
      moved_count += 1 if move_file_to_core_with_git(file)
    end

    # Clean up empty directories
    clean_empty_directories

    log_phase("Moved #{moved_count} files to core")

    # CRITICAL: Re-apply module declarations to moved files
    # (git mv preserves original content, so we need to re-update the modules)
    log_phase("🔄 Re-applying module declarations to moved files...")
    reapply_module_declarations_to_core_files

    # Test that Zeitwerk can find all the moved modules
    run_basic_tests("Phase 3 - After file moves")

    @stats[:files_moved] = moved_count
  end

  def move_file_to_core_with_git(file)
    relative_path = file.sub("lib/kumi/", "")
    new_path = "lib/kumi/core/#{relative_path}"

    # Create directory if needed
    FileUtils.mkdir_p(File.dirname(new_path))

    # Use git mv to preserve history
    result = system("git mv '#{file}' '#{new_path}' 2>/dev/null")
    if result
      log_phase("  Moved #{file} -> #{new_path}")
      true
    else
      record_error("Failed to move #{file} to #{new_path}")
      false
    end
  end

  def reapply_module_declarations_to_core_files
    core_files = Dir.glob("lib/kumi/core/**/*.rb")
    updated_count = 0

    core_files.each do |file|
      updated_count += 1 if update_file_module_declaration(file)
    end

    log_phase("  ✅ Re-applied module declarations to #{updated_count} core files")
  end

  def clean_empty_directories
    Dir.glob("lib/kumi/*/").each do |dir|
      next if dir.include?("/core/")

      if Dir.empty?(dir)
        Dir.rmdir(dir)
        log_phase("  Removed empty directory #{dir}")
      end
    end
  end

  # ====================
  # PHASE 4: UPDATE EXTERNAL REFERENCES
  # ====================

  def phase_4_update_references
    log_phase("Updating external references...")

    # Update public interface files
    update_public_interface_files

    # Update spec files
    update_spec_files

    # Update other files (examples, scripts, etc.)
    update_other_files

    # Test that all references work
    run_basic_tests("Phase 4 - After reference updates")
  end

  def update_public_interface_files
    log_phase("  Updating public interface files...")

    core_modules = %w[
      Analyzer Compiler Types Syntax Export Input Domain RubyParser
      Kumi::Registry.SchemaInstance SchemaMetadata Explain CompiledSchema
      EvaluationWrapper ErrorReporter ErrorReporting VectorizationMetadata
      JsonSchema AtomUnsatSolver ConstraintRelationshipSolver
    ]

    ["lib/kumi/schema.rb", "lib/kumi.rb"].each do |file|
      next unless File.exist?(file)

      update_file_references(file, core_modules, :public_interface_update)
    end
  end

  def update_spec_files
    log_phase("  Updating spec files...")

    spec_files = Dir.glob("{spec,test}/**/*.rb")
    spec_files.each { |file| update_spec_file_references(file) }
  end

  def update_other_files
    log_phase("  Updating other files...")

    other_files = Dir.glob("{examples,docs,scripts}/**/*.rb")
    other_files.each { |file| update_spec_file_references(file) if File.exist?(file) }
  end

  def update_file_references(file, core_modules, change_type)
    content = File.read(file)
    original_content = content.dup

    core_modules.each do |mod|
      content.gsub!(/\b#{mod}\./) { "Core::#{mod}." }
      content.gsub!(/\b#{mod}::/) { "Core::#{mod}::" }
      content.gsub!(/(\W)#{mod}(\s*\.)/) { "#{::Regexp.last_match(1)}Core::#{mod}#{::Regexp.last_match(2)}" }
    end

    # INLINE VALIDATION: Apply additional fixes
    content = apply_inline_fixes(content, file, :reference_update)

    return unless content != original_content

    track_file_changes(file, original_content, content, change_type)
    File.write(file, content)
  end

  def update_spec_file_references(file)
    content = File.read(file)
    original_content = content.dup

    core_modules = %w[
      Analyzer Compiler Types Syntax Export Input Domain RubyParser
      Kumi::Registry.SchemaInstance SchemaMetadata Explain CompiledSchema
      EvaluationWrapper ErrorReporter ErrorReporting VectorizationMetadata
      JsonSchema AtomUnsatSolver ConstraintRelationshipSolver
    ]

    core_modules.each do |mod|
      # Apply Core prefix, but skip VERSION patterns
      content.gsub!(/\bKumi::#{mod}(?!::[A-Z][a-zA-Z0-9]*::VERSION\b|::VERSION\b)/) { "Kumi::Core::#{mod}" }
    end

    # Special cases
    content.gsub!("include Kumi::Syntax", "include Kumi::Core::Syntax")
    content.gsub!("include Kumi::ErrorReporting", "include Kumi::Core::ErrorReporting")

    core_modules.each do |mod|
      content.gsub!(/^(\s*)#{mod}\./) { "#{::Regexp.last_match(1)}Kumi::Core::#{mod}." }
    end

    # INLINE VALIDATION: Apply additional fixes
    content = apply_inline_fixes(content, file, :spec_update)

    return unless content != original_content

    track_file_changes(file, original_content, content, :spec_reference_update)
    File.write(file, content)
  end

  # ====================
  # PHASE 5: FINAL VALIDATION
  # ====================

  def phase_5_final_validation
    log_phase("Running comprehensive validation...")

    # Test 1: Basic loading
    run_basic_tests("Final - Basic loading")

    # Test 2: Core module structure
    test_core_module_structure

    # Test 3: Final cleanup pass for Errors references
    fix_remaining_errors_references

    # Test 4: Full test suite (after cleanup)
    run_full_test_suite

    # Analyze change statistics
    analyze_final_statistics
  end

  def test_core_module_structure
    log_phase("  Testing core module structure...")

    test_script = <<~RUBY
      require "./lib/kumi"

      # Test that Core module exists
      raise "Kumi::Core not defined" unless defined?(Kumi::Core)

      # Test a few key modules
      core_modules = %w[Analyzer Compiler Syntax]
      core_modules.each do |mod|
        const_name = "Kumi::Core::\#{mod}"
        raise "\#{const_name} not available" unless Object.const_defined?(const_name)
      end

      puts "✅ Core module structure validated"
    RUBY

    result = system("ruby -e '#{test_script}' 2>/dev/null")
    return if result

    record_error("Core module structure validation failed")
    raise "Core module structure is invalid"
  end

  def fix_remaining_errors_references
    log_phase("  Final cleanup pass for VERSION references...")

    fixed_count = 0

    # Find all files that might have incorrect VERSION references
    files_to_check = Dir.glob("lib/**/*.rb") + Dir.glob("spec/**/*.rb") + Dir.glob("examples/**/*.rb")

    files_to_check.each do |file|
      content = File.read(file)
      original_content = content.dup

      # Only fix VERSION references like Kumi::Core::Export::Serializer::VERSION -> Kumi::VERSION
      content.gsub!(/Kumi::Core::[A-Z]\w*(?:::[A-Z]\w*)*::VERSION\b/, "Kumi::VERSION")

      if content != original_content
        File.write(file, content)
        fixed_count += 1
      end
    end

    if fixed_count > 0
      log_phase("  🔧 Fixed VERSION references in #{fixed_count} files")
    else
      log_phase("  ✅ No incorrect VERSION references found")
    end
  end

  def run_full_test_suite
    log_phase("🧪 Running full test suite...")

    stdout, stderr, status = Open3.capture3("bundle exec rspec")

    if status.success?
      # Extract test summary from output
      summary_line = stdout.lines.find { |line| line.include?("examples") && line.include?("failures") }
      log_phase("   ✅ Full test suite passed!")
      log_phase("   📊 #{summary_line.chomp}") if summary_line
    else
      log_phase("   ❌ Full test suite FAILED", :error)

      # Analyze uninitialized constant errors before writing logs
      test_output = stderr.empty? ? stdout : stderr
      analyze_uninitialized_constant_errors(test_output)

      # Write failed test logs to test_rspec.logs
      File.write("test_rspec.logs", test_output)
      log_phase("   📝 Test failure logs written to test_rspec.logs")

      record_error("Full test suite failed")
      raise "Full test suite failed"
    end
  end

  def analyze_uninitialized_constant_errors(test_output)
    log_phase("   🔍 Analyzing uninitialized constant errors...")

    # Extract all uninitialized constant errors
    constant_errors = []
    test_output.lines.each do |line|
      if line.match?(/NameError.*uninitialized constant ([A-Z][a-zA-Z0-9:]*[A-Z][a-zA-Z0-9]*)/)
        constant = line.match(/NameError.*uninitialized constant ([A-Z][a-zA-Z0-9:]*[A-Z][a-zA-Z0-9]*)/)[1]
        constant_errors << constant
      end
    end

    if constant_errors.any?
      unique_errors = constant_errors.uniq.sort
      log_phase("   📋 Found #{constant_errors.length} uninitialized constant errors (#{unique_errors.length} unique):")
      unique_errors.each do |const|
        count = constant_errors.count(const)
        log_phase("     #{count}x #{const}")
      end
    else
      log_phase("   ✅ No uninitialized constant errors found")
    end
  end

  def analyze_final_statistics
    return if @change_tracker.empty?

    @stats[:total_changes] = @change_tracker.values.sum { |stats| stats[:total_changes] }
    total_files = @change_tracker.length

    log_phase("📊 Change Statistics:")
    log_phase("   Files modified: #{total_files}")
    log_phase("   Total changes: #{@stats[:total_changes]}")

    # Show files with high change counts
    flagged_files = []
    @change_tracker.each do |file, stats|
      total = stats[:total_changes]

      if total >= @change_thresholds[:suspicious]
        flagged_files << { file: file, count: total, level: :suspicious }
      elsif total >= @change_thresholds[:critical]
        flagged_files << { file: file, count: total, level: :critical }
      elsif total >= @change_thresholds[:warning]
        flagged_files << { file: file, count: total, level: :warning }
      end
    end

    return unless flagged_files.any?

    log_phase("🚨 #{flagged_files.length} files need review:")
    flagged_files.each { |f| log_phase("   #{f[:file]} (#{f[:count]} changes)") }
  end

  def run_cleanup_validation
    log_phase("🔍 Running cleanup validation...")

    issues_found = 0

    # Check for double Core:: patterns
    issues_found += fix_double_core_patterns

    # Check for missing Core:: in moved files
    issues_found += fix_missing_core_references

    if issues_found > 0
      log_phase("🔧 Fixed #{issues_found} reference issues automatically")

      # Re-test basic loading after fixes
      run_basic_tests("Post-cleanup validation")
    else
      log_phase("✅ No cleanup issues found")
    end
  end

  def fix_double_core_patterns
    log_phase("  Checking for double Core:: patterns...")
    fixes = 0

    # Fix module declarations: Kumi::Core::Core -> Kumi::Core
    Dir.glob("lib/kumi/core/**/*.rb").each do |file|
      content = File.read(file)
      original_content = content.dup

      # Fix double Core in module declarations
      content.gsub!("module Kumi::Core::Core", "module Kumi::Core")

      # Fix double Core in references
      content.gsub!("Kumi::Core::Core::", "Kumi::Core::")
      content.gsub!("Core::Core::", "Core::")

      next unless content != original_content

      File.write(file, content)
      fixes += 1
    end

    # Also check public interface files
    ["lib/kumi/schema.rb"].each do |file|
      next unless File.exist?(file)

      content = File.read(file)
      original_content = content.dup

      content.gsub!("Core::Core::", "Core::")

      next unless content != original_content

      File.write(file, content)
      fixes += 1
    end

    fixes
  end

  def fix_missing_core_references
    log_phase("  Checking for missing Core:: references in moved files...")
    fixes = 0

    # Pattern: files in core/ should reference other core modules with Core::
    Dir.glob("lib/kumi/core/**/*.rb").each do |file|
      content = File.read(file)
      original_content = content.dup

      # Core modules that moved and need Core:: prefix when referenced
      core_modules = %w[
        Types Syntax Export Input Domain FunctionRegistry
        SchemaInstance SchemaMetadata Explain CompiledSchema
        EvaluationWrapper ErrorReporter ErrorReporting VectorizationMetadata
        JsonSchema AtomUnsatSolver ConstraintRelationshipSolver
      ]

      # Fix bare Kumi::ModuleName references (but not Kumi::Core::)
      core_modules.each do |mod|
        # Only fix if it's clearly a reference to a moved module
        content.gsub!(/\bKumi::#{mod}(?!::)/, "Kumi::Core::#{mod}")
      end

      # Fix string literal references (in eval, using statements, etc.)
      content.gsub!(/"using Kumi::([A-Z]\w+(?:::[A-Z]\w+)*)"/) do |match|
        module_path = ::Regexp.last_match(1)
        "\"using Kumi::Core::#{module_path}\""
      end

      # Fix other Kumi:: references in string literals
      content.gsub!(/(['"])([^'"]*?)Kumi::([A-Z]\w+(?:::[A-Z]\w+)*)([^'"]*?)\1/) do |match|
        quote = ::Regexp.last_match(1)
        prefix = ::Regexp.last_match(2)
        module_path = ::Regexp.last_match(3)
        suffix = ::Regexp.last_match(4)
        "#{quote}#{prefix}Kumi::Core::#{module_path}#{suffix}#{quote}"
      end

      next unless content != original_content

      File.write(file, content)
      fixes += 1
    end

    fixes
  end

  def log_completion_summary
    duration = Time.now - @start_time

    log_phase("=" * 60)
    log_phase("🎉 MIGRATION COMPLETED SUCCESSFULLY!")
    log_phase("=" * 60)
    log_phase("📈 Summary:")
    log_phase("   Files migrated: #{@stats[:files_to_migrate]}")
    log_phase("   Files moved: #{@stats[:files_moved]}")
    log_phase("   Total changes: #{@stats[:total_changes]}")
    log_phase("   Duration: #{duration.round(2)}s")
    log_phase("   Phases completed: #{@phases.count { |p| p[:status] == :success }}/#{@phases.length}")
  end

  def handle_failure(error)
    log_phase("🔄 Handling migration failure...")

    # Show failure summary
    log_phase("=" * 60)
    log_phase("❌ MIGRATION FAILED")
    log_phase("=" * 60)
    log_phase("💥 Error: #{error.message}")

    return unless @phases.any?

    log_phase("📋 Phase Status:")
    @phases.each do |phase|
      status_icon = phase[:status] == :success ? "✅" : "❌"
      log_phase("   #{status_icon} #{phase[:name]}")
    end
  rescue StandardError => e
    log_phase("⚠️  Error during failure handling: #{e.message}", :error)
    @errors << "Error during failure handling: #{e.message}"
  end

  def restore_to_initial_state
    log_phase("🔄 Restoring to initial state...")

    # Stash the migration script to avoid restoring it
    script_name = File.basename(__FILE__)
    if File.exist?(script_name)
      system("cp #{script_name} #{script_name}.backup")
      log_phase("📋 Backed up migration script")
    end

    return
    # Find the initial commit from the first rollback point
    if @rollback_points.any?
      initial_commit = @rollback_points.first[:commit]
      log_phase("📍 Rolling back to initial commit #{initial_commit[0..7]}...")
      result = system("git reset --hard #{initial_commit}")
      if result
        log_phase("✅ Repository restored to initial state")

        # Restore the migration script
        if File.exist?("#{script_name}.backup")
          system("mv #{script_name}.backup #{script_name}")
          log_phase("📋 Restored migration script")
        end
      else
        log_phase("❌ Failed to restore to initial state", :error)
      end
    else
      log_phase("⚠️  No initial commit stored - cannot restore")
    end
  end

  # ====================
  # INLINE VALIDATION
  # ====================

  def apply_inline_fixes(content, file_path, context = :general)
    original_content = content.dup

    # Fix 1: Double Core:: patterns
    content.gsub!("module Kumi::Core::Core", "module Kumi::Core")
    content.gsub!("Kumi::Core::Core::", "Kumi::Core::")
    content.gsub!("Core::Core::", "Core::")

    # Fix 2: For files in the core directory, be more selective about what gets the Core:: prefix
    if file_path.include?("/core/")
      # Only apply Core:: to modules that are actually in Core
      core_modules = %w[
        Analyzer Compiler Types Syntax Export Input Domain RubyParser
        Kumi::Registry.SchemaInstance SchemaMetadata Explain CompiledSchema
        EvaluationWrapper ErrorReporter ErrorReporting VectorizationMetadata
        JsonSchema AtomUnsatSolver ConstraintRelationshipSolver
      ]

      # Fix references to other core modules
      core_modules.each do |mod|
        # Replace Kumi::ModuleName with Core prefix, but skip VERSION references
        content.gsub!(/\bKumi::#{mod}(?!::[A-Z][a-zA-Z0-9]*::VERSION\b|::VERSION\b)/) { "Kumi::Core::#{mod}" }
      end
    else
      # For non-core files, apply broader fixes but exclude only top-level non-core modules
      content.gsub!(/(?<!module\s)(?<!class\s)(?<!struct\s)\bKumi::([A-Z][a-zA-Z0-9]*(?:::[A-Z][a-zA-Z0-9]*)*)/) do |match|
        module_path = ::Regexp.last_match(1)
        # Skip if already has Core:: or if it's a root-level non-core module
        first_part = module_path.split("::").first
        if module_path.start_with?("Core::") ||
           %w[Schema CLI VERSION].include?(first_part)
          match
        else
          "Kumi::Core::#{module_path}"
        end
      end
    end

    # Fix 3: String literal references - be selective here too
    content.gsub!(/"using Kumi::([A-Z]\w+(?:::[A-Z]\w+)*)"/) do |match|
      module_path = ::Regexp.last_match(1)
      # Don't move top-level non-core modules
      if module_path.start_with?("Core::") || %w[Schema CLI VERSION].include?(module_path.split("::").first)
        "\"using Kumi::#{module_path}\""
      else
        "\"using Kumi::Core::#{module_path}\""
      end
    end

    content
  end

  def count_line_differences(original, updated)
    original_lines = original.lines
    updated_lines = updated.lines

    differences = 0
    max_lines = [original_lines.length, updated_lines.length].max

    (0...max_lines).each do |i|
      orig_line = original_lines[i]&.strip
      new_line = updated_lines[i]&.strip
      differences += 1 if orig_line != new_line
    end

    differences
  end

  # ====================
  # UTILITIES
  # ====================

  def run_basic_tests(context)
    log_phase("🧪 Running basic tests (#{context})...")

    test_script = 'require "./lib/kumi"; puts "✅ Basic load successful"'
    stdout, stderr, status = Open3.capture3("ruby -e '#{test_script}'")

    if status.success?
      log_phase("   ✅ Basic loading test passed")
    else
      log_phase("   ❌ Basic loading test FAILED", :error)
      log_test_error("Basic Load Test", stderr, stdout)
      record_error("Basic test failed in #{context}")
      raise "Basic test failed in #{context}"
    end
  end

  def log_test_error(test_name, stderr, stdout)
    log_phase("🚨 #{test_name} Error Details:", :error)

    if stderr && !stderr.empty?
      # Clean and extract key error information
      error_lines = stderr.lines.first(5)
      error_lines.each do |line|
        cleaned_line = clean_path_from_error(line.chomp)
        log_phase("   #{cleaned_line}", :error)
      end
    end

    return unless stdout && !stdout.empty? && stdout != stderr

    cleaned_output = clean_path_from_error(stdout.chomp)
    log_phase("   Output: #{cleaned_output}")
  end

  def clean_path_from_error(message)
    # Remove the current working directory from paths to make them relative
    current_dir = Dir.pwd
    message.gsub(current_dir + "/", "")
           .gsub(current_dir, ".")
  end

  def track_file_changes(file_path, original_content, new_content, change_type)
    return 0 if original_content == new_content

    @change_tracker[file_path] ||= {
      total_changes: 0,
      change_types: Hash.new(0),
      phases: []
    }

    # Simple line-diff count
    original_lines = original_content.lines
    new_lines = new_content.lines

    changes_count = 0
    max_lines = [original_lines.length, new_lines.length].max
    (0...max_lines).each do |i|
      orig_line = original_lines[i]&.strip
      new_line = new_lines[i]&.strip
      changes_count += 1 if orig_line != new_line
    end

    @change_tracker[file_path][:total_changes] += changes_count
    @change_tracker[file_path][:change_types][change_type] += changes_count
    @change_tracker[file_path][:phases] << {
      phase: @current_phase,
      type: change_type,
      count: changes_count,
      timestamp: Time.now
    }

    changes_count
  end

  def flag_file(file, change_count, severity)
    icon = case severity
           when :warning then "⚠️"
           when :critical then "🚨"
           when :suspicious then "🔴"
           end

    log_phase("#{icon} #{file}: #{change_count} changes (#{severity})", severity)
  end

  def finalize_migration
    log_phase("Finalizing migration...")

    system("git add -A")
    commit_msg = "Complete Kumi to Kumi::Core migration\n\n" \
                 "Iterative migration completed successfully:\n" \
                 "- #{@metadata[:files_to_migrate]} files migrated\n" \
                 "- All tests passing\n" \
                 "- Zeitwerk autoloading working correctly"

    system("git commit -m '#{commit_msg}'")

    final_commit = `git rev-parse HEAD`.strip
    @metadata[:final_commit] = final_commit
    @metadata[:final_status] = :success

    log_phase("Migration committed as #{final_commit[0..7]}")
  end

  def record_error(message)
    @errors << {
      timestamp: Time.now,
      message: message,
      phase: @current_phase
    }
  end

  def save_migration_metadata
    @metadata[:end_time] = Time.now
    @metadata[:duration] = @metadata[:end_time] - @metadata[:start_time]
    @metadata[:errors] = @errors
    @metadata[:change_statistics] = @change_tracker

    File.write("migration_metadata_iterative.json", JSON.pretty_generate(@metadata))
    log_phase("Migration metadata saved")
  end
end

# Run migration if script is executed directly
if __FILE__ == $0
  begin
    migrator = IterativeKumiCoreMigrator.new
    migrator.migrate!

    # Success summary already logged by log_completion_summary
  rescue StandardError => e
    # Error details already logged by handle_failure
    exit 1
  end
end
