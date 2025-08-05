# frozen_string_literal: true

RSpec.describe "Dual Mode Debug Output" do
  let(:test_schema) do
    Class.new do
      extend Kumi::Schema

      schema do
        input do
          integer :age
          float :salary
        end

        trait :adult, (input.age >= 18)
        value :monthly_salary, input.salary / 12
        value :status do
          on adult, "Adult"
          base "Minor"
        end
      end
    end
  end

  describe "debug output verification" do
    it "shows both Ruby and JavaScript execution results" do
      with_dual_mode_debug do
        schema = Class.new do
          extend Kumi::Schema

          schema do
            input do
              integer :age
              float :salary
            end
            trait :adult, (input.age >= 18)
            value :monthly_salary, input.salary / 12
            value :status do
              on adult, "Adult"
              base "Minor"
            end
          end
        end

        test_data = { age: 30, salary: 60_000.0 }
        runner = schema.from(test_data)

        puts "\n=== Testing fetch operations ==="
        result1 = runner.fetch(:adult)
        result2 = runner.fetch(:monthly_salary)
        result3 = runner.fetch(:status)

        puts "\n=== Testing slice operation ==="
        slice_result = runner.slice(:adult, :status)

        # Verify results are correct
        expect(result1).to be(true)
        expect(result2).to be_within(0.01).of(5_000.0)
        expect(result3).to eq("Adult")
        expect(slice_result).to eq({ adult: true, status: "Adult" })
      end
    end

    it "can be enabled via environment variable" do
      ENV["KUMI_DUAL_DEBUG"] = "true"
      ENV["KUMI_DUAL_MODE"] = "true"

      begin
        test_data = { age: 25, salary: 50_000.0 }
        runner = test_schema.from(test_data)

        puts "\n=== Environment variable debug test ==="
        result = runner.fetch(:monthly_salary)
        expect(result).to be_within(0.01).of(4_166.67)
      ensure
        ENV.delete("KUMI_DUAL_DEBUG")
        ENV.delete("KUMI_DUAL_MODE")
      end
    end
  end
end
