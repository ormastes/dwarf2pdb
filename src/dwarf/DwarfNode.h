#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include <memory>

// Low-level DWARF view node.
// One per DIE, basically.
struct DwarfNode {
    uint16_t tag = 0; // DW_TAG_*
    std::vector<std::pair<uint16_t, std::string>> attrsStr;
    std::vector<std::pair<uint16_t, std::uint64_t>> attrsU64;

    DwarfNode* parent = nullptr;
    std::vector<std::unique_ptr<DwarfNode>> children;

    // For debugging/round-trip
    std::uint64_t originalDieOffset = 0;
};
