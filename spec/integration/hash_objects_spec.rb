# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Hash Objects Integration" do
  describe "hash objects with children" do
    it "validates and accesses basic hash object fields" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            hash :user_profile do
              string :name
              integer :age
              float :rating
            end
          end
          
          value :profile_name, input.user_profile.name
          value :profile_age, input.user_profile.age
          value :profile_rating, input.user_profile.rating
        end
      end
      
      test_data = {
        user_profile: {
          name: "Alice",
          age: 30,
          rating: 4.5
        }
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:profile_name]).to eq("Alice")
      expect(runner[:profile_age]).to eq(30)
      expect(runner[:profile_rating]).to eq(4.5)
    end

    it "supports operations on hash object fields" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            hash :product do
              float :price
              integer :quantity
              string :category
            end
          end
          
          value :subtotal, input.product.price * input.product.quantity
          trait :is_expensive, input.product.price > 100.0
          trait :is_electronics, input.product.category == "electronics"
          
          value :description do
            on is_expensive, "Expensive item"
            on is_electronics, "Electronics"
            base "Regular item"
          end
        end
      end
      
      test_data = {
        product: {
          price: 150.0,
          quantity: 2,
          category: "electronics"
        }
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:subtotal]).to eq(300.0)
      expect(runner[:description]).to eq("Expensive item")
    end

    it "supports nested hash objects" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            hash :order do
              string :id
              hash :customer do
                string :name
                string :email
              end
              hash :shipping do
                string :address
                string :city
              end
            end
          end
          
          value :order_summary, fn(:concat, input.order.id, " for ", input.order.customer.name)
          value :shipping_info, fn(:concat, input.order.shipping.city, " - ", input.order.shipping.address)
        end
      end
      
      test_data = {
        order: {
          id: "ORD-123",
          customer: {
            name: "Bob Smith",
            email: "bob@example.com"
          },
          shipping: {
            address: "123 Main St",
            city: "New York"
          }
        }
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:order_summary]).to eq("ORD-123 for Bob Smith")
      expect(runner[:shipping_info]).to eq("New York - 123 Main St")
    end

    it "supports mathematical operations on hash object fields" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            hash :product do
              float :price
              integer :quantity
              float :tax_rate
            end
            hash :shipping do
              float :base_cost
              float :weight_multiplier
              float :weight
            end
          end
          
          value :subtotal, input.product.price * input.product.quantity
          value :tax_amount, ref(:subtotal) * input.product.tax_rate
          value :shipping_cost, input.shipping.base_cost + (input.shipping.weight * input.shipping.weight_multiplier)
          value :total, ref(:subtotal) + ref(:tax_amount) + ref(:shipping_cost)
          value :price_per_unit_with_tax, (input.product.price * input.product.tax_rate) + input.product.price
        end
      end
      
      test_data = {
        product: {
          price: 50.0,
          quantity: 3,
          tax_rate: 0.1
        },
        shipping: {
          base_cost: 5.0,
          weight_multiplier: 2.0,
          weight: 1.5
        }
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:subtotal]).to eq(150.0)
      expect(runner[:tax_amount]).to eq(15.0)
      expect(runner[:shipping_cost]).to eq(8.0)  # 5.0 + (1.5 * 2.0)
      expect(runner[:total]).to eq(173.0)  # 150.0 + 15.0 + 8.0
      expect(runner[:price_per_unit_with_tax]).to eq(55.0)  # (50.0 * 0.1) + 50.0
    end

    it "supports complex calculations across nested hash objects" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            hash :order do
              hash :customer do
                float :discount_rate
                integer :loyalty_points
              end
              hash :line_item do
                float :unit_price
                integer :quantity
                hash :discounts do
                  float :bulk_discount
                  float :seasonal_discount
                end
              end
            end
          end
          
          value :base_amount, input.order.line_item.unit_price * input.order.line_item.quantity
          value :total_discount_rate, input.order.line_item.discounts.bulk_discount + input.order.line_item.discounts.seasonal_discount + input.order.customer.discount_rate
          value :discount_amount, ref(:base_amount) * ref(:total_discount_rate)
          value :points_value, input.order.customer.loyalty_points * 0.01
          value :final_amount, ref(:base_amount) - ref(:discount_amount) - ref(:points_value)
        end
      end
      
      test_data = {
        order: {
          customer: {
            discount_rate: 0.05,
            loyalty_points: 200
          },
          line_item: {
            unit_price: 25.0,
            quantity: 4,
            discounts: {
              bulk_discount: 0.10,
              seasonal_discount: 0.03
            }
          }
        }
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:base_amount]).to eq(100.0)  # 25.0 * 4
      expect(runner[:total_discount_rate]).to eq(0.18)  # 0.10 + 0.03 + 0.05
      expect(runner[:discount_amount]).to eq(18.0)  # 100.0 * 0.18
      expect(runner[:points_value]).to eq(2.0)  # 200 * 0.01
      expect(runner[:final_amount]).to eq(80.0)  # 100.0 - 18.0 - 2.0
    end

    it "handles mathematical operations with hash arrays" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :orders do
              hash :item do
                float :price
                integer :quantity
              end
              hash :fees do
                float :processing_fee
                float :service_fee
              end
            end
          end
          
          value :item_totals, input.orders.item.price * input.orders.item.quantity
          value :total_fees, input.orders.fees.processing_fee + input.orders.fees.service_fee
          value :order_totals, ref(:item_totals) + ref(:total_fees)
          value :grand_total, fn(:sum, ref(:order_totals))
          value :average_order_value, fn(:mean, ref(:order_totals))
        end
      end
      
      test_data = {
        orders: [
          {
            item: { price: 20.0, quantity: 2 },
            fees: { processing_fee: 1.5, service_fee: 2.0 }
          },
          {
            item: { price: 15.0, quantity: 3 },
            fees: { processing_fee: 1.0, service_fee: 1.5 }
          }
        ]
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:item_totals]).to eq([40.0, 45.0])  # [20*2, 15*3]
      expect(runner[:total_fees]).to eq([3.5, 2.5])  # [1.5+2.0, 1.0+1.5]
      expect(runner[:order_totals]).to eq([43.5, 47.5])  # [40+3.5, 45+2.5]
      expect(runner[:grand_total]).to eq(91.0)  # 43.5 + 47.5
      expect(runner[:average_order_value]).to eq(45.5)  # (43.5 + 47.5) / 2
    end

    it "works with mixed array and hash objects" do
      schema = Module.new do
        extend Kumi::Schema
        
        schema do
          input do
            array :orders do
              string :id
              hash :customer do
                string :name
                integer :age
              end
              float :total
            end
          end
          
          value :customer_names, input.orders.customer.name
          value :order_totals, input.orders.total
          value :total_revenue, fn(:sum, input.orders.total)
        end
      end
      
      test_data = {
        orders: [
          {
            id: "ORD-1",
            customer: { name: "Alice", age: 25 },
            total: 100.0
          },
          {
            id: "ORD-2", 
            customer: { name: "Bob", age: 30 },
            total: 200.0
          }
        ]
      }
      
      runner = schema.from(test_data)
      
      expect(runner[:customer_names]).to eq(["Alice", "Bob"])
      expect(runner[:order_totals]).to eq([100.0, 200.0])
      expect(runner[:total_revenue]).to eq(300.0)
    end

    context "validation behavior" do
      it "skips type validation for hash objects with children" do
        schema = Module.new do
          extend Kumi::Schema
          
          schema do
            input do
              hash :config do
                string :env
                integer :port
              end
              string :simple_field  # For comparison
            end
            
            value :env_name, input.config.env
            value :port_number, input.config.port
            value :simple_value, input.simple_field
          end
        end
        
        test_data = {
          config: {
            env: "production",
            port: 8080
          },
          simple_field: "test"
        }
        
        runner = schema.from(test_data)
        
        expect(runner[:env_name]).to eq("production")
        expect(runner[:port_number]).to eq(8080)
        expect(runner[:simple_value]).to eq("test")
      end

      it "child validation is not yet implemented (known limitation)" do
        # TODO: Implement child validation as documented in VALIDATIONS_MISSING.md
        schema = Module.new do
          extend Kumi::Schema
          
          schema do
            input do
              hash :settings do
                string :name
                integer :count
              end
            end
            
            value :setting_name, input.settings.name
          end
        end
        
        # Invalid child field type currently does NOT fail (limitation)
        invalid_data = {
          settings: {
            name: 123,  # Should be string but validation is not implemented
            count: 10
          }
        }
        
        # Currently this does not raise an error (known limitation)
        runner = schema.from(invalid_data)
        expect(runner[:setting_name]).to eq(123)  # Returns the invalid value
      end
    end
  end
end