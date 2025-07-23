# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kumi::AtomUnsatSolver, "depth safety" do
  let(:atom_class) { Kumi::AtomUnsatSolver::Atom }

  describe "large acyclic graphs" do
    it "handles 30k-node strict ladder without stack overflow" do
      # Create chain: x1 < x2 < x3 < ... < x30000 (acyclic)
      atoms = []
      (1...30_000).each do |i|
        atoms << atom_class.new(:<, :"x#{i}", :"x#{i + 1}")
      end

      start_time = Time.now
      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      duration = Time.now - start_time

      expect(result).to be false # Should not be UNSAT (no contradiction)
      expect(duration).to be < 1.0 # Should complete in under 1 second
    end

    it "handles wide graphs with many disconnected components" do
      # Create 1000 separate chains of 10 nodes each
      atoms = []
      1000.times do |chain|
        base = chain * 10
        9.times do |i|
          atoms << atom_class.new(:<, :"x#{base + i}", :"x#{base + i + 1}")
        end
      end

      start_time = Time.now
      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      duration = Time.now - start_time

      expect(result).to be false
      expect(duration).to be < 0.5
    end
  end

  describe "large cyclic graphs" do 
    it "detects cycles in 10k-node ladder with back-edge" do
      # Create chain x1 < x2 < ... < x10000 < x1 (creates cycle)
      atoms = []
      (1...10_000).each do |i|
        atoms << atom_class.new(:<, :"x#{i}", :"x#{i + 1}")
      end
      # Add back-edge to create cycle
      atoms << atom_class.new(:<, :x10000, :x1)

      start_time = Time.now
      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      duration = Time.now - start_time

      expect(result).to be true # Should be UNSAT (cycle detected)
      expect(duration).to be < 1.0
    end

    it "detects cycles in complex interconnected graph" do
      # Create a more complex cycle: multiple interconnected cycles
      atoms = []
      
      # Main cycle: x1 < x2 < x3 < x1
      atoms << atom_class.new(:<, :x1, :x2)
      atoms << atom_class.new(:<, :x2, :x3)  
      atoms << atom_class.new(:<, :x3, :x1)
      
      # Add many additional constraints that don't affect the cycle
      1000.times do |i|
        atoms << atom_class.new(:<, :"y#{i}", :"y#{i + 1}")
        atoms << atom_class.new(:>, :"z#{i}", i) # Numerical constraints
      end

      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      expect(result).to be true
    end
  end

  describe "mixed constraint types" do
    it "handles large mixed symbol-numeric and symbol-symbol constraints" do
      atoms = []

      # Add 5000 numerical bound constraints  
      2500.times do |i|
        atoms << atom_class.new(:>, :"x#{i}", i)      # x_i > i
        atoms << atom_class.new(:<, :"x#{i}", i + 100) # x_i < i + 100  
      end

      # Add 5000 symbol-symbol constraints forming chains
      2500.times do |i|
        atoms << atom_class.new(:<, :"y#{i}", :"y#{i + 1}")
      end

      start_time = Time.now
      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      duration = Time.now - start_time

      expect(result).to be false
      expect(duration).to be < 1.0
    end

    it "detects numerical contradictions in large constraint sets" do
      atoms = []

      # Add many valid constraints
      1000.times do |i|
        atoms << atom_class.new(:>, :"x#{i}", i)
        atoms << atom_class.new(:<, :"x#{i}", i + 50)
      end

      # Add one contradictory constraint
      atoms << atom_class.new(:>, :x500, 600)  # x500 > 600
      atoms << atom_class.new(:<, :x500, 550)  # x500 < 550 (contradiction)

      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      expect(result).to be true
    end
  end

  describe "stress tests" do
    it "handles empty constraint set" do
      result = Kumi::AtomUnsatSolver.unsat?([])
      expect(result).to be false
    end

    it "handles single constraint" do
      atoms = [atom_class.new(:>, :x, 5)]
      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      expect(result).to be false
    end

    it "handles constraints with duplicate edges" do
      atoms = [
        atom_class.new(:<, :x, :y),
        atom_class.new(:<, :x, :y), # Duplicate
        atom_class.new(:<, :y, :z),
        atom_class.new(:<, :z, :x)  # Creates cycle
      ]
      
      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      expect(result).to be true
    end
  end

  describe "correctness preservation" do
    # Ensure existing UNSAT detection cases still work correctly
    
    it "detects minor/teenager contradiction" do
      atoms = [
        atom_class.new(:>=, :age, 18), # adult
        atom_class.new(:<, :age, 18)   # teenager (contradiction)
      ]
      
      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      expect(result).to be true
    end

    it "detects x < 100 & y > 1000 with x=100, y=x*10" do
      # This represents: x=100, y=1000, x<100 (false), y>1000 (false)
      # The UNSAT detection should reason about the mathematical relationship
      atoms = [
        atom_class.new(:<, 100, 100),    # x < 100 where x = 100 (false)
        atom_class.new(:>, 1000, 1000)   # y > 1000 where y = 1000 (false)  
      ]
      
      result = Kumi::AtomUnsatSolver.unsat?(atoms) 
      expect(result).to be true
    end

    it "detects simple three-way cycle" do
      atoms = [
        atom_class.new(:<, :x, :y),
        atom_class.new(:<, :y, :z), 
        atom_class.new(:<, :z, :x)
      ]
      
      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      expect(result).to be true
    end

    it "allows satisfiable constraint chains" do
      atoms = [
        atom_class.new(:<, :x, :y),
        atom_class.new(:<, :y, :z),
        atom_class.new(:>, :z, 100)
      ]
      
      result = Kumi::AtomUnsatSolver.unsat?(atoms)
      expect(result).to be false
    end
  end
end