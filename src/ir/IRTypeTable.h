#pragma once
#include "IRNode.h"
#include <unordered_map>
#include <memory>

class IRTypeTable {
public:
    IRTypeTable() = default;

    IRType* createType(IRTypeKind k);

    IRType* lookup(IRTypeID id);
    const IRType* lookup(IRTypeID id) const;

    // TODO: implement structural interning / dedup later.
private:
    IRTypeID nextID = 1;
    std::unordered_map<IRTypeID, std::unique_ptr<IRType>> types;
};
