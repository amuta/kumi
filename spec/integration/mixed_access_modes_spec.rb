# frozen_string_literal: true

RSpec.describe "Mixed Access Modes Integration" do
  describe "Object and Element Access in Same Schema" do
    module UserAnalytics
      extend Kumi::Schema

      schema do
        input do
          # Object access mode - structured business data
          array :users do
            string :name
            integer :age
          end

          # Element access mode - multi-dimensional raw arrays
          array :recent_purchases do
            element :integer, :days_ago
          end
        end

        # Object access works normally
        value :user_names, input.users.name
        value :avg_age, fn(:avg, input.users.age)

        # Element access handles nested arrays
        value :all_purchase_days, fn(:flatten, input.recent_purchases.days_ago)
        value :recent_flags, input.recent_purchases.days_ago < 5
        trait :has_recent_purchase, fn(:any?, fn(:flatten, recent_flags))

        # Mixed usage in conditions
        trait :adult_users, input.users.age >= 18
        value :adult_count, fn(:count_if, adult_users)

        # Complex mixed logic - combining boolean arrays with scalar
        value :active_adult_flags, adult_users & has_recent_purchase
        trait :has_active_adults, fn(:any?, active_adult_flags)
        value :user_activity_summary, [fn(:size, input.users), adult_count, fn(:size, all_purchase_days)]
      end
    end

    let(:mixed_data) do
      {
        users: [
          { name: "Alice", age: 25 },
          { name: "Bob", age: 17 },
          { name: "Carol", age: 30 }
        ],
        recent_purchases: [
          [1, 3, 7],     # Recent activity
          [2, 4],        # Recent activity
          [10, 15, 20]   # Older activity
        ]
      }
    end

    it "handles mixed object and element access correctly" do
      result = UserAnalytics.from(mixed_data)

      # Object access results
      expect(result[:user_names]).to eq(%w[Alice Bob Carol])
      expect(result[:avg_age]).to eq(24.0) # (25 + 17 + 30) / 3
      expect(result[:adult_count]).to eq(2) # Alice and Carol

      # Element access results
      expect(result[:all_purchase_days]).to eq([1, 3, 7, 2, 4, 10, 15, 20])
      expect(result[:has_recent_purchase]).to be true # Has purchases < 5 days

      # Mixed logic results
      expect(result[:has_active_adults]).to be true # Has adults AND recent purchases
      expect(result[:user_activity_summary]).to eq([3, 2, 8]) # [total users, adults, total purchase days]
    end
  end

  describe "Separate Object and Element Arrays" do
    module GameAnalytics
      extend Kumi::Schema

      schema do
        input do
          # Object access for player metadata
          array :players do
            string :name
            integer :level
          end

          # Separate element access for score data
          array :score_matrices do
            element :array, :session do
              element :integer, :points
            end
          end
        end

        # Object-level aggregations
        value :player_names, input.players.name
        value :avg_level, fn(:avg, input.players.level)
        value :player_count, fn(:size, input.players)

        # Element access for score analysis
        value :all_scores, fn(:flatten, input.score_matrices.session.points)
        value :total_points, fn(:sum, all_scores)
        value :high_score_flags, input.score_matrices.session.points > 1000
        value :has_high_scorer, fn(:any?, fn(:flatten, high_score_flags))
      end
    end

    let(:game_data) do
      {
        players: [
          { name: "Alice", level: 15 },
          { name: "Bob", level: 12 }
        ],
        score_matrices: [
          [[800, 900], [1200, 1100]],   # Alice's scores
          [[600, 700, 800]]             # Bob's scores
        ]
      }
    end

    it "handles separate object and element arrays effectively" do
      result = GameAnalytics.from(game_data)

      expect(result[:player_names]).to eq(%w[Alice Bob])
      expect(result[:avg_level]).to eq(13.5) # (15 + 12) / 2
      expect(result[:player_count]).to eq(2)

      # Element access flattens all scores
      expect(result[:all_scores]).to eq([800, 900, 1200, 1100, 600, 700, 800])
      expect(result[:total_points]).to eq(6100) # Sum of all scores
      expect(result[:has_high_scorer]).to be true # Alice has scores > 1000
    end
  end

  describe "Multi-dimensional Element Arrays" do
    module DataCubeAnalysis
      extend Kumi::Schema

      schema do
        input do
          # Pure element access for 3D data cube
          array :data_cube do
            element :array, :layer do
              element :array, :row do
                element :float, :value
              end
            end
          end

          # Object access for metadata
          array :layer_metadata do
            string :name
            string :type
          end
        end

        # Multi-dimensional operations with intuitive progressive path traversal
        value :cube_dimensions, [
          fn(:size, input.data_cube), # Layers
          fn(:size, input.data_cube.layer),               # Matrices
          fn(:size, input.data_cube.layer.row),           # Rows (direct access!)
          fn(:size, input.data_cube.layer.row.value)      # Values
        ]

        value :all_values, fn(:flatten, input.data_cube.layer.row.value)
        value :cube_sum, fn(:sum, all_values)
        value :cube_stats, [fn(:min, all_values), fn(:max, all_values), fn(:avg, all_values)]

        # Mixed with metadata
        value :layer_names, input.layer_metadata.name
        value :metadata_count, fn(:size, input.layer_metadata)
      end
    end

    let(:cube_data) do
      {
        data_cube: [
          [                           # Layer 1
            [[1.0, 2.0], [3.0, 4.0]], # 2x2 matrix
            [[5.0, 6.0]]              # 1x2 matrix
          ],
          [                           # Layer 2
            [[7.0, 8.0, 9.0]]         # 1x3 matrix
          ]
        ],
        layer_metadata: [
          { name: "Input Layer", type: "data" },
          { name: "Hidden Layer", type: "computed" }
        ]
      }
    end

    it "handles complex multi-dimensional element access with object metadata" do
      result = DataCubeAnalysis.from(cube_data)

      # Dimensional analysis - now works correctly with progressive path traversal!
      expect(result[:cube_dimensions]).to eq([2, 3, 4, 9]) # [layers, matrices, rows, total values]

      # All values flattened to leaf elements
      expect(result[:all_values]).to eq([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0])
      expect(result[:cube_sum]).to eq(45.0) # Sum of 1+2+3+...+9
      expect(result[:cube_stats]).to eq([1.0, 9.0, 5.0]) # [min, max, avg]

      # Mixed with object access for metadata
      expect(result[:layer_names]).to eq(["Input Layer", "Hidden Layer"])
      expect(result[:metadata_count]).to eq(2)
    end
  end
end
