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
