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

    // NEW: Build IR from an existing PdbNode (for tests)
    std::unique_ptr<IRScope> readFromModel(
        const PdbNode& model,
        IRTypeTable& typeTable,
        IRMaps& maps
    );

private:
    // TODO: parse MSF, read TPI stream, etc.
    std::unique_ptr<PdbNode> parseRawPdb(const std::string& path);
};
