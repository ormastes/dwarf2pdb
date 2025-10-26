#include <catch2/catch_all.hpp>
#include "pdb/PdbReader.h"
#include "pdb/PdbWriter.h"
#include "pipeline/DwarfToPdb.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

TEST_CASE("PDB integration pipeline stub", "[it][pdb]") {
    PdbNode startModel;
    startModel.leafKind = 0x2222;
    startModel.prettyName = "IntegrationPdb";
    startModel.uniqueName = "??_Integration";
    startModel.typeIndexOrSymOffset = 0x1000;

    IRTypeTable typeTable;
    IRMaps maps;
    PdbReader preader;
    auto irRoot = preader.readFromModel(startModel, typeTable, maps);

    REQUIRE(irRoot);

    DwarfToPdb d2p;
    auto pdbModelOut = d2p.translate(irRoot.get(), typeTable, maps);

    REQUIRE(pdbModelOut);

    PdbWriter pwriter;
    pwriter.writePdb("tmp_out.pdb", pdbModelOut.get());

    // future:
    // auto irRoot2 = preader.readPdb("tmp_out.pdb", typeTable2, maps2);
    // CHECK(EqualPdbNode(reParsed, pdbModelOut.get()));

    SUCCEED("PDB integration pipeline (stubbed IO) executed.");
}
