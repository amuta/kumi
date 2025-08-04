require 'spec_helper'

RSpec.describe "Cascade Vectorization with Scalar Results" do
  describe "vectorized conditions with scalar results" do
    context "when cascade conditions are vectorized but results are scalar" do
      let(:schema) do
        Class.new do
          extend Kumi::Schema
          
          schema do
            input do
              array :items do
                float :price
                string :category
                boolean :on_sale
              end
              float :discount_rate
            end
            
            # Vectorized traits operating on array elements
            trait :is_electronics, input.items.category == "electronics"
            trait :is_expensive, input.items.price > 100.0
            trait :is_on_sale, input.items.on_sale == true
            
            # Cascade with vectorized condition but scalar results
            # This should produce a vectorized output based on the condition structure
            value :category_labels do
              on is_electronics, "Electronic Device"
              base "General Item"
            end
            
            # Cascade with multiple vectorized conditions and scalar results
            value :item_classification do
              on is_expensive, is_electronics, "Premium Electronics"
              on is_electronics, "Standard Electronics"
              on is_expensive, "Premium Item"
              base "Standard Item"
            end
            
            # Cascade mixing vectorized conditions with vectorized results
            value :pricing_strategy do
              on is_on_sale, fn(:multiply, input.items.price, fn(:subtract, 1.0, input.discount_rate))
              on is_expensive, fn(:multiply, input.items.price, 0.95)  # 5% discount for expensive items
              base input.items.price
            end
          end
        end
      end
      
      let(:test_data) do
        {
          items: [
            { price: 150.0, category: "electronics", on_sale: true },   # expensive electronics on sale
            { price: 80.0, category: "books", on_sale: true },         # cheap books on sale
            { price: 200.0, category: "furniture", on_sale: false },   # expensive furniture not on sale
            { price: 50.0, category: "electronics", on_sale: false }   # cheap electronics not on sale
          ],
          discount_rate: 0.2
        }
      end
      
      let(:runner) { schema.from(test_data) }
      
      it "produces vectorized results when conditions are vectorized, even with scalar case results" do
        # Verify traits are properly vectorized
        expect(runner[:is_electronics]).to eq([true, false, false, true])
        expect(runner[:is_expensive]).to eq([true, false, true, false])
        expect(runner[:is_on_sale]).to eq([true, true, false, false])
        
        # Cascade with single vectorized condition and scalar results should be vectorized
        expect(runner[:category_labels]).to eq([
          "Electronic Device",  # electronics
          "General Item",       # books
          "General Item",       # furniture  
          "Electronic Device"   # electronics
        ])
        
        # Cascade with multiple vectorized conditions and scalar results should be vectorized
        expect(runner[:item_classification]).to eq([
          "Premium Electronics", # expensive + electronics
          "Standard Item",       # neither expensive nor electronics
          "Premium Item",        # expensive but not electronics
          "Standard Electronics" # electronics but not expensive
        ])
        
        # Mixed cascade (vectorized conditions + vectorized results) should work correctly
        expect(runner[:pricing_strategy]).to eq([
          120.0,  # on_sale: 150 * (1 - 0.2) = 120
          64.0,   # on_sale: 80 * (1 - 0.2) = 64
          190.0,  # expensive: 200 * 0.95 = 190
          50.0    # base case: 50
        ])
      end
    end
    
    context "with nested array structures" do
      let(:nested_schema) do
        Class.new do
          extend Kumi::Schema
          
          schema do
            input do
              array :regions do
                string :name
                array :stores do
                  string :type
                  array :products do
                    string :category
                    float :price
                  end
                end
              end
            end
            
            # Deeply nested vectorized condition
            trait :is_premium_product, input.regions.stores.products.price > 500.0
            trait :is_electronics_product, input.regions.stores.products.category == "electronics"
            
            # Cascade with nested vectorized condition but scalar results
            value :product_tier do
              on is_premium_product, is_electronics_product, "Premium Tech"
              on is_premium_product, "Premium"
              on is_electronics_product, "Tech"
              base "Standard"
            end
          end
        end
      end
      
      let(:nested_data) do
        {
          regions: [
            {
              name: "North",
              stores: [
                {
                  type: "flagship",
                  products: [
                    { category: "electronics", price: 800.0 },  # Premium Tech
                    { category: "books", price: 30.0 }          # Standard
                  ]
                },
                {
                  type: "outlet", 
                  products: [
                    { category: "electronics", price: 200.0 }   # Tech
                  ]
                }
              ]
            },
            {
              name: "South",
              stores: [
                {
                  type: "regular",
                  products: [
                    { category: "furniture", price: 1200.0 }    # Premium
                  ]
                }
              ]
            }
          ]
        }
      end
      
      let(:nested_runner) { nested_schema.from(nested_data) }
      
      it "handles deeply nested vectorized conditions with scalar results" do
        expect(nested_runner[:is_premium_product]).to eq([
          [
            [true, false],   # flagship store: electronics > 500, books <= 500
            [false]          # outlet store: electronics <= 500
          ],
          [
            [true]           # regular store: furniture > 500
          ]
        ])
        
        expect(nested_runner[:is_electronics_product]).to eq([
          [
            [true, false],   # flagship store: electronics, books
            [true]           # outlet store: electronics
          ],
          [
            [false]          # regular store: furniture
          ]
        ])
        
        # Cascade should preserve the nested structure while applying scalar results
        expect(nested_runner[:product_tier]).to eq([
          [
            ["Premium Tech", "Standard"],  # flagship: premium electronics, standard books
            ["Tech"]                       # outlet: standard electronics
          ],
          [
            ["Premium"]                    # regular: premium furniture
          ]
        ])
      end
    end
    
    context "with mixed hierarchical levels" do
      let(:hierarchical_schema) do
        Class.new do
          extend Kumi::Schema
          
          schema do
            input do
              array :departments do
                string :name
                float :budget
                array :teams do
                  string :focus
                  array :employees do
                    string :level
                    float :salary
                  end
                end
              end
            end
            
            # Different hierarchical levels
            trait :high_budget_dept, input.departments.budget > 1_000_000
            trait :senior_employee, input.departments.teams.employees.level == "senior"
            trait :ai_team, input.departments.teams.focus == "AI"
            
            # Cascade mixing different hierarchical conditions with scalar results
            value :compensation_tier do
              on high_budget_dept, senior_employee, ai_team, "Elite AI Senior"
              on senior_employee, ai_team, "AI Senior"  
              on high_budget_dept, senior_employee, "Senior Executive"
              on senior_employee, "Senior"
              base "Standard"
            end
          end
        end
      end
      
      let(:hierarchical_data) do
        {
          departments: [
            {
              name: "Engineering", 
              budget: 2_000_000,
              teams: [
                {
                  focus: "AI",
                  employees: [
                    { level: "senior", salary: 180_000 },
                    { level: "junior", salary: 120_000 }
                  ]
                },
                {
                  focus: "Backend", 
                  employees: [
                    { level: "senior", salary: 160_000 }
                  ]
                }
              ]
            },
            {
              name: "Marketing",
              budget: 500_000,
              teams: [
                {
                  focus: "Digital",
                  employees: [
                    { level: "senior", salary: 140_000 },
                    { level: "junior", salary: 90_000 }
                  ]
                }
              ]
            }
          ]
        }
      end
      
      let(:hierarchical_runner) { hierarchical_schema.from(hierarchical_data) }
      
      it "handles hierarchical broadcasting with mixed condition levels and scalar results" do
        # Verify individual traits work correctly
        expect(hierarchical_runner[:high_budget_dept]).to eq([true, false])
        expect(hierarchical_runner[:senior_employee]).to eq([
          [[true, false], [true]],    # Engineering: AI team [senior, junior], Backend team [senior] 
          [[true, false]]             # Marketing: Digital team [senior, junior]
        ])
        expect(hierarchical_runner[:ai_team]).to eq([
          [true, false],              # Engineering: AI team, Backend team
          [false]                     # Marketing: Digital team  
        ])
        
        # Cascade should properly broadcast hierarchical conditions to employee level
        expect(hierarchical_runner[:compensation_tier]).to eq([
          [
            ["Elite AI Senior", "Standard"],  # Engineering AI: senior gets elite, junior gets standard
            ["Senior Executive"]               # Engineering Backend: senior gets executive (high budget + senior)
          ],
          [
            ["Senior", "Standard"]             # Marketing Digital: senior gets senior, junior gets standard  
          ]
        ])
      end
    end
  end
  
  describe "edge cases and error conditions" do
    context "when all conditions and results are scalar" do
      let(:scalar_schema) do
        Class.new do
          extend Kumi::Schema
          
          schema do
            input do
              float :age
              string :status
            end
            
            trait :is_adult, input.age >= 18
            trait :is_active, input.status == "active"
            
            value :category do
              on is_adult, is_active, "Adult Active"
              on is_adult, "Adult"
              base "Minor"
            end
          end
        end
      end
      
      it "produces scalar results when no vectorization is present" do
        adult_active = scalar_schema.from({ age: 25, status: "active" })
        expect(adult_active[:category]).to eq("Adult Active")
        
        adult_inactive = scalar_schema.from({ age: 25, status: "inactive" })
        expect(adult_inactive[:category]).to eq("Adult")
        
        minor = scalar_schema.from({ age: 16, status: "active" })  
        expect(minor[:category]).to eq("Minor")
      end
    end
    
    context "when base case is vectorized but conditions are scalar" do
      let(:base_vectorized_schema) do
        Class.new do
          extend Kumi::Schema
          
          schema do
            input do
              boolean :special_mode
              array :items do
                float :value
              end
            end
            
            trait :special, input.special_mode == true
            
            # Base case is vectorized, condition is scalar
            value :result do
              on special, "Special Mode"
              base input.items.value * 2.0  # vectorized base
            end
          end
        end
      end
      
      it "uses vectorized base case to determine result structure" do
        normal_mode = base_vectorized_schema.from({ 
          special_mode: false, 
          items: [{ value: 10.0 }, { value: 20.0 }] 
        })
        expect(normal_mode[:result]).to eq([20.0, 40.0])
        
        special_mode = base_vectorized_schema.from({ 
          special_mode: true, 
          items: [{ value: 10.0 }, { value: 20.0 }] 
        })
        expect(special_mode[:result]).to eq(["Special Mode", "Special Mode"])
      end
    end
  end
end