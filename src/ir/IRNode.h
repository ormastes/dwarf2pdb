#pragma once
#include <cstdint>
#include <memory>
#include <string>
#include <vector>
#include <unordered_map>

struct IRType;
struct IRStructType;
struct IRArrayType;
struct IRPointerType;

using IRTypeID = std::uint32_t;

enum class IRTypeKind {
    StructOrUnion,
    Array,
    Pointer,
    Unknown
};

struct IRField {
    std::string name;
    IRTypeID    type;          // points into IRTypeTable
    std::uint64_t byteOffset = 0;
    std::uint16_t bitOffset  = 0;
    std::uint16_t bitSize    = 0;
    bool isAnonymousArm      = false;
};

struct IRArrayDim {
    std::int64_t  lowerBound = 0;
    std::uint64_t count      = 0;
};

// Base type node
struct IRType {
    IRTypeID     id = 0;
    IRTypeKind   kind = IRTypeKind::Unknown;
    std::string  name;          // "Node", "anonymous$1", "int*", "int[10]"
    bool         isForwardDecl = false;
    bool         isUnion = false; // For StructOrUnion
    std::uint64_t sizeBytes = 0;  // total sizeof(T)

    // Struct/union-specific
    std::vector<IRField> fields;

    // Array-specific
    std::vector<IRArrayDim> dims;
    IRTypeID elementType = 0;
    IRTypeID indexType   = 0; // for PDB LF_ARRAY; DWARF might just leave this 0

    // Pointer-specific
    IRTypeID pointeeType = 0;
    std::uint32_t ptrSizeBytes = 0;
};

// Symbols in lexical scope
enum class IRSymbolKind {
    Variable,
    Function,
    Parameter
};

struct IRSymbol {
    std::string   name;
    IRSymbolKind  kind = IRSymbolKind::Variable;
    IRTypeID      type = 0;
    // TODO: storage info, live ranges
};

// Lexical scopes: CU, namespace, function, block, etc.
enum class IRScopeKind {
    CompileUnit,
    Namespace,
    Function,
    Block,
    FileStatic
};

struct IRScope {
    IRScopeKind kind = IRScopeKind::CompileUnit;
    std::string name;

    IRScope* parent = nullptr;
    std::vector<std::unique_ptr<IRScope>> children;

    std::vector<IRTypeID> declaredTypes;  // types primarily "introduced" here
    std::vector<IRSymbol> declaredSymbols;
};
