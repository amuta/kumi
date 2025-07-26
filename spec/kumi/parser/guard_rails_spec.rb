# frozen_string_literal: true

RSpec.describe "DSL Guard Rails" do
  def build_schema(&block)
    Kumi::Parser::Parser.new.parse(&block)
  end

  it "rejects unknown keywords" do
    expect { build_schema { foobar :x } }
      .to raise_error(NoMethodError, /unknown DSL keyword `foobar`/)
  end

  it "blocks proxy mutation" do
    expect do
      build_schema { def sneaky; end }
    end.to raise_error(FrozenError)
  end

  it "detects constant leakage" do
    expect do
      build_schema { Object.const_set(:Evil, 1) }
    end.to raise_error(Kumi::Errors::SemanticError, /Evil/)
    Object.send(:remove_const, :Evil) if Object.const_defined?(:Evil)
  end

  it "fails when someone redefines a reserved keyword" do
    # Save original method to restore it after the test
    original_value_method = Kumi::Parser::SchemaBuilder.instance_method(:value)

    begin
      expect do
        module Kumi
          module Parser
            class SchemaBuilder
              # shadow!
              def value(*); end
            end
          end
        end
      end.to raise_error(Kumi::Errors::SemanticError, /reserved/)
    ensure
      # Restore the original method because even that the GuardRails raise an error
      # the method is still redefined in the class.
      begin
        Kumi::Parser::SchemaBuilder.define_method(:value, original_value_method)
      rescue StandardError
      end
    end
  end
end
