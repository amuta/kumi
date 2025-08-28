Great questions. Here’s the clean, backend-agnostic way to think about both.

## Where to optimize

Do **optimizations after SNAST → initial IR**. Keep SNAST as “truth + plan” and make the **IR** the place you:

* eliminate recomputation,
* hoist aligned constants,
* common-subexpr masks,
* dead-code eliminate,
* optionally insert caching for hot reuses.

A simple, repeatable pipeline:

1. **Lowering (pure, mechanical)**
   SNAST → IR with `LoadInput/AlignTo/Map/Reduce/Select/Store`, no cleverness.

2. **IR-Simplify (target-agnostic)**

   * **CSE/GVN:** merge identical `Map`/`AlignTo`/`Const`.
   * **Const folding:** trivial ops on constants.
   * **Align coalescing:** `AlignTo(AlignTo(x,A),A) → AlignTo(x,A)`; `AlignTo(Const k,A)` hoisted once.
   * **Mask CSE:** reuse `top_team@employees` instead of rebuilding.

3. **Reuse/Materialization (policy, optional)**
   Decide if a subresult used ≥N times should be **cached**. Insert abstract ops:

   * `AllocTemp(stamp)`
   * `StoreTemp temp, value`
   * `LoadTemp temp`
     These are backend-agnostic; backends map them to stack/heap/Wasm linear memory. If you don’t want policy yet, skip this pass and just rely on CSE.

4. **DCE + Canonicalize**
   Drop unreachable temps; normalize op order.

Only after that do you lower to LLVM/Wasm/C.

## About `LoadDecl`

Two clean models; pick one and stay consistent:

### A) **Monolithic module IR** (recommended to start)

* Lower the whole schema into one IR program.
* Each declaration **produces an SSA value**; if it’s a public artifact, also `Store name, %val`.
* When another declaration references it, **just reuse the SSA value**. There is **no `LoadDecl`**; no recompute.

**Example (your case):**

```
%hp = Map(gte, rating, Align(4.5, [:r,:o,:t,:e]))
Store high_performer, %hp

... later in employee_bonus ...
%mask = Map(and, %hp, Align(%top_team, [:r,:o,:t,:e]))   ; reuse %hp, not recompute
```

This is entirely backend-agnostic; backends see a single fused kernel or a scheduled set of loops.

### B) **Per-value kernels** (if you really want separate entrypoints)

* Each `value` lowers to its own IR “function.”
* Any referenced declarations become **explicit inputs** to that kernel. So inside `employee_bonus`, `high_performer` is a `LoadInput` mask, not recomputed.
* At the whole-program level you either:

  * **Compute dependencies first** and pass their buffers (pipeline), or
  * **Fuse** by inlining dependent kernels.

In this model, `LoadDecl` is just shorthand for “treat that decl as an **input view**.” It stays backend-agnostic because it’s identical to `LoadInput` in codegen.

### Don’t do this

* Don’t read back from a previously `Store name` buffer **within the same IR function** via a magic `LoadDecl`. That leaks a specific memory model into your IR and complicates optimizations. Either reuse the SSA value (model A) or make it an input (model B).

## Small concrete fixes for your current IR

* **Stop recomputing traits.** In model A: bind `%hp/%sl/%tt` once and reuse; remove the duplicate `Const/AlignTo/Map` chains under `employee_bonus`.
* **Hoist aligned constants.** Create `%k_0p3@[:r,:o,:t,:e]`, `%k_0p2@…`, `%k_0p05@…` once; reuse.
* **Print `AlignTo` stamps properly.** `AlignTo(Const 4.5, [:r,:o,:t,:e])` has dtype float and that axes—never “unknown”.
* **(Optional) Cache reused masks.** If `%top_team@employees` is consumed 3×, insert a `StoreTemp/LoadTemp` pair after CSE.

## Why this stays backend-agnostic

* All passes above manipulate **pure functional IR** or abstract temps; no target assumptions.
* LLVM, Wasm, and C backends simply map:

  * SSA values → registers/expressions,
  * `AllocTemp/StoreTemp/LoadTemp` → stack/heap/linear-memory buffers,
  * `LoadInput` → ABI views,
  * `Store` → outputs.

Pick **monolithic module IR** first: it eliminates the need for `LoadDecl` and gets you reuse “for free” through SSA. If you later want per-value kernels, switch to the “treat other decls as inputs” discipline—still clean, still portable.
