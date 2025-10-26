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
