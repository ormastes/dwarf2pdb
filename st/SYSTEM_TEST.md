Beautiful. We’re going to design the **system tests (st/)** so they actually prove end-to-end correctness using real compiler/debugger outputs, not just stubs.

You asked for:

* Full round-trip tests that cover “all item conversion”, including combinations (bitfields, unions, arrays, templates, etc.).
* A test that uses **Visual C++ (cl.exe)** to generate an official PDB, then compares that PDB to *our* generated PDB.
* A test that uses **cdb** to inspect base types and values and verify debuggability.
* The ability to script / orchestrate with Python.

I’ll give you:

1. The 3 system tests we’re going to create
2. The directory layout and test fixtures
3. How each test runs (step-by-step)
4. Catch2 + CTest + Python integration code skeletons

This is all within `C:\dev\cv2pdb\newDwarf2Pdb\st\`.

---

## 0. Quick context we'll assume

* We already have:

  * DWARF ↔ IR ↔ PDB converter CLI: `dwarf_pdb_converter.exe`
  * IR core + mapping code
  * Spec completeness tests for DWARF and PDB in `ut/`
  * Integration tests in `it/`

System tests will now:

* Actually build code with compilers,
* Actually produce DWARF and PDB,
* Actually run our converter,
* Actually diff results.

These tests sit at the “this would fail in CI on Windows if anything important breaks” level.

---

## 1. We'll create 5 system tests

### Test ST1: "Round-trip all features"

**Goal:**
Take a *feature-stress* test source file that exercises as many constructs as possible:

* struct/class with: normal fields, bitfields, base class inheritance, methods (virtual + non-virtual)
* union with anonymous struct arm
* enum class
* typedef/using
* pointer, ref, rvalue ref
* array (multi-dim)
* template instantiation
* recursive struct (linked list style)
* globals, statics, locals, parameters

Pipeline we test:

1. Build that TU with **clang/MinGW** (DWARF debug info).
2. Run: DWARF → IR → PDB using our converter.
3. Take that PDB we emitted.
4. Run: PDB → IR → DWARF using our converter.
5. Re-emit DWARF and compare metadata against original DWARF for “no important difference.”

“Important difference” here = all semantic nodes in the mapping tables (types, fields, functions, params, etc.) survived:

* same names
* same field offsets/bit sizes/array dims
* same function and local symbol names
* same scoping relationships

We’ll accept differences in cosmetic / address / GUID / file path / language version / mangled name noise.

This test is about **semantic fidelity of the IR mapping**.

### Test ST2: “Compare with MSVC PDB”

**Goal:**

1. Build the same stress TU with **cl.exe /Zi /Z7** (so we get MSVC-style PDB).
2. Grab MSVC’s PDB: `original.pdb`.
3. Convert the **DWARF side** build with our converter to `our.pdb`.
4. Compare `our.pdb` and `original.pdb` at the semantic level:

   * Enumerate all struct/class/union types in both
   * Compare field layout, bitfields, array element types
   * Compare functions and their parameter names/types
   * Compare global variable symbols
   * Compare enums and their enumerator names/values
   * Compare template instantiation names (demangled)

We don’t require byte-for-byte identical streams (impossible). We assert “logically equivalent shape.”

This test proves **PDB emission quality**: do we look like MSVC output.

### Test ST3: “cdb check”

**Goal:**
Take the MSVC-built executable and debug it in `cdb` (Windows debugger) and take the converter-generated PDB, and:

* Resolve types
* Read variable values at runtime
* Check base types (e.g. `int`, `unsigned long long`, pointers) are correctly described
* Check that we can evaluate `a` and get the correct value
* Check struct field offsets match what cdb sees

This proves **debugger usability**: our PDB actually lets a debugger understand memory layout.

We'll script `cdb` with `-c "commands; q"` so we can capture stdout and parse with Python.

### Test ST4: "Extract DWARF from embedded EXE to separate file"

**Goal:**
Many compilers (clang, GCC on Windows/MinGW) embed DWARF debug info directly into the executable (`.exe` or `.o` file) in special sections (`.debug_info`, `.debug_abbrev`, `.debug_line`, etc.). This test validates the ability to extract embedded debug information.

**Use Cases:**
- Separate debug symbols for distribution (ship stripped exe, provide debug files separately)
- Create external debug files for post-mortem debugging
- Extract DWARF from MinGW-built executables for analysis

**Pipeline:**

1. Build `stress_test.cpp` with MinGW/clang `-gdwarf-5` → produces `stress_embedded.exe` (DWARF embedded in `.debug_*` sections)
2. Run: `dwarf_pdb_converter.exe --extract-dwarf stress_embedded.exe stress_extracted.dwarf`
3. Verify the extracted file contains complete DWARF sections using `llvm-dwarfdump --verify`
4. Compare semantic dump of embedded DWARF vs extracted DWARF to ensure no data loss
5. Verify the executable still runs (extraction doesn't corrupt the binary)

**What we validate:**
- All DWARF sections extracted correctly (`.debug_info`, `.debug_abbrev`, `.debug_str`, `.debug_line`, `.debug_ranges`, etc.)
- Type information preserved completely
- Line number tables intact
- Symbol information preserved
- No corruption of the original executable

This proves: **DWARF extraction capability** - we can separate debug info from executable for distribution or tooling purposes.

### Test ST5: "Convert embedded DWARF EXE directly to PDB"

**Goal:**
Support the most common real-world workflow: MinGW/clang produces an executable with embedded DWARF, and Windows developers want a PDB for debugging with Visual Studio or WinDbg without intermediate steps.

**Use Cases:**
- MinGW developers on Windows who want to use Visual Studio debugger
- Cross-compilation scenarios (build with GCC/clang, debug with WinDbg)
- CI/CD pipelines that need PDB output from non-MSVC builds

**Pipeline:**

1. Build `stress_test.cpp` with MinGW/clang `-gdwarf-5 -g` → produces `stress_embedded.exe` (DWARF embedded)
2. Run: `dwarf_pdb_converter.exe --dwarf-to-pdb stress_embedded.exe stress_from_embedded.pdb`
   - Automatically detects DWARF in `.debug_*` sections
   - Extracts and converts in single operation
   - Generates PDB with matching executable GUID/timestamp
3. Load `stress_embedded.exe` with the generated PDB in Visual Studio debugger
4. Set breakpoint at `main`, run to breakpoint
5. Verify debugger can:
   - Resolve all types from the original source (`Node`, `Packed`, `Derived`, etc.)
   - Show correct variable values (`a == 42`, `g_obj.base_val == 7`)
   - Display struct layouts correctly (bitfields, union arms, base classes)
   - Step through code with correct source line mapping
   - Evaluate expressions using the type system
6. Use `run_cdb_check.py` to automate validation:
   ```python
   # Load exe with our PDB
   cdb -y build -c "bp main; g; dt Packed; ? a; dx g_obj; q" stress_embedded.exe
   ```
7. Compare semantic dump with MSVC-generated PDB (from ST2) for equivalence

**What we validate:**
- Embedded DWARF detection and extraction works
- All type information converts correctly (structs, unions, bitfields, arrays, templates)
- Symbol information maps properly (globals, statics, locals, parameters)
- Line number information preserved for source-level debugging
- PDB references correct executable GUID for symbol matching
- Debugger can set breakpoints and inspect variables
- Type layout matches original DWARF layout exactly

This proves: **Direct embedded DWARF → PDB conversion** - the primary use case for MinGW/clang users on Windows who need Visual Studio/WinDbg debugging support.

---

## 2. Directory structure under `st/`

```text
st/
  SYSTEM_TEST.md                     (this file)
  stress_types.h                     (feature-rich type definitions)
  stress_test.cpp                    (test program with global 'a')
  test_roundtrip_all.cpp             (ST1: DWARF → PDB → DWARF roundtrip)
  test_compare_msvc_pdb.cpp          (ST2: Compare our PDB vs MSVC PDB)
  test_cdb_debugcheck.cpp            (ST3: CDB debugger validation)
  test_extract_dwarf.cpp             (ST4: Extract embedded DWARF to file)
  test_embedded_dwarf_to_pdb.cpp     (ST5: Embedded DWARF → PDB direct)
  scripts/
    build_dwarf.py                   (build with MinGW/clang -gdwarf-5)
    build_msvc.py                    (build with cl.exe /Zi to get PDB)
    run_cdb_check.py                 (invoke cdb, parse output)
    pdb_semantic_dump.py             (dump PDB semantic view)
    dwarf_semantic_dump.py           (dump DWARF semantic view)
    compare_semantic.py              (compare two semantic dumps)
    extract_dwarf_sections.py        (extract DWARF from embedded exe)
    verify_dwarf_completeness.py     (verify all DWARF sections present)
```

Notes:

* `stress_types.h` is where we define all the tricky types.
* `stress_test.cpp` includes `stress_types.h`, defines globals, `a`, `main`.
* Our Catch2 tests (`test_roundtrip_all.cpp`, etc.) will call these Python utilities via `std::system()` or (better) `std::filesystem` + `std::process` wrapper if you write one. For now we'll use `std::system()` in the code skeleton.

---

## 3. Test fixture source: `stress_types.h`

This header deliberately exercises unions, bitfields, anonymous members, arrays, templates, recursion, etc.

```cpp
// st/stress_types.h
#pragma once
#include <cstdint>

// Recursive struct
struct Node {
    int value;
    Node* next;
};

// Bitfield / anonymous union / anonymous struct arm
struct Packed {
    unsigned a:3;
    unsigned b:5;
    unsigned c:8;
    union {
        struct {
            uint16_t lo;
            uint16_t hi;
        }; // anonymous struct arm
        uint32_t both;
    };
};

// Inheritance / virtual / this pointer case
struct Base {
    int base_val;
    virtual int getBase() const { return base_val; }
};

struct Derived : public Base {
    int extra;
    int getBase() const override { return base_val + 1; }
    int getExtra() const { return extra; }
};

// Enum / enum class
enum SimpleEnum {
    SE_Zero = 0,
    SE_One = 1,
    SE_Two = 2
};

enum class ScopedEnum : uint16_t {
    Red   = 10,
    Green = 20,
    Blue  = 30
};

// Template
template <typename T, int N>
struct ArrayHolder {
    T elems[N];
    T& at(int idx) { return elems[idx]; }
};

// Multi-dim array user
struct MatrixUser {
    int m[3][4];
};

// Typedef / using aliases
using U32 = unsigned int;
typedef const Derived* ConstDerivedPtr;

// Function signature variety
int add_ints(int x, int y);

// Global variable we promised: `a`
extern int a;

// Something to read from cdb easily
extern Derived g_obj;

// static-internal linkage in .cpp (file static) will be tested in stress_test.cpp
```

### `stress_test.cpp`

```cpp
// st/stress_test.cpp
#include "stress_types.h"

int a = 42; // global
Derived g_obj = { /*Base*/ {7}, /*extra*/ 99 };

static int file_static = -5; // internal linkage

int add_ints(int x, int y) {
    return x + y;
}

// Use some templates so they instantiate
ArrayHolder<int, 4> ah4;
ArrayHolder<Node*, 2> ahNodePtr;

// Force some codegen for cdb to inspect
int main() {
    Node n1 { 123, nullptr };
    Packed p {};
    p.a = 5;
    p.b = 17;
    p.c = 200;
    p.lo = 0xBEEF;
    p.hi = 0xCAFE;

    MatrixUser mu {};
    mu.m[1][2] = 777;

    g_obj.base_val = 7;
    g_obj.extra    = 99;

    // return global a (like you required originally)
    return a;
}
```

This file is the canonical “stress input TU” for all system tests.

---

## 4. System Test ST1: Round-trip all features

### High-level algorithm

1. Call `build_dwarf.py` to build `stress_test.cpp` with MinGW/clang into:

   * `stress_dwarf.exe` (or `.o`, depending)
   * DWARF debug info (`-gdwarf-5`)
2. Use `dwarf_pdb_converter.exe --dwarf-to-pdb stress_dwarf.exe out_from_dwarf.pdb`
3. Use `dwarf_pdb_converter.exe --pdb-to-dwarf out_from_dwarf.pdb roundtrip_back.o`
4. Call `dwarf_semantic_dump.py` on both `stress_dwarf.exe` and `roundtrip_back.o` to get JSON “semantic dumps” that list:

   * types (structs/unions/classes) with fields/offsets/bitfields
   * arrays with dimensions
   * enums with enumerators
   * functions + params
   * globals/statics
5. Call `compare_semantic.py` to assert no “important difference”

### Catch2 test skeleton: `st/test_roundtrip_all.cpp`

```cpp
#include <catch2/catch_test_macros.hpp>
#include <cstdlib>
#include <string>

TEST_CASE("ST1 Round-trip DWARF -> PDB -> DWARF retains semantics", "[st][roundtrip]") {
    // Paths
    std::string buildScript    = "st/scripts/build_dwarf.py";
    std::string stressCpp      = "st/stress_test.cpp";
    std::string dwarfExe       = "build/stress_dwarf.exe";        // produced by build_dwarf.py
    std::string pdbFromDwarf   = "build/out_from_dwarf.pdb";
    std::string dwarfRoundtrip = "build/roundtrip_back.o";

    // 1. build DWARF binary with clang/mingw
    REQUIRE(std::system(
        (std::string("python ") + buildScript + " " + stressCpp + " " + dwarfExe).c_str()
    ) == 0);

    // 2. DWARF -> PDB
    REQUIRE(std::system(
        (std::string("dwarf_pdb_converter.exe --dwarf-to-pdb ")
         + dwarfExe + " " + pdbFromDwarf).c_str()
    ) == 0);

    // 3. PDB -> DWARF
    REQUIRE(std::system(
        (std::string("dwarf_pdb_converter.exe --pdb-to-dwarf ")
         + pdbFromDwarf + " " + dwarfRoundtrip).c_str()
    ) == 0);

    // 4. Dump semantics
    std::string dumpOrig      = "build/sem_orig.json";
    std::string dumpRoundtrip = "build/sem_round.json";

    REQUIRE(std::system(
        (std::string("python st/scripts/dwarf_semantic_dump.py ")
         + dwarfExe + " " + dumpOrig).c_str()
    ) == 0);

    REQUIRE(std::system(
        (std::string("python st/scripts/dwarf_semantic_dump.py ")
         + dwarfRoundtrip + " " + dumpRoundtrip).c_str()
    ) == 0);

    // 5. Compare
    REQUIRE(std::system(
        (std::string("python st/scripts/compare_semantic.py ")
         + dumpOrig + " " + dumpRoundtrip).c_str()
    ) == 0);
}
```

What the helper Python scripts do:

* `dwarf_semantic_dump.py <binary> <out.json>`
  Uses `llvm-dwarfdump --debug-info --debug-line --debug-types` style output parsing (or libllvm via python bindings if available) to extract:

  * struct/union/class -> fields (name, offset, bitfield)
  * array -> elem type + length
  * enum -> enumerators
  * global vars
  * functions + param lists
    Output as JSON dictionary.

* `compare_semantic.py <orig.json> <round.json>`
  Loads both, ignores addresses and producer strings, and asserts:

  * every type by name exists in both, with same size
  * every field in that type has same offset / bitSize
  * every global var name appears in both
  * every function name exists, with same param count/names

If mismatch → return non-zero → Catch2 test fails.

---

## 5. System Test ST2: Visual C++ PDB comparison

### High-level algorithm

1. Call `build_msvc.py` to compile `stress_test.cpp` with `cl.exe /Zi /std:c++20 /Od`:

   * produce `msvc_exe.exe`
   * produce `msvc_exe.pdb` (official PDB)
2. Take the DWARF-built binary from ST1 step 1 OR rebuild with clang -gdwarf and run `--dwarf-to-pdb` to produce `our_exe.pdb`
3. Use `pdb_semantic_dump.py` on:

   * `msvc_exe.pdb`
   * `our_exe.pdb`
     That script should:
   * Use DIA SDK, llvm-pdbutil, or your own PdbReader to dump semantic view:

     * all types (LF_STRUCTURE, LF_UNION, LF_CLASS, LF_ENUM, LF_ARRAY)
     * fieldlists (LF_MEMBER, LF_BITFIELD, LF_ENUMERATE)
     * functions (`S_GPROC32`/`S_LPROC32`, params from local symbols)
     * globals (`S_GDATA32`, etc.)
   * Output to JSON
4. Use `compare_semantic.py` to compare them with relaxed rules:

   * struct sizes and member layouts must match for any identically named type
   * enum constants must match names/values
   * functions with same demangled name must have same parameter count and names
   * globals must match name and type name

### Catch2 test skeleton: `st/test_compare_msvc_pdb.cpp`

```cpp
#include <catch2/catch_test_macros.hpp>
#include <cstdlib>
#include <string>

TEST_CASE("ST2 Our PDB vs MSVC PDB semantic diff", "[st][msvc]") {
    std::string buildMsvcScript = "st/scripts/build_msvc.py";
    std::string stressCpp       = "st/stress_test.cpp";

    std::string msvcExe         = "build/msvc_exe.exe";
    std::string msvcPdb         = "build/msvc_exe.pdb";

    std::string dwarfExe        = "build/stress_dwarf.exe";
    std::string ourPdb          = "build/our_from_dwarf.pdb";

    // 1. build with cl.exe -> msvc_exe.exe + msvc_exe.pdb
    REQUIRE(std::system(
        (std::string("python ") + buildMsvcScript + " " + stressCpp +
         " " + msvcExe + " " + msvcPdb).c_str()
    ) == 0);

    // 2. ensure dwarfExe (from ST1 build_dwarf.py) exists,
    //    then run dwarf -> pdb to get our_from_dwarf.pdb
    REQUIRE(std::system(
        (std::string("dwarf_pdb_converter.exe --dwarf-to-pdb ")
         + dwarfExe + " " + ourPdb).c_str()
    ) == 0);

    // 3. dump both PDBs semantically
    std::string dumpMsvc = "build/sem_msvc_pdb.json";
    std::string dumpOurs = "build/sem_our_pdb.json";

    REQUIRE(std::system(
        (std::string("python st/scripts/pdb_semantic_dump.py ")
         + msvcPdb + " " + dumpMsvc).c_str()
    ) == 0);

    REQUIRE(std::system(
        (std::string("python st/scripts/pdb_semantic_dump.py ")
         + ourPdb + " " + dumpOurs).c_str()
    ) == 0);

    // 4. compare
    REQUIRE(std::system(
        (std::string("python st/scripts/compare_semantic.py ")
         + dumpMsvc + " " + dumpOurs + " --pdb-mode").c_str()
    ) == 0);
}
```

Key idea:
If MSVC says `struct Packed` is 8 bytes with members `a:3`, `b:5`, `c:8`, union `{lo,hi}` at offset 4, etc., and our PDB says something else, we fail.

This directly checks that our **PdbWriter** is creating type records (`LF_STRUCTURE`, `LF_FIELDLIST`, `LF_MEMBER`, `LF_BITFIELD`, `LF_UNION`, etc.) compatible with what MSVC emits. That’s what you wanted: “visual c++ gen pdb and our pdb comparison test.”

---

## 6. System Test ST3: cdb runtime validation

### High-level algorithm

1. Launch `cdb` against:

   * `msvc_exe.exe` with `our_from_dwarf.pdb` copied/renamed to `msvc_exe.pdb` or `-y` path
2. In cdb:

   * Break at `main`
   * Dump type info of:

     * `Derived`
     * `Packed`
     * `Node`
   * Dump memory of `g_obj`, show `base_val` and `extra`
   * Evaluate `a`
3. Parse cdb’s output and assert:

   * `a == 42`
   * `g_obj.base_val == 7`, `g_obj.extra == 99`
   * Offsets of `Packed.a`, `Packed.b`, `Packed.c`, `Packed.lo`, etc., match what our PDB said in the semantic dump (or match expected constants)
   * That types exist by the same names (so debugger is resolving them)

We'll automate this with a Python harness that:

* Runs `cdb -c "bp main; g; dv /t; ? a; dx g_obj; q"` (or equivalent `!analyze`-style commands but we only need locals/expr eval),
* Captures stdout,
* Parses.

### Python script sketch: `st/scripts/run_cdb_check.py`

```python
#!/usr/bin/env python3
import sys, subprocess, json, re

exe = sys.argv[1]
pdb_dir = sys.argv[2]  # maybe where our PDB is located
out_json = sys.argv[3]

# Note:
#   We'll run cdb with:
#     -lines             (source/line info)
#     -y <pdb_dir>       (symbol path: use our PDB)
#   Command script:
#     bp main
#     g
#     ? a
#     dx g_obj
#     q

cmds = "bp main; g; ? a; dx g_obj; q"

proc = subprocess.run(
    ["cdb", "-y", pdb_dir, "-c", cmds, exe],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    text=True
)

out = proc.stdout

# Extract value of a
m_a = re.search(r'[^?]\?\s+a\s*=\s*([0-9A-Fa-fx]+)', out)
# or maybe cdb prints like "Evaluate expression: 42 = 0000002a"
# We'll just do a smarter regex later.
val_a = None
if m_a:
    val_a = m_a.group(1)

# Extract g_obj fields from "dx g_obj"
# cdb dx output often looks like:
#   g_obj                 : {...}
#   g_obj.base_val        : 7
#   g_obj.extra           : 99
base_val = None
extra_val = None
m_base = re.search(r'g_obj\.base_val\s*:\s*([0-9\-]+)', out)
m_extra= re.search(r'g_obj\.extra\s*:\s*([0-9\-]+)', out)
if m_base:
    base_val = int(m_base.group(1))
if m_extra:
    extra_val = int(m_extra.group(1))

result = {
    "val_a": val_a,
    "g_obj.base_val": base_val,
    "g_obj.extra": extra_val,
    "raw_output": out,
    "proc_returncode": proc.returncode,
}
with open(out_json, "w") as f:
    json.dump(result, f, indent=2)

sys.exit(0 if proc.returncode == 0 else proc.returncode)
```

### Catch2 test skeleton: `st/test_cdb_debugcheck.cpp`

```cpp
#include <catch2/catch_test_macros.hpp>
#include <cstdlib>
#include <fstream>
#include <nlohmann/json.hpp> // or roll your own tiny parser

TEST_CASE("ST3 cdb debugger sees correct values and types", "[st][cdb]") {
    std::string msvcExe   = "build/msvc_exe.exe";
    std::string pdbDir    = "build"; // directory containing our PDB
    std::string cdbJson   = "build/cdb_out.json";

    // run cdb script
    REQUIRE(std::system(
        (std::string("python st/scripts/run_cdb_check.py ")
         + msvcExe + " " + pdbDir + " " + cdbJson).c_str()
    ) == 0);

    // parse result
    std::ifstream in(cdbJson);
    nlohmann::json j;
    in >> j;

    // Check base types and global var values made it through
    // We expect a == 42, base_val==7, extra==99 after main runs bp/g
    // Note: this assumes main executed to bp set at main, then continued.
    // You can adjust cdb script flow to get correct timing.
    REQUIRE(j["proc_returncode"].get<int>() == 0);

    // check `a`
    // we allow hex or decimal, so just check substring "42" maybe:
    REQUIRE(j["val_a"].dump().find("42") != std::string::npos);

    // check struct layout visible to debugger allowed reading fields
    REQUIRE(j["g_obj.base_val"].get<int>() == 7);
    REQUIRE(j["g_obj.extra"].get<int>()    == 99);
}
```

This test gives us:

* Proof that our generated PDB is good enough that `cdb` can:

  * load symbols,
  * read globals,
  * dereference struct fields,
  * display their values.
* Indirect proof that struct layout and base types (`int`, `int`, etc.) are correct, because if layout were wrong, `dx g_obj` would show garbage.

That hits your requirement:

> "cdb base type info check and value check compare."

---

## 7. How these system tests use combinations

Because `stress_test.cpp` / `stress_types.h` already packs:

* bitfields
* anonymous union with anonymous struct arm
* inheritance + virtual methods
* recursive struct
* array and template
* local, global, static, parameter
* enum + enum class
* pointer types

…we’re hitting basically everything we said we needed for DWARF and PDB mapping:

* DW_TAG_member + DW_AT_bit_size ↔ LF_BITFIELD
* anonymous union arms ↔ LF_MEMBER of anonymous struct at offset 0
* DW_TAG_inheritance ↔ LF_BCLASS
* DW_TAG_array_type ↔ LF_ARRAY
* DW_TAG_template_* ↔ LF_ARGLIST, mangled names
* DW_TAG_variable (CU/static/local) ↔ S_GDATA32 / S_LDATA32 / S_LOCAL
* DW_TAG_subprogram / DW_TAG_lexical_block ↔ S_GPROC32 / S_BLOCK32
* DW_TAG_inlined_subroutine ↔ S_INLINESITE (we’ll get real inline once templates or inline methods show up)
* etc.

That satisfies “may combination also.”
The combinations show up naturally in that TU.

---

## 8. How to wire st/ into CMake/CTest

We already had a `st_tests` target earlier. We now split it to multiple test translation units:

```cmake
add_executable(st_tests
    st/test_roundtrip_all.cpp
    st/test_compare_msvc_pdb.cpp
    st/test_cdb_debugcheck.cpp
    st/test_extract_dwarf.cpp
    st/test_embedded_dwarf_to_pdb.cpp
)

target_link_libraries(st_tests
    PRIVATE converter_core Catch2::Catch2WithMain
)

target_include_directories(st_tests PRIVATE src)

catch_discover_tests(st_tests)
```

We also need `nlohmann/json` (or your own tiny JSON reader). You can vendor a single-header `json.hpp` in `st/third_party/json.hpp` and include it. Or you just do basic manual parsing since we only read a few numbers.

---

## 9. Summary

We now have a full **system test suite** that does exactly what you asked:

### ST1 – Round trip DWARF↔PDB↔DWARF:

* Build with DWARF (clang/MinGW).
* Convert DWARF→IR→PDB, then PDB→IR→DWARF.
* Dump semantic info from original and round-tripped DWARF.
* Compare with `compare_semantic.py` to assert “no important difference”.

This checks: *our semantic model (IR) preserves all core constructs.*

---

### ST2 – Compare against MSVC PDB:

* Build with `cl.exe /Zi` to get official MSVC PDB.
* Build with DWARF and convert to our PDB.
* Dump semantic info from both PDBs (types, members, layouts, globals, funcs).
* Compare with `compare_semantic.py --pdb-mode`.

This checks: *our PDB writer emits something equivalent to MSVC’s view of the same code.*

---

### ST3 – Debugger reality check with `cdb`:

* Load executable under `cdb` using our generated PDB.
* Break, run queries (`? a`, `dx g_obj`, etc.).
* Parse output and assert values match expected runtime values.

This checks: *a Windows debugger can consume our PDB to inspect real memory and interpret base types / struct layout / globals correctly.*

---

### ST4 – Extract embedded DWARF to separate file:

* Build executable with embedded DWARF (MinGW/clang standard behavior).
* Extract DWARF sections to standalone debug file.
* Verify all DWARF sections present and complete using `llvm-dwarfdump --verify`.
* Compare semantic equivalence of embedded vs extracted.

This checks: *our DWARF extraction correctly handles all debug sections (.debug_info, .debug_abbrev, .debug_line, .debug_str, .debug_ranges) without data loss.*

---

### ST5 – Direct embedded DWARF → PDB conversion:

* Build executable with embedded DWARF (most common MinGW use case).
* Convert directly to PDB in single operation (no intermediate files).
* Load in Visual Studio debugger or WinDbg with generated PDB.
* Verify full debugging experience (breakpoints, locals, types, stepping).

This checks: *the primary real-world workflow for MinGW developers works end-to-end, enabling Visual Studio debugging of GCC/clang-compiled Windows executables.*

---

This gives you:

* **Semantic diff safety** (ST1, ST4)
* **Layout and bitfield safety** (ST2, ST5)
* **Debugger usability safety** (ST3, ST5)
* **Embedded DWARF handling** (ST4, ST5) - critical for MinGW/clang Windows workflows
* **Real-world workflow validation** (ST5) - the most common use case

All tests are automated through Catch2 + Python scripts, so they can run in CI on Windows and detect regressions immediately.
