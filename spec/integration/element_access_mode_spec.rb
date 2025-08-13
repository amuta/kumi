# frozen_string_literal: true

RSpec.describe "Element Access Mode Integration (simplified)" do
  # 3D Arrays (cube)
  describe "3D Arrays (cube)" do
    module CubeSchema
      extend Kumi::Schema
      schema do
        input do
          array :cube do
            element :array, :layer do
              element :array, :matrix do
                element :integer, :cell
              end
            end
          end
        end

        value :cube,  input.cube
        value :layer, input.cube.layer
        value :matrix, input.cube.layer.matrix
        value :cell,   input.cube.layer.matrix.cell
      end
    end

    let(:cube_data) do
      { cube: [ # cube
        [ # layer 1
          [ # matrix 1
            [1, 2], # cell 1
            [3, 4]  # cell 2
          ],
          [[5, 6, 7]] # matrix 2
        ],
        [ # layer 2
          [ # matrix 2
            [8, 9], # cell 3
            [10, 11], # cell 4
            [12, 13] # cell 52
          ]
        ]
      ] }
    end

    it "materializes containers as scalars" do
      r = CubeSchema.from(cube_data)
      expect(r[:cube]).to   eq(cube_data[:cube])
      expect(r[:layer]).to  eq(cube_data[:cube])
      expect(r[:matrix]).to eq(cube_data[:cube])
    end
  end

  # describe "2D Arrays (matrix)" do
  #   module MatrixSchema
  #     extend Kumi::Schema
  #     schema do
  #       input do
  #         array :matrix do
  #           element :integer, :cell
  #         end
  #       end

  #       value :matrix_copy,   input.matrix
  #       value :matrix_size,   fn(:size, input.matrix) # scalar: rows
  #       value :row_sizes, fn(:size, input.matrix.cell) # vec: per-row sizes
  #       value :row_sizes_again,     fn(:size, input.matrix.cell) # scalar: flat list
  #       value :all_cells_flat, fn(:flatten, input.matrix.cell) # scalar list
  #       value :total_cells, fn(:size, fn(:flatten, input.matrix.cell)) # scalar: count
  #     end
  #   end

  #   let(:matrix_data) { { matrix: [[1, 2, 3], [4, 5], [6, 7, 8, 9]] } }

  #   it "handles 2D operations" do
  #     r = MatrixSchema.from(matrix_data)
  #     expect(r[:matrix_copy]).to eq(matrix_data[:matrix])
  #     expect(r[:matrix_size]).to eq(3)
  #     expect(r[:row_sizes]).to eq([3, 2, 4])
  #     expect(r[:row_sizes_again]).to eq([3, 2, 4])
  #     expect(r[:all_cells_flat]).to eq([1, 2, 3, 4, 5, 6, 7, 8, 9])
  #     expect(r[:total_cells]).to eq(9)
  #   end
  # end

  # describe "Mixed object/element access" do
  #   module MixedSchema
  #     extend Kumi::Schema
  #     schema do
  #       input do
  #         array :departments do
  #           string :name
  #           array :teams do
  #             string :team_name
  #             array :members do
  #               element :string, :employee_name
  #             end
  #           end
  #         end
  #       end

  #       value :dept_names,        input.departments.name
  #       value :team_names,        input.departments.teams.team_name
  #       value :member_arrays,     input.departments.teams.members
  #       value :flattened_members, fn(:flatten, input.departments.teams.members)
  #       value :total_members,     fn(:size, fn(:flatten, input.departments.teams.members))
  #     end
  #   end

  #   let(:mixed_data) do
  #     { departments: [
  #       { name: "Engineering",
  #         teams: [
  #           { team_name: "Backend",  members: [%w[Alice Bob], ["Charlie"]] },
  #           { team_name: "Frontend", members: [%w[Diana Eve Frank]] }
  #         ] },
  #       { name: "Design",
  #         teams: [
  #           { team_name: "UX", members: [["Grace"], %w[Henry Ivy]] }
  #         ] }
  #     ] }
  #   end

  #   it "handles mixed access" do
  #     r = MixedSchema.from(mixed_data)
  #     expect(r[:dept_names]).to eq(%w[Engineering Design])
  #     expect(r[:team_names]).to eq([%w[Backend Frontend], ["UX"]])
  #     expect(r[:member_arrays]).to eq([
  #                                       [[%w[Alice Bob], ["Charlie"]], [%w[Diana Eve Frank]]],
  #                                       [[["Grace"], %w[Henry Ivy]]]
  #                                     ])
  #     expect(r[:flattened_members]).to eq(%w[Alice Bob Charlie Diana Eve Frank Grace Henry Ivy])
  #     expect(r[:total_members]).to eq(9)
  #   end
  # end

  # describe "Edge cases" do
  #   module EdgeCaseSchema
  #     extend Kumi::Schema
  #     schema do
  #       input do
  #         array :data do
  #           element :array, :nested do
  #             element :integer, :value
  #           end
  #         end
  #       end
  #       value :safe_size,   fn(:size, input.data)                 # scalar
  #       value :nested_size, fn(:size, input.data.nested)          # vec
  #       value :deep_flatten, fn(:flatten, input.data.nested.value) # scalar list
  #     end
  #   end

  #   it "empty top-level" do
  #     r = EdgeCaseSchema.from({ data: [] })
  #     expect(r[:safe_size]).to eq(0)
  #     expect(r[:nested_size]).to eq([]) # vector over empty
  #     expect(r[:deep_flatten]).to eq([])
  #   end

  #   it "arrays with empty nested arrays" do
  #     r = EdgeCaseSchema.from({ data: [[], []] })
  #     expect(r[:safe_size]).to eq(2)
  #     expect(r[:nested_size]).to eq([0, 0])
  #     expect(r[:deep_flatten]).to eq([])
  #   end

  #   it "mixed empty and non-empty" do
  #     r = EdgeCaseSchema.from({ data: [[], [[1, 2]], []] })
  #     expect(r[:safe_size]).to eq(3)
  #     expect(r[:nested_size]).to eq([0, 1, 0])
  #     expect(r[:deep_flatten]).to eq([1, 2])
  #   end
  # end
end
