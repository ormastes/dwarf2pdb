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
