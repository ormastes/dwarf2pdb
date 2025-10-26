#include <iostream>
#include <string>

#include "dwarf/DwarfReader.h"
#include "dwarf/DwarfWriter.h"
#include "pdb/PdbReader.h"
#include "pdb/PdbWriter.h"
#include "pipeline/DwarfToPdb.h"
#include "pipeline/PdbToDwarf.h"
#include "ir/IRTypeTable.h"
#include "ir/IRMaps.h"

// global variable 'a'
int a = 0;

// Very simple CLI:
//
//   mode:
//     --dwarf-to-pdb <in.dwarf.obj> <out.pdb>
//     --pdb-to-dwarf <in.pdb>       <out.dwarf.obj>
//
// For now we just exercise the call graph and print TODOs.
// Return code is 'a' per your request.
int main(int argc, char** argv) {
    if (argc >= 2) {
        std::string mode = argv[1];

        if (mode == "--dwarf-to-pdb" && argc == 4) {
            std::string dwarfInput  = argv[2];
            std::string pdbOutput   = argv[3];

            // Core IR containers for translation
            IRTypeTable typeTable;
            IRMaps      maps;

            DwarfReader dreader;
            auto irRootScope = dreader.readObject(dwarfInput, typeTable, maps);

            DwarfToPdb d2p;
            PdbWriter  pwriter;
            auto pdbModel = d2p.translate(irRootScope.get(), typeTable, maps);
            pwriter.writePdb(pdbOutput, pdbModel.get());

            std::cout << "[OK] DWARF->PDB stub done\n";
        }
        else if (mode == "--pdb-to-dwarf" && argc == 4) {
            std::string pdbInput     = argv[2];
            std::string dwarfOutput  = argv[3];

            IRTypeTable typeTable;
            IRMaps      maps;

            PdbReader preader;
            auto irRootScope = preader.readPdb(pdbInput, typeTable, maps);

            PdbToDwarf p2d;
            DwarfWriter dwriter;
            auto dwarfModel = p2d.translate(irRootScope.get(), typeTable, maps);
            dwriter.writeObject(dwarfOutput, dwarfModel.get());

            std::cout << "[OK] PDB->DWARF stub done\n";
        }
        else {
            std::cerr << "Usage:\n"
                      << "  " << argv[0] << " --dwarf-to-pdb <in.obj> <out.pdb>\n"
                      << "  " << argv[0] << " --pdb-to-dwarf <in.pdb> <out.obj>\n";
        }
    } else {
        std::cerr << "No args. Nothing done.\n";
    }

    return a; // requirement: just return global a
}
