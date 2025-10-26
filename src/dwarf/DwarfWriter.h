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
