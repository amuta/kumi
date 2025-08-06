# frozen_string_literal: true

RSpec.describe "Element Access Mode Integration" do
  describe "2D Arrays (Matrices)" do
    ENV["DEBUG_COMPILER"] = "true"
    module GridSchema
      extend Kumi::Schema

      schema do
        input do
          array :grid do
            element :array, :rows do
              element :integer, :cell
            end
          end
        end

        value :grid_size, fn(:size, input.grid)
        value :rows_sizes, fn(:size, input.grid.rows)
        value :cells_size, fn(:size, input.grid.rows.cell)
        value :all_cells,   fn(:flatten, input.grid.rows.cell)
        value :total_cells, fn(:size, fn(:flatten, input.grid.rows.cell))

        trait :any_cell_greater_than_10, input.grid.rows.cell > 10
      end
    end
    ENV["DEBUG_COMPILER"] = nil

    let(:matrix_data) do
      {
        grid: [
          [0],            # Row 0: 1 cell
          [1, 2, 3],      # Row 1: 3 cells
          [4, 5],         # Row 2: 2 cells
          [6, 7, 8, 9]    # Row 3: 4 cells
        ]
      }
    end

    it "handles 2D matrix operations correctly" do
      result = GridSchema.from(matrix_data)

      puts result.evaluate
      # {:table_size=>4, :rows_sizes=>4, :all_cells=>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9], :total_cells=>10}
      expect(result[:table_size]).to eq(3) # 3 rows
      expect(result[:rows_sizes]).to eq([1, 3, 2, 4]) # Size of each row, preserving structure
      expect(result[:cells_sizes]).to eq([[1], [3], [2], [4]]) # Size of each row, preserving structure
      expect(result[:all_cells]).to eq([1, 2, 3, 4, 5, 6, 7, 8, 9]) # Flattened all cells
      expect(result[:total_cells]).to eq(9) # 3+2+
      expect(result[:any_cell_greater_than_10]).to eq([false, false, false, false]) # No cells > 10
    end
  end
end
