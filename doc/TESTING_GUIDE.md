# Testing Guide with Catch2

This guide explains how to write and run tests for the newDwarf2Pdb project using Catch2.

## Overview

The project uses [Catch2 v3](https://github.com/catchorg/Catch2) as the testing framework.

**Features:**
- Modern C++ testing framework
- Header-only usage option
- BDD-style test syntax
- Built-in matchers and assertions
- Test discovery and filtering
- Integrates with CTest/CDash

## Setup

### Download Catch2

Catch2 is downloaded automatically by default:

```bash
# Default: Catch2 enabled
cmake -B build

# Explicitly enable
cmake -DDOWNLOAD_CATCH2=ON -B build

# Disable if not needed
cmake -DDOWNLOAD_CATCH2=OFF -B build
```

**Location**: `lib/catch2/`
**Version**: 3.5.1

### Verify Installation

```bash
# Check Catch2 directory
ls lib/catch2/

# Should contain:
# - src/catch2/
# - CMakeLists.txt
# - LICENSE.txt
```

## Writing Tests

### Test File Structure

Create test files in `tests/` directory:

```
tests/
├── test_main.cpp           # Optional: custom main
├── test_ir_types.cpp       # IR type system tests
├── test_dwarf_reader.cpp   # DWARF reader tests
├── test_pdb_writer.cpp     # PDB writer tests
└── test_conversion.cpp     # End-to-end conversion tests
```

### Basic Test Example

**`tests/test_ir_types.cpp`:**

```cpp
#include <catch2/catch_test_macros.hpp>
#include "ir/IRTypeTable.h"
#include "ir/IRNode.h"

TEST_CASE("IRTypeTable creates unique types", "[ir][types]") {
    IRTypeTable table;

    SECTION("Create struct type") {
        IRType* type1 = table.createType(IRTypeKind::StructOrUnion);
        REQUIRE(type1 != nullptr);
        REQUIRE(type1->kind == IRTypeKind::StructOrUnion);
        REQUIRE(type1->id != 0);
    }

    SECTION("Create pointer type") {
        IRType* ptr = table.createType(IRTypeKind::Pointer);
        REQUIRE(ptr != nullptr);
        REQUIRE(ptr->kind == IRTypeKind::Pointer);
    }

    SECTION("Type IDs are unique") {
        IRType* type1 = table.createType(IRTypeKind::StructOrUnion);
        IRType* type2 = table.createType(IRTypeKind::StructOrUnion);
        REQUIRE(type1->id != type2->id);
    }
}

TEST_CASE("IRType fields can be added", "[ir][types]") {
    IRTypeTable table;
    IRType* structType = table.createType(IRTypeKind::StructOrUnion);

    IRField field;
    field.name = "myField";
    field.type = structType->id;
    field.byteOffset = 0;
    field.bitSize = 0;

    structType->fields.push_back(field);

    REQUIRE(structType->fields.size() == 1);
    REQUIRE(structType->fields[0].name == "myField");
}
```

### Using BDD Style

```cpp
#include <catch2/catch_test_macros.hpp>
#include "dwarf/DwarfReader.h"

SCENARIO("Reading DWARF structure types", "[dwarf][reader]") {
    GIVEN("A DWARF file with a struct definition") {
        DwarfReader reader;
        IRTypeTable typeTable;
        IRMaps maps;

        std::string testFile = "testdata/simple_struct.o";

        WHEN("The file is read") {
            auto rootScope = reader.readObject(testFile, typeTable, maps);

            THEN("The struct type should be in the type table") {
                REQUIRE(rootScope != nullptr);
                REQUIRE(rootScope->declaredTypes.size() > 0);
            }

            AND_THEN("The struct should have correct fields") {
                IRTypeID structId = rootScope->declaredTypes[0];
                IRType* structType = typeTable.lookup(structId);

                REQUIRE(structType != nullptr);
                REQUIRE(structType->kind == IRTypeKind::StructOrUnion);
                REQUIRE(structType->fields.size() == 2);
            }
        }
    }
}
```

### Matchers and Assertions

```cpp
#include <catch2/catch_test_macros.hpp>
#include <catch2/matchers/catch_matchers_string.hpp>
#include <catch2/matchers/catch_matchers_vector.hpp>

using Catch::Matchers::StartsWith;
using Catch::Matchers::EndsWith;
using Catch::Matchers::Contains;

TEST_CASE("Type names are formatted correctly", "[ir][names]") {
    IRType type;
    type.name = "struct Node";

    // String matchers
    REQUIRE_THAT(type.name, StartsWith("struct"));
    REQUIRE_THAT(type.name, EndsWith("Node"));
    REQUIRE_THAT(type.name, Contains(" "));
}

TEST_CASE("Field list matching", "[ir][fields]") {
    IRType type;
    type.fields.push_back(IRField{"field1", 1, 0, 0, 0, false});
    type.fields.push_back(IRField{"field2", 2, 4, 0, 0, false});

    std::vector<std::string> fieldNames;
    for (const auto& f : type.fields) {
        fieldNames.push_back(f.name);
    }

    REQUIRE_THAT(fieldNames, Contains(std::vector<std::string>{"field1", "field2"}));
}
```

### Testing Exceptions

```cpp
#include <catch2/catch_test_macros.hpp>
#include "pdb/PdbReader.h"

TEST_CASE("PdbReader throws on invalid file", "[pdb][reader]") {
    PdbReader reader;
    IRTypeTable typeTable;
    IRMaps maps;

    REQUIRE_THROWS(reader.readPdb("nonexistent.pdb", typeTable, maps));
    REQUIRE_THROWS_AS(reader.readPdb("invalid.pdb", typeTable, maps),
                      std::runtime_error);
    REQUIRE_THROWS_WITH(reader.readPdb("bad.pdb", typeTable, maps),
                        "Failed to open PDB file");
}
```

### Parameterized Tests

```cpp
#include <catch2/catch_test_macros.hpp>
#include <catch2/generators/catch_generators.hpp>

TEST_CASE("IRTypeKind values are distinct", "[ir][types]") {
    auto kind = GENERATE(
        IRTypeKind::StructOrUnion,
        IRTypeKind::Array,
        IRTypeKind::Pointer,
        IRTypeKind::Unknown
    );

    IRTypeTable table;
    IRType* type = table.createType(kind);

    REQUIRE(type->kind == kind);
}

TEST_CASE("Bitfield sizes", "[ir][bitfields]") {
    auto bitSize = GENERATE(1, 2, 4, 8, 16, 32);

    IRField field;
    field.bitSize = bitSize;

    REQUIRE(field.bitSize == bitSize);
    REQUIRE(field.bitSize > 0);
    REQUIRE(field.bitSize <= 32);
}
```

## Building and Running Tests

### Enable Testing

Uncomment the test section in `CMakeLists.txt`:

```cmake
if(CATCH2_AVAILABLE)
    enable_testing()

    add_executable(tests
        tests/test_ir_types.cpp
        tests/test_dwarf_reader.cpp
        tests/test_pdb_writer.cpp
    )

    target_link_libraries(tests PRIVATE
        Catch2::Catch2WithMain
        pdb_support
        dwarf_support
    )

    target_include_directories(tests PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
    )

    include(CTest)
    include(Catch)
    catch_discover_tests(tests)
endif()
```

### Build Tests

```bash
# Configure with tests enabled
cmake -DDOWNLOAD_CATCH2=ON -B build

# Build tests
cmake --build build --target tests

# Or with Make/Ninja
ninja -C build tests
nmake tests
```

### Run Tests

```bash
# Run all tests
cd build
ctest

# Or run test executable directly
./tests

# Run with verbose output
ctest -V
./tests -v

# Run specific test
./tests "IRTypeTable creates unique types"

# Run tests with tag
./tests [ir]
./tests [dwarf][reader]

# List all tests
./tests --list-tests

# List all tags
./tests --list-tags
```

### CTest Integration

```bash
# Run tests with CTest
ctest

# Verbose output
ctest -V

# Run specific test
ctest -R test_ir_types

# Parallel testing
ctest -j8

# Stop on first failure
ctest --stop-on-failure

# Generate XML report
ctest -T Test --output-on-failure
```

## Test Organization

### By Module

```cpp
// tests/test_ir_types.cpp
TEST_CASE("IR tests", "[ir]") { /* ... */ }

// tests/test_dwarf_reader.cpp
TEST_CASE("DWARF reader tests", "[dwarf][reader]") { /* ... */ }

// tests/test_pdb_writer.cpp
TEST_CASE("PDB writer tests", "[pdb][writer]") { /* ... */ }
```

Run specific module:
```bash
./tests [ir]        # Run IR tests only
./tests [dwarf]     # Run DWARF tests only
./tests [pdb]       # Run PDB tests only
```

### By Feature

```cpp
TEST_CASE("Struct conversion", "[conversion][struct]") { /* ... */ }
TEST_CASE("Union conversion", "[conversion][union]") { /* ... */ }
TEST_CASE("Array conversion", "[conversion][array]") { /* ... */ }
```

Run feature tests:
```bash
./tests [conversion]       # All conversion tests
./tests [conversion][struct]  # Struct conversion only
```

### Integration Tests

```cpp
// tests/test_integration.cpp
TEST_CASE("End-to-end DWARF to PDB", "[integration][e2e]") {
    // Load DWARF
    DwarfReader dreader;
    IRTypeTable typeTable;
    IRMaps maps;
    auto irScope = dreader.readObject("test.o", typeTable, maps);

    // Convert to PDB
    DwarfToPdb converter;
    PdbWriter pwriter;
    auto pdbModel = converter.translate(irScope.get(), typeTable, maps);
    pwriter.writePdb("output.pdb", pdbModel.get());

    // Verify PDB was created
    REQUIRE(std::filesystem::exists("output.pdb"));
}
```

## Advanced Testing

### Custom Main

If you need custom setup/teardown, create `tests/test_main.cpp`:

```cpp
#define CATCH_CONFIG_RUNNER
#include <catch2/catch_session.hpp>

int main(int argc, char* argv[]) {
    // Global setup
    std::cout << "Starting tests...\n";

    int result = Catch::Session().run(argc, argv);

    // Global teardown
    std::cout << "Tests complete.\n";

    return result;
}
```

Then update CMakeLists.txt:
```cmake
add_executable(tests
    tests/test_main.cpp  # Custom main
    tests/test_ir_types.cpp
    # ... other test files
)

target_link_libraries(tests PRIVATE
    Catch2::Catch2  # Not Catch2WithMain!
    pdb_support
    dwarf_support
)
```

### Fixtures

```cpp
#include <catch2/catch_test_macros.hpp>

struct TypeTableFixture {
    IRTypeTable table;

    TypeTableFixture() {
        // Setup
        std::cout << "Setting up type table\n";
    }

    ~TypeTableFixture() {
        // Teardown
        std::cout << "Cleaning up type table\n";
    }
};

TEST_CASE_METHOD(TypeTableFixture, "Test with fixture", "[ir]") {
    auto type = table.createType(IRTypeKind::StructOrUnion);
    REQUIRE(type != nullptr);
}
```

### Benchmarking

```cpp
#include <catch2/catch_test_macros.hpp>
#include <catch2/benchmark/catch_benchmark.hpp>

TEST_CASE("Type creation performance", "[.][benchmark]") {
    IRTypeTable table;

    BENCHMARK("Create struct type") {
        return table.createType(IRTypeKind::StructOrUnion);
    };

    BENCHMARK("Create and lookup") {
        auto type = table.createType(IRTypeKind::Pointer);
        return table.lookup(type->id);
    };
}
```

Run benchmarks:
```bash
./tests [.][benchmark]
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure
        run: cmake -DDOWNLOAD_CATCH2=ON -B build

      - name: Build
        run: cmake --build build --target tests

      - name: Run Tests
        run: |
          cd build
          ctest --output-on-failure
```

### Test Coverage

With Clang64:
```bash
setup_clang64_env.bat

cmake -DCMAKE_CXX_FLAGS="--coverage" \
      -DCMAKE_BUILD_TYPE=Debug \
      -B build-coverage

cmake --build build-coverage --target tests
./build-coverage/tests

# Generate coverage report
llvm-profdata merge default.profraw -o tests.profdata
llvm-cov show ./build-coverage/tests -instr-profile=tests.profdata
```

## Best Practices

1. **One assertion per test** (when possible)
2. **Use descriptive test names**
3. **Tag tests appropriately** for easy filtering
4. **Keep tests fast** - mock slow operations
5. **Test edge cases** - null pointers, empty containers, etc.
6. **Use fixtures** for common setup
7. **Don't test implementation details** - test behavior
8. **Run tests often** during development

## Troubleshooting

### Catch2 not found

```bash
# Check installation
ls lib/catch2/

# Re-download
rm -rf lib/catch2
cmake -DDOWNLOAD_CATCH2=ON -B build
```

### Tests don't run

```bash
# Check if tests were built
ls build/tests.exe

# Enable testing in CMakeLists.txt
# Uncomment the testing section

# Rebuild
cmake --build build --target tests
```

### Linker errors

```bash
# Make sure you're linking Catch2
target_link_libraries(tests PRIVATE
    Catch2::Catch2WithMain  # Or Catch2::Catch2 if custom main
)
```

## References

- [Catch2 Documentation](https://github.com/catchorg/Catch2/tree/devel/docs)
- [Catch2 Tutorial](https://github.com/catchorg/Catch2/blob/devel/docs/tutorial.md)
- [Assertion Macros](https://github.com/catchorg/Catch2/blob/devel/docs/assertions.md)
- [Test Cases and Sections](https://github.com/catchorg/Catch2/blob/devel/docs/test-cases-and-sections.md)
