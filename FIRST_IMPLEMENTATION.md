Awesome. I'll give you a first cut "v0 skeleton" of a DWARF↔PDB converter project in C++.

Goals you asked for:

* Folder-per-layer (`dwarf_reader`, `dwarf_writer`, `dwarf_node`, `ir`, `pdb_node`, `pdb_reader`, `pdb_writer`, …).
* An `int main()` with global `int a;` that just returns `a;`.
* Ability to conceptually “generate PDB from DWARF5” and “generate DWARF5 from PDB”.
* First version of the converter: stubbed pipeline and mapping logic.

I'll give you:

1. Directory layout
2. CMakeLists.txt (so you can actually build it)
3. All headers / sources with minimal compile-ready code
4. Notes on what to fill in next

---

## 1. Directory layout

```text
dwarf-pdb-converter/
├─ CMakeLists.txt
├─ src/
│  ├─ main.cpp
│  ├─ dwarf/
│  │   ├─ DwarfNode.h
│  │   ├─ DwarfNode.cpp
│  │   ├─ DwarfReader.h
│  │   ├─ DwarfReader.cpp
│  │   ├─ DwarfWriter.h
│  │   ├─ DwarfWriter.cpp
│  ├─ pdb/
│  │   ├─ PdbNode.h
│  │   ├─ PdbNode.cpp
│  │   ├─ PdbReader.h
│  │   ├─ PdbReader.cpp
│  │   ├─ PdbWriter.h
│  │   ├─ PdbWriter.cpp
│  ├─ ir/
│  │   ├─ IRNode.h
│  │   ├─ IRNode.cpp
│  │   ├─ IRTypeTable.h
│  │   ├─ IRTypeTable.cpp
│  │   ├─ IRMaps.h
│  │   ├─ IRMaps.cpp
│  ├─ pipeline/
│      ├─ DwarfToPdb.h
│      ├─ DwarfToPdb.cpp
│      ├─ PdbToDwarf.h
│      ├─ PdbToDwarf.cpp
```

* `dwarf/*`: DWARF-specific view + I/O.
* `pdb/*`: PDB-specific view + I/O.
* `ir/*`: canonical format-neutral IR (type table, scopes, etc.).
* `pipeline/*`: high-level converters that orchestrate DWARF→IR→PDB and PDB→IR→DWARF.
* `main.cpp`: CLI entry, global `int a`, returns `a`.

Right now all of this is stubbed. It compiles, but the "real work" is TODO.

---

## 2. CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.20)

project(dwarf_pdb_converter
    VERSION 0.0.1
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(dwarf_pdb_converter
    src/main.cpp

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
)

target_include_directories(dwarf_pdb_converter PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)
```

You can just `cmake -S . -B build && cmake --build build`.

---

## 3. Source code

### 3.1 `src/main.cpp`

This satisfies your “int a; global variable just return a;” requirement and wires the pipeline stubs.

```cpp
#include <iostream>
#include <string>

#include "dwarf/DwarfReader.h"
#include "dwarf/DwarfWriter.h"
#include "pdb/PdbReader.h"
#include "pdb/PdbWriter.h"
#include "pipeline/DwarfToPdb.h"
#include "pipeline/PdbToDwarf.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

// global variable 'a'
int a = 0;

// Very simple CLI:
//
//   mode:
//     --dwarf-to-pdb <in.dwarf.obj> <out.pdb>
//     --pdb-to-dwarf <in.pdb>       <out.dwarf.obj>
//
// For now we just exercise the call graph and print TODOs.
// Return code is 'a' per your request.
int main(int argc, char** argv) {
    if (argc >= 2) {
        std::string mode = argv[1];

        if (mode == "--dwarf-to-pdb" && argc == 4) {
            std::string dwarfInput  = argv[2];
            std::string pdbOutput   = argv[3];

            // Core IR containers for translation
            IRTypeTable typeTable;
            IRMaps      maps;

            DwarfReader dreader;
            auto irRootScope = dreader.readObject(dwarfInput, typeTable, maps);

            DwarfToPdb d2p;
            PdbWriter  pwriter;
            auto pdbModel = d2p.translate(irRootScope.get(), typeTable, maps);
            pwriter.writePdb(pdbOutput, pdbModel.get());

            std::cout << "[OK] DWARF->PDB stub done\n";
        }
        else if (mode == "--pdb-to-dwarf" && argc == 4) {
            std::string pdbInput     = argv[2];
            std::string dwarfOutput  = argv[3];

            IRTypeTable typeTable;
            IRMaps      maps;

            PdbReader preader;
            auto irRootScope = preader.readPdb(pdbInput, typeTable, maps);

            PdbToDwarf p2d;
            DwarfWriter dwriter;
            auto dwarfModel = p2d.translate(irRootScope.get(), typeTable, maps);
            dwriter.writeObject(dwarfOutput, dwarfModel.get());

            std::cout << "[OK] PDB->DWARF stub done\n";
        }
        else {
            std::cerr << "Usage:\n"
                      << "  " << argv[0] << " --dwarf-to-pdb <in.obj> <out.pdb>\n"
                      << "  " << argv[0] << " --pdb-to-dwarf <in.pdb> <out.obj>\n";
        }
    } else {
        std::cerr << "No args. Nothing done.\n";
    }

    return a; // requirement: just return global a
}
```

---

### 3.2 IR core

#### `src/ir/IRNode.h`

This defines semantic IR types, scopes, fields, etc. (trimmed version of the design we discussed).

```cpp
#pragma once
#include <cstdint>
#include <memory>
#include <string>
#include <vector>
#include <unordered_map>

struct IRType;
struct IRStructType;
struct IRArrayType;
struct IRPointerType;

using IRTypeID = std::uint32_t;

enum class IRTypeKind {
    StructOrUnion,
    Array,
    Pointer,
    Unknown
};

struct IRField {
    std::string name;
    IRTypeID    type;          // points into IRTypeTable
    std::uint64_t byteOffset = 0;
    std::uint16_t bitOffset  = 0;
    std::uint16_t bitSize    = 0;
    bool isAnonymousArm      = false;
};

struct IRArrayDim {
    std::int64_t  lowerBound = 0;
    std::uint64_t count      = 0;
};

// Base type node
struct IRType {
    IRTypeID     id = 0;
    IRTypeKind   kind = IRTypeKind::Unknown;
    std::string  name;          // "Node", "anonymous$1", "int*", "int[10]"
    bool         isForwardDecl = false;
    bool         isUnion = false; // For StructOrUnion
    std::uint64_t sizeBytes = 0;  // total sizeof(T)

    // Struct/union-specific
    std::vector<IRField> fields;

    // Array-specific
    std::vector<IRArrayDim> dims;
    IRTypeID elementType = 0;
    IRTypeID indexType   = 0; // for PDB LF_ARRAY; DWARF might just leave this 0

    // Pointer-specific
    IRTypeID pointeeType = 0;
    std::uint32_t ptrSizeBytes = 0;
};

// Symbols in lexical scope
enum class IRSymbolKind {
    Variable,
    Function,
    Parameter
};

struct IRSymbol {
    std::string   name;
    IRSymbolKind  kind = IRSymbolKind::Variable;
    IRTypeID      type = 0;
    // TODO: storage info, live ranges
};

// Lexical scopes: CU, namespace, function, block, etc.
enum class IRScopeKind {
    CompileUnit,
    Namespace,
    Function,
    Block,
    FileStatic
};

struct IRScope {
    IRScopeKind kind = IRScopeKind::CompileUnit;
    std::string name;

    IRScope* parent = nullptr;
    std::vector<std::unique_ptr<IRScope>> children;

    std::vector<IRTypeID> declaredTypes;  // types primarily "introduced" here
    std::vector<IRSymbol> declaredSymbols;
};
```

#### `src/ir/IRTypeTable.h`

```cpp
#pragma once
#include "IRNode.h"
#include <unordered_map>
#include <memory>

class IRTypeTable {
public:
    IRTypeTable() = default;

    IRType* createType(IRTypeKind k);

    IRType* lookup(IRTypeID id);
    const IRType* lookup(IRTypeID id) const;

    // TODO: implement structural interning / dedup later.
private:
    IRTypeID nextID = 1;
    std::unordered_map<IRTypeID, std::unique_ptr<IRType>> types;
};
```

#### `src/ir/IRTypeTable.cpp`

```cpp
#include "IRTypeTable.h"

IRType* IRTypeTable::createType(IRTypeKind k) {
    IRTypeID id = nextID++;
    auto t = std::make_unique<IRType>();
    t->id = id;
    t->kind = k;
    IRType* raw = t.get();
    types[id] = std::move(t);
    return raw;
}

IRType* IRTypeTable::lookup(IRTypeID id) {
    auto it = types.find(id);
    if (it == types.end()) return nullptr;
    return it->second.get();
}

const IRType* IRTypeTable::lookup(IRTypeID id) const {
    auto it = types.find(id);
    if (it == types.end()) return nullptr;
    return it->second.get();
}
```

#### `src/ir/IRMaps.h`

These are the per-format ID maps: DWARF DIE offset ↔ IRTypeID, PDB TypeIndex ↔ IRTypeID, etc.

```cpp
#pragma once
#include <cstdint>
#include <unordered_map>
#include "IRNode.h"

class IRMaps {
public:
    // DWARF side
    // key: DWARF DIE offset (or some CU-relative ID you assign)
    std::unordered_map<std::uint64_t, IRTypeID> dwarfDieToIR;
    std::unordered_map<IRTypeID, std::uint64_t> irToDwarfDie;

    // PDB side
    // key: CodeView type index
    std::unordered_map<std::uint32_t, IRTypeID> pdbTIToIR;
    std::unordered_map<IRTypeID, std::uint32_t> irToPdbTI;
};
```

#### `src/ir/IRMaps.cpp`

```cpp
#include "IRMaps.h"
// currently empty, placeholder for helper funcs
```

#### `src/ir/IRNode.cpp`

```cpp
#include "IRNode.h"
// currently empty: IRNode structs are simple POD-like holders
```

---

### 3.3 DWARF side

These are placeholders. Eventually these talk to libdwarf / libdw / LLVM DWARFContext etc. For now: stubs that build a trivial IR tree.

#### `src/dwarf/DwarfNode.h`

```cpp
#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <memory>

// Low-level DWARF view node.
// One per DIE, basically.
struct DwarfNode {
    uint16_t tag = 0; // DW_TAG_*
    std::vector<std::pair<uint16_t, std::string>> attrsStr;
    std::vector<std::pair<uint16_t, std::uint64_t>> attrsU64;

    DwarfNode* parent = nullptr;
    std::vector<std::unique_ptr<DwarfNode>> children;

    // For debugging/round-trip
    std::uint64_t originalDieOffset = 0;
};
```

#### `src/dwarf/DwarfNode.cpp`

```cpp
#include "DwarfNode.h"
// trivial for now
```

#### `src/dwarf/DwarfReader.h`

```cpp
#pragma once
#include <memory>
#include <string>
#include "../ir/IRNode.h"
#include "../ir/IRTypeTable.h"
#include "../ir/IRMaps.h"
#include "DwarfNode.h"

// DwarfReader:
// 1. parse DWARF from an object file (ELF, etc.)
// 2. build IRScope + IRTypeTable
// 3. fill IRMaps.dwarfDieToIR
class DwarfReader {
public:
    std::unique_ptr<IRScope> readObject(
        const std::string& path,
        IRTypeTable& typeTable,
        IRMaps& maps
    );

private:
    // internal helpers (future)
    std::unique_ptr<DwarfNode> parseRawDwarf(const std::string& path);
    void importCompileUnit(DwarfNode* cuNode,
                           IRScope& irCU,
                           IRTypeTable& typeTable,
                           IRMaps& maps);
};
```

#### `src/dwarf/DwarfReader.cpp`

```cpp
#include "DwarfReader.h"
#include <iostream>

// Stub: Build a fake IR tree with one CU scope and one dummy struct type.
std::unique_ptr<IRScope> DwarfReader::readObject(
    const std::string& path,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    std::cout << "[DwarfReader] reading DWARF from " << path << " (stub)\n";

    auto root = std::make_unique<IRScope>();
    root->kind = IRScopeKind::CompileUnit;
    root->name = path;

    // Create a dummy struct type in IR
    IRType* t = typeTable.createType(IRTypeKind::StructOrUnion);
    t->name = "DummyFromDwarf";
    t->isUnion = false;
    t->sizeBytes = 16;
    t->fields.push_back(IRField{
        "fieldA",
        t->id, // self-type just for circular demo (nonsense, but ok stub)
        0,0,0,false
    });

    // Track ownership in scope
    root->declaredTypes.push_back(t->id);

    // Also put a dummy symbol
    IRSymbol varSym;
    varSym.name = "var_from_dwarf";
    varSym.kind = IRSymbolKind::Variable;
    varSym.type = t->id;
    root->declaredSymbols.push_back(varSym);

    // Fill ID maps with fake DIE offset 0x1234
    maps.dwarfDieToIR[0x1234] = t->id;
    maps.irToDwarfDie[t->id]  = 0x1234;

    return root;
}

std::unique_ptr<DwarfNode> DwarfReader::parseRawDwarf(const std::string& path) {
    // TODO: real DWARF parse
    auto cu = std::make_unique<DwarfNode>();
    cu->tag = 0x11; // DW_TAG_compile_unit (just symbolic)
    cu->originalDieOffset = 0x1000;
    return cu;
}

void DwarfReader::importCompileUnit(DwarfNode* cuNode,
                                    IRScope& irCU,
                                    IRTypeTable& typeTable,
                                    IRMaps& maps) {
    // TODO: walk children etc.
    (void)cuNode;
    (void)irCU;
    (void)typeTable;
    (void)maps;
}
```

#### `src/dwarf/DwarfWriter.h`

```cpp
#pragma once
#include <memory>
#include <string>
#include "../ir/IRNode.h"
#include "../ir/IRTypeTable.h"
#include "../ir/IRMaps.h"
#include "DwarfNode.h"

// DwarfWriter:
// 1. take IRScope/IRTypeTable
// 2. assign DIE offsets (update maps.irToDwarfDie)
// 3. serialize to DWARF in an object or .dwo/etc.
class DwarfWriter {
public:
    // dwarfModel is optional pre-built DwarfNode view.
    void writeObject(
        const std::string& outPath,
        const DwarfNode* dwarfModel /* can be null */
    );
};
```

#### `src/dwarf/DwarfWriter.cpp`

```cpp
#include "DwarfWriter.h"
#include <iostream>

void DwarfWriter::writeObject(
    const std::string& outPath,
    const DwarfNode* dwarfModel
) {
    std::cout << "[DwarfWriter] writing DWARF to " << outPath
              << " (stub). dwarfModel=" << (dwarfModel ? "yes" : "no")
              << "\n";

    // TODO:
    // - assign DIE offsets for each IRType
    // - emit .debug_info, .debug_abbrev, .debug_str, etc.
    (void)dwarfModel;
}
```

---

### 3.4 PDB side

Again, stubs. Eventually these talk to DIA / msf / cv streams / llvm-pdb.

#### `src/pdb/PdbNode.h`

```cpp
#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <memory>

// Low-level PDB / CodeView node.
// Could represent LF_* type records or S_* symbols.
struct PdbNode {
    uint16_t leafKind = 0; // LF_* or S_*
    std::vector<std::uint8_t> payload;

    PdbNode* parent = nullptr;
    std::vector<std::unique_ptr<PdbNode>> children;

    // for types we might store "type index"
    std::uint32_t typeIndexOrSymOffset = 0;
    std::string prettyName;
    std::string uniqueName;
};
```

#### `src/pdb/PdbNode.cpp`

```cpp
#include "PdbNode.h"
// trivial right now
```

#### `src/pdb/PdbReader.h`

```cpp
#pragma once
#include <memory>
#include <string>
#include "../ir/IRNode.h"
#include "../ir/IRTypeTable.h"
#include "../ir/IRMaps.h"
#include "PdbNode.h"

// PdbReader:
// 1. open PDB
// 2. read TPI (type records) + symbol streams
// 3. populate IRTypeTable + IRScope
// 4. fill maps.pdbTIToIR
class PdbReader {
public:
    std::unique_ptr<IRScope> readPdb(
        const std::string& path,
        IRTypeTable& typeTable,
        IRMaps& maps
    );

private:
    // TODO: parse MSF, read TPI stream, etc.
    std::unique_ptr<PdbNode> parseRawPdb(const std::string& path);
};
```

#### `src/pdb/PdbReader.cpp`

```cpp
#include "PdbReader.h"
#include <iostream>

std::unique_ptr<IRScope> PdbReader::readPdb(
    const std::string& path,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    std::cout << "[PdbReader] reading PDB from " << path << " (stub)\n";

    auto root = std::make_unique<IRScope>();
    root->kind = IRScopeKind::CompileUnit;
    root->name = path;

    // Create a dummy struct type in IR
    IRType* t = typeTable.createType(IRTypeKind::StructOrUnion);
    t->name = "DummyFromPdb";
    t->isUnion = true;
    t->sizeBytes = 8;

    IRField f;
    f.name = "alt0";
    f.type = t->id;
    f.byteOffset = 0;
    t->fields.push_back(f);

    root->declaredTypes.push_back(t->id);

    IRSymbol sym;
    sym.name = "var_from_pdb";
    sym.kind = IRSymbolKind::Variable;
    sym.type = t->id;
    root->declaredSymbols.push_back(sym);

    // map PDB type index 0x1000 <-> our IRTypeID
    maps.pdbTIToIR[0x1000] = t->id;
    maps.irToPdbTI[t->id]  = 0x1000;

    return root;
}

std::unique_ptr<PdbNode> PdbReader::parseRawPdb(const std::string& path) {
    (void)path;
    // Would parse PDB streams and build node tree for debugging/roundtrip.
    return std::make_unique<PdbNode>();
}
```

#### `src/pdb/PdbWriter.h`

```cpp
#pragma once
#include <memory>
#include <string>
#include "PdbNode.h"

// PdbWriter:
// 1. take IRScope/IRTypeTable (wrapped upstream)
// 2. assign CodeView type indices
// 3. write MSF/PDB streams.
class PdbWriter {
public:
    void writePdb(
        const std::string& outPath,
        const PdbNode* pdbModel /* can be null */
    );
};
```

#### `src/pdb/PdbWriter.cpp`

```cpp
#include "PdbWriter.h"
#include <iostream>

void PdbWriter::writePdb(
    const std::string& outPath,
    const PdbNode* pdbModel
) {
    std::cout << "[PdbWriter] writing PDB to " << outPath
              << " (stub). pdbModel=" << (pdbModel ? "yes" : "no")
              << "\n";

    // TODO:
    // - build TPI stream: emit LF_STRUCTURE / LF_UNION / LF_ARRAY / LF_POINTER ...
    // - build symbol streams: S_GPROC32, S_LOCAL, S_UDT, etc.
    (void)pdbModel;
}
```

---

### 3.5 Pipeline

These are the “glue translators”:

* `DwarfToPdb`: take IR (produced by DWARF reader), produce a `PdbNode` tree ready for PdbWriter.
* `PdbToDwarf`: opposite direction.

#### `src/pipeline/DwarfToPdb.h`

```cpp
#pragma once
#include <memory>
#include <string>
#include "../ir/IRNode.h"
#include "../ir/IRTypeTable.h"
#include "../ir/IRMaps.h"
#include "../pdb/PdbNode.h"

// DwarfToPdb:
// Takes IR (which came from DwarfReader) and builds PdbNode model.
// Also assigns PDB type indices in maps.irToPdbTI, etc.
class DwarfToPdb {
public:
    std::unique_ptr<PdbNode> translate(
        IRScope* rootScope,
        IRTypeTable& typeTable,
        IRMaps& maps
    );

private:
    void emitTypesAsPdb(
        IRTypeTable& typeTable,
        IRMaps& maps,
        PdbNode& pdbRoot
    );
};
```

#### `src/pipeline/DwarfToPdb.cpp`

```cpp
#include "DwarfToPdb.h"
#include <iostream>

std::unique_ptr<PdbNode> DwarfToPdb::translate(
    IRScope* rootScope,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    std::cout << "[DwarfToPdb] translate IR -> PDB model (stub)\n";
    (void)rootScope;
    auto pdbRoot = std::make_unique<PdbNode>();
    pdbRoot->leafKind = 0x1234; // fake
    pdbRoot->prettyName = "PdbRootFromDwarf";

    emitTypesAsPdb(typeTable, maps, *pdbRoot);
    return pdbRoot;
}

void DwarfToPdb::emitTypesAsPdb(
    IRTypeTable& typeTable,
    IRMaps& maps,
    PdbNode& pdbRoot
) {
    (void)typeTable;
    (void)maps;
    (void)pdbRoot;
    // TODO:
    // walk all IRTypeTable entries:
    //   assign a fresh CodeView TI if not present in maps.irToPdbTI
    //   create child PdbNode for LF_STRUCTURE / LF_UNION / LF_ARRAY / etc.
}
```

#### `src/pipeline/PdbToDwarf.h`

```cpp
#pragma once
#include <memory>
#include <string>
#include "../ir/IRNode.h"
#include "../ir/IRTypeTable.h"
#include "../ir/IRMaps.h"
#include "../dwarf/DwarfNode.h"

// PdbToDwarf:
// Takes IR (which came from PdbReader) and builds DwarfNode model.
// Also assigns DIE offsets in maps.irToDwarfDie.
class PdbToDwarf {
public:
    std::unique_ptr<DwarfNode> translate(
        IRScope* rootScope,
        IRTypeTable& typeTable,
        IRMaps& maps
    );

private:
    void emitTypesAsDwarf(
        IRTypeTable& typeTable,
        IRMaps& maps,
        DwarfNode& dwarfCU
    );
};
```

#### `src/pipeline/PdbToDwarf.cpp`

```cpp
#include "PdbToDwarf.h"
#include <iostream>

std::unique_ptr<DwarfNode> PdbToDwarf::translate(
    IRScope* rootScope,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    std::cout << "[PdbToDwarf] translate IR -> DWARF model (stub)\n";
    (void)rootScope;

    auto cuNode = std::make_unique<DwarfNode>();
    cuNode->tag = 0x11; // pretend DW_TAG_compile_unit
    cuNode->originalDieOffset = 0x2000; // fake

    emitTypesAsDwarf(typeTable, maps, *cuNode);
    return cuNode;
}

void PdbToDwarf::emitTypesAsDwarf(
    IRTypeTable& typeTable,
    IRMaps& maps,
    DwarfNode& dwarfCU
) {
    (void)typeTable;
    (void)maps;
    (void)dwarfCU;
    // TODO:
    // walk IRTypeTable:
    //   assign DIE offsets if not present in maps.irToDwarfDie
    //   make children DwarfNode for DW_TAG_structure_type / union / array / pointer
    //   attach DW_AT_bit_size, DW_AT_data_member_location, etc.
}
```

---

## 4. What you have now

* A compilable C++17 project with:

  * Global `int a;`
  * `main()` that returns `a`.
  * CLI stubs `--dwarf-to-pdb` and `--pdb-to-dwarf`.
  * A clean separation of:

    * DWARF view (reader/writer, DwarfNode)
    * PDB view (reader/writer, PdbNode)
    * Shared IR (IRTypeTable, IRScope, IRMaps)
    * Converters (DwarfToPdb, PdbToDwarf)
* The IR layer is the single source of truth for type identity.
* `IRMaps` is where you solve the "shared type ID" / forward-ref problem for both sides.

This is effectively “first version of dwarf5 pdb converter.”

---

## 5. Next steps you'll likely do

1. **Real DWARF parse**

   * Use libdwarf / LLVM DWARFContext to walk CUs/ DIEs.
   * For each DIE that is a type (`DW_TAG_structure_type`, `DW_TAG_union_type`, `DW_TAG_array_type`, `DW_TAG_pointer_type`, etc.), call `typeTable.createType(...)`, fill fields, and record `maps.dwarfDieToIR[dwarfDieOffset] = newIRTypeID`.

2. **Real PDB parse**

   * Use LLVM’s PDB reading APIs or DIA to walk the TPI stream.
   * For each LF_* type record, create an IRType.
     Record `maps.pdbTIToIR[ti] = newIRTypeID`.

3. **Writers**

   * `PdbWriter`: walk `IRTypeTable`, assign new TIs for anything missing in `maps.irToPdbTI`, serialize LF_*.
   * `DwarfWriter`: walk `IRTypeTable`, assign DIE offsets for anything missing in `maps.irToDwarfDie`, serialize DWARF sections.

4. **Bitfields / anonymous unions / template args**

   * Extend `IRType` / `IRField` to carry:

     * bitSize / bitOffset (already there),
     * isUnion,
     * anonymization flag.
   * Add vector of template params if you need precise reconstruction.

5. **Scope fidelity**

   * Extend `IRScope` to mark lexical ranges (addr ranges) and local-only types.
   * When writing PDB:

     * local types become `S_UDT`-like symbols in `S_BLOCK32` under the function.
   * When writing DWARF:

     * local types become nested `DW_TAG_structure_type` under `DW_TAG_subprogram`.

---

This should give you a solid kickoff repo that (1) compiles, (2) matches the layered design we discussed, and (3) is ready for you to start filling in real DWARF5/PDB logic.
