# Pass Conventions, Contracts, and Dedup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make kumi-core's compiler-pass layer consistent and enforceable: working per-path lint rules, a written conventions doc, declared `reads`/`writes` state contracts enforced by `PassManager`, and dedup of the copy-pasted boundary passes, NAST traversals, and the monolithic `PassManager#run`.

**Architecture:** Analyzer passes stay `state → state` (`PassBase`), IR passes stay `graph → graph` (`IR::Passes::Base`). A class-level contract DSL on `PassBase` replaces `# In:/# Out:` comments; `PassManager` enforces contracts for any pass that declares one. Boundary adapters collapse into two parameterized base classes (`IRValidatePass`, `IRLowerPass`). NAST nodes gain a `children` protocol used by traversal passes.

**Tech Stack:** Ruby 3.1+, zeitwerk autoloading, RSpec, RuboCop (with `.rubocop_todo.yml` ratchet).

**Branch:** `pass-conventions` (already created off `streaming-v2`). Working directory for all commands: `/home/muta/repos/kumi/kumi-core`.

**Spec:** `docs/superpowers/specs/2026-06-12-pass-conventions-and-dedup-design.md`

**Baseline (verified 2026-06-12):** `bundle exec rspec` → 910 examples, 0 failures, 3 pending, ~4s. `bundle exec rubocop` → 1,286 offenses in 218 files (config points at dead paths). No `.rubocop_todo.yml` exists. No method-name collisions exist between pass instance methods and the state keys the DSL will define readers for (verified by grep).

**Orphan passes (out of scope, do not delete, do not migrate):** `LowerToIRV2Pass`, `AssembleIRV2Pass`, `IRDependencyPass`, `IRExecutionSchedulePass`, `LoadInputCSE`, `ContractCheckerPass`, `FormalConstraintPropagator`, `JoinReducePlanningPass` are referenced by no pipeline and (except JoinReducePlanning's own spec) no other code. They keep working because contract enforcement only applies to passes that declare a contract. `LoadInputCSE` still gets renamed in Task 12 because the spec's naming rule covers all pass classes. Flag the orphan list to the user at the end as a candidate for deletion in a separate decision.

---

### Task 1: Fix RuboCop config and add offense ratchet

**Files:**
- Modify: `.rubocop.yml` (full rewrite)
- Create: `.rubocop_todo.yml` (generated)

- [ ] **Step 1: Replace `.rubocop.yml` with this exact content**

```yaml
plugins:
  - rubocop-performance
  - rubocop-rspec

AllCops:
  NewCops: enable
  TargetRubyVersion: 3.1
  SuggestExtensions: false
  Exclude:
    - 'bin/*'
    - 'cmd/**/*'
    - 'coverage/**/*'
    - 'examples/**/*'
    - 'golden/**/*'
    - 'pkg/**/*'
    - 'spec/fixtures/**/*'
    - 'tmp/**/*'
    - 'vendor/**/*'
    - 'vscode-extension/**/*'

Style/StringLiterals:
  EnforcedStyle: double_quotes

Style/Documentation:
  Enabled: false

Style/OpenStructUse:
  Enabled: false

Naming/VariableNumber:
  Enabled: false

Layout/LineLength:
  Max: 140

# Pass bodies legitimately carry long dispatch methods; relaxed only there.
Metrics/MethodLength:
  Max: 20
  Exclude:
    - 'lib/kumi/core/analyzer/passes/**/*'
    - 'lib/kumi/ir/**/*'
    - 'spec/**/*'

Metrics/AbcSize:
  Max: 20
  Exclude:
    - 'lib/kumi/core/analyzer/passes/**/*'
    - 'lib/kumi/ir/**/*'
    - 'spec/**/*'

Metrics/CyclomaticComplexity:
  Max: 10
  Exclude:
    - 'lib/kumi/core/analyzer/passes/**/*'
    - 'lib/kumi/ir/**/*'

Metrics/PerceivedComplexity:
  Max: 10
  Exclude:
    - 'lib/kumi/core/analyzer/passes/**/*'
    - 'lib/kumi/ir/**/*'

Metrics/BlockLength:
  Exclude:
    - 'spec/**/*'
    - '*.gemspec'

Metrics/ParameterLists:
  Max: 6

Lint/MissingSuper:
  Exclude:
    - 'lib/kumi/core/analyzer/passes/pass_base.rb'

RSpec/MultipleExpectations:
  Enabled: false

RSpec/ExampleLength:
  Max: 30

RSpec/MultipleMemoizedHelpers:
  Max: 10

RSpec/VerifiedDoubleReference:
  Enabled: false

RSpec/DescribeClass:
  Enabled: false

RSpec/ContextWording:
  Enabled: false

RSpec/IdenticalEqualityAssertion:
  Enabled: false

RSpec/PendingWithoutReason:
  Enabled: false
```

- [ ] **Step 2: Apply safe autocorrects**

Run: `bundle exec rubocop -a || true`
Expected: many files corrected; remaining offenses reported; non-zero exit is fine at this step.

- [ ] **Step 3: Verify the suite still passes after autocorrect**

Run: `bundle exec rspec`
Expected: `910 examples, 0 failures, 3 pending`

If any failure appears, inspect the autocorrected file involved, revert that single correction by hand, and add the offending cop to `.rubocop_todo.yml` scope in Step 4 (the regenerate will absorb it).

- [ ] **Step 4: Generate the ratchet**

Run: `bundle exec rubocop --auto-gen-config --auto-gen-only-exclude --exclude-limit 300`
Expected: creates `.rubocop_todo.yml` and prepends `inherit_from: .rubocop_todo.yml` to `.rubocop.yml`.

- [ ] **Step 5: Verify lint is green**

Run: `bundle exec rubocop`
Expected: `no offenses detected`

- [ ] **Step 6: Commit**

```bash
git add .rubocop.yml .rubocop_todo.yml -A
git commit -m "Fix rubocop config paths, scope metrics to pass dirs, add offense ratchet"
```

---

### Task 2: Write `docs/PASSES.md` conventions doc

**Files:**
- Create: `docs/PASSES.md`

- [ ] **Step 1: Create `docs/PASSES.md` with this exact content**

```markdown
# Compiler Pass Conventions

These rules are enforced by `spec/kumi/analyzer_pipeline_contract_spec.rb`,
`PassManager` contract checks, and RuboCop. Change the enforcement when you
change a rule.

## Naming

- Every pass class name ends in `Pass`; its file name ends in `_pass.rb`.
- New acronyms in class names require a zeitwerk inflector entry in
  `lib/kumi.rb` and are discouraged — prefer plain words.

## Two pass shapes, never mixed

- **Analyzer passes** (`lib/kumi/core/analyzer/passes/`): subclass
  `Passes::PassBase`. `run(errors)` takes an error accumulator and returns an
  `AnalysisState`. State is immutable; produce new state with `state.with`.
- **IR passes** (`lib/kumi/ir/*/passes/`): subclass `Kumi::IR::Passes::Base`.
  `run(graph:, context:)` returns a graph; compose with `IR::Passes::Pipeline`.
- Bridging happens only through the boundary adapters `IRValidatePass` and
  `IRLowerPass` — never call an IR pipeline ad hoc from an analyzer pass.

## State contracts

Every analyzer pass declares what it touches, at the top of the class body:

    class SNASTPass < PassBase
      reads  :nast_module, :metadata_table, :registry
      writes :snast_module
    end

- `reads` — required keys; fails fast in `PassManager` if absent. Also defines
  a reader method per key.
- `optional_reads` — keys that may be absent; reader returns `nil`.
- `writes` — every key the pass adds or replaces. A pass that produces no
  state declares bare `writes` (no arguments) so the contract is still
  explicit. `PassManager` rejects any undeclared write.
- `# In:` / `# Out:` comments are banned — the DSL is the single source of
  truth, and `spec/kumi/analyzer_pipeline_contract_spec.rb` checks that every
  pipeline pass declares a contract and that pass ordering satisfies all reads.
- Passes that annotate IR/NAST nodes in place (e.g. `AttachTerminalInfoPass`)
  declare bare `writes`; keep such in-place mutation limited to node `meta` /
  annotation fields, never structure.

## Loading

- zeitwerk owns everything under `lib/kumi/`. Inside `lib/`, only require
  stdlib (`require "json"` etc.) — never `require "kumi/..."` for autoloadable
  constants. Exceptions are the files explicitly ignored in `lib/kumi.rb`.

## Debug and checkpoint env vars

- `DEBUG_<SHORT_NAME>=1` enables per-pass debug output; the short name is the
  class name minus the `Pass` suffix, underscored (`SNASTPass` → `DEBUG_SNAST`).
- `KUMI_RESUME_AT` / `KUMI_STOP_AFTER` take the pass short class name
  (e.g. `SNASTPass`).
- `KUMI_DEBUG_REQUIRE_FROZEN=1` makes `PassManager` assert state values are
  frozen after each pass (debug mode only).
```

- [ ] **Step 2: Commit**

```bash
git add docs/PASSES.md
git commit -m "Document compiler pass conventions in docs/PASSES.md"
```

---

### Task 3: Contract DSL on PassBase (TDD)

**Files:**
- Modify: `lib/kumi/core/analyzer/passes/pass_base.rb`
- Test: `spec/kumi/core/analyzer/passes/pass_base_contract_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/kumi/core/analyzer/passes/pass_base_contract_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::Passes::PassBase, "contract DSL" do
  def state_with(data)
    Kumi::Core::Analyzer::AnalysisState.new(data)
  end

  describe ".reads" do
    it "records required reads and defines a reader method" do
      klass = Class.new(described_class) { reads :foo }
      expect(klass.declared_reads).to eq([:foo])
      expect(klass.new(nil, state_with(foo: 42)).foo).to eq(42)
    end

    it "raises through the reader when a required key is missing" do
      klass = Class.new(described_class) { reads :foo }
      expect { klass.new(nil, state_with({})).foo }.to raise_error(StandardError, /foo/)
    end
  end

  describe ".optional_reads" do
    it "records optional reads and defines a nil-tolerant reader" do
      klass = Class.new(described_class) { optional_reads :maybe }
      expect(klass.declared_optional_reads).to eq([:maybe])
      expect(klass.new(nil, state_with({})).maybe).to be_nil
      expect(klass.new(nil, state_with(maybe: 1)).maybe).to eq(1)
    end
  end

  describe ".writes" do
    it "records written keys" do
      klass = Class.new(described_class) { writes :out_a, :out_b }
      expect(klass.declared_writes).to eq(%i[out_a out_b])
    end

    it "marks the contract declared even with no arguments" do
      klass = Class.new(described_class) { writes }
      expect(klass.declared_writes).to eq([])
      expect(klass.contract_declared?).to be(true)
    end
  end

  describe ".contract_declared?" do
    it "is false when no macro was called" do
      expect(Class.new(described_class).contract_declared?).to be(false)
    end

    it "is true when any macro was called" do
      expect(Class.new(described_class) { reads :x }.contract_declared?).to be(true)
    end
  end

  describe "inheritance" do
    it "merges contracts down the class hierarchy" do
      parent = Class.new(described_class) { reads :a; writes :w }
      child = Class.new(parent) { reads :b; optional_reads :o }
      expect(child.declared_reads).to eq(%i[a b])
      expect(child.declared_optional_reads).to eq([:o])
      expect(child.declared_writes).to eq([:w])
      expect(child.contract_declared?).to be(true)
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/kumi/core/analyzer/passes/pass_base_contract_spec.rb`
Expected: FAIL — `undefined method 'reads'`

- [ ] **Step 3: Add the DSL to PassBase**

In `lib/kumi/core/analyzer/passes/pass_base.rb`, insert immediately after the line `include Kumi::Core::ErrorReporting`:

```ruby
          class << self
            def reads(*keys)
              keys.each do |key|
                own_reads << key
                define_method(key) { get_state(key) }
              end
              mark_contract!
            end

            def optional_reads(*keys)
              keys.each do |key|
                own_optional_reads << key
                define_method(key) { state[key] }
              end
              mark_contract!
            end

            def writes(*keys)
              own_writes.concat(keys)
              mark_contract!
            end

            def declared_reads
              inherited_contract(:declared_reads) + own_reads
            end

            def declared_optional_reads
              inherited_contract(:declared_optional_reads) + own_optional_reads
            end

            def declared_writes
              inherited_contract(:declared_writes) + own_writes
            end

            def contract_declared?
              return true if defined?(@contract_declared) && @contract_declared

              superclass.respond_to?(:contract_declared?) && superclass.contract_declared?
            end

            private

            def mark_contract!
              @contract_declared = true
            end

            def own_reads = @own_reads ||= []
            def own_optional_reads = @own_optional_reads ||= []
            def own_writes = @own_writes ||= []

            def inherited_contract(method_name)
              superclass.respond_to?(method_name) ? superclass.public_send(method_name) : []
            end
          end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/kumi/core/analyzer/passes/pass_base_contract_spec.rb`
Expected: PASS (8 examples)

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: `918 examples, 0 failures, 3 pending`

- [ ] **Step 6: Commit**

```bash
git add lib/kumi/core/analyzer/passes/pass_base.rb spec/kumi/core/analyzer/passes/pass_base_contract_spec.rb
git commit -m "Add reads/writes contract DSL to PassBase"
```

---

### Task 4: Decompose PassManager#run (behavior-preserving)

**Files:**
- Modify: `lib/kumi/core/analyzer/pass_manager.rb` (full rewrite)
- Existing tests: `spec/kumi/core/analyzer/pass_manager_spec.rb` (must stay green untouched)

- [ ] **Step 1: Replace `lib/kumi/core/analyzer/pass_manager.rb` with this exact content**

```ruby
# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      class PassManager
        attr_reader :passes, :errors

        def initialize(passes)
          @passes = passes
          @errors = []
        end

        def run(syntax_tree, initial_state = nil, errors = [], options = {})
          state = initial_state || AnalysisState.new

          passes.each_with_index do |pass_class, phase_index|
            pass_name = pass_class.name.split("::").last
            Checkpoint.entering(pass_name:, idx: phase_index, state:) if options[:checkpoint_enabled]

            instrumentation = Instrumentation.new(pass_name, options)
            instrumentation.before(state)

            begin
              state = execute_pass(pass_class, pass_name, syntax_tree, state, errors, options)
            rescue StandardError => e
              error_obj = capture_exception(pass_name, e, errors)
              instrumentation.after_failure(e)
              return failure_result(state, [error_obj], pass_class, phase_index)
            end

            raise "Pass #{pass_name} returned #{state.class}, expected AnalysisState" unless state.is_a?(AnalysisState)

            instrumentation.after_success(state)
            Checkpoint.leaving(pass_name:, idx: phase_index, state:) if options[:checkpoint_enabled]

            return failure_result(state, errors, pass_class, phase_index) unless errors.empty?
            return ExecutionResult.success(final_state: state, stopped: true) if options[:stop_after] == pass_name
          end

          ExecutionResult.success(final_state: state)
        end

        private

        def execute_pass(pass_class, pass_name, syntax_tree, state, errors, options)
          pass_instance = pass_class.new(syntax_tree, state)

          if options[:profiling_enabled]
            Dev::Profiler.phase("analyzer.pass", pass: pass_name) { pass_instance.run(errors) }
          else
            pass_instance.run(errors)
          end
        end

        def capture_exception(pass_name, exception, errors)
          location_hint = exception.backtrace&.first
          message = if location_hint
                      "Error in Analysis Pass(#{pass_name}) at #{location_hint}: #{exception.message}"
                    else
                      "Error in Analysis Pass(#{pass_name}): #{exception.message}"
                    end
          error_obj = ErrorReporter.create_error(message, location: nil, type: :semantic, backtrace: exception.backtrace)
          errors << error_obj
          error_obj
        end

        def failure_result(state, errors, pass_class, phase_index)
          phase = ExecutionPhase.new(pass_class: pass_class, index: phase_index)
          converted = errors.map do |error|
            PassFailure.new(
              message: error.message,
              phase: phase_index,
              pass_name: phase.pass_name,
              location: error.respond_to?(:location) ? error.location : nil
            )
          end
          ExecutionResult.failure(final_state: state, errors: converted, failed_at_phase: phase_index)
        end

        class Instrumentation
          def initialize(pass_name, options)
            @pass_name = pass_name
            @debug = options[:debug_enabled]
            @profiling = options[:profiling_enabled]
          end

          def before(state)
            @before = state.to_h if @debug
            Debug.reset_log(pass: @pass_name) if @debug
            @t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) if @profiling
          end

          def after_success(state)
            return unless @debug

            after = state.to_h
            enforce_frozen!(after) if ENV["KUMI_DEBUG_REQUIRE_FROZEN"] == "1"
            Debug.emit(pass: @pass_name, diff: Debug.diff_state(@before, after), elapsed_ms: elapsed_ms, logs: Debug.drain_log)
          end

          def after_failure(exception)
            return unless @debug

            logs = Debug.drain_log + [{ level: :error, id: :exception, message: exception.message, error_class: exception.class.name }]
            Debug.emit(pass: @pass_name, diff: {}, elapsed_ms: elapsed_ms, logs: logs)
          end

          private

          def elapsed_ms
            return 0 unless @profiling && @t0

            ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @t0) * 1000).round(2)
          end

          def enforce_frozen!(after)
            (after || {}).each do |k, v|
              next if v.nil? || v.is_a?(Numeric) || v.is_a?(Symbol) || v.is_a?(TrueClass) || v.is_a?(FalseClass) ||
                      (v.is_a?(String) && v.frozen?)

              raise "State[#{k}] not frozen: #{v.class}" unless v.frozen?
            end
          end
        end
      end
    end
  end
end
```

Behavior notes (verify against the original while editing): exception path emits debug with empty diff and converts only the captured error; non-empty `errors` after a pass converts all entries; the frozen guard runs only in debug mode and raises out of `run` (not converted to a failure result); `stop_after` matches the short pass name. All preserved above.

- [ ] **Step 2: Run the manager and analyzer specs**

Run: `bundle exec rspec spec/kumi/core/analyzer/pass_manager_spec.rb spec/kumi/core/analyzer/execution_phase_spec.rb spec/kumi/core/analyzer/pass_failure_spec.rb spec/kumi/analyzer_refactoring_spec.rb`
Expected: PASS, 0 failures

- [ ] **Step 3: Run the full suite**

Run: `bundle exec rspec`
Expected: `918 examples, 0 failures, 3 pending`

- [ ] **Step 4: Commit**

```bash
git add lib/kumi/core/analyzer/pass_manager.rb
git commit -m "Decompose PassManager#run into execute/instrumentation/failure helpers"
```

---

### Task 5: Contract enforcement in PassManager (TDD)

**Files:**
- Modify: `lib/kumi/core/analyzer/pass_manager.rb`
- Test: `spec/kumi/core/analyzer/pass_manager_contract_spec.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/kumi/core/analyzer/pass_manager_contract_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe Kumi::Core::Analyzer::PassManager, "contract enforcement" do
  def named_pass(name, &body)
    klass = Class.new(Kumi::Core::Analyzer::Passes::PassBase, &body)
    klass.define_singleton_method(:name) { "Kumi::Test::#{name}" }
    klass
  end

  def run_manager(pass_class, initial = {})
    manager = described_class.new([pass_class])
    manager.run(nil, Kumi::Core::Analyzer::AnalysisState.new(initial), [], {})
  end

  it "fails when a declared read is missing from state" do
    pass = named_pass("NeedsInputPass") do
      reads :nast_module
      def run(_errors) = state
    end

    result = run_manager(pass)
    expect(result.failed?).to be(true)
    expect(result.errors.first.message).to include("nast_module")
  end

  it "fails when a pass writes an undeclared key" do
    pass = named_pass("SneakyWritePass") do
      writes
      def run(_errors) = state.with(:surprise, 1)
    end

    result = run_manager(pass)
    expect(result.failed?).to be(true)
    expect(result.errors.first.message).to include("surprise")
  end

  it "allows declared writes, including overwriting an existing key" do
    pass = named_pass("DeclaredWritePass") do
      reads :counter
      writes :counter
      def run(_errors) = state.with(:counter, counter + 1)
    end

    result = run_manager(pass, counter: 1)
    expect(result.failed?).to be(false)
    expect(result.final_state[:counter]).to eq(2)
  end

  it "skips enforcement for passes without a declared contract" do
    pass = named_pass("LegacyPass") do
      def run(_errors) = state.with(:anything, :goes)
    end

    result = run_manager(pass)
    expect(result.failed?).to be(false)
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/kumi/core/analyzer/pass_manager_contract_spec.rb`
Expected: FAIL — the first two examples fail (no enforcement yet); the last two pass.

- [ ] **Step 3: Add enforcement to PassManager**

In `lib/kumi/core/analyzer/pass_manager.rb`, replace the `begin` block body in `run`:

```ruby
            begin
              state = execute_pass(pass_class, pass_name, syntax_tree, state, errors, options)
            rescue StandardError => e
```

with:

```ruby
            begin
              enforce_reads!(pass_class, pass_name, state)
              contract_before = state.to_h
              state = execute_pass(pass_class, pass_name, syntax_tree, state, errors, options)
              enforce_writes!(pass_class, pass_name, contract_before, state)
            rescue StandardError => e
```

and add these private methods after `execute_pass`:

```ruby
        def enforce_reads!(pass_class, pass_name, state)
          return unless pass_class.contract_declared?

          missing = pass_class.declared_reads.reject { |key| state.key?(key) }
          return if missing.empty?

          raise "#{pass_name} declares reads #{missing.inspect} but they are missing from analysis state"
        end

        def enforce_writes!(pass_class, pass_name, before, state)
          return unless pass_class.contract_declared?
          return unless state.is_a?(AnalysisState)

          after = state.to_h
          changed = after.keys.select { |key| !before.key?(key) || !before[key].equal?(after[key]) }
          undeclared = changed - pass_class.declared_writes
          return if undeclared.empty?

          raise "#{pass_name} wrote undeclared state keys #{undeclared.inspect} (declared writes: #{pass_class.declared_writes.inspect})"
        end
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/kumi/core/analyzer/pass_manager_contract_spec.rb`
Expected: PASS (4 examples)

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: `922 examples, 0 failures, 3 pending` (no pipeline pass declares a contract yet, so nothing else changes)

- [ ] **Step 6: Commit**

```bash
git add lib/kumi/core/analyzer/pass_manager.rb spec/kumi/core/analyzer/pass_manager_contract_spec.rb
git commit -m "Enforce declared pass contracts in PassManager"
```

---

### Task 6: Declare contracts on DEFAULT_PASSES

**Files (all under `lib/kumi/core/analyzer/passes/`):**
- Modify: `name_indexer.rb`, `import_analysis_pass.rb`, `input_collector.rb`, `input_form_schema_pass.rb`, `declaration_validator.rb`, `semantic_constraint_validator.rb`, `dependency_resolver.rb`, `toposorter.rb`, `input_access_planner_pass.rb`

For each file: insert the contract lines immediately after the `class X < PassBase` (or `< VisitorPass`) line, and delete any `# In:` / `# Out:` comment lines in the file. Do not change `run` bodies in this task.

- [ ] **Step 1: Insert these exact declarations**

`name_indexer.rb` (class `NameIndexer`):
```ruby
          writes :declarations, :imported_declarations, :hints
```

`import_analysis_pass.rb` (class `ImportAnalysisPass`):
```ruby
          reads :imported_declarations
          writes :imported_schemas
```

`input_collector.rb` (class `InputCollector`):
```ruby
          writes :input_metadata
```

`input_form_schema_pass.rb` (class `InputFormSchemaPass`):
```ruby
          reads :input_metadata
          writes :input_form_schema
```

`declaration_validator.rb` (class `DeclarationValidator < VisitorPass`):
```ruby
          writes
```

`semantic_constraint_validator.rb` (class `SemanticConstraintValidator < VisitorPass`):
```ruby
          writes
```

`dependency_resolver.rb` (class `DependencyResolver`):
```ruby
          reads :declarations, :input_metadata, :imported_schemas
          writes :dependencies, :dependents, :leaves
```

`toposorter.rb` (class `Toposorter`):
```ruby
          optional_reads :declarations, :dependencies
          writes :evaluation_order
```

`input_access_planner_pass.rb` (class `InputAccessPlannerPass`):
```ruby
          reads :input_metadata
          writes :input_table, :index_table
```

- [ ] **Step 2: Run the full suite — enforcement is now live for these passes**

Run: `bundle exec rspec`
Expected: `922 examples, 0 failures, 3 pending`

If a contract-violation failure appears, the declaration is wrong, not the pass: read the error message (it names the pass and keys) and fix the declaration to match what the pass actually reads/writes.

- [ ] **Step 3: Commit**

```bash
git add lib/kumi/core/analyzer/passes
git commit -m "Declare state contracts on DEFAULT_PASSES"
```

---

### Task 7: Declare contracts on LOWERING_PASSES (excluding boundary adapters)

**Files (all under `lib/kumi/core/analyzer/passes/`):**
- Modify: `normalize_to_nast_pass.rb`, `constant_folding_pass.rb`, `nast_dimensional_analyzer_pass.rb`, `snast_pass.rb`, `unsat_detector.rb`, `output_schema_pass.rb`, `attach_terminal_info_pass.rb`, `attach_anchors_pass.rb`, `precompute_access_paths_pass.rb`, `lower_to_dfir_pass.rb`

Skip `df_validate_pass.rb`, `vec_validate_pass.rb`, `loop_validate_pass.rb`, `vec/lower_pass.rb`, `loop/lower_pass.rb` — Tasks 9–10 rewrite them with contracts included.

- [ ] **Step 1: Insert these exact declarations** (same placement rule as Task 6; also delete `# In:/# Out:` comment lines)

`normalize_to_nast_pass.rb` (class `NormalizeToNASTPass`):
```ruby
          reads :declarations, :evaluation_order, :index_table, :registry
          optional_reads :imported_schemas
          writes :nast_module
```

`constant_folding_pass.rb` (class `ConstantFoldingPass`):
```ruby
          reads :nast_module, :evaluation_order, :registry
          writes :nast_module
```

`nast_dimensional_analyzer_pass.rb` (class `NASTDimensionalAnalyzerPass`):
```ruby
          reads :nast_module, :input_table, :registry
          optional_reads :imported_schemas
          writes :metadata_table, :declaration_table
```

`snast_pass.rb` (class `SNASTPass`):
```ruby
          reads :nast_module, :metadata_table, :declaration_table, :input_table, :index_table, :registry
          writes :snast_module
```

`unsat_detector.rb` (class `UnsatDetector < VisitorPass`):
```ruby
          reads :declarations, :input_metadata, :registry
          writes
```

`output_schema_pass.rb` (class `OutputSchemaPass`):
```ruby
          reads :snast_module, :hints
          writes :output_schema
```

`attach_terminal_info_pass.rb` (class `AttachTerminalInfoPass`):
```ruby
          reads :snast_module, :input_table
          writes
```

`attach_anchors_pass.rb` (class `AttachAnchorsPass`):
```ruby
          reads :snast_module
          writes :anchor_by_decl
```

`precompute_access_paths_pass.rb` (class `PrecomputeAccessPathsPass`):
```ruby
          reads :input_table
          writes :precomputed_plan_by_fqn
```

`lower_to_dfir_pass.rb` (class `LowerToDFIRPass`):
```ruby
          reads :snast_module, :input_table, :registry
          optional_reads :imported_schemas, :precomputed_plan_by_fqn
          writes :df_module, :df_module_unoptimized
```

- [ ] **Step 2: Run the full suite**

Run: `bundle exec rspec`
Expected: `922 examples, 0 failures, 3 pending`. Same fix rule as Task 6 if a contract violation surfaces.

- [ ] **Step 3: Commit**

```bash
git add lib/kumi/core/analyzer/passes
git commit -m "Declare state contracts on lowering passes"
```

---

### Task 8: Declare contracts on TARGET_PASSES

**Files:**
- Modify: `lib/kumi/core/analyzer/passes/codegen/loop_ruby_pass.rb`, `lib/kumi/core/analyzer/passes/codegen/loop_js_pass.rb`

- [ ] **Step 1: Insert these exact declarations**

`codegen/loop_ruby_pass.rb` (class `Codegen::LoopRubyPass`):
```ruby
            reads :loop_module, :registry, :schema_digest
            writes :ruby_codegen_files
```

`codegen/loop_js_pass.rb` (class `Codegen::LoopJsPass`):
```ruby
            reads :loop_module, :registry, :schema_digest
            writes :javascript_codegen_files
```

- [ ] **Step 2: Run the full suite**

Run: `bundle exec rspec`
Expected: `922 examples, 0 failures, 3 pending`

- [ ] **Step 3: Commit**

```bash
git add lib/kumi/core/analyzer/passes/codegen
git commit -m "Declare state contracts on codegen passes"
```

---

### Task 9: Collapse the three IR validate passes

**Files:**
- Create: `lib/kumi/core/analyzer/passes/ir_validate_pass.rb`
- Modify: `lib/kumi/core/analyzer/passes/df_validate_pass.rb`, `vec_validate_pass.rb`, `loop_validate_pass.rb` (full rewrites)
- Modify: `lib/kumi.rb` (inflector entry)

- [ ] **Step 1: Add the inflector entry**

In `lib/kumi.rb`, inside the `AUTOLOADER.inflector.inflect(...)` hash, add (keep alphabetical-ish placement near the other `ir_*` entries):

```ruby
    "ir_validate_pass" => "IRValidatePass",
```

- [ ] **Step 2: Create `lib/kumi/core/analyzer/passes/ir_validate_pass.rb`**

```ruby
# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class IRValidatePass < PassBase
          class << self
            attr_reader :module_key, :validator, :unoptimized_key, :registry_aware

            def validates(module_key, with:, unoptimized_key: nil, registry: false)
              @module_key = module_key
              @validator = with
              @unoptimized_key = unoptimized_key
              @registry_aware = registry
              optional_reads module_key
              optional_reads unoptimized_key if unoptimized_key
              optional_reads :registry if registry
              writes
            end
          end

          def run(_errors)
            config = self.class
            if config.unoptimized_key && (unoptimized = state[config.unoptimized_key])
              config.validator.validate!(unoptimized, allow_fold: true, registry: state[:registry])
            end

            if (ir_module = state[config.module_key])
              if config.registry_aware
                config.validator.validate!(ir_module, registry: state[:registry])
              else
                config.validator.validate!(ir_module)
              end
            end

            state
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: Rewrite the three validate passes**

`df_validate_pass.rb`:
```ruby
# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class DFValidatePass < IRValidatePass
          validates :df_module, with: Kumi::IR::DF::Validator,
                                unoptimized_key: :df_module_unoptimized, registry: true
        end
      end
    end
  end
end
```

`vec_validate_pass.rb`:
```ruby
# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class VecValidatePass < IRValidatePass
          validates :vec_module, with: Kumi::IR::Vec::Validator
        end
      end
    end
  end
end
```

`loop_validate_pass.rb`:
```ruby
# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class LoopValidatePass < IRValidatePass
          validates :loop_module, with: Kumi::IR::Loop::Validator
        end
      end
    end
  end
end
```

Note: the old `require "kumi/ir/df"` / `"kumi/ir/vec"` / `"kumi/ir/loop"` lines are intentionally dropped — zeitwerk resolves the validator constants.

- [ ] **Step 4: Run the full suite**

Run: `bundle exec rspec`
Expected: `922 examples, 0 failures, 3 pending`

- [ ] **Step 5: Commit**

```bash
git add lib/kumi.rb lib/kumi/core/analyzer/passes
git commit -m "Collapse IR validate passes into parameterized IRValidatePass"
```

---

### Task 10: Collapse the two IR lower passes

**Files:**
- Create: `lib/kumi/core/analyzer/passes/ir_lower_pass.rb`
- Modify: `lib/kumi/core/analyzer/passes/vec/lower_pass.rb`, `lib/kumi/core/analyzer/passes/loop/lower_pass.rb` (full rewrites)
- Modify: `lib/kumi.rb` (inflector entry)

- [ ] **Step 1: Add the inflector entry**

In `lib/kumi.rb` inflector hash:

```ruby
    "ir_lower_pass" => "IRLowerPass",
```

- [ ] **Step 2: Create `lib/kumi/core/analyzer/passes/ir_lower_pass.rb`**

```ruby
# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        class IRLowerPass < PassBase
          class << self
            attr_reader :from_key, :to_key

            def lowers(from:, to:)
              @from_key = from
              @to_key = to
              optional_reads from
              writes to
            end
          end

          def run(_errors)
            source = state[self.class.from_key]
            return state unless source

            state.with(self.class.to_key, lower(source).freeze)
          end

          private

          def lower(source)
            raise NotImplementedError, "#{self.class.name} must implement #lower"
          end
        end
      end
    end
  end
end
```

- [ ] **Step 3: Rewrite the two lower passes**

`vec/lower_pass.rb`:
```ruby
# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Vec
          class LowerPass < IRLowerPass
            lowers from: :df_module, to: :vec_module

            private

            def lower(df_module)
              vec_module = Kumi::IR::Vec::Module.from_df(df_module)
              Kumi::IR::Vec::Pipeline.run(graph: vec_module, context: {})
            end
          end
        end
      end
    end
  end
end
```

`loop/lower_pass.rb`:
```ruby
# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module Passes
        module Loop
          class LowerPass < IRLowerPass
            lowers from: :vec_module, to: :loop_module
            reads :registry
            optional_reads :precomputed_plan_by_fqn

            private

            def lower(vec_module)
              context = { input_plans: precomputed_plan_by_fqn || {}, registry: registry }
              loop_module = Kumi::IR::Loop::Module.from_vec(vec_module, context: context)
              Kumi::IR::Loop::Pipeline.run(graph: loop_module, context: context)
            end
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run the full suite**

Run: `bundle exec rspec`
Expected: `922 examples, 0 failures, 3 pending`

- [ ] **Step 5: Commit**

```bash
git add lib/kumi.rb lib/kumi/core/analyzer/passes
git commit -m "Collapse IR lower passes into parameterized IRLowerPass"
```

---

### Task 11: NAST children protocol + traversal rewrites (TDD)

**Files:**
- Modify: `lib/kumi/core/nast.rb`
- Modify: `lib/kumi/core/analyzer/passes/attach_terminal_info_pass.rb:24-47` (the `annotate!` method)
- Modify: `lib/kumi/core/analyzer/passes/attach_anchors_pass.rb:31-62` (the `pick_anchor_fqn` method)
- Test: `spec/kumi/core/nast_children_spec.rb`

Scope note vs the design spec: the spec listed five hand-rolled NAST traversals. Only
`AttachTerminalInfoPass` and `AttachAnchorsPass` are rewritten here — `ContractCheckerPass`
and `LowerToIRV2Pass` are orphans (see plan header), and `NASTDimensionalAnalyzerPass`'s
case statement does distinct per-node-type analysis, not pure traversal, so a generic
recurse would not shrink it.

- [ ] **Step 1: Write the failing spec**

Create `spec/kumi/core/nast_children_spec.rb` (use a `let`-bound alias, not a constant —
a bare `NAST = ...` in a describe block leaks onto `Object`):

```ruby
# frozen_string_literal: true

RSpec.describe "Kumi::Core::NAST children protocol" do
  let(:nast) { Kumi::Core::NAST }
  let(:const_a) { nast::Const.new(value: 1) }
  let(:const_b) { nast::Const.new(value: 2) }

  it "returns [] for leaf nodes" do
    expect(const_a.children).to eq([])
    expect(nast::InputRef.new(path: [:x]).children).to eq([])
    expect(nast::Ref.new(name: :y).children).to eq([])
    expect(nast::IndexRef.new(name: :i, input_fqn: "x").children).to eq([])
  end

  it "returns args for call-like nodes" do
    call = nast::Call.new(fn: :add, args: [const_a, const_b])
    tuple = nast::Tuple.new(args: [const_a])
    expect(call.children).to eq([const_a, const_b])
    expect(tuple.children).to eq([const_a])
  end

  it "returns operand structure for select, fold, reduce, declaration" do
    select = nast::Select.new(cond: const_a, on_true: const_b, on_false: const_a)
    fold = nast::Fold.new(fn: :sum, arg: const_a)
    reduce = nast::Reduce.new(fn: :sum, over: [:i], arg: const_b)
    decl = nast::Declaration.new(name: :d, body: const_a)
    expect(select.children).to eq([const_a, const_b, const_a])
    expect(fold.children).to eq([const_a])
    expect(reduce.children).to eq([const_b])
    expect(decl.children).to eq([const_a])
  end

  it "returns node-valued parts of pairs and hashes" do
    pair = nast::Pair.new(key: const_a, value: const_b)
    expect(pair.children).to eq([const_a, const_b])

    symbol_pair = nast::Pair.new(key: :k, value: const_b)
    expect(symbol_pair.children).to eq([const_b])

    hash = nast::Hash.new(pairs: [pair])
    expect(hash.children).to eq([pair])
  end

  it "returns declarations for modules" do
    decl = nast::Declaration.new(name: :d, body: const_a)
    mod = nast::Module.new(decls: { d: decl })
    expect(mod.children).to eq([decl])
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/kumi/core/nast_children_spec.rb`
Expected: FAIL — `undefined method 'children'`

- [ ] **Step 3: Add `children` to NAST nodes**

In `lib/kumi/core/nast.rb`:

In the `Node` struct block (after `accept`):
```ruby
        def children = []

        def each_child(&) = children.each(&)
```

In each class, after its `accept` method:

`ImportCall`, `Call`, `Tuple`:
```ruby
        def children = args
```

`Pair`:
```ruby
        def children = [key, value].grep(Node)
```

`Hash`:
```ruby
        def children = pairs
```

`Select`:
```ruby
        def children = [cond, on_true, on_false]
```

`Fold` and `Reduce`:
```ruby
        def children = [arg]
```

`Declaration`:
```ruby
        def children = [body]
```

In the `Module` struct block (after `accept`):
```ruby
        def children = decls.values
```

- [ ] **Step 4: Run the spec to verify it passes**

Run: `bundle exec rspec spec/kumi/core/nast_children_spec.rb`
Expected: PASS (5 examples)

- [ ] **Step 5: Rewrite `AttachTerminalInfoPass#annotate!`**

Replace the whole `annotate!` method (`attach_terminal_info_pass.rb`) with:

```ruby
          def annotate!(node, by_fqn)
            case node
            when NAST::InputRef
              annotate_input_ref!(node, by_fqn)
            else
              node.children.each { |child| annotate!(child, by_fqn) }
            end
          end
```

- [ ] **Step 6: Rewrite `AttachAnchorsPass#pick_anchor_fqn`'s walk lambda**

Replace the `walk` lambda body in `attach_anchors_pass.rb` with:

```ruby
            walk = lambda do |x|
              case x
              when NAST::InputRef
                ax = axes_of(x)
                found ||= ir_fqn(x) if prefix?(wanted_axes, ax)
              when NAST::Ref
                decl = @snast.decls.fetch(x.name) { raise "unknown declaration #{x.name}" }
                walk.call(decl.body)
              when NAST::IndexRef
                found ||= x.input_fqn
              else
                x.children.each { |child| walk.call(child) }
              end
            end
```

(Behavior note: the old version visited `Pair#value` only; `children` adds the key when it is a node, where annotation/anchor walks are no-ops on `Const` keys — equivalent results.)

- [ ] **Step 7: Run the full suite**

Run: `bundle exec rspec`
Expected: `927 examples, 0 failures, 3 pending`

- [ ] **Step 8: Commit**

```bash
git add lib/kumi/core/nast.rb lib/kumi/core/analyzer/passes spec/kumi/core/nast_children_spec.rb
git commit -m "Add NAST children protocol and use it for traversal passes"
```

---

### Task 12: Rename the 8 non-suffixed passes

**Files:** 8 file renames under `lib/kumi/core/analyzer/passes/`, references across `lib/`, `spec/`, `docs/`, and the inflector in `lib/kumi.rb`.

- [ ] **Step 1: Rename the implementation files**

```bash
cd lib/kumi/core/analyzer/passes
git mv name_indexer.rb name_indexer_pass.rb
git mv input_collector.rb input_collector_pass.rb
git mv declaration_validator.rb declaration_validator_pass.rb
git mv semantic_constraint_validator.rb semantic_constraint_validator_pass.rb
git mv dependency_resolver.rb dependency_resolver_pass.rb
git mv toposorter.rb toposorter_pass.rb
git mv unsat_detector.rb unsat_detector_pass.rb
git mv load_input_cse.rb load_input_cse_pass.rb
cd -
```

- [ ] **Step 2: Rename the matching spec files**

```bash
cd spec/kumi/analyzer/passes
git mv name_indexer_spec.rb name_indexer_pass_spec.rb
git mv toposorter_spec.rb toposorter_pass_spec.rb
git mv dependency_resolver_spec.rb dependency_resolver_pass_spec.rb
cd -
```

(`definition_validator_spec.rb` keeps its name — it doesn't match a class file name today and renaming it is not required by the convention, which covers pass classes/files.)

- [ ] **Step 3: Update all references**

Word-boundary replace across the repo (the `\b` guards make this idempotent — `NameIndexerPass` will not match `\bNameIndexer\b`):

```bash
grep -rl --include="*.rb" --include="*.md" -E "\b(NameIndexer|InputCollector|DeclarationValidator|SemanticConstraintValidator|DependencyResolver|Toposorter|UnsatDetector|LoadInputCSE)\b" lib spec docs \
  | xargs sed -i -E \
    -e 's/\bNameIndexer\b/NameIndexerPass/g' \
    -e 's/\bInputCollector\b/InputCollectorPass/g' \
    -e 's/\bDeclarationValidator\b/DeclarationValidatorPass/g' \
    -e 's/\bSemanticConstraintValidator\b/SemanticConstraintValidatorPass/g' \
    -e 's/\bDependencyResolver\b/DependencyResolverPass/g' \
    -e 's/\bToposorter\b/ToposorterPass/g' \
    -e 's/\bUnsatDetector\b/UnsatDetectorPass/g' \
    -e 's/\bLoadInputCSE\b/LoadInputCSEPass/g' \
    -e 's/\bload_input_cse\b/load_input_cse_pass/g'
```

The last expression also fixes the inflector key in `lib/kumi.rb`
(`"load_input_cse_pass" => "LoadInputCSEPass"` after both substitutions). The other
seven renames need no inflector entries — zeitwerk derives them.

- [ ] **Step 4: Verify nothing was missed**

```bash
grep -rn --include="*.rb" -E "\b(NameIndexer|InputCollector|DeclarationValidator|SemanticConstraintValidator|DependencyResolver|Toposorter|UnsatDetector|LoadInputCSE)\b(?!Pass)" lib spec || echo CLEAN
```

If your grep lacks lookahead support, use: `grep -rn --include="*.rb" -E "\b(NameIndexer|InputCollector|Toposorter|UnsatDetector|LoadInputCSE)[^P]" lib spec` and review hits manually.
Expected: `CLEAN` (or no hits).

- [ ] **Step 5: Run the full suite**

Run: `bundle exec rspec`
Expected: `927 examples, 0 failures, 3 pending`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Rename passes to use the Pass suffix consistently"
```

---

### Task 13: Pipeline self-check spec

**Files:**
- Test: `spec/kumi/analyzer_pipeline_contract_spec.rb`

- [ ] **Step 1: Write the spec**

Create `spec/kumi/analyzer_pipeline_contract_spec.rb`:

```ruby
# frozen_string_literal: true

RSpec.describe "analyzer pipeline contracts" do
  let(:pipeline) do
    Kumi::Analyzer::DEFAULT_PASSES +
      Kumi::Analyzer::LOWERING_PASSES +
      Kumi::Analyzer::TARGET_PASSES
  end

  let(:initial_keys) { %i[registry schema_digest] }

  it "declares a contract on every pipeline pass" do
    undeclared = pipeline.reject(&:contract_declared?)
    expect(undeclared).to be_empty, "passes without contracts: #{undeclared.map(&:name).inspect}"
  end

  it "names every pipeline pass with a Pass suffix" do
    badly_named = pipeline.reject { |pass| pass.name.split("::").last.end_with?("Pass") }
    expect(badly_named).to be_empty, "passes without Pass suffix: #{badly_named.map(&:name).inspect}"
  end

  it "orders passes so every required read has an earlier producer" do
    available = initial_keys.dup
    pipeline.each do |pass|
      missing = pass.declared_reads - available
      expect(missing).to be_empty, "#{pass.name} reads #{missing.inspect} before any earlier pass writes it"
      available.concat(pass.declared_writes)
    end
  end
end
```

- [ ] **Step 2: Run it**

Run: `bundle exec rspec spec/kumi/analyzer_pipeline_contract_spec.rb`
Expected: PASS (3 examples). A failure here means a contract from Tasks 6–10 is wrong or a pass was missed — the message names it; fix the declaration, not the spec.

- [ ] **Step 3: Run the full suite**

Run: `bundle exec rspec`
Expected: `930 examples, 0 failures, 3 pending`

- [ ] **Step 4: Commit**

```bash
git add spec/kumi/analyzer_pipeline_contract_spec.rb
git commit -m "Add pipeline contract self-check spec"
```

---

### Task 14: Cleanup — analyzer.rb comments, redundant requires, ratchet refresh

**Files:**
- Modify: `lib/kumi/analyzer.rb`
- Modify: `lib/kumi/core/analyzer/passes/lower_to_dfir_pass.rb` (drop `require "kumi/ir/df"`)
- Modify: `.rubocop_todo.yml` (regenerated)

- [ ] **Step 1: Strip the numbered/descriptive comments from the pass lists in `lib/kumi/analyzer.rb`**

The contracts and the self-check spec now carry this information. The lists become:

```ruby
    DEFAULT_PASSES = [
      Passes::NameIndexerPass,
      Passes::ImportAnalysisPass,
      Passes::InputCollectorPass,
      Passes::InputFormSchemaPass,
      Passes::DeclarationValidatorPass,
      Passes::SemanticConstraintValidatorPass,
      Passes::DependencyResolverPass,
      Passes::ToposorterPass,
      Passes::InputAccessPlannerPass
    ].freeze

    # Lowering pipeline: NAST -> SNAST -> DFIR -> VecIR -> LoopIR
    LOWERING_PASSES = [
      Passes::NormalizeToNASTPass,
      Passes::ConstantFoldingPass,
      Passes::NASTDimensionalAnalyzerPass,
      Passes::SNASTPass,
      Passes::UnsatDetectorPass,
      Passes::OutputSchemaPass,
      Passes::AttachTerminalInfoPass,
      Passes::AttachAnchorsPass,
      Passes::PrecomputeAccessPathsPass,
      Passes::LowerToDFIRPass,
      Passes::DFValidatePass,
      Passes::Vec::LowerPass,
      Passes::VecValidatePass,
      Passes::Loop::LowerPass,
      Passes::LoopValidatePass
    ].freeze

    TARGET_PASSES = [
      Passes::Codegen::LoopRubyPass,
      Passes::Codegen::LoopJsPass
    ].freeze
```

(The class names above already reflect Task 12's renames, which Task 12's sed applied to this file — verify they match.)

- [ ] **Step 2: Remove the redundant internal require**

In `lib/kumi/core/analyzer/passes/lower_to_dfir_pass.rb`, delete the line `require "kumi/ir/df"`. Verify no other `require "kumi/` remains in pass files:

```bash
grep -rn 'require "kumi/' lib/kumi/core/analyzer/passes/ || echo CLEAN
```

Expected: `CLEAN`. (Other `require_relative` uses elsewhere in `lib/` are load-order or zeitwerk-ignored cases — leave them.)

- [ ] **Step 3: Refresh the rubocop ratchet** (the refactor moved offense locations)

```bash
bundle exec rubocop --auto-gen-config --auto-gen-only-exclude --exclude-limit 300
bundle exec rubocop
```

Expected: `no offenses detected`

- [ ] **Step 4: Full verification — the rake default must work end to end**

Run: `bundle exec rake`
Expected: `930 examples, 0 failures, 3 pending` followed by rubocop `no offenses detected`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Strip pass-list comments, drop redundant requires, refresh rubocop ratchet"
```

---

## Final report to user

After Task 14, report: commit list, final suite/lint status, and the orphan-pass list
(`LowerToIRV2Pass`, `AssembleIRV2Pass`, `IRDependencyPass`, `IRExecutionSchedulePass`,
`LoadInputCSEPass`, `ContractCheckerPass`, `FormalConstraintPropagator`,
`JoinReducePlanningPass`) as a candidate deletion the user should decide on separately.
