# frozen_string_literal: true

RSpec.describe "Element Access Mode Integration" do
  describe "2D Arrays (Matrices)" do
    module MatrixSchema
      extend Kumi::Schema

      schema do
        input do
          array :matrix do
            element :integer, :cell
          end
        end

        value :matrix_size, fn(:size, input.matrix)
        value :total_cells, fn(:size, fn(:flatten, input.matrix.cell))
        value :all_cells, fn(:flatten, input.matrix.cell)
        value :row_sizes, fn(:size, input.matrix.cell)
      end
    end

    let(:matrix_data) do
      {
        matrix: [
          [1, 2, 3],      # Row 1: 3 cells
          [4, 5],         # Row 2: 2 cells
          [6, 7, 8, 9]    # Row 3: 4 cells
        ]
      }
    end

    it "handles 2D matrix operations correctly" do
      result = MatrixSchema.from(matrix_data)

      expect(result[:matrix_size]).to eq(3)      # 3 rows
      expect(result[:total_cells]).to eq(9)      # 3+2+4 = 9 total cells
      expect(result[:all_cells]).to eq([1, 2, 3, 4, 5, 6, 7, 8, 9])
      expect(result[:row_sizes]).to eq(9)        # Size of cell data with progressive traversal
    end
  end

  describe "3D Arrays (Cube of Matrices)" do
    module CubeSchema
      extend Kumi::Schema

      schema do
        input do
          array :cube do
            element :array, :matrix do
              element :integer, :cell
            end
          end
        end

        # Immediate structure counts
        value :n_layers, fn(:size, input.cube)
        value :n_matrices, fn(:size, input.cube.matrix)
        value :n_rows, fn(:size, input.cube.matrix.cell)

        # Flattened counts (all flatten to same result due to element access mode)
        value :total_elements, fn(:size, fn(:flatten, input.cube.matrix.cell))
        value :sum_all, fn(:sum, fn(:flatten, input.cube.matrix.cell))
        value :max_value, fn(:max, fn(:flatten, input.cube.matrix.cell))

        # Access patterns
        value :all_values_flat, fn(:flatten, input.cube.matrix.cell)
      end
    end

    let(:cube_data) do
      {
        cube: [
          [                           # Layer 1
            [[1, 2], [3, 4]],         # Matrix 1: 2x2
            [[5, 6, 7]]               # Matrix 2: 1x3
          ],
          [                           # Layer 2
            [[8, 9], [10, 11], [12, 13]] # Matrix 1: 3x2
          ]
        ]
      }
    end

    it "handles 3D cube operations correctly" do
      result = CubeSchema.from(cube_data)

      # Structure counts
      expect(result[:n_layers]).to eq(2)         # 2 layers in cube
      expect(result[:n_matrices]).to eq(3)       # 3 matrices with progressive traversal
      expect(result[:n_rows]).to eq(6)           # 6 total rows with progressive traversal

      # Flattened operations
      expect(result[:total_elements]).to eq(13)  # All individual cell values: 1-13
      expect(result[:sum_all]).to eq(91)         # Sum of 1+2+3+...+13 = 91
      expect(result[:max_value]).to eq(13)       # Maximum value

      # Verify flattened structure
      expect(result[:all_values_flat]).to eq([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13])
    end
  end

  describe "4D Arrays (Hypercube)" do
    module HypercubeSchema
      extend Kumi::Schema

      schema do
        input do
          array :hypercube do
            element :array, :cube do
              element :array, :matrix do
                element :integer, :cell
              end
            end
          end
        end

        # Progressive depth access
        value :level_0, fn(:size, input.hypercube)
        value :level_1, fn(:size, input.hypercube.cube)
        value :level_2, fn(:size, input.hypercube.cube.matrix)
        value :level_3, fn(:size, input.hypercube.cube.matrix.cell)

        # Total element counts at each level
        value :total_cubes, fn(:size, fn(:flatten, input.hypercube.cube))
        value :total_matrices, fn(:size, fn(:flatten, input.hypercube.cube.matrix))
        value :total_rows, fn(:size, fn(:flatten, input.hypercube.cube.matrix))
        value :total_cells, fn(:size, fn(:flatten, input.hypercube.cube.matrix.cell))

        # Sample complex operations
        value :max_cell, fn(:max, fn(:flatten, input.hypercube.cube.matrix.cell))
        value :sum_all, fn(:sum, fn(:flatten, input.hypercube.cube.matrix.cell))
        value :cell_count_by_depth, [
          fn(:size, input.hypercube),
          fn(:size, input.hypercube.cube),
          fn(:size, input.hypercube.cube.matrix),
          fn(:size, input.hypercube.cube.matrix.cell)
        ]
      end
    end

    let(:hypercube_data) do
      {
        hypercube: [
          [                              # Dimension 1, Cube 1
            [                            # Layer 1
              [[1, 2], [3, 4]],          # Matrix 1: 2x2 = 4 cells
              [[5, 6]]                   # Matrix 2: 1x2 = 2 cells
            ],
            [                            # Layer 2
              [[7, 8, 9]]                # Matrix 1: 1x3 = 3 cells
            ]
          ],
          [                              # Dimension 1, Cube 2
            [                            # Layer 1
              [[10, 11, 12], [13, 14]]   # Matrix 1: 2 rows = 5 cells
            ]
          ]
        ]
      }
    end

    it "handles 4D hypercube operations correctly" do
      result = HypercubeSchema.from(hypercube_data)

      # Progressive depth access with progressive path traversal
      expect(result[:level_0]).to eq(2)          # 2 top-level hypercubes
      expect(result[:level_1]).to eq(3)          # 3 cubes/layers total
      expect(result[:level_2]).to eq(4)          # 4 matrices total
      expect(result[:level_3]).to eq(6)          # 6 rows total

      # Total counts after flattening - all flatten to leaf elements in element access mode
      expect(result[:total_cubes]).to eq(14)     # All flatten to leaf elements (14 total numbers)
      expect(result[:total_matrices]).to eq(14)  # All flatten to leaf elements
      expect(result[:total_rows]).to eq(14)      # All flatten to leaf elements
      expect(result[:total_cells]).to eq(14)     # 4 + 2 + 3 + 5 = 14 individual numbers

      # Complex operations
      expect(result[:max_cell]).to eq(14)
      expect(result[:sum_all]).to eq(105) # 1+2+3+...+14 = 105
      expect(result[:cell_count_by_depth]).to eq([2, 3, 4, 6])
    end
  end

  describe "Mixed Element and Object Access" do
    module MixedSchema
      extend Kumi::Schema

      schema do
        input do
          array :departments do # Object access (default)
            string :name
            array :teams do            # Object access (default)
              string :team_name
              array :members do        # Element access mode - NOTE: This is a limitation
                element :string, :employee_name
              end
            end
          end
        end

        # Object access for structured data
        value :dept_names, input.departments.name
        value :team_names, input.departments.teams.team_name

        # Direct member array access (bypassing element access for now)
        value :member_arrays, input.departments.teams.members
        value :flattened_members, fn(:flatten, input.departments.teams.members)
        value :total_member_count, fn(:size, fn(:flatten, input.departments.teams.members))
      end
    end

    let(:mixed_data) do
      {
        departments: [
          {
            name: "Engineering",
            teams: [
              {
                team_name: "Backend",
                members: [%w[Alice Bob], ["Charlie"]]
              },
              {
                team_name: "Frontend",
                members: [%w[Diana Eve Frank]]
              }
            ]
          },
          {
            name: "Design",
            teams: [
              {
                team_name: "UX",
                members: [["Grace"], %w[Henry Ivy]]
              }
            ]
          }
        ]
      }
    end

    it "handles mixed access modes with current limitations" do
      result = MixedSchema.from(mixed_data)

      # Object access works normally
      expect(result[:dept_names]).to eq(%w[Engineering Design])
      expect(result[:team_names]).to eq([%w[Backend Frontend], ["UX"]])

      # Member arrays accessed directly (element access has limitations when mixed with object access)
      expected_member_arrays = [
        [[%w[Alice Bob], ["Charlie"]], [%w[Diana Eve Frank]]],
        [[["Grace"], %w[Henry Ivy]]]
      ]
      expect(result[:member_arrays]).to eq(expected_member_arrays)

      # Flattening works on the member arrays
      expect(result[:flattened_members]).to eq(%w[
                                                 Alice Bob Charlie Diana Eve Frank Grace Henry Ivy
                                               ])
      expect(result[:total_member_count]).to eq(9)
    end
  end

  describe "Scientific Computing Use Cases" do
    module TensorSchema
      extend Kumi::Schema

      schema do
        input do
          array :tensor do # 4D tensor: batch x channel x height x width
            element :array, :channel do
              element :array, :row do
                element :float, :pixel
              end
            end
          end
        end

        # Tensor dimensions
        value :batch_size, fn(:size, input.tensor)
        value :channels, fn(:size, fn(:flatten, input.tensor.channel))
        value :height, fn(:size, fn(:flatten, input.tensor.channel.row))
        value :width, fn(:size, fn(:flatten, input.tensor.channel.row.pixel))

        # Statistical operations across dimensions
        value :mean_pixel_value, fn(:flat_avg, input.tensor.channel.row.pixel)
        value :max_pixel_value, fn(:flat_max, input.tensor.channel.row.pixel)
        value :min_pixel_value, fn(:flat_min, input.tensor.channel.row.pixel)
        value :sum_pixel_value, fn(:flat_sum, input.tensor.channel.row.pixel)
        value :pixel_count, fn(:flat_size, input.tensor.channel.row.pixel)

        # Channel-wise statistics
        value :channel_maxes, fn(:max, input.tensor.channel.row.pixel)
      end
    end

    let(:tensor_data) do
      {
        tensor: [
          [                                    # Batch 1
            [                                  # Channel 1 (RGB Red)
              [0.1, 0.2, 0.3],                # Row 1
              [0.4, 0.5, 0.6]                 # Row 2
            ],
            [ # Channel 2 (RGB Green)
              [0.7, 0.8, 0.9],                # Row 1
              [1.0, 1.1, 1.2]                 # Row 2
            ]
          ],
          [                                    # Batch 2
            [                                  # Channel 1
              [1.3, 1.4],                     # Row 1 (different dimensions)
              [1.5, 1.6],                     # Row 2
              [1.7, 1.8]                      # Row 3
            ]
          ]
        ]
      }
    end

    it "handles tensor operations like a scientific computing framework" do
      result = TensorSchema.from(tensor_data)

      # Tensor shape analysis - element access mode flattens all to leaf elements
      expect(result[:batch_size]).to eq(2)       # 2 batches
      expect(result[:channels]).to eq(18)        # All flatten to 18 pixel values
      expect(result[:height]).to eq(18)          # All flatten to 18 pixel values
      expect(result[:width]).to eq(18)           # All flatten to 18 pixel values
      expect(result[:pixel_count]).to eq(18)     # 18 total pixel values

      # Statistical operations - calculated from 0.1 to 1.8 (18 values)
      expected_sum = (0.1..1.8).step(0.1).sum.round(1) # Sum from 0.1 to 1.8 step 0.1
      expected_mean = expected_sum / 18.0

      expect(result[:mean_pixel_value]).to be_within(0.01).of(0.95)  # Average of 0.1 to 1.8
      expect(result[:max_pixel_value]).to eq(1.8)
      expect(result[:min_pixel_value]).to eq(0.1)
      expect(result[:sum_pixel_value]).to be_within(0.01).of(17.1)   # Sum of 0.1+0.2+...+1.8

      # Channel-wise statistics - max value across all dimensions
      expect(result[:channel_maxes]).to eq(1.8) # Maximum pixel value across all channels
    end
  end

  describe "Game Development Use Cases" do
    module GameWorldSchema
      extend Kumi::Schema

      schema do
        input do
          array :world_grid do # 3D world: layers x rows x columns
            element :array, :layer do
              element :array, :row do
                element :integer, :tile_id
              end
            end
          end
        end

        # World analysis
        value :world_layers, fn(:size, input.world_grid)
        value :total_tiles, fn(:size, fn(:flatten, input.world_grid.layer.row.tile_id))
        value :unique_tiles, fn(:unique, fn(:flatten, input.world_grid.layer.row.tile_id))
        value :tile_count, fn(:size, fn(:unique, fn(:flatten, input.world_grid.layer.row.tile_id)))

        # Gameplay mechanics
        trait :has_water, fn(:include?, fn(:flatten, input.world_grid.layer.row.tile_id), 1)
        trait :has_mountains, fn(:include?, fn(:flatten, input.world_grid.layer.row.tile_id), 3)

        value :world_type do
          on has_water, has_mountains, "diverse"
          on has_water, "coastal"
          on has_mountains, "mountainous"
          base "plains"
        end
      end
    end

    let(:game_world_data) do
      {
        world_grid: [
          [                      # Ground layer
            [[0, 0, 1],          # Row 1: grass, grass, water
             [2, 0, 1]],         # Row 2: dirt, grass, water
            [[1, 1, 1],          # Row 1: all water
             [3, 3, 0]]          # Row 2: mountain, mountain, grass
          ],
          [                      # Sky layer (simpler)
            [[4, 4, 4, 4]]       # Row 1: all clouds
          ]
        ]
      }
    end

    it "handles game world analysis correctly" do
      result = GameWorldSchema.from(game_world_data)

      expect(result[:world_layers]).to eq(2)
      expect(result[:total_tiles]).to eq(16)      # 6 + 6 + 4 = 16 tiles total
      expect(result[:unique_tiles]).to contain_exactly(0, 1, 2, 3, 4)
      expect(result[:tile_count]).to eq(5)        # 5 unique tile types

      expect(result[:has_water]).to be true       # Contains tile_id 1 (water)
      expect(result[:has_mountains]).to be true   # Contains tile_id 3 (mountain)
      expect(result[:world_type]).to eq("diverse") # Has both water and mountains
    end
  end

  describe "Data Analysis Use Cases" do
    module DataAnalysisSchema
      extend Kumi::Schema

      schema do
        input do
          array :experiments do          # Multiple experiments
            element :array, :trial do    # Each experiment has multiple trials
              element :array, :measurement do # Each trial has multiple measurements
                element :float, :value
              end
            end
          end
        end

        # Hierarchical statistics
        value :experiment_count, fn(:size, input.experiments)
        value :total_trials, fn(:size, fn(:flatten, input.experiments.trial.measurement))
        value :total_measurements, fn(:size, fn(:flatten, input.experiments.trial.measurement.value))

        # Statistical analysis across all data
        value :global_sum, fn(:sum, fn(:flatten, input.experiments.trial.measurement.value))
        value :global_min, fn(:min, fn(:flatten, input.experiments.trial.measurement.value))
        value :global_max, fn(:max, fn(:flatten, input.experiments.trial.measurement.value))

        # Experiment-level analysis
        value :experiment_sums, fn(:sum, input.experiments.trial.measurement.value)
        value :experiment_maxes, fn(:max, input.experiments.trial.measurement.value)
      end
    end

    let(:data_analysis_data) do
      {
        experiments: [
          [                           # Experiment 1
            [                         # Trial 1
              [[1.1, 1.2, 1.3]],      # Measurement set 1
              [[1.4, 1.5]]            # Measurement set 2
            ],
            [                         # Trial 2
              [[2.1, 2.2]]            # Measurement set 1
            ]
          ],
          [                           # Experiment 2
            [                         # Trial 1
              [[3.1, 3.2, 3.3, 3.4]] # Measurement set 1
            ]
          ]
        ]
      }
    end

    it "handles hierarchical data analysis correctly" do
      result = DataAnalysisSchema.from(data_analysis_data)

      expect(result[:experiment_count]).to eq(2)
      expect(result[:total_trials]).to eq(11)        # All flatten to 11 leaf values in element access mode
      expect(result[:total_measurements]).to eq(11)  # 3+2+2+4 = 11 values

      # Statistical analysis
      expected_sum = 1.1 + 1.2 + 1.3 + 1.4 + 1.5 + 2.1 + 2.2 + 3.1 + 3.2 + 3.3 + 3.4
      expect(result[:global_sum]).to be_within(0.01).of(expected_sum) # Sum of all 11 values
      expect(result[:global_min]).to eq(1.1)
      expect(result[:global_max]).to eq(3.4)

      # Experiment-level results - in element access mode, these aggregate to single values
      expect(result[:experiment_sums]).to be_within(0.01).of(expected_sum) # Sum of all values
      expect(result[:experiment_maxes]).to eq(3.4) # Maximum across all values
    end
  end

  describe "Edge Cases and Error Handling" do
    module EdgeCaseSchema
      extend Kumi::Schema

      schema do
        input do
          array :data do
            element :array, :nested do
              element :integer, :value
            end
          end
        end

        value :safe_size, fn(:size, input.data)
        value :nested_size, fn(:size, input.data.nested)
        value :deep_flatten, fn(:flatten, input.data.nested.value)
      end
    end

    it "handles empty arrays correctly" do
      result = EdgeCaseSchema.from({ data: [] })

      expect(result[:safe_size]).to eq(0)
      expect(result[:nested_size]).to eq(0)
      expect(result[:deep_flatten]).to eq([])
    end

    it "handles arrays with empty nested arrays" do
      result = EdgeCaseSchema.from({ data: [[], []] })

      expect(result[:safe_size]).to eq(2)
      expect(result[:nested_size]).to eq(0)  # Empty nested arrays have no elements
      expect(result[:deep_flatten]).to eq([])
    end

    it "handles mixed empty and non-empty arrays" do
      result = EdgeCaseSchema.from({ data: [[], [[1, 2]], []] })

      expect(result[:safe_size]).to eq(3)
      expect(result[:nested_size]).to eq(1)  # Only one non-empty element at nested level
      expect(result[:deep_flatten]).to eq([1, 2])
    end
  end
end
