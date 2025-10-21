# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Error Handling with Location Information" do
  describe "LocatedError access patterns" do
    it "exposes location components via convenience methods" do
      location = Kumi::Syntax::Location.new(file: "test.rb", line: 42, column: 10)
      error = Kumi::Core::Errors::SemanticError.new("Test error", location)

      # Direct access via convenience methods
      expect(error.location_file).to eq("test.rb")
      expect(error.location_line).to eq(42)
      expect(error.location_column).to eq(10)
    end

    it "provides path alias for file" do
      location = Kumi::Syntax::Location.new(file: "/path/to/schema.rb", line: 5, column: 0)
      error = Kumi::Core::Errors::SemanticError.new("Test", location)

      expect(error.path).to eq("/path/to/schema.rb")
      expect(error.path).to eq(error.location_file)
    end

    it "provides line and column aliases" do
      location = Kumi::Syntax::Location.new(file: "schema.rb", line: 100, column: 25)
      error = Kumi::Core::Errors::SemanticError.new("Test", location)

      expect(error.line).to eq(100)
      expect(error.column).to eq(25)
    end

    it "checks if location information is present" do
      with_location = Kumi::Core::Errors::SemanticError.new(
        "Error with location",
        Kumi::Syntax::Location.new(file: "test.rb", line: 10, column: 0)
      )
      without_location = Kumi::Core::Errors::SemanticError.new("Error without location")

      expect(with_location.has_location?).to be true
      expect(without_location.has_location?).to be_falsy # Could be nil or false
    end

    it "handles nil location gracefully" do
      error = Kumi::Core::Errors::SemanticError.new("Test error", nil)

      expect(error.location_file).to be_nil
      expect(error.location_line).to be_nil
      expect(error.location_column).to be_nil
      expect(error.has_location?).to be_falsy # Could be nil or false
    end
  end

  describe "ErrorEntry location access" do
    it "extracts location components from ErrorEntry" do
      location = Kumi::Syntax::Location.new(file: "app/schema.rb", line: 25, column: 8)
      entry = Kumi::Core::ErrorReporter.create_error(
        "Something went wrong",
        location: location,
        type: :semantic
      )

      expect(entry.file).to eq("app/schema.rb")
      expect(entry.line).to eq(25)
      expect(entry.column).to eq(8)
      expect(entry.path).to eq("app/schema.rb")
    end

    it "validates location information in ErrorEntry" do
      valid_location = Kumi::Syntax::Location.new(file: "test.rb", line: 1, column: 0)
      valid_entry = Kumi::Core::ErrorReporter.create_error(
        "Error",
        location: valid_location
      )

      expect(valid_entry.valid_location?).to be true
      expect(valid_entry.location?).to be true
    end

    it "handles missing location in ErrorEntry" do
      entry = Kumi::Core::ErrorReporter.create_error("Error without location")

      expect(entry.file).to be_nil
      expect(entry.line).to be_nil
      expect(entry.column).to be_nil
      expect(entry.valid_location?).to be_falsy # Could be nil or false
      expect(entry.location?).to be_falsy
    end
  end

  describe "error extraction patterns" do
    it "captures all error locations from error array" do
      errors = [
        Kumi::Core::ErrorReporter.create_error(
          "Error 1",
          location: Kumi::Syntax::Location.new(file: "a.rb", line: 10, column: 0)
        ),
        Kumi::Core::ErrorReporter.create_error(
          "Error 2",
          location: Kumi::Syntax::Location.new(file: "b.rb", line: 20, column: 5)
        ),
        Kumi::Core::ErrorReporter.create_error("Error 3") # no location
      ]

      locations = errors.map { |e| { file: e.file, line: e.line, column: e.column } }

      expect(locations).to eq([
                                { file: "a.rb", line: 10, column: 0 },
                                { file: "b.rb", line: 20, column: 5 },
                                { file: nil, line: nil, column: nil }
                              ])
    end

    it "filters errors by location presence" do
      errors = [
        Kumi::Core::ErrorReporter.create_error(
          "With location",
          location: Kumi::Syntax::Location.new(file: "test.rb", line: 5, column: 0)
        ),
        Kumi::Core::ErrorReporter.create_error("Without location"),
        Kumi::Core::ErrorReporter.create_error(
          "Also with location",
          location: Kumi::Syntax::Location.new(file: "other.rb", line: 15, column: 3)
        )
      ]

      with_location = errors.select(&:valid_location?)
      without_location = errors.reject(&:valid_location?)

      expect(with_location.size).to eq(2)
      expect(without_location.size).to eq(1)
      expect(with_location.map(&:file)).to eq(["test.rb", "other.rb"])
    end

    it "groups errors by file from location" do
      errors = [
        Kumi::Core::ErrorReporter.create_error(
          "Error in a.rb #1",
          location: Kumi::Syntax::Location.new(file: "a.rb", line: 10, column: 0)
        ),
        Kumi::Core::ErrorReporter.create_error(
          "Error in b.rb",
          location: Kumi::Syntax::Location.new(file: "b.rb", line: 20, column: 0)
        ),
        Kumi::Core::ErrorReporter.create_error(
          "Error in a.rb #2",
          location: Kumi::Syntax::Location.new(file: "a.rb", line: 15, column: 5)
        )
      ]

      grouped = errors.select(&:valid_location?).group_by(&:file)

      expect(grouped["a.rb"].size).to eq(2)
      expect(grouped["b.rb"].size).to eq(1)
      expect(grouped["a.rb"].map(&:line)).to eq([10, 15])
    end

    it "sorts errors by line number within file" do
      errors = [
        Kumi::Core::ErrorReporter.create_error(
          "Error at line 30",
          location: Kumi::Syntax::Location.new(file: "test.rb", line: 30, column: 0)
        ),
        Kumi::Core::ErrorReporter.create_error(
          "Error at line 10",
          location: Kumi::Syntax::Location.new(file: "test.rb", line: 10, column: 0)
        ),
        Kumi::Core::ErrorReporter.create_error(
          "Error at line 20",
          location: Kumi::Syntax::Location.new(file: "test.rb", line: 20, column: 0)
        )
      ]

      sorted = errors.select(&:valid_location?).sort_by(&:line)

      expect(sorted.map(&:line)).to eq([10, 20, 30])
    end
  end

  describe "real error scenarios" do
    it "captures error from semantic error during schema analysis" do
      expect do
        build_schema do
          input { integer :x }
          value :v, 100
          trait :impossible, fn(:and, v == 100, v == 50)
          value :result do
            on impossible, "Bad"
            base "Good"
          end
        end
      end.to(raise_error do |e|
        expect(e).to be_a(Kumi::Core::Errors::SemanticError)
        expect(e.has_location?).to be true
        expect(e.location_file).to include("error_handling_spec")
        expect(e.location_line).to be > 0
        expect(e.location_column).to be >= 0
      end)
    end

    it "provides clean error information for logging" do
      location = Kumi::Syntax::Location.new(file: "/home/user/app/schema.rb", line: 42, column: 8)
      error = Kumi::Core::Errors::TypeError.new("Type mismatch", location)

      # Easy to extract for logging - use location_* methods, not message
      log_entry = {
        type: "TypeError",
        file: error.path,
        line: error.line,
        column: error.column,
        has_location: error.has_location?
      }

      expect(log_entry).to eq({
                                type: "TypeError",
                                file: "/home/user/app/schema.rb",
                                line: 42,
                                column: 8,
                                has_location: true
                              })
    end
  end

  describe "ErrorEntry formatting" do
    it "formats error message with location" do
      location = Kumi::Syntax::Location.new(file: "schema.rb", line: 10, column: 5)
      entry = Kumi::Core::ErrorReporter.create_error("Test error", location: location)

      expect(entry.to_s).to include("schema.rb line=10 column=5")
      expect(entry.to_s).to include("Test error")
    end

    it "formats error message without location" do
      entry = Kumi::Core::ErrorReporter.create_error("Error without location")

      expect(entry.to_s).to include("at ?")
      expect(entry.to_s).to include("Error without location")
    end
  end
end
