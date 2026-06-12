# frozen_string_literal: true

RSpec.describe "analyzer pipeline contracts" do
  let(:pipeline) do
    Kumi::Analyzer::DEFAULT_PASSES +
      Kumi::Analyzer::LOWERING_PASSES +
      Kumi::Analyzer::TARGET_PASSES
  end

  let(:initial_keys) { %i[registry schema_digest] }

  it "declares a contract on every pipeline pass" do
    undeclared = pipeline.reject(&:contract_declared?)
    expect(undeclared).to be_empty, "passes without contracts: #{undeclared.map(&:name).inspect}"
  end

  it "names every pipeline pass with a Pass suffix" do
    badly_named = pipeline.reject { |pass| pass.name.split("::").last.end_with?("Pass") }
    expect(badly_named).to be_empty, "passes without Pass suffix: #{badly_named.map(&:name).inspect}"
  end

  it "orders passes so every required read has an earlier producer" do
    available = initial_keys.dup
    pipeline.each do |pass|
      missing = pass.declared_reads - available
      expect(missing).to be_empty, "#{pass.name} reads #{missing.inspect} before any earlier pass writes it"
      available.concat(pass.declared_writes)
    end
  end
end
