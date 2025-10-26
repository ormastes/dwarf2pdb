# Repository Guidelines

## Final Project Goal

**dwarf2pdb** produces an executable that converts DWARF-embedded executables into stripped executables with separate PDB debug files:

**Input:** DWARF-embedded executable (ELF/PE with embedded DWARF debug info)
**Output:** Stripped executable + separate PDB file

This enables Windows debugging tools to work with executables originally compiled with DWARF debug information.

## Development Methodology

**Test Driven Development (TDD)** is the core methodology:

1. **Write tests first** - Define expected behavior through tests before implementation
2. **Implement minimally** - Write just enough code to make tests pass
3. **Refactor** - Clean up code while maintaining test coverage
4. **Iterate** - Repeat for each feature, maintaining full test coverage

All new features must follow the TDD cycle: red (failing test) → green (passing test) → refactor.

## Project Structure & Modules
- Source: `src/` by domain — `ir/`, `dwarf/`, `pdb/`, `pipeline/`, `util/`.
- CLI: `dwarf_pdb_converter` built from `src/main.cpp` into `build/`.
- Tests: unit `ut/`, integration `it/`, system `st/` (binaries in `build/test/`).
- Docs: `README.md`, `TEST_STRUCTURE.md`, `NODES.md`, `DWARF5_PDB_MATCH.md`; user guides in `doc/`. Scripts in `script/`.

## Build, Test, and Run
- Configure: `cmake -S . -B build` (add `-DCMAKE_BUILD_TYPE=Debug` if single-config).
- Build: `cmake --build build -j` (MSVC: optionally `--config Debug`).
- Run tests: `ctest --test-dir build --output-on-failure`.
- Run suites directly: `build/test/ut_tests`, `build/test/it_dwarf_tests`, `build/test/it_pdb_tests`, `build/test/st_tests`.
- Run CLI: `build/dwarf_pdb_converter --help` (may be `build/Debug/...` on multi-config).
- Windows env: `script\setup_msvc_env.bat`; tool/libs download via `script/download_tool_libs.cmake`.

## Coding Style & Conventions
- C++17, 4-space indent, no tabs. Headers `.h`, sources `.cpp`.
- Naming: Classes `PascalCase` (e.g., `DwarfReader`), functions `camelCase`, constants/macros `UPPER_SNAKE_CASE`, namespaces lowercase.
- Respect module boundaries; avoid cyclic deps. Keep headers minimal and documented where non-obvious.

## Architecture Overview (from CLAUDE.md)
- Three-layer pipeline: DWARF ↔ IR ↔ PDB (`src/ir`, `src/dwarf`, `src/pdb`).
- IR owns canonical IDs; never reuse DWARF offsets or PDB type indices as identities. Use `IRTypeTable` + `IRMaps` for bijections.
- Utilities in `src/util/Compare.*` support deep round-trip checks.

## Testing Guidelines
- Tests mirror CLAUDE.md and `TEST_STRUCTURE.md` (ut/it/st). Name files `test_*.cpp` near their suite.
- Keep tests deterministic; write round-trip coverage for new features. Run with `ctest` or suite binaries.

## Commit & PR Guidelines
- One logical change per commit; imperative subject (≤72 chars). Example: `Add IR mapping for LF_UNION`.
- PRs: focused description, linked issues, and `ctest` output. Update docs/tests when behavior or interfaces change.
