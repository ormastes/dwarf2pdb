# Library Usage Examples

Quick reference for using the downloaded PDB and DWARF libraries in your code.

## PDB/CodeView Usage (LLVM)

### Reading PDB Files

```cpp
#include "llvm/DebugInfo/PDB/PDB.h"
#include "llvm/DebugInfo/PDB/IPDBSession.h"
#include "llvm/DebugInfo/PDB/PDBSymbolTypeFunctionSig.h"
#include "llvm/DebugInfo/PDB/PDBSymbolTypeUDT.h"
#include "llvm/DebugInfo/CodeView/TypeRecord.h"

using namespace llvm;
using namespace llvm::pdb;
using namespace llvm::codeview;

// Open a PDB file
std::unique_ptr<IPDBSession> session;
auto error = loadDataForPDB(PDB_ReaderType::Native, "path/to/file.pdb", session);
if (error) {
    // Handle error
    return;
}

// Get global scope
auto globalScope = session->getGlobalScope();

// Enumerate types
auto typeEnum = globalScope->findAllChildren<PDBSymbolTypeUDT>();
while (auto type = typeEnum->getNext()) {
    auto name = type->getName();
    auto size = type->getLength();
    // Process type...
}
```

### Writing PDB Files

```cpp
#include "llvm/DebugInfo/CodeView/TypeTableBuilder.h"
#include "llvm/DebugInfo/CodeView/TypeRecord.h"
#include "llvm/DebugInfo/MSF/MSFBuilder.h"

using namespace llvm;
using namespace llvm::codeview;
using namespace llvm::msf;

// Create type table builder
TypeTableBuilder typeTable(BAlloc);

// Add a struct type
FieldListRecordBuilder fieldList;
fieldList.addField(DataMemberRecord{
    MemberAccess::Public,
    TypeIndex::Int32(),
    /*offset=*/0,
    "field1"
});

TypeIndex fieldListIdx = typeTable.writeKnownType(fieldList);

ClassRecord classRec{
    /*memberCount=*/1,
    ClassOptions::None,
    fieldListIdx,
    TypeIndex::None(), // derived from
    TypeIndex::None(), // VTable shape
    /*size=*/4,
    "MyStruct",
    /*uniqueName=*/"MyStruct"
};

TypeIndex structIdx = typeTable.writeKnownType(classRec);
```

### Working with CodeView Type Records

```cpp
#include "llvm/DebugInfo/CodeView/CVTypeVisitor.h"
#include "llvm/DebugInfo/CodeView/TypeDeserializer.h"

using namespace llvm::codeview;

class MyTypeVisitor : public TypeVisitorCallbacks {
public:
    Error visitKnownRecord(CVType &record, ClassRecord &Class) override {
        // Handle struct/class
        std::string name = Class.getName();
        uint64_t size = Class.getSize();
        return Error::success();
    }

    Error visitKnownRecord(CVType &record, UnionRecord &Union) override {
        // Handle union
        return Error::success();
    }

    Error visitKnownRecord(CVType &record, ArrayRecord &Array) override {
        // Handle array
        return Error::success();
    }

    Error visitKnownRecord(CVType &record, PointerRecord &Pointer) override {
        // Handle pointer
        return Error::success();
    }
};

// Visit all types
MyTypeVisitor visitor;
CVTypeVisitor typeVisitor(visitor);
for (auto &typeRecord : typeStream) {
    typeVisitor.visitTypeRecord(typeRecord);
}
```

## DWARF Usage (libdwarf)

### Reading DWARF Information

```cpp
#include "libdwarf.h"
#include <iostream>

// Open DWARF file
Dwarf_Debug dbg = nullptr;
Dwarf_Error err = nullptr;
int fd = open("path/to/file.o", O_RDONLY);

int res = dwarf_init(fd, DW_DLC_READ, nullptr, nullptr, &dbg, &err);
if (res != DW_DLV_OK) {
    // Handle error
    return;
}

// Iterate through compilation units
Dwarf_Unsigned cu_header_length = 0;
Dwarf_Half version_stamp = 0;
Dwarf_Unsigned abbrev_offset = 0;
Dwarf_Half address_size = 0;
Dwarf_Unsigned next_cu_header = 0;

while (true) {
    Dwarf_Die cu_die = nullptr;

    res = dwarf_next_cu_header(dbg, &cu_header_length, &version_stamp,
                               &abbrev_offset, &address_size,
                               &next_cu_header, &err);

    if (res == DW_DLV_NO_ENTRY) break;
    if (res != DW_DLV_OK) {
        // Handle error
        break;
    }

    // Get CU DIE
    res = dwarf_siblingof(dbg, nullptr, &cu_die, &err);
    if (res == DW_DLV_OK) {
        // Process CU
        process_die(dbg, cu_die, 0);
        dwarf_dealloc(dbg, cu_die, DW_DLA_DIE);
    }
}

dwarf_finish(dbg, &err);
close(fd);
```

### Processing DIEs (Debug Information Entries)

```cpp
void process_die(Dwarf_Debug dbg, Dwarf_Die die, int level) {
    Dwarf_Error err = nullptr;
    Dwarf_Half tag = 0;

    // Get DIE tag
    if (dwarf_tag(die, &tag, &err) != DW_DLV_OK) {
        return;
    }

    // Process based on tag
    switch (tag) {
        case DW_TAG_structure_type:
        case DW_TAG_class_type:
            process_struct_type(dbg, die);
            break;

        case DW_TAG_union_type:
            process_union_type(dbg, die);
            break;

        case DW_TAG_array_type:
            process_array_type(dbg, die);
            break;

        case DW_TAG_pointer_type:
            process_pointer_type(dbg, die);
            break;

        case DW_TAG_member:
            process_member(dbg, die);
            break;
    }

    // Process children
    Dwarf_Die child = nullptr;
    if (dwarf_child(die, &child, &err) == DW_DLV_OK) {
        process_die(dbg, child, level + 1);
        dwarf_dealloc(dbg, child, DW_DLA_DIE);

        // Process siblings
        Dwarf_Die sibling = nullptr;
        while (dwarf_siblingof(dbg, child, &sibling, &err) == DW_DLV_OK) {
            process_die(dbg, sibling, level + 1);
            child = sibling;
        }
    }
}
```

### Reading DWARF Attributes

```cpp
void process_struct_type(Dwarf_Debug dbg, Dwarf_Die die) {
    Dwarf_Error err = nullptr;

    // Get name
    char *name = nullptr;
    if (dwarf_diename(die, &name, &err) == DW_DLV_OK) {
        std::cout << "Struct: " << name << std::endl;
        dwarf_dealloc(dbg, name, DW_DLA_STRING);
    }

    // Get byte size
    Dwarf_Attribute attr = nullptr;
    if (dwarf_attr(die, DW_AT_byte_size, &attr, &err) == DW_DLV_OK) {
        Dwarf_Unsigned size = 0;
        if (dwarf_formudata(attr, &size, &err) == DW_DLV_OK) {
            std::cout << "  Size: " << size << " bytes" << std::endl;
        }
        dwarf_dealloc(dbg, attr, DW_DLA_ATTR);
    }

    // Check if forward declaration
    if (dwarf_attr(die, DW_AT_declaration, &attr, &err) == DW_DLV_OK) {
        std::cout << "  (forward declaration)" << std::endl;
        dwarf_dealloc(dbg, attr, DW_DLA_ATTR);
    }
}

void process_member(Dwarf_Debug dbg, Dwarf_Die die) {
    Dwarf_Error err = nullptr;

    // Get member name
    char *name = nullptr;
    if (dwarf_diename(die, &name, &err) == DW_DLV_OK) {
        std::cout << "  Member: " << name << std::endl;
        dwarf_dealloc(dbg, name, DW_DLA_STRING);
    }

    // Get member location (offset)
    Dwarf_Attribute attr = nullptr;
    if (dwarf_attr(die, DW_AT_data_member_location, &attr, &err) == DW_DLV_OK) {
        Dwarf_Unsigned offset = 0;
        if (dwarf_formudata(attr, &offset, &err) == DW_DLV_OK) {
            std::cout << "    Offset: " << offset << std::endl;
        }
        dwarf_dealloc(dbg, attr, DW_DLA_ATTR);
    }

    // Get bit field information
    if (dwarf_attr(die, DW_AT_bit_size, &attr, &err) == DW_DLV_OK) {
        Dwarf_Unsigned bit_size = 0;
        if (dwarf_formudata(attr, &bit_size, &err) == DW_DLV_OK) {
            std::cout << "    Bit size: " << bit_size << std::endl;
        }
        dwarf_dealloc(dbg, attr, DW_DLA_ATTR);
    }

    if (dwarf_attr(die, DW_AT_bit_offset, &attr, &err) == DW_DLV_OK) {
        Dwarf_Unsigned bit_offset = 0;
        if (dwarf_formudata(attr, &bit_offset, &err) == DW_DLV_OK) {
            std::cout << "    Bit offset: " << bit_offset << std::endl;
        }
        dwarf_dealloc(dbg, attr, DW_DLA_ATTR);
    }
}
```

### Writing DWARF Information

```cpp
#include "libdwarf.h"

// Create producer
Dwarf_P_Debug dbg = nullptr;
Dwarf_Error err = nullptr;

dbg = dwarf_producer_init(
    DW_DLC_WRITE | DW_DLC_SIZE_64,
    callback_func,
    nullptr, // error handler
    nullptr, // error argument
    &err
);

// Add compilation unit
Dwarf_P_Die cu_die = dwarf_new_die(dbg, DW_TAG_compile_unit,
                                   nullptr, nullptr, nullptr, nullptr, &err);

// Add producer attribute
dwarf_add_AT_producer(cu_die, "My Compiler 1.0", &err);

// Add struct type
Dwarf_P_Die struct_die = dwarf_new_die(dbg, DW_TAG_structure_type,
                                       cu_die, nullptr, nullptr, nullptr, &err);

// Add name
dwarf_add_AT_name(struct_die, "MyStruct", &err);

// Add size
dwarf_add_AT_unsigned_const(dbg, struct_die, DW_AT_byte_size, 16, &err);

// Add member
Dwarf_P_Die member_die = dwarf_new_die(dbg, DW_TAG_member,
                                       struct_die, nullptr, nullptr, nullptr, &err);

dwarf_add_AT_name(member_die, "field1", &err);
dwarf_add_AT_data_member_location(dbg, member_die, 0, &err);

// Transform and write
Dwarf_Signed elf_section_count = 0;
dwarf_transform_to_disk_form(dbg, &elf_section_count, &err);

// ... write sections to file ...

dwarf_producer_finish(dbg, &err);
```

## Integration Example: DWARF to PDB Converter

```cpp
#include "llvm/DebugInfo/PDB/PDB.h"
#include "llvm/DebugInfo/CodeView/TypeTableBuilder.h"
#include "libdwarf.h"
#include <unordered_map>

class DwarfToPdbConverter {
private:
    Dwarf_Debug dwarfDbg;
    llvm::codeview::TypeTableBuilder pdbTypeTable;
    std::unordered_map<Dwarf_Off, llvm::codeview::TypeIndex> dwarfToPdbMap;

public:
    void convertStructType(Dwarf_Die dwarf_die) {
        Dwarf_Error err = nullptr;

        // Read DWARF struct info
        char *name = nullptr;
        dwarf_diename(dwarf_die, &name, &err);

        Dwarf_Attribute attr = nullptr;
        Dwarf_Unsigned size = 0;
        if (dwarf_attr(dwarf_die, DW_AT_byte_size, &attr, &err) == DW_DLV_OK) {
            dwarf_formudata(attr, &size, &err);
            dwarf_dealloc(dwarfDbg, attr, DW_DLA_ATTR);
        }

        // Convert to PDB
        llvm::codeview::FieldListRecordBuilder fieldList;

        // Process members (iterate children)
        Dwarf_Die child = nullptr;
        if (dwarf_child(dwarf_die, &child, &err) == DW_DLV_OK) {
            do {
                Dwarf_Half tag = 0;
                dwarf_tag(child, &tag, &err);

                if (tag == DW_TAG_member) {
                    convertMember(child, fieldList);
                }

                Dwarf_Die sibling = nullptr;
                if (dwarf_siblingof(dwarfDbg, child, &sibling, &err) != DW_DLV_OK) {
                    break;
                }
                child = sibling;
            } while (child);
        }

        // Build PDB struct record
        auto fieldListIdx = pdbTypeTable.writeKnownType(fieldList);

        llvm::codeview::ClassRecord classRec{
            /*memberCount=*/fieldList.size(),
            llvm::codeview::ClassOptions::None,
            fieldListIdx,
            llvm::codeview::TypeIndex::None(),
            llvm::codeview::TypeIndex::None(),
            static_cast<uint64_t>(size),
            name ? name : "",
            name ? name : ""
        };

        auto pdbTypeIdx = pdbTypeTable.writeKnownType(classRec);

        // Store mapping
        Dwarf_Off dieOffset = 0;
        dwarf_dieoffset(dwarf_die, &dieOffset, &err);
        dwarfToPdbMap[dieOffset] = pdbTypeIdx;

        if (name) {
            dwarf_dealloc(dwarfDbg, name, DW_DLA_STRING);
        }
    }

    void convertMember(Dwarf_Die member_die,
                      llvm::codeview::FieldListRecordBuilder& fieldList) {
        // Implementation similar to above examples
        // Read DWARF member info and add to PDB field list
    }
};
```

## Common Patterns

### Error Handling Pattern (DWARF)

```cpp
template<typename Func>
bool safe_dwarf_call(Func func, const char* operation) {
    Dwarf_Error err = nullptr;
    int res = func(&err);

    if (res != DW_DLV_OK) {
        if (res == DW_DLV_ERROR) {
            std::cerr << "DWARF error in " << operation << ": "
                     << dwarf_errmsg(err) << std::endl;
            dwarf_dealloc(dwarfDbg, err, DW_DLA_ERROR);
        }
        return false;
    }
    return true;
}
```

### Error Handling Pattern (LLVM PDB)

```cpp
template<typename T>
llvm::Expected<T> safe_pdb_operation(std::function<llvm::Expected<T>()> func) {
    auto result = func();
    if (!result) {
        llvm::errs() << "PDB error: " << toString(result.takeError()) << "\n";
        return result.takeError();
    }
    return result;
}
```

## Build Integration

In your CMakeLists.txt:

```cmake
add_executable(myconverter
    src/main.cpp
    src/converter.cpp
)

target_link_libraries(myconverter PRIVATE
    pdb_support    # Provides LLVM PDB libraries
    dwarf_support  # Provides libdwarf
)

# Platform-specific settings
if(WIN32)
    target_link_libraries(myconverter PRIVATE
        diaguids  # For DIA SDK on Windows
    )
endif()
```

## Further Reading

- [LLVM PDB Documentation](https://llvm.org/docs/PDB/)
- [libdwarf Documentation](https://www.prevanders.net/libdwarf.html)
- [DWARF Standard](http://dwarfstd.org/)
- [CodeView Type Records](https://llvm.org/docs/PDB/TpiStream.html)
