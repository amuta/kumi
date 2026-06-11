# frozen_string_literal: true

require "date"
require "fileutils"

module KumiReleaseTasks
  VERSION_FILE = "lib/kumi/version.rb"
  CHANGELOG_FILE = "CHANGELOG.md"
  VERSION_PATTERN = /\A\d+\.\d+\.\d+(?:[.-][0-9A-Za-z.-]+)?\z/

  module_function

  def requested_version
    ENV.fetch("VERSION") do
      abort "Missing VERSION. Example: bundle exec rake release:prepare VERSION=0.0.35"
    end
  end

  def validate_version!(version)
    return if version.match?(VERSION_PATTERN)

    abort "Invalid VERSION=#{version.inspect}; expected semantic version like 0.0.35"
  end

  def current_version
    File.read(VERSION_FILE).match(/VERSION = "([^"]+)"/)&.[](1) ||
      abort("Could not read current version from #{VERSION_FILE}")
  end

  def ensure_requested_version_matches_current!(version)
    return if current_version == version

    abort "VERSION=#{version} does not match #{VERSION_FILE} (#{current_version}). Run release:prepare first."
  end

  def ensure_release_files_match!(version)
    changelog = File.read(CHANGELOG_FILE)
    lockfile = File.read("Gemfile.lock")
    abort "#{CHANGELOG_FILE} does not contain ## [#{version}]. Run release:prepare first." unless changelog.include?("## [#{version}]")
    abort "Gemfile.lock does not contain kumi (#{version}). Run release:prepare first." unless lockfile.include?("kumi (#{version})")
  end

  def ensure_clean_git!
    return if ENV["ALLOW_DIRTY"] == "1"

    status = `git status --porcelain`
    return if status.empty?

    abort "Worktree is not clean. Commit release changes first, or set ALLOW_DIRTY=1."
  end

  def run!(*command)
    puts "$ #{command.join(' ')}"
    system(*command) || abort("Command failed: #{command.join(' ')}")
  end

  def update_version_file(version)
    content = File.read(VERSION_FILE)
    updated = content.sub(/VERSION = "[^"]+"/, %(VERSION = "#{version}"))
    File.write(VERSION_FILE, updated)
  end

  def update_changelog(version, date: Date.today.iso8601)
    content = File.read(CHANGELOG_FILE)
    abort "#{CHANGELOG_FILE} already contains a #{version} section" if content.include?("## [#{version}]")

    match =
      content.match(/\A## \[Unreleased\]\n(?<body>.*?)(?=\n## \[|\z)/m) ||
      abort("Could not find top-level ## [Unreleased] section in #{CHANGELOG_FILE}")
    body = match[:body].strip
    abort "Refusing to release with an empty Unreleased changelog" if body.empty? && ENV["ALLOW_EMPTY_CHANGELOG"] != "1"

    release_section = "## [#{version}] – #{date}\n#{body}\n"
    updated = content.sub(match[0], "## [Unreleased]\n\n#{release_section}")
    File.write(CHANGELOG_FILE, updated)
  end

  def gem_path(version)
    File.join("pkg", "kumi-#{version}.gem")
  end

  def build_gem(version)
    FileUtils.mkdir_p("pkg")
    FileUtils.rm_f(gem_path(version))
    run!("gem", "build", "kumi.gemspec", "--output", gem_path(version))
  end
end

namespace :release do # rubocop:disable Metrics/BlockLength
  desc "Update version, changelog, and Gemfile.lock. Usage: rake release:prepare VERSION=0.0.35"
  task :prepare do
    version = KumiReleaseTasks.requested_version
    KumiReleaseTasks.validate_version!(version)
    KumiReleaseTasks.update_version_file(version)
    KumiReleaseTasks.update_changelog(version)
    KumiReleaseTasks.run!("bundle", "lock", "--local")
    puts "Prepared Kumi #{version}. Review #{KumiReleaseTasks::CHANGELOG_FILE} before publishing."
  end

  desc "Run release checks: specs and gem build. Use STRICT=1 to include full RuboCop."
  task verify: :spec do
    version = KumiReleaseTasks.current_version
    if ENV["STRICT"] == "1"
      Rake::Task[:rubocop].invoke
    else
      puts "Skipping full RuboCop during release verification. Set STRICT=1 to include it."
    end
    KumiReleaseTasks.build_gem(version)
    puts "Verified Kumi #{version}."
  end

  desc "Build and install the current gem locally"
  task install: :verify do
    version = KumiReleaseTasks.current_version
    KumiReleaseTasks.run!("gem", "install", KumiReleaseTasks.gem_path(version), "--no-document")
  end

  desc "Push the verified gem to RubyGems. Usage: rake release:publish VERSION=0.0.35"
  task :publish do
    version = KumiReleaseTasks.requested_version
    KumiReleaseTasks.validate_version!(version)
    KumiReleaseTasks.ensure_requested_version_matches_current!(version)
    KumiReleaseTasks.ensure_release_files_match!(version)
    KumiReleaseTasks.ensure_clean_git!
    Rake::Task["release:verify"].invoke
    KumiReleaseTasks.run!("gem", "push", KumiReleaseTasks.gem_path(version))
    puts "Published Kumi #{version} to RubyGems."
  end
end
