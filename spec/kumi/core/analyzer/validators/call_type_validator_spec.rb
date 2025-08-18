# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::Core::Analyzer::Validators::CallTypeValidator do
  include AnalyzerStateHelper

  describe "input metadata structure analysis" do
    it "shows input_metadata structure for nested hash objects" do
      state = analyze_up_to(:input_metadata) do
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

        value :test_simple, input.order.customer.discount_rate
        value :test_deep, input.order.line_item.discounts.bulk_discount
      end

      input_meta = state[:input_metadata]

      puts "\n=== INPUT METADATA STRUCTURE ==="
      puts "Top-level keys: #{input_meta.keys.inspect}"

      order_meta = input_meta[:order]
      puts "\norder metadata:"
      puts "  type: #{order_meta[:type]}"
      puts "  container: #{order_meta[:container]}"
      puts "  children keys: #{order_meta[:children]&.keys&.inspect}"

      if order_meta[:children]
        customer_meta = order_meta[:children][:customer]
        puts "\norder.customer metadata:"
        puts "  type: #{customer_meta[:type]}"
        puts "  container: #{customer_meta[:container]}"
        puts "  children keys: #{customer_meta[:children]&.keys&.inspect}"

        if customer_meta[:children]
          discount_rate_meta = customer_meta[:children][:discount_rate]
          puts "\norder.customer.discount_rate metadata:"
          puts "  type: #{discount_rate_meta[:type]}"
          puts "  container: #{discount_rate_meta[:container]}"
        end

        line_item_meta = order_meta[:children][:line_item]
        puts "\norder.line_item metadata:"
        puts "  type: #{line_item_meta[:type]}"
        puts "  container: #{line_item_meta[:container]}"
        puts "  children keys: #{line_item_meta[:children]&.keys&.inspect}"

        if line_item_meta[:children]
          discounts_meta = line_item_meta[:children][:discounts]
          puts "\norder.line_item.discounts metadata:"
          puts "  type: #{discounts_meta[:type]}"
          puts "  container: #{discounts_meta[:container]}"
          puts "  children keys: #{discounts_meta[:children]&.keys&.inspect}"

          if discounts_meta[:children]
            bulk_discount_meta = discounts_meta[:children][:bulk_discount]
            puts "\norder.line_item.discounts.bulk_discount metadata:"
            puts "  type: #{bulk_discount_meta[:type]}"
            puts "  container: #{bulk_discount_meta[:container]}"
          end
        end
      end

      # Assert the structure we expect
      expect(input_meta).to have_key(:order)
      expect(order_meta[:type]).to eq(:hash)
      expect(order_meta[:children]).to have_key(:customer)
      expect(order_meta[:children]).to have_key(:line_item)

      # Test path navigation
      customer_discount_rate = order_meta.dig(:children, :customer, :children, :discount_rate)
      expect(customer_discount_rate[:type]).to eq(:float)

      bulk_discount = order_meta.dig(:children, :line_item, :children, :discounts, :children, :bulk_discount)
      expect(bulk_discount[:type]).to eq(:float)
    end

    it "shows access_plans structure for nested hash objects" do
      state = analyze_up_to(:access_plans) do
        input do
          hash :order do
            hash :customer do
              float :discount_rate
            end
            hash :line_item do
              float :unit_price
              hash :discounts do
                float :bulk_discount
              end
            end
          end
        end

        value :test_simple, input.order.customer.discount_rate
        value :test_deep, input.order.line_item.discounts.bulk_discount
      end

      access_plans = state[:access_plans]

      puts "\n=== ACCESS PLANS STRUCTURE ==="
      puts "access_plans keys: #{access_plans&.keys&.inspect}"

      if access_plans
        access_plans.each do |path_str, plans|
          puts "\nPath: #{path_str}"
          puts "  Number of plans: #{plans&.length || 0}"
          next unless plans && !plans.empty?

          plan = plans.first
          puts "  Plan class: #{plan.class}"
          puts "  Plan methods: #{plan.methods.grep(/type|meta/).inspect}" if plan.respond_to?(:methods)
          puts "  Plan inspect: #{plan.inspect[0..200]}..."
        end
      end

      # We want to understand what's available for type inference
      expect(access_plans).to be_a(Hash) if access_plans
    end

    it "demonstrates the correct path for type inference" do
      state = analyze_up_to(:access_plans) do
        input do
          hash :product do
            float :price
            integer :quantity
          end
        end

        value :subtotal, input.product.price * input.product.quantity
      end

      input_meta = state[:input_metadata]
      access_plans = state[:access_plans]

      puts "\n=== TYPE INFERENCE PATH ANALYSIS ==="

      # Simulate what CallTypeValidator.infer_expr_type should do for input.product.price
      path = %i[product price]
      path_str = path.join(".")

      puts "Path: #{path.inspect}"
      puts "Path string: #{path_str}"

      # Method 1: Check access_plans
      if access_plans && access_plans[path_str]
        puts "Found in access_plans: #{access_plans[path_str].inspect[0..100]}..."
      else
        puts "NOT found in access_plans"
      end

      # Method 2: Navigate input_metadata
      root_meta = input_meta[path.first]
      puts "Root metadata: #{root_meta[:type]} (#{root_meta[:container]})"

      if root_meta[:children] && root_meta[:children][path[1]]
        field_meta = root_meta[:children][path[1]]
        puts "Field metadata: #{field_meta[:type]} (#{field_meta[:container]})"

        # This is what we should return for type inference
        expected_type = field_meta[:type]
        puts "Expected type for #{path_str}: #{expected_type}"

        expect(expected_type).to eq(:float)
      end
    end
  end
end
