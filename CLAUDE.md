# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Final Project Goal

**dwarf2pdb** produces an executable that converts DWARF-embedded executables into stripped executables with separate PDB debug files:

**Input:** DWARF-embedded executable (ELF/PE with embedded DWARF debug info)
**Output:** Stripped executable + separate PDB file

This enables Windows debugging tools (Visual Studio, WinDbg) to work with executables originally compiled with DWARF debug information (GCC, Clang on Linux/macOS).

## Development Methodology: Test Driven Development (TDD)

This project follows **strict Test Driven Development**:

1. **Write tests first** - Every feature starts with a failing test that defines the expected behavior
2. **Implement minimally** - Write just enough code to make the test pass
3. **Refactor** - Improve code quality while maintaining passing tests
4. **Iterate** - Repeat the cycle for each new feature

**TDD Test Hierarchy:**
- **Unit tests (ut/)** - Test individual components in isolation
- **Integration tests (it/)** - Test format I/O pipelines with real libraries
- **System tests (st/)** - Test end-to-end conversion with real executables

All code changes must maintain or increase test coverage. No feature is complete without corresponding tests.

## Project Overview

**dwarf2pdb** is a DWARF ↔ PDB bidirectional converter that enables round-trip translation between debug formats. The project uses a three-layer architecture with a format-neutral intermediate representation (IR) layer between DWARF and PDB layers.

### Project Organization

**Root Directory** - Important architecture and design documents
- `README.md` - Architecture discussion and design rationale
- `FIRST_IMPLEMENTATION.md` - Skeleton project structure
- `TEST_STRUCTURE.md` - Test infrastructure design with Catch2
- `NODES.md` - Comprehensive DWARF ↔ PDB ↔ IR mapping table
- `DWARF5_PDB_MATCH.md` - Detailed format correspondence
- `CLAUDE.md` - This file

**doc/** - User documentation and setup guides
- `GETTING_STARTED.md` - Quick setup guide with library downloads
- `LIBRARY_SETUP.md` - LLVM/PDB/DWARF library configuration details
- `LIBRARY_USAGE_EXAMPLES.md` - API usage patterns and code examples
- `COMPILER_SETUP.md` - Compiler environment configuration

**script/** - Build and environment setup scripts
- `download_tool_libs.cmake` - CMake script for downloading libraries and tools
- `setup_msvc_env.bat` - Activate local MSVC environment (Windows)
- `setup_clang64_env.bat` - Activate local Clang64 environment (Windows)
- `setup_gcc32_env.bat` - Activate local GCC32 environment (Windows)
- `test_library_setup.bat` / `.sh` - Quick library setup verification

### Architecture Philosophy

The converter uses **DWARF → IR → PDB** and **PDB → IR → DWARF** pipelines instead of direct conversion. This solves critical issues:
- Shared/recursive type identity across formats
- Different scoping models (DWARF's lexical nesting vs PDB's TPI stream)
- Forward declarations vs full definitions
- Anonymous aggregates and template instantiations

**Key Insight:** Never try to reuse DWARF offsets or PDB type indices as canonical IDs. The IR layer maintains its own `IRTypeID` system with per-format mapping tables.

## Build System

### Directory Structure
```
build/                      # CMake build directory
├── dwarf_pdb_converter     # Main CLI executable
├── lib/                   # Static/shared libraries
└── test/                  # All test executables and generated files
    ├── ut_tests           # Unit tests
    ├── it_dwarf_tests     # DWARF integration tests
    ├── it_pdb_tests       # PDB integration tests
    └── st_tests           # System tests
```

### Common Commands

**Configure and build:**
```bash
cmake -S . -B build
cmake --build build
```

**Run all tests:**
```bash
ctest --test-dir build
```

**Run specific test suites:**
```bash
./build/test/ut_tests              # Unit tests: roundtrip node → IR → node
./build/test/it_dwarf_tests        # Integration: DWARF binary I/O simulation
./build/test/it_pdb_tests          # Integration: PDB binary I/O simulation
./build/test/st_tests              # System: end-to-end toolchain
```

**Run CLI converter:**
```bash
./build/dwarf_pdb_converter --dwarf-to-pdb input.o output.pdb
./build/dwarf_pdb_converter --pdb-to-dwarf input.pdb output.o
```

**Run single test case:**
```bash
./build/test/ut_tests "DWARF node -> IR -> DWARF node roundtrip basic"
./build/test/it_pdb_tests -t "[pdb]"  # Run tests tagged with [pdb]
```

**Environment setup (Windows):**
```bash
script\setup_msvc_env.bat     # Activate local MSVC environment
script\setup_clang64_env.bat  # Activate local Clang64 environment
script\setup_gcc32_env.bat    # Activate local GCC32 environment
```

## Code Architecture

### Three-Layer Design

**1. IR Layer (src/ir/)** - Format-neutral canonical representation
- `IRTypeTable` - Owns all type instances, handles deduplication
- `IRType` - Base type node (struct/union, array, pointer, etc.)
- `IRScope` - Lexical scope tree (CU, namespace, function, block)
- `IRSymbol` - Variables, parameters, functions
- `IRMaps` - Bidirectional mappings between format IDs and IRTypeID

**2. DWARF Layer (src/dwarf/)**
- `DwarfNode` - Low-level DIE representation with tag/attributes
- `DwarfReader` - Parses DWARF → builds IR (fills `mapDieToIR`)
- `DwarfWriter` - Emits IR → DWARF binary (assigns DIE offsets via `mapIRToDie`)

**3. PDB Layer (src/pdb/)**
- `PdbNode` - Low-level CodeView record representation (LF_*, S_*)
- `PdbReader` - Parses TPI/symbol streams → builds IR (fills `mapTItoIR`)
- `PdbWriter` - Emits IR → PDB streams (assigns type indices via `mapIRtoTI`)

**4. Pipeline (src/pipeline/)**
- `DwarfToPdb` - Orchestrates IR (from DWARF) → PdbNode translation
- `PdbToDwarf` - Orchestrates IR (from PDB) → DwarfNode translation

**5. Utilities (src/util/)**
- `Compare` - Deep structural equality for IR, DwarfNode, PdbNode (enables round-trip testing)

### Memory Management

- **Ownership:** `IRTypeTable` owns all `IRType` via `unique_ptr`. `IRScope` owns child scopes via `unique_ptr`.
- **References:** Cross-references use `IRTypeID` integers or raw pointers (never `shared_ptr` to avoid cycles)
- **Parent pointers:** Non-owning raw pointers for tree traversal

### ID Mapping Strategy

Each format maintains separate ID spaces:
- **DWARF:** DIE offsets (uint64_t)
- **PDB:** Type indices starting at 0x1000 (uint32_t)
- **IR:** IRTypeID (sequential uint32_t starting at 1)

Mappings stored in `IRMaps`:
```cpp
// DWARF side
std::unordered_map<uint64_t, IRTypeID> dwarfDieToIR;
std::unordered_map<IRTypeID, uint64_t> irToDwarfDie;

// PDB side
std::unordered_map<uint32_t, IRTypeID> pdbTIToIR;
std::unordered_map<IRTypeID, uint32_t> irToPdbTI;
```

## Test Structure

Tests follow a **ut/it/st** hierarchy based on TEST_STRUCTURE.md:

**Unit Tests (ut/)** - Test in-memory transformations
- `test_roundtrip_dwarf.cpp` - DwarfNode → IR → DwarfNode
- `test_roundtrip_pdb.cpp` - PdbNode → IR → PdbNode

**Integration Tests (it/)** - Test format I/O pipelines
- `it/dwarf/test_dwarf_integration.cpp` - Full DWARF binary emit/parse cycle
- `it/pdb/test_pdb_integration.cpp` - Full PDB binary emit/parse cycle

**System Tests (st/)** - End-to-end toolchain validation
- `test_system_pipeline.cpp` - Compile sample code → convert → verify

All test executables output to `build/test/` and run with that as working directory. Test-generated files (tmp_out_dwarf.o, tmp_out.pdb) are created in `build/test/`.

## Key Implementation Details

### Handling Bitfields
- DWARF: `DW_TAG_member` with `DW_AT_bit_size`, `DW_AT_bit_offset`, `DW_AT_data_member_location`
- PDB: `LF_BITFIELD` record with position/width
- IR: `IRField` with `bitSize`, `bitOffset`, `byteOffset` fields

### Anonymous Unions in Unions
- DWARF: Unnamed `DW_TAG_member` with nested `DW_TAG_union_type`
- PDB: `LF_MEMBER` (offset 0) pointing to internal `LF_UNION` record
- IR: Mark `IRField` with `isAnonymousArm = true` flag

### Scope Fidelity
- DWARF scopes types lexically (local struct inside function is child DIE)
- PDB scopes types in TPI stream, tracks locality via symbol records
- IR preserves lexical nesting via `IRScope` tree with `parent`/`children`

### Recursive Types
Example: `struct Node { Node* next; }`
- Use `IRTypeID` to break cycles
- Build forward references first, fill in details after
- Both DWARF and PDB support forward declarations naturally

## Format Mapping Reference

Key construct mappings (see NODES.md for full table):

| Concept | DWARF | PDB | IR |
|---------|-------|-----|-----|
| Compile unit | `DW_TAG_compile_unit` | DBI module + `S_COMPILE3` | `IRScope::CompileUnit` |
| Struct/class | `DW_TAG_structure_type` | `LF_STRUCTURE` + `LF_FIELDLIST` | `IRType::StructOrUnion` |
| Union | `DW_TAG_union_type` | `LF_UNION` + `LF_FIELDLIST` | `IRType::StructOrUnion` (isUnion=true) |
| Array | `DW_TAG_array_type` + `DW_TAG_subrange_type` | `LF_ARRAY` | `IRType::Array` with `dims[]` |
| Pointer | `DW_TAG_pointer_type` | `LF_POINTER` | `IRType::Pointer` |
| Function | `DW_TAG_subprogram` | `S_GPROC32`/`S_LPROC32` | `IRScope::Function` + `IRSymbol::Function` |
| Member field | `DW_TAG_member` | `LF_MEMBER` in `LF_FIELDLIST` | `IRField` |

## Development Workflow

When implementing new format support:

1. **Add to IR first** - Extend `IRType`/`IRScope`/`IRField` structures
2. **Update readers** - Teach `DwarfReader` and `PdbReader` to populate new IR fields
3. **Update writers** - Teach `DwarfWriter` and `PdbWriter` to emit from IR
4. **Update pipeline** - Adjust `DwarfToPdb`/`PdbToDwarf` translation logic
5. **Add comparison** - Extend `Compare.cpp` equality checks
6. **Write tests** - Add roundtrip tests to verify no information loss

## Important Constraints

- **Never modify test working directory:** Tests run in `build/test/`, respect this
- **Don't duplicate types:** Always check `IRTypeTable` before creating new `IRType`
- **Preserve bitfield layout:** Exact bit positions matter for ABI compatibility
- **Use readFromModel for tests:** Test helpers inject in-memory models, not file I/O
- **Keep format nodes separate:** `DwarfNode`/`PdbNode` are views, not truth

## Documentation Resources

**Root Directory - Architecture & Design:**
- `README.md` - Architecture discussion and design rationale
- `FIRST_IMPLEMENTATION.md` - Skeleton project structure and build instructions
- `TEST_STRUCTURE.md` - Test infrastructure design with Catch2 integration
- `NODES.md` - Comprehensive DWARF ↔ PDB ↔ IR mapping table
- `DWARF5_PDB_MATCH.md` - Detailed format correspondence for complex constructs
- `TODO_PLAN.md` - Implementation roadmap and task planning
- `CLAUDE.md` - This file (guidance for Claude Code)

**Test Documentation:**
- `st/SYSTEM_TEST.md` - System test design and validation strategy
- `it/pdb/PDB_IT.md` - PDB integration test specifications

**doc/ - User Guides:**
- `GETTING_STARTED.md` - Setup guide with library downloads
- `LIBRARY_SETUP.md` - LLVM/PDB/DWARF library configuration
- `LIBRARY_USAGE_EXAMPLES.md` - API usage patterns
- `COMPILER_SETUP.md` - Compiler environment configuration
- `TESTING_GUIDE.md` - Testing infrastructure and methodology

**script/ - Build Scripts:**
- `download_tool_libs.cmake` - Automated library/tool download
- Environment activation scripts (setup_*_env.bat)
- Library setup verification scripts (test_library_setup.*)

## Current Status

The project has a **complete test infrastructure** with stub implementations. All components compile and tests pass with placeholder logic. Next steps are to:

1. Integrate real DWARF parsing (libdwarf/LLVM DWARFContext)
2. Integrate real PDB parsing (LLVM DebugInfoPDB)
3. Implement actual type conversion logic in pipeline
4. Fill in binary serialization in writers
5. Tighten test assertions as functionality grows
