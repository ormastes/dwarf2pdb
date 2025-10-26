#include "IRTypeTable.h"

IRType* IRTypeTable::createType(IRTypeKind k) {
    IRTypeID id = nextID++;
    auto t = std::make_unique<IRType>();
    t->id = id;
    t->kind = k;
    IRType* raw = t.get();
    types[id] = std::move(t);
    return raw;
}

IRType* IRTypeTable::lookup(IRTypeID id) {
    auto it = types.find(id);
    if (it == types.end()) return nullptr;
    return it->second.get();
}

const IRType* IRTypeTable::lookup(IRTypeID id) const {
    auto it = types.find(id);
    if (it == types.end()) return nullptr;
    return it->second.get();
}
