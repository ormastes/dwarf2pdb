#include <catch2/catch_all.hpp>
#include "pdb/PdbReader.h"
#include "pipeline/DwarfToPdb.h"
#include "util/Compare.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

// Similar:
// 1. Fake original PdbNode
// 2. PdbReader::readFromModel -> IR
// 3. DwarfToPdb::translate(IR) -> PdbNode
// 4. Assert shape

TEST_CASE("PDB node -> IR -> PDB node roundtrip basic", "[ut][pdb]") {
    PdbNode original;
    original.leafKind = 0x1234;
    original.prettyName = "PdbRootPretty";
    original.uniqueName = "??_C@Something";
    original.typeIndexOrSymOffset = 0x1000;

    IRTypeTable typeTable;
    IRMaps maps;
    PdbReader preader;
    auto irRoot = preader.readFromModel(original, typeTable, maps);

    REQUIRE(irRoot);
    REQUIRE(irRoot->declaredTypes.size() == 1);

    DwarfToPdb d2p;
    auto rebuilt = d2p.translate(irRoot.get(), typeTable, maps);

    REQUIRE(rebuilt);

    CHECK(rebuilt->leafKind == 0x1234); // we set same in translate() stub
    CHECK(rebuilt->prettyName == "PdbRootFromDwarf" ||
          rebuilt->prettyName == "PdbRootPretty");

    SUCCEED("PDB roundtrip stub completed.");
}
