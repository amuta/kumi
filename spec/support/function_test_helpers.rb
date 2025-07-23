# frozen_string_literal: true

RSpec.shared_examples "a function with correct metadata" do |name, expected_arity, expected_param_types, expected_return_type|
  it "has correct signature for #{name}" do
    signature = Kumi::FunctionRegistry.signature(name)
    expect(signature[:arity]).to eq(expected_arity)
    expect(signature[:param_types]).to eq(expected_param_types)
    expect(signature[:return_type]).to eq(expected_return_type)
    expect(signature[:description]).to be_a(String)
  end

  it "is supported" do
    expect(Kumi::FunctionRegistry.supported?(name)).to be true
  end

  it "can be fetched" do
    fn = Kumi::FunctionRegistry.fetch(name)
    expect(fn).to respond_to(:call)
  end
end

RSpec.shared_examples "a working function" do |name, test_args, expected_result|
  it "#{name} works correctly with args #{test_args.inspect}" do
    fn = Kumi::FunctionRegistry.fetch(name)
    result = fn.call(*test_args)
    expect(result).to eq(expected_result)
  end
end
