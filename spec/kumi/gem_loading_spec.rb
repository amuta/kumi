# frozen_string_literal: true

require "fileutils"
require "rbconfig"
require "tmpdir"

RSpec.describe "loading Kumi as an installed gem" do
  def run_unbundled(env, *command, chdir:)
    Bundler.with_unbundled_env do
      Open3.capture3(env, *command, chdir: chdir)
    end
  end

  def expect_success(status, stdout, stderr)
    expect(status).to be_success, "#{stdout}\n#{stderr}"
  end

  def build_gem(repo_root, dir)
    gem_file = File.join(dir, "kumi-#{Kumi::VERSION}.gem")
    stdout, stderr, status = run_unbundled(
      {},
      RbConfig.ruby, "-S", "gem", "build", "kumi.gemspec", "--output", gem_file,
      chdir: repo_root
    )
    expect_success(status, stdout, stderr)
    gem_file
  end

  def install_gem(gem_file, dir)
    gem_home = File.join(dir, "gem_home")
    gem_path = ([gem_home] + Gem.path).join(File::PATH_SEPARATOR)
    gem_env = {
      "BUNDLE_BIN_PATH" => nil,
      "BUNDLE_GEMFILE" => nil,
      "GEM_HOME" => gem_home,
      "GEM_PATH" => gem_path,
      "RUBYLIB" => nil,
      "RUBYOPT" => nil
    }

    stdout, stderr, status = run_unbundled(
      gem_env,
      RbConfig.ruby, "-S", "gem", "install", "--local", gem_file, "--no-document", "--ignore-dependencies",
      chdir: dir
    )
    expect_success(status, stdout, stderr)
    gem_env
  end

  def installed_gem_root(gem_env, dir)
    script = "puts Gem::Specification.find_by_name('kumi', '= #{Kumi::VERSION}').full_gem_path"
    stdout, stderr, status = run_unbundled(gem_env, RbConfig.ruby, "-e", script, chdir: dir)
    expect_success(status, stdout, stderr)
    stdout.strip
  end

  def assert_external_load(gem_env, dir)
    load_script = <<~RUBY
      require "kumi"
      raise "top-level AUTOLOADER leaked" if Object.const_defined?(:AUTOLOADER, false)
      raise "missing Kumi::AUTOLOADER" unless Kumi.const_defined?(:AUTOLOADER, false)
      raise "wrong version: \#{Kumi::VERSION}" unless Kumi::VERSION == ENV.fetch("EXPECTED_KUMI_VERSION")

      puts Kumi::VERSION
    RUBY

    stdout, stderr, status = run_unbundled(
      gem_env.merge("EXPECTED_KUMI_VERSION" => Kumi::VERSION),
      RbConfig.ruby, "-e", load_script,
      chdir: dir
    )
    expect_success(status, stdout, stderr)
    expect(stdout).to include(Kumi::VERSION)
  end

  it "does not require golden-test support files at runtime" do
    repo_root = File.expand_path("../..", __dir__)

    Dir.mktmpdir("kumi-gem-load") do |dir|
      gem_env = install_gem(build_gem(repo_root, dir), dir)
      gem_root = installed_gem_root(gem_env, dir)
      FileUtils.rm_f(File.join(gem_root, "lib/kumi/dev/golden_schema_modules.rb"))
      assert_external_load(gem_env, dir)
    end
  end
end
