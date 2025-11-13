# LoopIR Roadmap

LoopIR is the stage where DF’s pure dataflow graph becomes structured loops,
accumulators, and buffer lifetimes. This document captures the phases and
responsibilities we want in the redesigned LoopIR.

## Inputs
- `DF::Graph` – already axis-aware, typed, and enriched with array/stencil ops.
- Access plans / anchor metadata – attached to DF LoadInput/LoadField nodes.
- Registry information – kernel intent, shift/roll defaults, reducer specs.

## Responsibilities
1. **Loop Materialization**
   - Translate DF axis stacks into nested loops (`LoopStart/LoopEnd`), reusing
     plan metadata to decide ordering and reuse of anchor collections.
   - Introduce explicit loop-carried registers for axis indices (`%x_i`) and
     vector lanes once VecIR splits axes.
2. **Accumulator / Reduction Expansion**
   - Convert `DF::Reduce` into accumulator declarations, updates, and yields.
   - Handle partial reductions (axis subsets) with the same semantics LIR uses
     today.
3. **Stencil Expansion**
   - Lower `AxisShift`/`AxisBroadcast` into gather/clamp/mask logic with explicit
     temporary registers. Because DF already stores axis/policy/offset we can do
     this mechanically rather than rediscovering it.
4. **Import Expansion**
   - Inline or reference imported schemas by pulling their already-compiled DF /
     Loop IR fragments, respecting mapping keys.
5. **Memory & Buffer Prep**
   - Identify which results require materialization vs. streaming. This stage
     can stay minimal (just mark allocation requirements) so BufIR can later
     decide actual buffer placement.
6. **Metadata Propagation**
   - Keep axis/plan identifiers on LoopIR nodes so VecIR and BufIR know where
     values came from and can reason about aliasing and scheduling.

## Pipeline Phases
1. **DF→Loop Lowering Pass**
   - Walk DF graph in topological order, emitting loop/accumulator instructions.
   - Use plan IDs from load ops to reopen identical loops for different
     declarations (loop fusion ready).
2. **Loop Simplification**
   - Deduplicate nested loops produced by shared axes.
   - Remove broadcasts that are now implicit through loop ordering.
3. **Fusion / Scheduling (existing logic)**
   - Reuse current LIR fusion passes with minimal changes because loop
     constructs remain the same, just fed by richer metadata.
4. **Preparation for VecIR / BufIR**
   - Annotate loops with unit-stride/lane-friendly axes from DF axis metadata.
   - Mark values that should be staged in buffers vs. streamed.

# Pre-Loop Optimizations (DF Stage)

Before LoopIR we can and should run transformations while the program is still
pure dataflow. This keeps loop-level passes simpler.

## Candidates
1. **Broadcast Simplification**
   - Collapse chains of `AxisBroadcast`, eliminate redundant broadcasts when
     axes already align, fold broadcasts of constants.
2. **Stencil CSE / Duplication**
   - Deduplicate identical `AxisShift` nodes so multiple consumers share the
     same gathered neighborhood, reducing later gather instructions.
3. **Map Fusion**
   - Combine successive `Map` nodes over identical axes into a single composite
     kernel, akin to current scalar fusion but without loops in the way.
4. **Constant Folding / Dead Value Removal**
   - Because DF nodes carry full type info, we can propagate constants, remove
     unused subgraphs, and simplify `Select` branches earlier.
5. **Import Inlining Decisions**
   - Decide whether an `ImportCall` should be inlined or left as a reference
     based on size/axes. Doing this before LoopIR avoids building loops we’ll
     immediately inline away.
6. **Axis Planning / Reordering**
   - Analyze axis stacks to detect opportunities for reordering (e.g., move
     broadcast axes outward) before loops exist. Emit `AxisBroadcast` /
     `AxisShift` rewrites to match the desired execution order.
7. **Tuple / Array Canonicalization**
   - Normalize array literals (`ArrayBuild`) and eliminate unused slots before
     they become concrete buffers.

Running these optimizations in DF makes LoopIR purely about executing the final
plan (loops + buffers), keeping the downstream passes close to what we already
ship today while enabling richer rewrites up front.
