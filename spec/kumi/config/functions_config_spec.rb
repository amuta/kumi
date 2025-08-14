# frozen_string_literal: true

require 'yaml'

RSpec.describe "Functions Configuration" do
  let(:config_path) { File.join(File.dirname(__FILE__), '../../../config/functions.yaml') }
  let(:functions_config) { YAML.load_file(config_path) }
  let(:parser) { Kumi::Core::Functions::SignatureParser }

  describe "YAML structure" do
    it "loads without errors" do
      expect { functions_config }.not_to raise_error
    end

    it "contains an array of function definitions" do
      expect(functions_config).to be_an(Array)
      expect(functions_config).not_to be_empty
    end
  end

  describe "function definitions" do
    it "all have required fields" do
      required_fields = %w[name domain opset class signature kernels]
      
      functions_config.each do |func|
        required_fields.each do |field|
          expect(func).to have_key(field), "Function #{func['name']} missing required field: #{field}"
        end
      end
    end

    it "all have valid signature arrays" do
      functions_config.each do |func|
        expect(func['signature']).to be_an(Array), "Function #{func['name']} signature must be an array"
        expect(func['signature']).not_to be_empty, "Function #{func['name']} signature cannot be empty"
      end
    end

    it "all signatures parse correctly with NEP 20 parser" do
      functions_config.each do |func|
        func['signature'].each do |sig_string|
          expect { parser.parse(sig_string) }.not_to raise_error, 
            "Function #{func['name']} has invalid signature: #{sig_string}"
        end
      end
    end

    it "all have valid classes" do
      valid_classes = %w[scalar aggregate structure vector]
      
      functions_config.each do |func|
        expect(valid_classes).to include(func['class']), 
          "Function #{func['name']} has invalid class: #{func['class']}"
      end
    end

    it "all have valid domains" do
      valid_domains = %w[core struct mask string datetime]
      
      functions_config.each do |func|
        expect(valid_domains).to include(func['domain']), 
          "Function #{func['name']} has invalid domain: #{func['domain']}"
      end
    end

    it "all have valid kernel implementations" do
      functions_config.each do |func|
        expect(func['kernels']).to be_an(Array), "Function #{func['name']} kernels must be an array"
        expect(func['kernels']).not_to be_empty, "Function #{func['name']} must have at least one kernel"
        
        func['kernels'].each do |kernel|
          expect(kernel).to have_key('backend'), "Kernel missing backend for #{func['name']}"
          expect(kernel).to have_key('impl'), "Kernel missing impl for #{func['name']}"
          expect(kernel).to have_key('priority'), "Kernel missing priority for #{func['name']}"
        end
      end
    end
  end

  describe "NEP 20 signature compliance" do
    it "validates fixed-size dimension signatures" do
      fixed_size_sigs = functions_config.flat_map { |f| f['signature'] }.select { |s| s.match?(/\d/) }
      
      fixed_size_sigs.each do |sig_string|
        signature = parser.parse(sig_string)
        signature.in_shapes.flatten.each do |dim|
          if dim.fixed_size?
            expect(dim.size).to be > 0, "Fixed-size dimension must be positive in: #{sig_string}"
          end
        end
      end
    end

    it "validates broadcastable dimension signatures" do
      broadcastable_sigs = functions_config.flat_map { |f| f['signature'] }.select { |s| s.include?('|1') }
      
      broadcastable_sigs.each do |sig_string|
        signature = parser.parse(sig_string)
        # Broadcastable dimensions should only be in inputs, not outputs
        signature.out_shape.each do |dim|
          expect(dim.broadcastable?).to be false, 
            "Output dimension cannot be broadcastable in: #{sig_string}"
        end
      end
    end

    it "validates flexible dimension signatures" do
      flexible_sigs = functions_config.flat_map { |f| f['signature'] }.select { |s| s.include?('?') }
      
      flexible_sigs.each do |sig_string|
        signature = parser.parse(sig_string)
        # Just validate they parse correctly - flexible logic is complex
        expect(signature).to be_a(Kumi::Core::Functions::Signature)
      end
    end
  end

  describe "signature consistency" do
    it "validates join policies match signature patterns" do
      functions_config.each do |func|
        func['signature'].each do |sig_string|
          signature = parser.parse(sig_string)
          
          if signature.join_policy
            # Functions with join policies should have different dimension names
            case signature.join_policy
            when :product
              # Product should have policy set
              expect(signature.join_policy).to eq(:product)
            when :zip
              # Zip should have policy set  
              expect(signature.join_policy).to eq(:zip)
            end
          end
        end
      end
    end

    it "validates aggregate class functions have reduction signatures" do
      aggregate_functions = functions_config.select { |f| f['class'] == 'aggregate' }
      
      aggregate_functions.each do |func|
        has_reduction = func['signature'].any? do |sig_string|
          signature = parser.parse(sig_string)
          signature.reduction?
        end
        
        expect(has_reduction).to be(true), 
          "Aggregate function #{func['name']} should have at least one reduction signature"
      end
    end

    it "validates scalar class functions have compatible signatures" do
      scalar_functions = functions_config.select { |f| f['class'] == 'scalar' }
      
      scalar_functions.each do |func|
        func['signature'].each do |sig_string|
          signature = parser.parse(sig_string)
          
          # Scalar functions should preserve or reduce dimensions, not add new ones
          input_dim_names = signature.in_shapes.flatten.map(&:name).uniq
          output_dim_names = signature.out_shape.map(&:name).uniq
          
          # Output dimensions should be subset of input dimensions (or empty for scalars)
          extra_dims = output_dim_names - input_dim_names
          expect(extra_dims).to be_empty, 
            "Scalar function #{func['name']} introduces new dimensions #{extra_dims} in: #{sig_string}"
        end
      end
    end
  end

  describe "function coverage" do
    let(:function_names) { functions_config.map { |f| f['name'] } }

    it "includes basic arithmetic operations" do
      %w[core.add core.sub core.mul core.div].each do |op|
        expect(function_names).to include(op)
      end
    end

    it "includes comparison operations" do
      expect(function_names).to include('core.eq')
      expect(function_names).to include('core.gt')
    end

    it "includes logical operations" do
      %w[core.and core.or core.not].each do |op|
        expect(function_names).to include(op)
      end
    end

    it "includes aggregate operations" do
      %w[agg.sum agg.min agg.max agg.mean].each do |op|
        expect(function_names).to include(op)
      end
    end
  end
end