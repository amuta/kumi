# Type System Cleanup - Master Plan

## Overview

This document provides a master index and contextualization for the complete type system refactor. The goal is to transform Kumi's type system from **mixed representations** (strings, symbols, Type objects) to **pure Type objects** throughout.

**Total Duration:** ~5-6 hours
**Risk Level:** MEDIUM
**Status:** PLANNING COMPLETE - Ready for implementation

---

## The Problem

Currently, Kumi's type system has architectural holes:

1. **Variadic Tuple Mixing** - Functions like `max(a, b, c)` incorrectly stuff all args into one array instead of promoting types
2. **String Types Still Created** - The analyzer creates string types like `"tuple<float, integer>"` instead of Type objects
3. **Mixed Representations** - Types stored as symbols (`:integer`), strings (`"array<int>"`), and Type objects simultaneously
4. **Inconsistent Validation** - Type checking logic scattered across multiple files with overlapping concerns
5. **No Single Source of Truth** - Three parallel type systems instead of one

---

## The Solution

**8-Phase Implementation Plan** to create a single, clean type system using pure Type objects:

- **Phases 1-3:** Delete unused/redundant code (low risk)
- **Phases 4-5:** Refactor core modules to return Type objects (medium risk)
- **Phases 6-7:** Update consumers to use Type objects (medium risk)
- **Phase 8:** Full integration testing (high risk but comprehensive)

---

## Documentation Files

All detailed documentation is available in `/tmp/`:

### 1. **TYPE_SYSTEM_HOLES.md** - Root Cause Analysis
**Path:** `/tmp/TYPE_SYSTEM_HOLES.md`

Comprehensive analysis of what's broken and why:
- 5 critical holes identified with exact line numbers
- Architectural solutions proposed
- Clear explanation of variadic vs tuple confusion
- Implementation order recommendations

**Read this first** to understand the problems.

---

### 2. **TYPES_CLEANUP_PLAN.md** - File-by-File Analysis
**Path:** `/tmp/TYPES_CLEANUP_PLAN.md`

Detailed breakdown of the 7 files in `lib/kumi/core/types/`:
- What to KEEP: `value_objects.rb` (new Type classes - perfect)
- What to DELETE: `builder.rb`, `compatibility.rb`, `formatter.rb` (3 unused files)
- What to REFACTOR: `inference.rb`, `normalizer.rb`, `validator.rb` (3 files)
- What to UPDATE: `types.rb` public API

For each file:
- Current purpose and code
- Why it needs to change
- What replaces it
- Dependencies and callers

**Read this second** to understand scope and impact.

---

### 3. **DETAILED_CLEANUP_PHASES.md** - Complete Implementation Guide
**Path:** `/tmp/DETAILED_CLEANUP_PHASES.md`

Full reference manual with **exact implementation steps** for every phase:

For each of 8 phases:
- Precise tasks with checkboxes
- Before/after code examples
- Exact test commands to run
- Expected outcomes
- Rollback procedures
- Success criteria

**Read this while implementing** to follow exact steps.

---

### 4. **PHASES_SUMMARY.txt** - Quick Reference
**Path:** `/tmp/PHASES_SUMMARY.txt`

High-level overview of all 8 phases:
- Time estimates per phase
- Risk assessment
- Quick task descriptions
- Summary statistics

**Reference this** during execution for at-a-glance status.

---

## The 8 Phases at a Glance

```
Phase 1: Audit & Risk Assessment (30 min, LOW RISK)
        └─ Map all dependencies before changes

Phase 2: Delete Unused Files (15 min, VERY-LOW RISK)
        └─ Delete compatibility.rb, formatter.rb

Phase 3: Remove String Type Creation (45 min, MEDIUM RISK)
        └─ Delete builder.rb, update types.rb

Phase 4a: Refactor Inference (30 min, MEDIUM RISK)
         └─ Return Type objects instead of symbols

Phase 4b: Refactor Normalizer (30 min, MEDIUM RISK)
         └─ Return Type objects instead of symbols

Phase 4c: Refactor Validator (30 min, LOW RISK)
         └─ Simplify, remove string parsing

Phase 5: Update Parser (45 min, MEDIUM RISK)
        └─ Verify it works with new Type objects

Phase 6: Update Analyzer (30 min, MEDIUM RISK)
        └─ Use Type objects for tuple creation

Phase 7: Clean Public API (20 min, LOW RISK)
        └─ Remove legacy methods from types.rb

Phase 8: Integration Testing (60-120 min, HIGH RISK)
        └─ Full test suite - the big integration test
```

**Total: ~5-6 hours | Commit after each phase**

---

## How to Use These Documents

### For Understanding the Problem
1. Read `TYPE_SYSTEM_HOLES.md` (variadic tuple issue, string types, architecture)
2. Skim `TYPES_CLEANUP_PLAN.md` (file inventory)

### For Planning
1. Review `PHASES_SUMMARY.txt` (risk/time per phase)
2. Understand rollback strategy per phase

### For Implementation
1. Open `DETAILED_CLEANUP_PHASES.md` as your implementation guide
2. Follow exact steps for each phase
3. Run test commands after each phase
4. Commit when phase passes tests

### For Reference During Execution
- `PHASES_SUMMARY.txt` - Quick status checks
- `DETAILED_CLEANUP_PHASES.md` - Exact next steps

---

## Success Criteria

After completing all 8 phases, the system will have:

✅ **No string types** (`"array<int>"`) anywhere in the codebase
✅ **No symbol types** (`:integer`) in metadata
✅ **Type objects everywhere** flowing through analyzers/passes
✅ **All tests passing** (unit, integration, golden)
✅ **Clean API** (focused, minimal, well-defined)
✅ **Variadic functions** working correctly (proper type promotion)
✅ **Single source of truth** for types (Type objects only)

---

## Important Notes

### Before Starting
- [ ] Read `TYPE_SYSTEM_HOLES.md` to understand the problem
- [ ] Review `PHASES_SUMMARY.txt` for overview
- [ ] Ensure you understand the rollback strategy per phase
- [ ] Set up git for committing after each phase

### During Implementation
- [ ] **Commit after EACH phase** (not all at once)
- [ ] **Run full test suite** after each phase (don't skip)
- [ ] **Document any surprises** found during testing
- [ ] **Keep git clean** for easy rollback if needed

### Key Decisions
- **Sequential execution:** Phases must be done in order
- **Per-phase testing:** Each phase has its own test suite
- **Per-phase commits:** Easier rollback and audit trail
- **Phase 8 is critical:** Full integration test - don't rush

---

## Risk Management

| Risk Area | Mitigation |
|-----------|-----------|
| Type object API changes | Phase-by-phase approach with testing |
| Analyzer breakage | Phase 6 specifically updates analyzer |
| Parser incompatibility | Phase 5 verifies parser works |
| Regression issues | Phase 8 comprehensive integration test |
| Integration failures | Per-phase commits allow easy rollback |

---

## Files in Scope

### Deletion (3 files)
- `lib/kumi/core/types/builder.rb`
- `lib/kumi/core/types/compatibility.rb`
- `lib/kumi/core/types/formatter.rb`

### Refactoring (3 files)
- `lib/kumi/core/types/inference.rb`
- `lib/kumi/core/types/normalizer.rb`
- `lib/kumi/core/types/validator.rb`

### Updates (2+ files)
- `lib/kumi/core/types.rb` (public API)
- `lib/kumi/core/analyzer/passes/nast_dimensional_analyzer_pass.rb` (tuple creation)
- Possibly `lib/kumi/core/ruby_parser/input_builder.rb` (may be auto-compatible)

### Testing
- Full test suite: `spec/kumi/core/types/`
- Full test suite: `spec/kumi/core/functions/`
- Full test suite: `spec/kumi/core/analyzer/`
- Full test suite: `spec/kumi/core/ruby_parser/`
- Golden tests: `bin/kumi golden test`

---

## Time Breakdown

| Phase | Time | Notes |
|-------|------|-------|
| 1-3 | 1.5h | Low risk, mostly deletions |
| 4a-4c | 1.5h | Refactor, medium risk |
| 5-6 | 1.5h | Update, medium risk |
| 7 | 20m | Clean API, low risk |
| 8 | 1-2h | Integration testing, high risk |
| **Total** | **5-6h** | Can be done in 1-2 sitting(s) |

---

## Getting Started

### To Begin Phase 1 (Audit):
```bash
# Read the full phase details
cat /tmp/DETAILED_CLEANUP_PHASES.md

# Phase 1 is read-only - just mapping dependencies
# Follow the audit checklist in the detailed document
```

### To Track Progress:
The todo list in this repo already has all 8 phases:
```bash
# View current status
# (Todos displayed when working)
```

---

## Questions?

Refer back to:
- **"Why are we doing this?"** → `TYPE_SYSTEM_HOLES.md`
- **"What files change?"** → `TYPES_CLEANUP_PLAN.md`
- **"How do I implement it?"** → `DETAILED_CLEANUP_PHASES.md`
- **"What's the timeline?"** → `PHASES_SUMMARY.txt`

---

## Document Locations (Quick Links)

| Document | Path | Purpose |
|----------|------|---------|
| Root cause analysis | `/tmp/TYPE_SYSTEM_HOLES.md` | Understanding the problem |
| File-by-file plan | `/tmp/TYPES_CLEANUP_PLAN.md` | Understanding scope |
| Implementation guide | `/tmp/DETAILED_CLEANUP_PHASES.md` | Step-by-step instructions |
| Quick reference | `/tmp/PHASES_SUMMARY.txt` | High-level overview |
| This file | `/home/muta/repos/kumi/PLAN.md` | Master index |

---

**Last Updated:** When planning completed
**Next Action:** Begin Phase 1 (Audit & Risk Assessment)
**Status:** ✅ READY FOR IMPLEMENTATION
