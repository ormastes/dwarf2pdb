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
