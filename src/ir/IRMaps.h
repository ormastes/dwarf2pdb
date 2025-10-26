#pragma once
#include <cstdint>
#include <unordered_map>
#include "IRNode.h"

class IRMaps {
public:
    // DWARF side
    // key: DWARF DIE offset (or some CU-relative ID you assign)
    std::unordered_map<std::uint64_t, IRTypeID> dwarfDieToIR;
    std::unordered_map<IRTypeID, std::uint64_t> irToDwarfDie;

    // PDB side
    // key: CodeView type index
    std::unordered_map<std::uint32_t, IRTypeID> pdbTIToIR;
    std::unordered_map<IRTypeID, std::uint32_t> irToPdbTI;
};
