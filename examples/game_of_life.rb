$LOAD_PATH.unshift(File.join(__dir__, "..", "lib"))
require "kumi"

NEIGHBOR_DELTAS = [[-1, -1], [-1, 0], [-1, 1], [0, -1], [0, 1], [1, -1], [1, 0], [1, 1]]
begin
  # in a block so we dont define this globally
  def neighbor_cells_sum_method(cells, row, col, height, width)
    # Calculate neighbor indices with wraparound
    NEIGHBOR_DELTAS.map do |dr, dc|
      neighbor_row = (row + dr) % height
      neighbor_col = (col + dc) % width
      neighbor_index = (neighbor_row * width) + neighbor_col
      cells[neighbor_index]
    end.sum
  end
  Kumi::FunctionRegistry.register_with_metadata(:neighbor_cells_sum, method(:neighbor_cells_sum_method),
                                                return_type: :integer, arity: 5,
                                                param_types: %i[array integer integer integer integer],
                                                description: "Get neighbor cells for Conway's Game of Life")
end

module GameOfLife
  extend Kumi::Schema
  WIDTH = 50
  HEIGHT = 30

  schema do
    # Complete Game of Life engine - computes entire next generation
    input do
      array :cells, elem: { type: :integer }
    end

    # Generate next state for every cell in the grid
    next_cell_values = []

    (0...HEIGHT).each do |row|
      (0...WIDTH).each do |col|
        # Neighbor count and current state for this cell
        cell_index = (row * WIDTH) + col
        value :"neighbor_sum_#{cell_index}", fn(:neighbor_cells_sum, input.cells, row, col, HEIGHT, WIDTH)

        # Game of Life rules: (alive && neighbors == 2) || (neighbors == 3)
        trait :"cell_#{cell_index}_alive",
              ((input.cells[cell_index] == 1) & (ref(:"neighbor_sum_#{cell_index}") == 2)) |
              (ref(:"neighbor_sum_#{cell_index}") == 3)

        # Next state for this cell
        value :"cell_#{cell_index}_next" do
          on :"cell_#{cell_index}_alive", 1
          base 0
        end

        next_cell_values << ref(:"cell_#{cell_index}_next")
      end
    end

    # Complete next generation as array
    value :next_cells, next_cell_values

    # Render current state as visual string
    value :cell_symbols, fn(:map_conditional, input.cells, 1, "█", " ")
    value :grid_rows, fn(:each_slice, cell_symbols, WIDTH)
    value :rendered_grid, fn(:map_join_rows, grid_rows, "", "\n")
  end
end

# # Helper to pretty‑print the grid
def render(cells, width)
  cells.each_slice(width) do |row|
    puts row.map { |v| v == 1 ? "█" : " " }.join
  end
end

# # Bootstrap a simple glider on a 10×10 grid
width  = GameOfLife::WIDTH
height = GameOfLife::HEIGHT
cells  = Array.new(width * height, 0)
# Glider pattern
[[1, 1], [2, 3], [3, 1], [3, 2], [3, 3]].each { |r, c| cells[(r * width) + c] = 1 }

compiled_schema = GameOfLife.__compiled_schema__
wrapper = Kumi::EvaluationWrapper.new(cells: cells)

10_000.times do |gen|
  system("clear") || system("cls")
  puts "Conway's Game of Life - Generation #{gen}"
  puts ""

  # Render using Kumi instead of Ruby function!
  rendered_output = compiled_schema.evaluate_binding(:rendered_grid, wrapper)
  puts rendered_output

  # Calculate next generation with single schema call!
  result = compiled_schema.evaluate_binding(:next_cells, wrapper)
  cells.replace(result)
  wrapper.clear

  sleep 0.001
end
