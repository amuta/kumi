# Analyzer Debug System

## Debug Module

**File**: `lib/kumi/core/analyzer/debug.rb`

**Enable**: `KUMI_DEBUG_STATE=1`

**Output**: JSONL to stdout with state diffs and timing per pass

**Configuration**:
- `KUMI_DEBUG_REQUIRE_FROZEN=1` - Enforce state immutability checks

## Checkpoint System

**Files**: 
- `lib/kumi/core/analyzer/checkpoint.rb`
- `lib/kumi/core/analyzer/state_serde.rb`

**Enable**: `KUMI_CHECKPOINT=1`

**Configuration**:
- `KUMI_CHECKPOINT_DIR=path` - Output directory (default: `/tmp/kumi_checkpoints`)
- `KUMI_CHECKPOINT_FORMAT=marshal|json|both` - File format (default: `marshal`)
- `KUMI_CHECKPOINT_PHASE=before|after|both` - When to save (default: `both`)

**Resume/Stop**:
- `KUMI_RESUME_FROM=file.msh` - Resume from checkpoint file
- `KUMI_RESUME_AT=PassName` - Skip to specific pass
- `KUMI_STOP_AFTER=PassName` - Stop after specific pass

## Object Printers

**File**: `spec/support/debug_printers.rb`

Handles clean output for debug logs. Add new object types here when they appear as `#<Object:0x...>` in debug output.

## Usage

```bash
# Basic debug
KUMI_DEBUG_STATE=1 bundle exec ruby script.rb

# Debug with checkpoints
KUMI_DEBUG_STATE=1 KUMI_CHECKPOINT=1 bundle exec ruby script.rb

# Resume from checkpoint
KUMI_RESUME_FROM=/tmp/kumi_checkpoints/005_TypeChecker_after.msh bundle exec ruby script.rb

# Stop at specific pass for debugging
KUMI_STOP_AFTER=BroadcastDetector bundle exec ruby script.rb
```