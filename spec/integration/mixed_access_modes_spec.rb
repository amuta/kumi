# # frozen_string_literal: true

# RSpec.describe "Mixed Access Modes Integration" do
#   # describe "Object and Element Access in Same Schema" do
#   #   module UserAnalytics
#   #     extend Kumi::Schema

#   #     schema do
#   #       input do
#   #         # Object access mode - structured business data
#   #         array :users do
#   #           string :name
#   #           integer :age
#   #         end

#   #         # Element access mode - multi-dimensional raw arrays
#   #         array :recent_purchases do
#   #           element :integer, :days_ago
#   #         end
#   #       end

#   #       # Object access works normally
#   #       value :user_names, input.users.name
#   #       value :avg_age, fn(:avg, input.users.age)

#   #       # Element access handles nested arrays
#   #       value :all_purchase_days, fn(:flatten, input.recent_purchases.days_ago)
#   #       value :recent_flags, input.recent_purchases.days_ago < 5
#   #       trait :has_recent_purchase, fn(:any?, fn(:flatten, recent_flags))

#   #       # Mixed usage in conditions
#   #       trait :adult_users, input.users.age >= 18
#   #       value :adult_count, fn(:count_if, adult_users)

#   #       # Complex mixed logic - combining boolean arrays with scalar
#   #       value :active_adult_flags, adult_users & has_recent_purchase
#   #       trait :has_active_adults, fn(:any?, active_adult_flags)
#   #       value :user_activity_summary, [fn(:size, input.users), adult_count, fn(:size, all_purchase_days)]
#   #     end
#   #   end

#   #   let(:mixed_data) do
#   #     {
#   #       users: [
#   #         { name: "Alice", age: 25 },
#   #         { name: "Bob", age: 17 },
#   #         { name: "Carol", age: 30 }
#   #       ],
#   #       recent_purchases: [
#   #         [1, 3, 7],     # Recent activity
#   #         [2, 4],        # Recent activity
#   #         [10, 15, 20]   # Older activity
#   #       ]
#   #     }
#   #   end

#   #   it "handles mixed object and element access correctly" do
#   #     result = UserAnalytics.from(mixed_data)

#   #     # Object access results
#   #     expect(result[:user_names]).to eq(%w[Alice Bob Carol])
#   #     expect(result[:avg_age]).to eq(24.0) # (25 + 17 + 30) / 3
#   #     expect(result[:adult_count]).to eq(2) # Alice and Carol

#   #     # Element access results
#   #     expect(result[:all_purchase_days]).to eq([1, 3, 7, 2, 4, 10, 15, 20])
#   #     expect(result[:has_recent_purchase]).to be true # Has purchases < 5 days

#   #     # Mixed logic results
#   #     expect(result[:has_active_adults]).to be true # Has adults AND recent purchases
#   #     expect(result[:user_activity_summary]).to eq([3, 2, 8]) # [total users, adults, total purchase days]
#   #   end
#   # end
#   describe "Separate Object and Element Arrays + Cascades (traits only)" do
#     module GameAnalytics
#       extend Kumi::Schema

#       schema do
#         input do
#           array :players do
#             string  :name
#             integer :level
#             array :score_matrices do
#               element :array, :session do
#                 element :integer, :points
#               end
#             end
#           end
#         end

#         # ---- basics
#         value :total_points, fn(:sum, input.players.score_matrices.session.points)
#         value :total_points_by_player, [input.players.name, fn(:sum, input.players.score_matrices.session.points)]

#         # ---- traits for per-player cascade
#         trait :player_total_ge_3500_2, total_points >= 3500
#         trait :player_total_ge_3500,  fn(:sum,  input.players.score_matrices.session.points) >= 3500
#         trait :player_has_high_sesh,  fn(:any?, input.players.score_matrices.session.points > 1000)
#         trait :player_level_ge_13,    input.players.level >= 13

#         value :player_tier do
#           on   player_total_ge_3500, "Legend"
#           on   player_has_high_sesh, "Clutch"
#           on   player_level_ge_13,   "Mid"
#           base "Newbie"
#         end

#         value :player_tier_zip, [input.players.name, player_tier]

#         # ---- traits for per-matrix cascade (scope [:players, :score_matrices])
#         trait :matrix_has_high_sesh, fn(:any?, input.players.score_matrices.session.points > 1000)
#         trait :matrix_sum_ge_1500,   fn(:sum,  input.players.score_matrices.session.points) >= 1500

#         value :matrix_label_cascade do
#           on   matrix_has_high_sesh, "Hot Matrix"
#           on   matrix_sum_ge_1500,   "Solid"
#           base "Meh"
#         end

#         value :matrix_labels_zip, [input.players.score_matrices, matrix_label_cascade]
#       end
#     end

#     let(:game_data) do
#       {
#         players: [
#           { name: "Alice", level: 15, score_matrices: [[800, 900], [1200, 1100]] },
#           { name: "Bob",   level: 12, score_matrices: [[600, 700, 800]] }
#         ]
#       }
#     end

#     it "handles cascades with trait-only conditions" do
#       result = GameAnalytics.from(game_data)

#       expect(result[:player_tier_zip]).to eq([
#                                                %w[Alice Legend], # 4000 ≥ 3500
#                                                %w[Bob Newbie] # none > 1000, level 12, sum 2100
#                                              ])

#       expect(result[:matrix_labels_zip]).to eq([
#                                                  [[[800, 900], "Solid"], # sum 1700 ≥ 1500, none > 1000
#                                                   [[1200, 1100], "Hot Matrix"]], # has > 1000
#                                                  [[[600, 700, 800], "Solid"]]
#                                                ])
#     end

#     it "evaluates matrix-level traits correctly" do
#       result = GameAnalytics.from(game_data)

#       # matrix_has_high_sesh should be per-matrix: [[false, true], [false]]
#       expect(result[:matrix_has_high_sesh]).to eq([[false, true], [false]])

#       # matrix_sum_ge_1500 should be per-matrix: [[true, true], [true]]
#       expect(result[:matrix_sum_ge_1500]).to eq([[true, true], [true]])
#     end

#     it "evaluates matrix cascade labels correctly" do
#       result = GameAnalytics.from(game_data)

#       # matrix_label_cascade should be per-matrix: [["Solid", "Hot Matrix"], ["Solid"]]
#       expect(result[:matrix_label_cascade]).to eq([["Solid", "Hot Matrix"], ["Solid"]])
#     end

#     it "handles cross-scope references correctly" do
#       result = GameAnalytics.from(game_data)

#       # Player-level traits should remain per-player
#       expect(result[:player_has_high_sesh]).to eq([true, false])  # Alice has, Bob doesn't
#       expect(result[:player_total_ge_3500]).to eq([true, false])   # Alice: 4000≥3500, Bob: 2100<3500

#       # Matrix-level should be per-matrix
#       expect(result[:matrix_has_high_sesh]).to eq([[false, true], [false]])
#     end

#     it "demonstrates constraint propagation through array zip" do
#       result = GameAnalytics.from(game_data)

#       # The key insight: matrix_labels_zip forces matrix_label_cascade to have [:players, :score_matrices] scope
#       # which then propagates to matrix_has_high_sesh and matrix_sum_ge_1500
#       matrices = result[:matrix_labels_zip]

#       # Alice has 2 matrices, Bob has 1 matrix
#       expect(matrices.length).to eq(2)
#       expect(matrices[0].length).to eq(2)  # Alice: 2 matrices
#       expect(matrices[1].length).to eq(1)  # Bob: 1 matrix

#       # Each element is [matrix_data, label]
#       alice_matrix_1 = matrices[0][0]
#       alice_matrix_2 = matrices[0][1]
#       bob_matrix_1 = matrices[1][0]

#       expect(alice_matrix_1).to eq([[800, 900], "Solid"])
#       expect(alice_matrix_2).to eq([[1200, 1100], "Hot Matrix"])
#       expect(bob_matrix_1).to eq([[600, 700, 800], "Solid"])
#     end
#   end

#   # describe "Separate Object and Element Arrays (expanded)" do
#   #   module GameAnalytics
#   #     extend Kumi::Schema

#   #     schema do
#   #       input do
#   #         # Object access for player metadata
#   #         array :players do
#   #           string  :name
#   #           integer :level
#   #           array :score_matrices do          # axis: :score_matrices
#   #             element :array, :session do     # axis: :session
#   #               element :integer, :points     # leaf
#   #             end
#   #           end
#   #         end
#   #       end

#   #       # ---------- Object-level aggregations (scalar results) ----------
#   #       value :player_names,  input.players.name
#   #       value :avg_level,     fn(:avg,  input.players.level)     # => 13.5
#   #       value :player_count,  fn(:size, input.players)           # => 2

#   #       # ---------- Element access variations ----------
#   #       # Flat list of ALL scores (ravel + flatten)
#   #       value :all_scores,    fn(:flatten, input.players.score_matrices.session.points)
#   #       # Grand total points across everyone (global reduce)
#   #       value :total_points,  fn(:sum,     input.players.score_matrices.session.points)

#   #       # Per-player totals (grouped-on-demand via array LUB = [:players])
#   #       value :total_points_by_player, [player_names, total_points]

#   #       # Per-player, per-matrix session sums:
#   #       # Use the raw container `input.players.score_matrices` to set LUB=[:players, :score_matrices]
#   #       # Then sum(points) groups by that required_scope, reducing only :session.
#   #       value :matrix_sums_zip,
#   #             [input.players.score_matrices,
#   #              fn(:sum, input.players.score_matrices.session.points)]

#   #       # Nested boolean tree (players → matrices → session) without flatten
#   #       value :high_score_flags_tree,
#   #             input.players.score_matrices.session.points > 1000

#   #       # Per-matrix flag: does THIS matrix have any score > 1000?
#   #       # LUB = [:players, :score_matrices] (from the first array element),
#   #       # so any? groups by player+matrix and reduces the :session axis only.
#   #       value :matrix_has_high_score_zip,
#   #             [input.players.score_matrices,
#   #              fn(:any?, input.players.score_matrices.session.points > 1000)]

#   #       # Global flag: any score > 1000 anywhere
#   #       value :has_high_scorer,
#   #             fn(:any?, fn(:flatten, high_score_flags_tree))
#   #     end
#   #   end

#   #   let(:game_data) do
#   #     {
#   #       players: [
#   #         { name: "Alice", level: 15, score_matrices: [[800, 900], [1200, 1100]] },
#   #         { name: "Bob",   level: 12, score_matrices: [[600, 700, 800]] }
#   #       ]
#   #     }
#   #   end

#   #   it "handles scalar, per-player and per-matrix groupings correctly" do
#   #     result = GameAnalytics.from(game_data)

#   #     # Object-level
#   #     expect(result[:player_names]).to eq(%w[Alice Bob])
#   #     expect(result[:avg_level]).to    eq(13.5)
#   #     expect(result[:player_count]).to eq(2)

#   #     # Flatten / global reductions
#   #     expect(result[:all_scores]).to   eq([800, 900, 1200, 1100, 600, 700, 800])
#   #     expect(result[:total_points]).to eq(6100) # 4000 + 2100

#   #     # Group to [:players]
#   #     expect(result[:total_points_by_player]).to eq([
#   #                                                     ["Alice", 4000], # 800+900 + 1200+1100
#   #                                                     ["Bob", 2100] # 600+700+800
#   #                                                   ])

#   #     # Group to [:players, :score_matrices] (and lift to nested arrays)
#   #     expect(result[:matrix_sums_zip]).to eq([
#   #                                              [[[800, 900], 1700], # Alice, matrix 0
#   #                                               [[1200, 1100], 2300]], # Alice, matrix 1
#   #                                              [[[600, 700, 800], 2100]] # Bob, matrix 0
#   #                                            ])

#   #     # Elementwise boolean tree: players → matrices → session
#   #     expect(result[:high_score_flags_tree]).to eq([
#   #                                                    [[false, false], [true, true]], # Alice: [800,900] <1000; [1200,1100] >1000
#   #                                                    [[false, false, false]] # Bob: all <1000
#   #                                                  ])

#   #     # Per-matrix any? (>1000)
#   #     expect(result[:matrix_has_high_score_zip]).to eq([
#   #                                                        [[[800, 900], false],
#   #                                                         [[1200, 1100], true]],
#   #                                                        [[[600, 700, 800], false]]
#   #                                                      ])

#   #     # Global any?
#   #     expect(result[:has_high_scorer]).to be true
#   #   end
#   # end

#   # describe "Multi-dimensional Element Arrays" do
#   #   module DataCubeAnalysis
#   #     extend Kumi::Schema

#   #     schema do
#   #       input do
#   #         # Pure element access for 3D data cube
#   #         array :data_cube do
#   #           element :array, :layer do
#   #             element :array, :row do
#   #               element :float, :value
#   #             end
#   #           end
#   #         end

#   #         # Object access for metadata
#   #         array :layer_metadata do
#   #           string :name
#   #           string :type
#   #         end
#   #       end

#   #       value :values_dimensions, fn(:size, input.data_cube.layer.row.value)
#   #       # Multi-dimensional operations with intuitive progressive path traversal

#   #       value :layers, fn(:size, input.data_cube) # Number of layers across the cube
#   #       value :rows_across_layers, fn(:size, input.data_cube.layer) # Rows across all layers
#   #       value :values_across_rows, fn(:size, input.data_cube.layer.row) # Values across all rows
#   #       value :leaf_values, fn(:size, input.data_cube.layer.row.value) # Total leaf values

#   #       value :all_values, fn(:flatten, input.data_cube.layer.row.value)
#   #       value :cube_sum, fn(:sum, all_values)
#   #       value :cube_stats, [fn(:min, all_values), fn(:max, all_values), fn(:avg, all_values)]

#   #       # Mixed with metadata
#   #       value :layer_names, input.layer_metadata.name
#   #       value :metadata_count, fn(:size, input.layer_metadata)
#   #     end
#   #   end

#   #   let(:cube_data) do
#   #     {
#   #       data_cube: [
#   #         [ # layer 0
#   #           [ # row 0
#   #             1.0, # value 0
#   #             2.0 # value 1
#   #           ],
#   #           [ # row 1
#   #             3.0, # value 0
#   #             4.0  # value 1
#   #           ]
#   #         ],
#   #         [ # layer 1
#   #           [ # row 0
#   #             5.0, # value 0
#   #             6.0 # value 1
#   #           ]
#   #         ],
#   #         [ # layer 2
#   #           [ # row 0
#   #             7.0, # value 0
#   #             8.0, # value 1
#   #             9.0 # value 2
#   #           ]
#   #         ]
#   #       ],
#   #       layer_metadata: [
#   #         { name: "Input Layer", type: "data" },
#   #         { name: "Hidden Layer", type: "computed" }
#   #       ]
#   #     }
#   #   end

#   #   it "handles complex multi-dimensional element access with object metadata" do
#   #     result = DataCubeAnalysis.from(cube_data)

#   #     puts
#   #     expect(result[:values_dimensions]).to eq(9) # 2 rows, 2 values per row

#   #     # Explanation of dimensions:
#   #     # - data_cube has 3 layers
#   #     # - Each layer has a varying number of rows
#   #     # - Each row has a varying number of values
#   #     # - The :size function is called at each level to count elements
#   #     #   - data_cube counts layers
#   #     #   - layer counts rows
#   #     #   - row counts values
#   #     #   - leaf_values counts all values across all rows in all layers
#   #     expect(result[:layers]).to eq(3) # 3 layers in the cube
#   #     expect(result[:rows_across_layers]).to eq(4) # 4 rows across all layers
#   #     expect(result[:values_across_rows]).to eq(9) # 9 values across all rows
#   #     expect(result[:leaf_values]).to eq(9) # 9 leaf values in total

#   #     # All values flattened to leaf elements
#   #     expect(result[:all_values]).to eq([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0])
#   #     expect(result[:cube_sum]).to eq(45.0) # Sum of 1+2+3+...+9
#   #     expect(result[:cube_stats]).to eq([1.0, 9.0, 5.0]) # [min, max, avg]

#   #     # Mixed with object access for metadata
#   #     expect(result[:layer_names]).to eq(["Input Layer", "Hidden Layer"])
#   #     expect(result[:metadata_count]).to eq(2)
#   #   end
#   # end
# end
