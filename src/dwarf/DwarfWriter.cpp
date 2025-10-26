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
