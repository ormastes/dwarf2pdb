#include "DwarfReader.h"
#include <iostream>

// Stub: Build a fake IR tree with one CU scope and one dummy struct type.
std::unique_ptr<IRScope> DwarfReader::readObject(
    const std::string& path,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    std::cout << "[DwarfReader] reading DWARF from " << path << " (stub)\n";

    auto root = std::make_unique<IRScope>();
    root->kind = IRScopeKind::CompileUnit;
    root->name = path;

    // Create a dummy struct type in IR
    IRType* t = typeTable.createType(IRTypeKind::StructOrUnion);
    t->name = "DummyFromDwarf";
    t->isUnion = false;
    t->sizeBytes = 16;
    t->fields.push_back(IRField{
        "fieldA",
        t->id, // self-type just for circular demo (nonsense, but ok stub)
        0,0,0,false
    });

    // Track ownership in scope
    root->declaredTypes.push_back(t->id);

    // Also put a dummy symbol
    IRSymbol varSym;
    varSym.name = "var_from_dwarf";
    varSym.kind = IRSymbolKind::Variable;
    varSym.type = t->id;
    root->declaredSymbols.push_back(varSym);

    // Fill ID maps with fake DIE offset 0x1234
    maps.dwarfDieToIR[0x1234] = t->id;
    maps.irToDwarfDie[t->id]  = 0x1234;

    return root;
}

std::unique_ptr<IRScope> DwarfReader::readFromModel(
    const DwarfNode& model,
    IRTypeTable& typeTable,
    IRMaps& maps
) {
    // Very dumb translation for test:
    // - Make one CU IRScope named "fromModel"
    // - Create one IRType named from model first attrStr if present
    auto root = std::make_unique<IRScope>();
    root->kind = IRScopeKind::CompileUnit;
    root->name = "fromModel";

    IRType* t = typeTable.createType(IRTypeKind::StructOrUnion);
    t->isUnion = false;
    t->sizeBytes = 16;
    if (!model.attrsStr.empty()) {
        t->name = model.attrsStr[0].second;
    } else {
        t->name = "AnonFromDwarfNode";
    }

    // self-field to prove round-trip
    IRField f;
    f.name = "self";
    f.type = t->id;
    f.byteOffset = 0;
    t->fields.push_back(f);

    root->declaredTypes.push_back(t->id);

    IRSymbol s;
    s.name = "symFromDwarf";
    s.kind = IRSymbolKind::Variable;
    s.type = t->id;
    root->declaredSymbols.push_back(s);

    maps.dwarfDieToIR[model.originalDieOffset] = t->id;
    maps.irToDwarfDie[t->id] = model.originalDieOffset;
    return root;
}

std::unique_ptr<DwarfNode> DwarfReader::parseRawDwarf(const std::string& path) {
    // TODO: real DWARF parse
    (void)path;
    auto cu = std::make_unique<DwarfNode>();
    cu->tag = 0x11; // DW_TAG_compile_unit (just symbolic)
    cu->originalDieOffset = 0x1000;
    return cu;
}

void DwarfReader::importCompileUnit(DwarfNode* cuNode,
                                    IRScope& irCU,
                                    IRTypeTable& typeTable,
                                    IRMaps& maps) {
    // TODO: walk children etc.
    (void)cuNode;
    (void)irCU;
    (void)typeTable;
    (void)maps;
}
