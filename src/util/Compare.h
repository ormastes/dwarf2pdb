#pragma once
#include <string>
#include <vector>
#include "../ir/IRNode.h"
#include "../dwarf/DwarfNode.h"
#include "../pdb/PdbNode.h"

// Compare two IRTypes by structure (not by address)
bool EqualIRType(const IRType* a, const IRType* b);

// Compare two IRScopes recursively (including symbols and declaredTypes list).
// NOTE: Only checks structure and names / kinds, not address ranges etc.
bool EqualIRScope(const IRScope* a, const IRScope* b);

// Compare DwarfNode recursively: tag, child count, and simple attrs we store
bool EqualDwarfNode(const DwarfNode* a, const DwarfNode* b);

// Compare PdbNode recursively: leafKind, pretty/uniqueName, child shape
bool EqualPdbNode(const PdbNode* a, const PdbNode* b);
