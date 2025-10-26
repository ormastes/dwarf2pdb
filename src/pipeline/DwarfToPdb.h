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
