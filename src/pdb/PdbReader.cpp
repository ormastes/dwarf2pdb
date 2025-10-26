#include "PdbReader.h"
#include <iostream>

std::unique_ptr<IRScope> PdbReader::readPdb(
    const std::string& path,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    std::cout << "[PdbReader] reading PDB from " << path << " (stub)\n";

    auto root = std::make_unique<IRScope>();
    root->kind = IRScopeKind::CompileUnit;
    root->name = path;

    // Create a dummy struct type in IR
    IRType* t = typeTable.createType(IRTypeKind::StructOrUnion);
    t->name = "DummyFromPdb";
    t->isUnion = true;
    t->sizeBytes = 8;

    IRField f;
    f.name = "alt0";
    f.type = t->id;
    f.byteOffset = 0;
    t->fields.push_back(f);

    root->declaredTypes.push_back(t->id);

    IRSymbol sym;
    sym.name = "var_from_pdb";
    sym.kind = IRSymbolKind::Variable;
    sym.type = t->id;
    root->declaredSymbols.push_back(sym);

    // map PDB type index 0x1000 <-> our IRTypeID
    maps.pdbTIToIR[0x1000] = t->id;
    maps.irToPdbTI[t->id]  = 0x1000;

    return root;
}

std::unique_ptr<IRScope> PdbReader::readFromModel(
    const PdbNode& model,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    auto root = std::make_unique<IRScope>();
    root->kind = IRScopeKind::CompileUnit;
    root->name = "fromPdbModel";

    IRType* t = typeTable.createType(IRTypeKind::StructOrUnion);
    t->isUnion = true;
    t->sizeBytes = 8;
    t->name = model.prettyName.empty() ? "AnonFromPdbNode" : model.prettyName;

    IRField f;
    f.name = "alt0";
    f.type = t->id;
    f.byteOffset = 0;
    t->fields.push_back(f);

    root->declaredTypes.push_back(t->id);

    IRSymbol s;
    s.name = "symFromPdb";
    s.kind = IRSymbolKind::Variable;
    s.type = t->id;
    root->declaredSymbols.push_back(s);

    maps.pdbTIToIR[model.typeIndexOrSymOffset] = t->id;
    maps.irToPdbTI[t->id] = model.typeIndexOrSymOffset;
    return root;
}

std::unique_ptr<PdbNode> PdbReader::parseRawPdb(const std::string& path) {
    (void)path;
    // Would parse PDB streams and build node tree for debugging/roundtrip.
    return std::make_unique<PdbNode>();
}
