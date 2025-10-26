#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <memory>

// Low-level PDB / CodeView node.
// Could represent LF_* type records or S_* symbols.
struct PdbNode {
    uint16_t leafKind = 0; // LF_* or S_*
    std::vector<std::uint8_t> payload;

    PdbNode* parent = nullptr;
    std::vector<std::unique_ptr<PdbNode>> children;

    // for types we might store "type index"
    std::uint32_t typeIndexOrSymOffset = 0;
    std::string prettyName;
    std::string uniqueName;
};
