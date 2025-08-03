# frozen_string_literal: true

RSpec.describe "Dual Mode Execution" do
  describe "Ruby vs JavaScript comparison" do
    let(:simple_schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input do
            integer :age
            float :salary
          end

          trait :adult, (input.age >= 18)
          trait :senior, (input.age >= 65)
          
          value :monthly_salary, input.salary / 12
          value :annual_bonus, input.salary * 0.1
          
          value :status do
            on senior, "Senior"
            on adult, "Adult"
            base "Minor"
          end
        end
      end
    end

    let(:math_heavy_schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input do
            float :salary
            float :bonus_rate
            integer :years_experience
          end

          value :annual_bonus, input.salary * input.bonus_rate
          value :experience_bonus, input.years_experience * 1000
          value :total_compensation, fn(:add, input.salary, fn(:add, annual_bonus, experience_bonus))
          value :monthly_compensation, total_compensation / 12
        end
      end
    end

    let(:array_schema) do
      Class.new do
        extend Kumi::Schema

        schema do
          input do
            array :numbers, elem: { type: :float }
            float :threshold
          end

          value :sum_all, fn(:sum, input.numbers)
          value :average, sum_all / fn(:size, input.numbers)
          # Count numbers greater than threshold  
          trait :above_thresh, fn(:any?, fn(:map_conditional, input.numbers, input.threshold, true, false))
          value :above_threshold, fn(:sum, fn(:map_conditional, input.numbers, input.threshold, 1, 0))
        end
      end
    end

    context "with dual mode enabled", :focus do
      with_dual_mode_enabled do
        it "produces identical results for simple calculations" do
          test_data = { age: 30, salary: 75_000.0 }
          runner = simple_schema.from(test_data)

          expect(runner.fetch(:adult)).to eq(true)
          expect(runner.fetch(:monthly_salary)).to eq(6_250.0)
          expect(runner.fetch(:annual_bonus)).to eq(7_500.0)
          expect(runner.fetch(:status)).to eq("Adult")
        end

        it "produces identical results for senior citizens" do
          test_data = { age: 70, salary: 60_000.0 }
          runner = simple_schema.from(test_data)

          expect(runner.fetch(:senior)).to eq(true)
          expect(runner.fetch(:adult)).to eq(true)  # seniors are also adults
          expect(runner.fetch(:status)).to eq("Senior")  # but senior takes precedence
        end

        it "produces identical results for minors" do
          test_data = { age: 16, salary: 15_000.0 }
          runner = simple_schema.from(test_data)

          expect(runner.fetch(:adult)).to eq(false)
          expect(runner.fetch(:senior)).to eq(false)
          expect(runner.fetch(:status)).to eq("Minor")
        end

        it "handles complex mathematical calculations" do
          test_data = { salary: 100_000.0, bonus_rate: 0.15, years_experience: 5 }
          runner = math_heavy_schema.from(test_data)

          annual_bonus = runner.fetch(:annual_bonus)
          experience_bonus = runner.fetch(:experience_bonus)
          total_compensation = runner.fetch(:total_compensation)
          monthly_compensation = runner.fetch(:monthly_compensation)

          expect(annual_bonus).to eq(15_000.0)  # 100k * 0.15
          expect(experience_bonus).to eq(5_000.0)  # 5 * 1000
          expect(total_compensation).to eq(120_000.0)  # 100k + 15k + 5k
          expect(monthly_compensation).to be_within(0.01).of(10_000.0)  # 120k / 12
        end

        it "handles array operations correctly" do
          test_data = { numbers: [1.0, 5.0, 10.0, 15.0, 20.0], threshold: 10.0 }
          runner = array_schema.from(test_data)

          expect(runner.fetch(:sum_all)).to eq(51.0)
          expect(runner.fetch(:average)).to eq(10.2)
          # map_conditional returns 1 for value == threshold, 0 otherwise
          # Only 10.0 == 10.0, so result should be 1
          expect(runner.fetch(:above_threshold)).to eq(1)
        end

        it "produces identical results when using slice" do
          test_data = { age: 45, salary: 85_000.0 }
          runner = simple_schema.from(test_data)

          result = runner.slice(:adult, :monthly_salary, :status)
          
          expect(result[:adult]).to eq(true)
          expect(result[:monthly_salary]).to be_within(0.01).of(7_083.33)
          expect(result[:status]).to eq("Adult")
        end
      end
    end

    context "without dual mode" do
      it "works normally without JavaScript execution" do
        test_data = { age: 25, salary: 50_000.0 }
        runner = simple_schema.from(test_data, dual_mode: false)

        expect(runner[:adult]).to eq(true)
        expect(runner[:monthly_salary]).to be_within(0.01).of(4_166.67)
        expect(runner[:status]).to eq("Adult")
      end
    end

    context "dual mode error handling" do
      # This would test cases where Ruby and JS produce different results
      # In a real scenario, this should never happen, but it's useful for debugging
      
      it "raises clear errors when results don't match" do
        # This test would require modifying the JS compiler to produce incorrect results
        # Left as a placeholder for debugging scenarios
        skip "Placeholder for debugging dual mode mismatches"
      end
    end
  end

  describe "environment variable control" do
    it "enables dual mode via KUMI_DUAL_MODE=true" do
      ENV['KUMI_DUAL_MODE'] = 'true'
      
      begin
        test_schema = Class.new do
          extend Kumi::Schema
          schema do
            input { integer :x }
            value :doubled, input.x * 2
          end
        end

        with_dual_mode do
          runner = test_schema.from({ x: 5 })
          expect(runner.fetch(:doubled)).to eq(10)
        end
      ensure
        ENV.delete('KUMI_DUAL_MODE')
      end
    end
  end
end