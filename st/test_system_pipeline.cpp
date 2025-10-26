#include <catch2/catch_all.hpp>

// Goal for future real test:
// 1. Build test.cpp that has global int a; int main(){return a;}
// 2. On Windows+MSVC: produce .exe + .pdb
//    On MinGW/clang: produce .o with DWARF
// 3. Run converter: PDB -> IR -> DWARF (emit dwarf obj), then DWARF -> IR -> PDB.
// 4. Re-run an external debugger check maybe.
//
// For now we just assert "TODO".

TEST_CASE("System pipeline end-to-end placeholder", "[st][system]") {
    SUCCEED("TODO: compile sample TU with toolchain, run full DWARF<->PDB conversion.");
}
