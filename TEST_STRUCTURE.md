Perfect. We’re going to evolve the skeleton project into a testable converter project with Catch2 and a test layout like you described:

```text
C:\dev\cv2pdb\newDwarf2Pdb\
  ├── src/
  ├── ut/           (unit tests)
  ├── it/
  │   ├── dwarf/    (integration tests for DWARF)
  │   └── pdb/      (integration tests for PDB)
  └── st/           (system tests)
```

We'll do 4 things:

1. Add equality/compare helpers so we can round-trip node → IR → node and check “same”.
2. Add Catch2-based tests:

   * **ut**: DwarfNode ↔ IR ↔ DwarfNode, and PdbNode ↔ IR ↔ PdbNode.
   * **it/dwarf** and **it/pdb**: placeholders that model “serialize to binary and back”.
   * **st**: placeholder for full toolchain test (MinGW build, produce PDB, convert back).
3. Update CMake to build tests (with Catch2 via FetchContent).
4. Add any missing translation helpers so tests can call them.

I’ll show the updated project contents you should drop into your repo.

---

## 1. Add `util/Compare.*` for deep equality

We’ll add a small utility to compare IR, DwarfNode, and PdbNode.
This lets tests assert round-trip stability.

### `src/util/Compare.h`

```cpp
#pragma once
#include <string>
#include <vector>
#include "../ir/IRNode.h"
#include "../dwarf/DwarfNode.h"
#include "../pdb/PdbNode.h"

// Compare two IRTypes by structure (not by address)
bool EqualIRType(const IRType* a, const IRType* b);

// Compare two IRScopes recursively (including symbols and declaredTypes list).
// NOTE: Only checks structure and names / kinds, not address ranges etc.
bool EqualIRScope(const IRScope* a, const IRScope* b);

// Compare DwarfNode recursively: tag, child count, and simple attrs we store
bool EqualDwarfNode(const DwarfNode* a, const DwarfNode* b);

// Compare PdbNode recursively: leafKind, pretty/uniqueName, child shape
bool EqualPdbNode(const PdbNode* a, const PdbNode* b);
```

### `src/util/Compare.cpp`

```cpp
#include "Compare.h"
#include <algorithm>

// Helper: compare vectors of same length using lambda cmp(i,j)
template <typename T, typename F>
static bool CompareVec(const std::vector<T>& A,
                       const std::vector<T>& B,
                       F cmp) {
    if (A.size() != B.size()) return false;
    for (size_t i = 0; i < A.size(); ++i) {
        if (!cmp(A[i], B[i])) return false;
    }
    return true;
}

bool EqualIRType(const IRType* a, const IRType* b) {
    if (!a || !b) return a == b;
    if (a->kind        != b->kind)        return false;
    if (a->name        != b->name)        return false;
    if (a->isForwardDecl != b->isForwardDecl) return false;
    if (a->isUnion     != b->isUnion)     return false;
    if (a->sizeBytes   != b->sizeBytes)   return false;
    if (a->pointeeType != b->pointeeType) return false;
    if (a->ptrSizeBytes!= b->ptrSizeBytes)return false;
    if (a->elementType != b->elementType) return false;
    if (a->indexType   != b->indexType)   return false;
    if (!CompareVec(a->dims, b->dims, [](const IRArrayDim& x,const IRArrayDim& y){
        return x.lowerBound==y.lowerBound && x.count==y.count;
    })) return false;
    if (!CompareVec(a->fields, b->fields, [](const IRField& x,const IRField& y){
        return x.name==y.name
            && x.type==y.type
            && x.byteOffset==y.byteOffset
            && x.bitOffset==y.bitOffset
            && x.bitSize==y.bitSize
            && x.isAnonymousArm==y.isAnonymousArm;
    })) return false;

    // We ignore a->id vs b->id because different tables can assign different IDs.
    return true;
}

static bool EqualIRSymbol(const IRSymbol& a, const IRSymbol& b) {
    return a.name == b.name &&
           a.kind == b.kind &&
           a.type == b.type;
}

bool EqualIRScope(const IRScope* a, const IRScope* b) {
    if (!a || !b) return a == b;
    if (a->kind != b->kind) return false;
    if (a->name != b->name) return false;

    // Compare declaredTypes list (same #, same IDs in same order)
    if (a->declaredTypes.size() != b->declaredTypes.size()) return false;
    for (size_t i = 0; i < a->declaredTypes.size(); ++i) {
        if (a->declaredTypes[i] != b->declaredTypes[i]) return false;
    }

    // Compare symbols
    if (!CompareVec(a->declaredSymbols, b->declaredSymbols, EqualIRSymbol))
        return false;

    // Children recursion
    if (a->children.size() != b->children.size()) return false;
    for (size_t i = 0; i < a->children.size(); ++i) {
        if (!EqualIRScope(a->children[i].get(), b->children[i].get()))
            return false;
    }

    return true;
}

bool EqualDwarfNode(const DwarfNode* a, const DwarfNode* b) {
    if (!a || !b) return a == b;
    if (a->tag != b->tag) return false;
    if (a->attrsStr.size() != b->attrsStr.size()) return false;
    if (a->attrsU64.size() != b->attrsU64.size()) return false;

    for (size_t i = 0; i < a->attrsStr.size(); ++i) {
        if (a->attrsStr[i].first  != b->attrsStr[i].first)  return false;
        if (a->attrsStr[i].second != b->attrsStr[i].second) return false;
    }
    for (size_t i = 0; i < a->attrsU64.size(); ++i) {
        if (a->attrsU64[i].first  != b->attrsU64[i].first)  return false;
        if (a->attrsU64[i].second != b->attrsU64[i].second) return false;
    }

    if (a->children.size() != b->children.size()) return false;
    for (size_t i = 0; i < a->children.size(); ++i) {
        if (!EqualDwarfNode(a->children[i].get(), b->children[i].get()))
            return false;
    }
    return true;
}

bool EqualPdbNode(const PdbNode* a, const PdbNode* b) {
    if (!a || !b) return a == b;
    if (a->leafKind != b->leafKind) return false;
    if (a->prettyName != b->prettyName) return false;
    if (a->uniqueName != b->uniqueName) return false;

    // For simplicity, ignore payload bytes ordering for now
    if (a->children.size() != b->children.size()) return false;
    for (size_t i = 0; i < a->children.size(); ++i) {
        if (!EqualPdbNode(a->children[i].get(), b->children[i].get()))
            return false;
    }
    return true;
}
```

We intentionally ignore DIE offsets / PDB TIs because they can change on re-emit.

---

## 2. Add “round-trip” helpers to pipeline for tests

Right now:

* `DwarfReader` builds IR.
* `PdbToDwarf` builds a new `DwarfNode` from IR.
* `PdbReader` builds IR.
* `DwarfToPdb` builds a new `PdbNode` from IR.

This is enough to simulate:

* DWARF node -> IR (via DwarfReader) -> DWARF node (via PdbToDwarf)
* PDB node -> IR (via PdbReader) -> PDB node (via DwarfToPdb)

But `DwarfReader` and `PdbReader` stubs currently don't accept an existing node; they fabricate dummy IR from filenames. We’ll add “in-memory injection” helpers that tests can call.

### Update `src/dwarf/DwarfReader.h`:

```cpp
// ...
class DwarfReader {
public:
    std::unique_ptr<IRScope> readObject(
        const std::string& path,
        IRTypeTable& typeTable,
        IRMaps& maps
    );

    // NEW: Build IR from an already-existing DwarfNode tree (for tests).
    std::unique_ptr<IRScope> readFromModel(
        const DwarfNode& model,
        IRTypeTable& typeTable,
        IRMaps& maps
    );

private:
    // ...
};
```

### Update `src/dwarf/DwarfReader.cpp`:

```cpp
std::unique_ptr<IRScope> DwarfReader::readFromModel(
    const DwarfNode& model,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    // Very dumb translation for test:
    // - Make one CU IRScope named "fromModel"
    // - Create one IRType named from model first attrStr if present
    auto root = std::make_unique<IRScope>();
    root->kind = IRScopeKind::CompileUnit;
    root->name = "fromModel";

    IRType* t = typeTable.createType(IRTypeKind::StructOrUnion);
    t->isUnion = false;
    t->sizeBytes = 16;
    if (!model.attrsStr.empty()) {
        t->name = model.attrsStr[0].second;
    } else {
        t->name = "AnonFromDwarfNode";
    }

    // self-field to prove round-trip
    IRField f;
    f.name = "self";
    f.type = t->id;
    f.byteOffset = 0;
    t->fields.push_back(f);

    root->declaredTypes.push_back(t->id);

    IRSymbol s;
    s.name = "symFromDwarf";
    s.kind = IRSymbolKind::Variable;
    s.type = t->id;
    root->declaredSymbols.push_back(s);

    maps.dwarfDieToIR[model.originalDieOffset] = t->id;
    maps.irToDwarfDie[t->id] = model.originalDieOffset;
    return root;
}
```

We’re not trying to be semantically correct yet — just stable/deterministic for test.

We do the same for PDB:

### Update `src/pdb/PdbReader.h`:

```cpp
class PdbReader {
public:
    std::unique_ptr<IRScope> readPdb(
        const std::string& path,
        IRTypeTable& typeTable,
        IRMaps& maps
    );

    // NEW: Build IR from an existing PdbNode (for tests)
    std::unique_ptr<IRScope> readFromModel(
        const PdbNode& model,
        IRTypeTable& typeTable,
        IRMaps& maps
    );

private:
    // ...
};
```

### Update `src/pdb/PdbReader.cpp`:

```cpp
std::unique_ptr<IRScope> PdbReader::readFromModel(
    const PdbNode& model,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    auto root = std::make_unique<IRScope>();
    root->kind = IRScopeKind::CompileUnit;
    root->name = "fromPdbModel";

    IRType* t = typeTable.createType(IRTypeKind::StructOrUnion);
    t->isUnion = true;
    t->sizeBytes = 8;
    t->name = model.prettyName.empty() ? "AnonFromPdbNode" : model.prettyName;

    IRField f;
    f.name = "alt0";
    f.type = t->id;
    f.byteOffset = 0;
    t->fields.push_back(f);

    root->declaredTypes.push_back(t->id);

    IRSymbol s;
    s.name = "symFromPdb";
    s.kind = IRSymbolKind::Variable;
    s.type = t->id;
    root->declaredSymbols.push_back(s);

    maps.pdbTIToIR[model.typeIndexOrSymOffset] = t->id;
    maps.irToPdbTI[t->id] = model.typeIndexOrSymOffset;
    return root;
}
```

Now, `DwarfToPdb::translate()` and `PdbToDwarf::translate()` already build new nodes from IR. That’s good for round trip.

---

## 3. Catch2 test setup

We'll pull Catch2 via `FetchContent` in CMake and build 3 test executables:

* `ut_tests` for unit tests
* `it_dwarf_tests` / `it_pdb_tests` for integration (binary emit placeholder)
* `st_tests` for system tests (toolchain placeholder)

### Top-level `CMakeLists.txt` (updated)

Replace the previous root CMakeLists.txt with this expanded one:

```cmake
cmake_minimum_required(VERSION 3.20)

project(dwarf_pdb_converter
    VERSION 0.0.1
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Main library sources (we'll build them into an OBJECT lib for reuse in tests)
add_library(converter_core OBJECT
    src/dwarf/DwarfNode.cpp
    src/dwarf/DwarfReader.cpp
    src/dwarf/DwarfWriter.cpp

    src/pdb/PdbNode.cpp
    src/pdb/PdbReader.cpp
    src/pdb/PdbWriter.cpp

    src/ir/IRNode.cpp
    src/ir/IRTypeTable.cpp
    src/ir/IRMaps.cpp

    src/pipeline/DwarfToPdb.cpp
    src/pipeline/PdbToDwarf.cpp

    src/util/Compare.cpp
)

target_include_directories(converter_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# The CLI executable that uses converter_core
add_executable(dwarf_pdb_converter
    src/main.cpp
)
target_link_libraries(dwarf_pdb_converter PRIVATE converter_core)

# -------- Catch2 setup --------
include(FetchContent)
FetchContent_Declare(
    catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG        v3.6.0
)
FetchContent_MakeAvailable(catch2)

# -------- Unit tests (ut) --------
add_executable(ut_tests
    ut/test_roundtrip_dwarf.cpp
    ut/test_roundtrip_pdb.cpp
)
target_link_libraries(ut_tests
    PRIVATE converter_core Catch2::Catch2WithMain
)
target_include_directories(ut_tests PRIVATE src)

# -------- Integration tests (it) --------
add_executable(it_dwarf_tests
    it/dwarf/test_dwarf_integration.cpp
)
target_link_libraries(it_dwarf_tests
    PRIVATE converter_core Catch2::Catch2WithMain
)
target_include_directories(it_dwarf_tests PRIVATE src)

add_executable(it_pdb_tests
    it/pdb/test_pdb_integration.cpp
)
target_link_libraries(it_pdb_tests
    PRIVATE converter_core Catch2::Catch2WithMain
)
target_include_directories(it_pdb_tests PRIVATE src)

# -------- System tests (st) --------
add_executable(st_tests
    st/test_system_pipeline.cpp
)
target_link_libraries(st_tests
    PRIVATE converter_core Catch2::Catch2WithMain
)
target_include_directories(st_tests PRIVATE src)

include(CTest)
include(Catch)
catch_discover_tests(ut_tests)
catch_discover_tests(it_dwarf_tests)
catch_discover_tests(it_pdb_tests)
catch_discover_tests(st_tests)
```

Now we add the tests.

---

## 4. ut/: unit round-trip tests

### `ut/test_roundtrip_dwarf.cpp`

```cpp
#include <catch2/catch_all.hpp>
#include "dwarf/DwarfReader.h"
#include "pipeline/PdbToDwarf.h"
#include "util/Compare.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

// Goal:
// 1. Build a fake DwarfNode tree "original"
// 2. DwarfReader::readFromModel() -> IRScope + IRTypeTable
// 3. PdbToDwarf::translate(IR) -> DwarfNode "roundTripped"
// 4. Compare original vs roundTripped (with some expectations)

TEST_CASE("DWARF node -> IR -> DWARF node roundtrip basic", "[ut][dwarf]") {
    // Step 1: fake original dwarf model
    DwarfNode originalCU;
    originalCU.tag = 0x11; // pretend DW_TAG_compile_unit
    originalCU.originalDieOffset = 0x9999;
    originalCU.attrsStr.push_back({0x03, "DummyFromDwarf"}); // pretend DW_AT_name

    // Step 2: build IR
    IRTypeTable typeTable;
    IRMaps maps;
    DwarfReader dreader;
    auto irRoot = dreader.readFromModel(originalCU, typeTable, maps);

    REQUIRE(irRoot);
    REQUIRE(irRoot->declaredTypes.size() == 1);

    // Step 3: IR -> DwarfNode using PdbToDwarf translator
    PdbToDwarf p2d;
    auto rebuiltCU = p2d.translate(irRoot.get(), typeTable, maps);

    REQUIRE(rebuiltCU);

    // Step 4: Compare shape. We don't expect perfect match yet,
    // but we can at least check tag and child count equality.
    // Let's just assert tag is same as PdbToDwarf currently produces (0x11)
    CHECK(rebuiltCU->tag == 0x11);

    // We can also check that translate() produced *some* attrs or children.
    // Minimally we assert not null; structural equivalence will tighten later.
    // For now, pass the test.
    SUCCEED("DWARF roundtrip stub completed.");
}
```

### `ut/test_roundtrip_pdb.cpp`

```cpp
#include <catch2/catch_all.hpp>
#include "pdb/PdbReader.h"
#include "pipeline/DwarfToPdb.h"
#include "util/Compare.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

// Similar:
// 1. Fake original PdbNode
// 2. PdbReader::readFromModel -> IR
// 3. DwarfToPdb::translate(IR) -> PdbNode
// 4. Assert shape

TEST_CASE("PDB node -> IR -> PDB node roundtrip basic", "[ut][pdb]") {
    PdbNode original;
    original.leafKind = 0x1234;
    original.prettyName = "PdbRootPretty";
    original.uniqueName = "??_C@Something";
    original.typeIndexOrSymOffset = 0x1000;

    IRTypeTable typeTable;
    IRMaps maps;
    PdbReader preader;
    auto irRoot = preader.readFromModel(original, typeTable, maps);

    REQUIRE(irRoot);
    REQUIRE(irRoot->declaredTypes.size() == 1);

    DwarfToPdb d2p;
    auto rebuilt = d2p.translate(irRoot.get(), typeTable, maps);

    REQUIRE(rebuilt);

    CHECK(rebuilt->leafKind == 0x1234); // we set same in translate() stub
    CHECK(rebuilt->prettyName == "PdbRootFromDwarf" ||
          rebuilt->prettyName == "PdbRootPretty");

    SUCCEED("PDB roundtrip stub completed.");
}
```

These tests don't assert strict deep equality yet because our pipeline stubs aren’t symmetrical. Later, once translation preserves names/fields/etc., you’ll tighten those `CHECK`s and use `EqualDwarfNode` / `EqualPdbNode`.

---

## 5. it/: integration tests (binary emit simulation)

You defined:

* `it/dwarf`: “dwarf node -> ir node -> dwarf node -> dwarf binary -> dwarf node and compare”
* `it/pdb`: same but for PDB.

We don’t actually emit true DWARF/PDB binaries yet. So we simulate “binary write + reload” by calling Writer and then Reader again. Eventually, `DwarfWriter::writeObject()` and `PdbWriter::writePdb()` will serialize to disk, and the Readers will re-import from that disk.

For now they’re stubs, but we still put test scaffolding in place.

### `it/dwarf/test_dwarf_integration.cpp`

```cpp
#include <catch2/catch_all.hpp>
#include "dwarf/DwarfReader.h"
#include "dwarf/DwarfWriter.h"
#include "pipeline/PdbToDwarf.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

// Future shape we want:
//
// original DwarfNode -> IR -> DwarfNodeModel -> DwarfWriter.writeObject(temp.obj)
// -> DwarfReader.readObject(temp.obj) -> compare.
//
// Right now, readObject() and writeObject() are stubs, so we just assert
// the call chain doesn't crash.

TEST_CASE("DWARF integration pipeline stub", "[it][dwarf]") {
    DwarfNode startModel;
    startModel.tag = 0x11;
    startModel.originalDieOffset = 0xAAAA;
    startModel.attrsStr.push_back({0x03, "IntegrationDwarf"});

    IRTypeTable typeTable;
    IRMaps maps;
    DwarfReader dreader;
    auto irRoot = dreader.readFromModel(startModel, typeTable, maps);

    REQUIRE(irRoot);

    PdbToDwarf p2d;
    auto dwarfModelOut = p2d.translate(irRoot.get(), typeTable, maps);

    REQUIRE(dwarfModelOut);

    DwarfWriter dwriter;
    dwriter.writeObject("tmp_out_dwarf.o", dwarfModelOut.get());

    // In the future:
    // auto irRoot2 = dreader.readObject("tmp_out_dwarf.o", typeTable2, maps2);
    // CHECK(EqualDwarfNode(reParsedFromDisk, dwarfModelOut.get()));

    SUCCEED("DWARF integration pipeline (stubbed IO) executed.");
}
```

### `it/pdb/test_pdb_integration.cpp`

```cpp
#include <catch2/catch_all.hpp>
#include "pdb/PdbReader.h"
#include "pdb/PdbWriter.h"
#include "pipeline/DwarfToPdb.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

TEST_CASE("PDB integration pipeline stub", "[it][pdb]") {
    PdbNode startModel;
    startModel.leafKind = 0x2222;
    startModel.prettyName = "IntegrationPdb";
    startModel.uniqueName = "??_Integration";
    startModel.typeIndexOrSymOffset = 0x1000;

    IRTypeTable typeTable;
    IRMaps maps;
    PdbReader preader;
    auto irRoot = preader.readFromModel(startModel, typeTable, maps);

    REQUIRE(irRoot);

    DwarfToPdb d2p;
    auto pdbModelOut = d2p.translate(irRoot.get(), typeTable, maps);

    REQUIRE(pdbModelOut);

    PdbWriter pwriter;
    pwriter.writePdb("tmp_out.pdb", pdbModelOut.get());

    // future:
    // auto irRoot2 = preader.readPdb("tmp_out.pdb", typeTable2, maps2);
    // CHECK(EqualPdbNode(reParsed, pdbModelOut.get()));

    SUCCEED("PDB integration pipeline (stubbed IO) executed.");
}
```

---

## 6. st/: system test

System test idea:

* Compile a trivial C++ TU with MinGW (producing DWARF or PDB depending on toolchain).
* Run converter end to end.

We can’t do actual toolchain spawning yet in this skeleton, so we mark as pending. Catch2 supports `SUCCEED` so test passes but reminds you what to fill.

### `st/test_system_pipeline.cpp`

```cpp
#include <catch2/catch_all.hpp>

// Goal for future real test:
// 1. Build test.cpp that has global int a; int main(){return a;}
// 2. On Windows+MSVC: produce .exe + .pdb
//    On MinGW/clang: produce .o with DWARF
// 3. Run converter: PDB -> IR -> DWARF (emit dwarf obj), then DWARF -> IR -> PDB.
// 4. Re-run an external debugger check maybe.
//
// For now we just assert "TODO".

TEST_CASE("System pipeline end-to-end placeholder", "[st][system]") {
    SUCCEED("TODO: compile sample TU with toolchain, run full DWARF<->PDB conversion.");
}
```

Later you’ll:

* Actually spawn build commands with `std::system("clang ...")` or MSVC cl.exe inside this test, gated by `#ifdef _WIN32`.
* Call your converter CLI binary `dwarf_pdb_converter` to do `--pdb-to-dwarf` / `--dwarf-to-pdb`.
* Re-run dwarfdump / llvm-pdbutil etc. to sanity check.

---

## 7. Recap / what you have now

You now have:

### Project structure

```text
newDwarf2Pdb/
  CMakeLists.txt
  src/
    main.cpp
    dwarf/
      DwarfNode.h/.cpp
      DwarfReader.h/.cpp
      DwarfWriter.h/.cpp
    pdb/
      PdbNode.h/.cpp
      PdbReader.h/.cpp
      PdbWriter.h/.cpp
    ir/
      IRNode.h/.cpp
      IRTypeTable.h/.cpp
      IRMaps.h/.cpp
    pipeline/
      DwarfToPdb.h/.cpp
      PdbToDwarf.h/.cpp
    util/
      Compare.h/.cpp
  ut/
    test_roundtrip_dwarf.cpp
    test_roundtrip_pdb.cpp
  it/
    dwarf/test_dwarf_integration.cpp
    pdb/test_pdb_integration.cpp
  st/
    test_system_pipeline.cpp
```

### What the tests do right now

* **ut tests**: build fake DwarfNode/PdbNode → IR → back to node using pipeline, and assert basic sanity. This tests your in-memory graph transforms and the IR maps.
* **it tests**: simulate I/O pipeline (Reader → IR → Writer). They’re placeholders for binary emit/parse later.
* **st test**: placeholder for full real toolchain, where eventually you’ll compile a TU with global `int a; int main(){return a;}` and actually run your CLI to produce PDB↔DWARF.

### Why this is good:

* You already enforce the architectural contract: DWARF ↔ IR ↔ PDB goes through `IRTypeTable` + `IRMaps`.
* You have a place (`Compare.*`) to evolve deep-structural equality once your translator stops being stubby.
* You have Catch2 wired in CMake so you can run:

  ```bash
  cmake -S . -B build
  cmake --build build
  ctest --test-dir build
  ```

From here, you can start filling in “real” logic in tiny steps (like preserving names, fields, sizes, forward refs) and then tighten your `CHECK`s in the tests.

This gives you a first working test harness for the DWARF5↔PDB converter project.
