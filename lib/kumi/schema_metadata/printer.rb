# frozen_string_literal: true

module Kumi
  class SchemaMetadata
    # Renders {SchemaMetadata} as a compact, readable report — the algebra of the
    # schema in one screen. Designed to be dropped into an LLM prompt: every
    # input's type/domain/shape, every definition's expression and
    # dependencies, and the evaluation order, with no source file required.
    #
    #   INPUTS (free variables)
    #     age              : integer  in 18..99
    #     income           : float
    #     items[].qty      : integer  in 1..100      (axis: items)
    #     items[].price    : float                   (axis: items)
    #
    #   DEFINITIONS (value/trait := expression)
    #     adult     trait  boolean          := (input.age >= 18)
    #     line      value  float   [items]  := (input.items.item.qty * input.items.item.price)
    #     subtotal  value  float            := sum(line)        reads: line
    #
    #   EVALUATION ORDER
    #     line -> subtotal -> adult -> wealthy -> tier
    class Printer
      def initialize(metadata)
        @md = metadata
      end

      def render
        sections = [legend, inputs_section, definitions_section, order_section]
        sections << imports_section unless @md.imported_names.empty?
        sections.compact.join("\n\n")
      end

      private

      # A one-block reading guide. `@[a x b]` is where a value an input lives;
      # `[a x b]` is a value's shape (the axes it spans); `sum`/`count` etc.
      # collapse an axis (the result is one rank shallower).
      def legend
        <<~LEGEND.strip
          # Schema algebra. Notation:
          #   @[a x b]  input lives inside arrays a, b (one element per a,b pair)
          #   [a x b]   a value's shape: it has one result per a,b pair
          #   scalar    a single value (no array axes)
          #   reductions (sum, count, min, ...) collapse the innermost axis
        LEGEND
      end

      def inputs_section
        rows = @md.input_fields.map do |f|
          dom = f.domain ? "  in #{f.domain}" : ""
          shape = f.in_array ? "  @[#{f.axes.join(' x ')}]" : ""
          ["  #{input_name(f)}", ": #{f.type}#{dom}", shape]
        end
        "INPUTS (free variables)\n#{align(rows)}"
      end

      # The access path a user writes: the array axes plus the leaf key, with the
      # element-selector keys (region, office, ...) dropped. Lossless because it
      # is built from authoritative axis data, not a positional guess:
      #   - org salary -> regions.offices.teams.employees.salary
      #   - array-of-array (input.x.y.v) -> x.y.v
      # When the leaf *is* the array element (no inner key), it already equals
      # the last axis, so we don't append it twice.
      def input_name(field)
        return field.address unless field.in_array

        leaf = field.path.last
        parts = field.axes.dup
        parts << leaf unless parts.last == leaf
        parts.join(".")
      end

      # One block per definition, so wide expressions and cascades stay readable
      # instead of running off a single aligned line.
      def definitions_section
        blocks = @md.definitions.values.map do |d|
          shape = d.axes.empty? ? "scalar" : "[#{d.axes.join(' x ')}]"
          header = "  #{d.name}  (#{d.kind} : #{d.type} #{shape})"
          lines = [header, "      = #{d.expression}"]
          lines << "      reads: #{d.reads.join(', ')}" unless d.reads.empty?
          lines.join("\n")
        end
        "DEFINITIONS\n#{blocks.join("\n\n")}"
      end

      def order_section
        order = @md.evaluation_order
        return nil if order.empty?

        "EVALUATION ORDER (topological)\n  #{order.join(' -> ')}"
      end

      def imports_section
        "IMPORTS (inlined at compile time)\n  #{@md.imported_names.join(', ')}"
      end

      # Left-align columns to their widest cell for a clean table.
      def align(rows)
        return "" if rows.empty?

        widths = Array.new(rows.map(&:length).max, 0)
        rows.each { |row| row.each_with_index { |cell, i| widths[i] = [widths[i], cell.to_s.length].max } }
        rows.map do |row|
          row.each_with_index.map { |cell, i| cell.to_s.ljust(i == row.length - 1 ? 0 : widths[i] + 2) }
             .join.rstrip
        end.join("\n")
      end
    end
  end
end
