# VM Profiling with Schema Differentiation

## Overview

Profiles VM operation execution with schema-level differentiation. Tracks operations by schema type for multi-schema performance analysis.

## Core Components

**Profiler**: `lib/kumi/core/ir/execution_engine/profiler.rb`
- Streams VM operation events with schema identification
- Supports persistent mode for cross-run analysis
- JSONL event format with operation metadata

**Profile Aggregator**: `lib/kumi/dev/profile_aggregator.rb`  
- Analyzes profiling data by schema type
- Generates summary and detailed performance reports
- Schema breakdown showing operations and timing per schema

**CLI Integration**: `bin/kumi profile`
- Processes JSONL profiling data files
- Multiple output formats: summary, detailed, raw

## Usage

### Basic Profiling

```bash
# Single schema with operations
KUMI_PROFILE=1 KUMI_PROFILE_OPS=1 KUMI_PROFILE_FILE=profile.jsonl ruby script.rb

# Persistent mode across multiple runs
KUMI_PROFILE=1 KUMI_PROFILE_PERSISTENT=1 KUMI_PROFILE_OPS=1 KUMI_PROFILE_FILE=profile.jsonl ruby script.rb

# Streaming mode for real-time analysis  
KUMI_PROFILE=1 KUMI_PROFILE_STREAM=1 KUMI_PROFILE_OPS=1 KUMI_PROFILE_FILE=profile.jsonl ruby script.rb
```

### CLI Analysis

```bash
# Summary report with schema breakdown
kumi profile profile.jsonl --summary

# Detailed per-operation analysis
kumi profile profile.jsonl --detailed

# Raw event stream
kumi profile profile.jsonl --raw
```

## Environment Variables

**Core**:
- `KUMI_PROFILE=1` - Enable profiling
- `KUMI_PROFILE_FILE=path` - Output file (required)
- `KUMI_PROFILE_OPS=1` - Enable VM operation profiling

**Modes**:
- `KUMI_PROFILE_PERSISTENT=1` - Append to existing files across runs
- `KUMI_PROFILE_STREAM=1` - Stream individual events vs batch
- `KUMI_PROFILE_TRUNCATE=1` - Truncate existing files

## Event Format

JSONL with operation metadata:

```json
{"event":"vm_operation","schema":"TestSchema","operation":"LoadInput","duration_ms":0.001,"timestamp":"2025-01-20T10:30:45.123Z"}
{"event":"vm_operation","schema":"TestSchema","operation":"Map","duration_ms":0.002,"timestamp":"2025-01-20T10:30:45.125Z"}
```

## Schema Differentiation

Tracks operations by schema class name for multi-schema analysis:

**Implementation**:
- Schema name propagated through compilation pipeline
- Profiler tags each VM operation with schema identifier  
- Aggregator groups operations by schema type

**Output Example**:
```
Total operations: 24 (0.8746ms)
Schemas analyzed: SchemaA, SchemaB
  SchemaA: 12 operations, 0.3242ms
  SchemaB: 12 operations, 0.0504ms
```

## Performance Analysis

**Reference Operations**: Typically dominate execution time in complex schemas
**Map Operations**: Element-wise computations on arrays
**LoadInput Operations**: Data access operations

Use schema breakdown to identify performance differences between schema types.