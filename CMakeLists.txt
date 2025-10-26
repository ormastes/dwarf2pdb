cmake_minimum_required(VERSION 3.20)

# ============================================================================
# Compiler Setup - Use Clang64 as default if available
# ============================================================================
if(NOT DEFINED CMAKE_C_COMPILER AND NOT DEFINED CMAKE_CXX_COMPILER)
    set(CLANG64_DIR "${CMAKE_CURRENT_SOURCE_DIR}/tools/clang64")

    if(EXISTS "${CLANG64_DIR}/bin/clang.exe")
        message(STATUS "Using local MinGW Clang 64-bit compiler")
        set(CMAKE_C_COMPILER "${CLANG64_DIR}/bin/clang.exe" CACHE STRING "C compiler" FORCE)
        set(CMAKE_CXX_COMPILER "${CLANG64_DIR}/bin/clang++.exe" CACHE STRING "C++ compiler" FORCE)
        set(CMAKE_AR "${CLANG64_DIR}/bin/llvm-ar.exe" CACHE STRING "AR" FORCE)
        set(CMAKE_RANLIB "${CLANG64_DIR}/bin/llvm-ranlib.exe" CACHE STRING "RANLIB" FORCE)
    elseif(EXISTS "${CLANG64_DIR}/bin/clang")
        message(STATUS "Using local MinGW Clang 64-bit compiler")
        set(CMAKE_C_COMPILER "${CLANG64_DIR}/bin/clang" CACHE STRING "C compiler" FORCE)
        set(CMAKE_CXX_COMPILER "${CLANG64_DIR}/bin/clang++" CACHE STRING "C++ compiler" FORCE)
        set(CMAKE_AR "${CLANG64_DIR}/bin/llvm-ar" CACHE STRING "AR" FORCE)
        set(CMAKE_RANLIB "${CLANG64_DIR}/bin/llvm-ranlib" CACHE STRING "RANLIB" FORCE)
    else()
        message(STATUS "Clang64 not found, using system compiler")
        message(STATUS "To download Clang64: cmake -DDOWNLOAD_MINGW_CLANG64=ON ..")
    endif()
endif()

project(dwarf_pdb_converter
    VERSION 0.0.1
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================================
# Library and Tool Downloads
# ============================================================================
option(DOWNLOAD_LIBS "Download PDB and DWARF libraries" ON)

# Always include download script for tool downloads (MSVC, Clang64, GCC32, Catch2)
include(${CMAKE_CURRENT_SOURCE_DIR}/script/download_tool_libs.cmake)

# Main library sources (we'll build them into an OBJECT lib for reuse in tests)
add_library(converter_core OBJECT
    src/dwarf/DwarfNode.cpp
    src/dwarf/DwarfReader.cpp
    src/dwarf/DwarfWriter.cpp

    src/pdb/PdbNode.cpp
    src/pdb/PdbReader.cpp
    src/pdb/PdbWriter.cpp

    src/ir/IRNode.cpp
    src/ir/IRTypeTable.cpp
    src/ir/IRMaps.cpp

    src/pipeline/DwarfToPdb.cpp
    src/pipeline/PdbToDwarf.cpp

    src/util/Compare.cpp
)

target_include_directories(converter_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# The CLI executable that uses converter_core
add_executable(dwarf_pdb_converter
    src/main.cpp
)
target_link_libraries(dwarf_pdb_converter PRIVATE converter_core)

# ============================================================================
# Output Directory Configuration
# ============================================================================
# Set output directories for all targets
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# Create test output directory
set(TEST_OUTPUT_DIR ${CMAKE_BINARY_DIR}/test)
file(MAKE_DIRECTORY ${TEST_OUTPUT_DIR})

# -------- Catch2 setup --------
include(FetchContent)
FetchContent_Declare(
    catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG        v3.6.0
)
FetchContent_MakeAvailable(catch2)

# -------- Unit tests (ut) --------
add_executable(ut_tests
    ut/test_roundtrip_dwarf.cpp
    ut/test_roundtrip_pdb.cpp
)
target_link_libraries(ut_tests
    PRIVATE converter_core Catch2::Catch2WithMain
)
target_include_directories(ut_tests PRIVATE src)
set_target_properties(ut_tests PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${TEST_OUTPUT_DIR}
)

# -------- Integration tests (it) --------
add_executable(it_dwarf_tests
    it/dwarf/test_dwarf_integration.cpp
)
target_link_libraries(it_dwarf_tests
    PRIVATE converter_core Catch2::Catch2WithMain
)
target_include_directories(it_dwarf_tests PRIVATE src)
set_target_properties(it_dwarf_tests PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${TEST_OUTPUT_DIR}
)

add_executable(it_pdb_tests
    it/pdb/test_pdb_integration.cpp
)
target_link_libraries(it_pdb_tests
    PRIVATE converter_core Catch2::Catch2WithMain
)
target_include_directories(it_pdb_tests PRIVATE src)
set_target_properties(it_pdb_tests PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${TEST_OUTPUT_DIR}
)

# -------- System tests (st) --------
add_executable(st_tests
    st/test_system_pipeline.cpp
)
target_link_libraries(st_tests
    PRIVATE converter_core Catch2::Catch2WithMain
)
target_include_directories(st_tests PRIVATE src)
set_target_properties(st_tests PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${TEST_OUTPUT_DIR}
)

include(CTest)
include(Catch)
catch_discover_tests(ut_tests WORKING_DIRECTORY ${TEST_OUTPUT_DIR})
catch_discover_tests(it_dwarf_tests WORKING_DIRECTORY ${TEST_OUTPUT_DIR})
catch_discover_tests(it_pdb_tests WORKING_DIRECTORY ${TEST_OUTPUT_DIR})
catch_discover_tests(st_tests WORKING_DIRECTORY ${TEST_OUTPUT_DIR})

# Print configuration
message(STATUS "")
message(STATUS "=== dwarf_pdb_converter Configuration ===")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Download Libraries: ${DOWNLOAD_LIBS}")
message(STATUS "Build Directory: ${CMAKE_BINARY_DIR}")
message(STATUS "Test Output Directory: ${TEST_OUTPUT_DIR}")
message(STATUS "==========================================")
