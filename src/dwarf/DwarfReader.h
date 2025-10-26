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

    // NEW: Build IR from an already-existing DwarfNode tree (for tests).
    std::unique_ptr<IRScope> readFromModel(
        const DwarfNode& model,
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
