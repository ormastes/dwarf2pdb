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
