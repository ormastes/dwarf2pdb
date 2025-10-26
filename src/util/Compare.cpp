#include "Compare.h"
#include <algorithm>

// Helper: compare vectors of same length using lambda cmp(i,j)
template <typename T, typename F>
static bool CompareVec(const std::vector<T>& A,
                       const std::vector<T>& B,
                       F cmp) {
    if (A.size() != B.size()) return false;
    for (size_t i = 0; i < A.size(); ++i) {
        if (!cmp(A[i], B[i])) return false;
    }
    return true;
}

bool EqualIRType(const IRType* a, const IRType* b) {
    if (!a || !b) return a == b;
    if (a->kind        != b->kind)        return false;
    if (a->name        != b->name)        return false;
    if (a->isForwardDecl != b->isForwardDecl) return false;
    if (a->isUnion     != b->isUnion)     return false;
    if (a->sizeBytes   != b->sizeBytes)   return false;
    if (a->pointeeType != b->pointeeType) return false;
    if (a->ptrSizeBytes!= b->ptrSizeBytes)return false;
    if (a->elementType != b->elementType) return false;
    if (a->indexType   != b->indexType)   return false;
    if (!CompareVec(a->dims, b->dims, [](const IRArrayDim& x,const IRArrayDim& y){
        return x.lowerBound==y.lowerBound && x.count==y.count;
    })) return false;
    if (!CompareVec(a->fields, b->fields, [](const IRField& x,const IRField& y){
        return x.name==y.name
            && x.type==y.type
            && x.byteOffset==y.byteOffset
            && x.bitOffset==y.bitOffset
            && x.bitSize==y.bitSize
            && x.isAnonymousArm==y.isAnonymousArm;
    })) return false;

    // We ignore a->id vs b->id because different tables can assign different IDs.
    return true;
}

static bool EqualIRSymbol(const IRSymbol& a, const IRSymbol& b) {
    return a.name == b.name &&
           a.kind == b.kind &&
           a.type == b.type;
}

bool EqualIRScope(const IRScope* a, const IRScope* b) {
    if (!a || !b) return a == b;
    if (a->kind != b->kind) return false;
    if (a->name != b->name) return false;

    // Compare declaredTypes list (same #, same IDs in same order)
    if (a->declaredTypes.size() != b->declaredTypes.size()) return false;
    for (size_t i = 0; i < a->declaredTypes.size(); ++i) {
        if (a->declaredTypes[i] != b->declaredTypes[i]) return false;
    }

    // Compare symbols
    if (!CompareVec(a->declaredSymbols, b->declaredSymbols, EqualIRSymbol))
        return false;

    // Children recursion
    if (a->children.size() != b->children.size()) return false;
    for (size_t i = 0; i < a->children.size(); ++i) {
        if (!EqualIRScope(a->children[i].get(), b->children[i].get()))
            return false;
    }

    return true;
}

bool EqualDwarfNode(const DwarfNode* a, const DwarfNode* b) {
    if (!a || !b) return a == b;
    if (a->tag != b->tag) return false;
    if (a->attrsStr.size() != b->attrsStr.size()) return false;
    if (a->attrsU64.size() != b->attrsU64.size()) return false;

    for (size_t i = 0; i < a->attrsStr.size(); ++i) {
        if (a->attrsStr[i].first  != b->attrsStr[i].first)  return false;
        if (a->attrsStr[i].second != b->attrsStr[i].second) return false;
    }
    for (size_t i = 0; i < a->attrsU64.size(); ++i) {
        if (a->attrsU64[i].first  != b->attrsU64[i].first)  return false;
        if (a->attrsU64[i].second != b->attrsU64[i].second) return false;
    }

    if (a->children.size() != b->children.size()) return false;
    for (size_t i = 0; i < a->children.size(); ++i) {
        if (!EqualDwarfNode(a->children[i].get(), b->children[i].get()))
            return false;
    }
    return true;
}

bool EqualPdbNode(const PdbNode* a, const PdbNode* b) {
    if (!a || !b) return a == b;
    if (a->leafKind != b->leafKind) return false;
    if (a->prettyName != b->prettyName) return false;
    if (a->uniqueName != b->uniqueName) return false;

    // For simplicity, ignore payload bytes ordering for now
    if (a->children.size() != b->children.size()) return false;
    for (size_t i = 0; i < a->children.size(); ++i) {
        if (!EqualPdbNode(a->children[i].get(), b->children[i].get()))
            return false;
    }
    return true;
}
