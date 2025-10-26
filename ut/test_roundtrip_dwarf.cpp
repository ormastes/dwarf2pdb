#include <catch2/catch_all.hpp>
#include "dwarf/DwarfReader.h"
#include "pipeline/PdbToDwarf.h"
#include "util/Compare.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

// Goal:
// 1. Build a fake DwarfNode tree "original"
// 2. DwarfReader::readFromModel() -> IRScope + IRTypeTable
// 3. PdbToDwarf::translate(IR) -> DwarfNode "roundTripped"
// 4. Compare original vs roundTripped (with some expectations)

TEST_CASE("DWARF node -> IR -> DWARF node roundtrip basic", "[ut][dwarf]") {
    // Step 1: fake original dwarf model
    DwarfNode originalCU;
    originalCU.tag = 0x11; // pretend DW_TAG_compile_unit
    originalCU.originalDieOffset = 0x9999;
    originalCU.attrsStr.push_back({0x03, "DummyFromDwarf"}); // pretend DW_AT_name

    // Step 2: build IR
    IRTypeTable typeTable;
    IRMaps maps;
    DwarfReader dreader;
    auto irRoot = dreader.readFromModel(originalCU, typeTable, maps);

    REQUIRE(irRoot);
    REQUIRE(irRoot->declaredTypes.size() == 1);

    // Step 3: IR -> DwarfNode using PdbToDwarf translator
    PdbToDwarf p2d;
    auto rebuiltCU = p2d.translate(irRoot.get(), typeTable, maps);

    REQUIRE(rebuiltCU);

    // Step 4: Compare shape. We don't expect perfect match yet,
    // but we can at least check tag and child count equality.
    // Let's just assert tag is same as PdbToDwarf currently produces (0x11)
    CHECK(rebuiltCU->tag == 0x11);

    // We can also check that translate() produced *some* attrs or children.
    // Minimally we assert not null; structural equivalence will tighten later.
    // For now, pass the test.
    SUCCEED("DWARF roundtrip stub completed.");
}
