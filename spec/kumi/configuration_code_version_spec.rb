# frozen_string_literal: true

require "spec_helper"

# The compiler cache key folds in a `code_version` fingerprint so that editing
# the compiler invalidates stale generated code even when the schema digest is
# unchanged. Without it, recompiling after a compiler change silently reused old
# generated code from the cache dir — a debugging trap.
RSpec.describe Kumi::Configuration, "#code_version" do
  subject(:config) { described_class.new }

  it "is a non-empty string derived from the gem version" do
    expect(config.code_version).to be_a(String)
    expect(config.code_version).to include(Kumi::VERSION)
  end

  it "memoizes (cheap on repeated reads)" do
    expect(config.code_version).to equal(config.code_version)
  end

  it "honours an explicit override" do
    config.code_version = "pinned-123"
    expect(config.code_version).to eq("pinned-123")
  end

  it "honours KUMI_CODE_VERSION from the environment" do
    original = ENV.fetch("KUMI_CODE_VERSION", nil)
    ENV["KUMI_CODE_VERSION"] = "from-env"
    expect(described_class.new.code_version).to eq("from-env")
  ensure
    if original.nil?
      ENV.delete("KUMI_CODE_VERSION")
    else
      ENV["KUMI_CODE_VERSION"] = original
    end
  end
end
