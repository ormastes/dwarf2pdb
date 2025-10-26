#include <catch2/catch_all.hpp>
#include "dwarf/DwarfReader.h"
#include "dwarf/DwarfWriter.h"
#include "pipeline/PdbToDwarf.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

// Future shape we want:
//
// original DwarfNode -> IR -> DwarfNodeModel -> DwarfWriter.writeObject(temp.obj)
// -> DwarfReader.readObject(temp.obj) -> compare.
//
// Right now, readObject() and writeObject() are stubs, so we just assert
// the call chain doesn't crash.

TEST_CASE("DWARF integration pipeline stub", "[it][dwarf]") {
    DwarfNode startModel;
    startModel.tag = 0x11;
    startModel.originalDieOffset = 0xAAAA;
    startModel.attrsStr.push_back({0x03, "IntegrationDwarf"});

    IRTypeTable typeTable;
    IRMaps maps;
    DwarfReader dreader;
    auto irRoot = dreader.readFromModel(startModel, typeTable, maps);

    REQUIRE(irRoot);

    PdbToDwarf p2d;
    auto dwarfModelOut = p2d.translate(irRoot.get(), typeTable, maps);

    REQUIRE(dwarfModelOut);

    DwarfWriter dwriter;
    dwriter.writeObject("tmp_out_dwarf.o", dwarfModelOut.get());

    // In the future:
    // auto irRoot2 = dreader.readObject("tmp_out_dwarf.o", typeTable2, maps2);
    // CHECK(EqualDwarfNode(reParsedFromDisk, dwarfModelOut.get()));

    SUCCEED("DWARF integration pipeline (stubbed IO) executed.");
}
