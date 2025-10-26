# download_tool_libs.cmake
# Downloads MS PDB and DWARF5 read/generation libraries

cmake_minimum_required(VERSION 3.14)

include(FetchContent)

# Set base directories for libraries and tools
set(PDB_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/pdb_lib" CACHE PATH "Directory for PDB libraries")
set(DWARF_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/dwarf_lib" CACHE PATH "Directory for DWARF libraries")
set(LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/lib" CACHE PATH "Directory for additional libraries")
set(TOOLS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/tools" CACHE PATH "Directory for tools")
set(MSVC_TOOLS_DIR "${TOOLS_DIR}/msvc" CACHE PATH "Directory for MSVC Build Tools")
set(CLANG64_DIR "${TOOLS_DIR}/clang64" CACHE PATH "Directory for MinGW Clang 64-bit")
set(GCC32_DIR "${TOOLS_DIR}/gcc32" CACHE PATH "Directory for MinGW GCC 32-bit")
set(CATCH2_DIR "${LIB_DIR}/catch2" CACHE PATH "Directory for Catch2 testing framework")

# Options to download tools and libraries
option(DOWNLOAD_MSVC "Download and install MSVC Build Tools" OFF)
option(DOWNLOAD_MINGW_CLANG64 "Download MinGW with Clang 64-bit" OFF)
option(DOWNLOAD_MINGW_GCC32 "Download MinGW with GCC 32-bit" OFF)
option(DOWNLOAD_CATCH2 "Download Catch2 testing framework" ON)

# Create directories if they don't exist
file(MAKE_DIRECTORY ${PDB_LIB_DIR})
file(MAKE_DIRECTORY ${DWARF_LIB_DIR})
file(MAKE_DIRECTORY ${LIB_DIR})
file(MAKE_DIRECTORY ${TOOLS_DIR})

message(STATUS "=== Downloading Debug Information Libraries ===")

# ============================================================================
# 1. Download LLVM Project (for PDB support via llvm-pdbutil and CodeView)
# ============================================================================
message(STATUS "Downloading LLVM (for PDB/CodeView support)...")

FetchContent_Declare(
    llvm_project
    GIT_REPOSITORY https://github.com/llvm/llvm-project.git
    GIT_TAG        llvmorg-17.0.6
    GIT_SHALLOW    TRUE
    SOURCE_DIR     ${PDB_LIB_DIR}/llvm-project
)

set(LLVM_ENABLE_PROJECTS "llvm" CACHE STRING "LLVM projects to build")
set(LLVM_TARGETS_TO_BUILD "X86" CACHE STRING "LLVM targets")
set(LLVM_INCLUDE_TESTS OFF CACHE BOOL "Include LLVM tests")
set(LLVM_INCLUDE_EXAMPLES OFF CACHE BOOL "Include LLVM examples")
set(LLVM_INCLUDE_BENCHMARKS OFF CACHE BOOL "Include LLVM benchmarks")
set(LLVM_BUILD_TOOLS ON CACHE BOOL "Build LLVM tools")

FetchContent_MakeAvailable(llvm_project)

message(STATUS "LLVM downloaded to: ${PDB_LIB_DIR}/llvm-project")

# ============================================================================
# 2. Download libdwarf (for DWARF5 support)
# ============================================================================
message(STATUS "Downloading libdwarf (for DWARF5 support)...")

FetchContent_Declare(
    libdwarf
    GIT_REPOSITORY https://github.com/davea42/libdwarf-code.git
    GIT_TAG        v0.9.2
    GIT_SHALLOW    TRUE
    SOURCE_DIR     ${DWARF_LIB_DIR}/libdwarf
)

set(BUILD_SHARED OFF CACHE BOOL "Build shared libdwarf")
set(BUILD_NON_SHARED ON CACHE BOOL "Build static libdwarf")
set(BUILD_DWARFDUMP ON CACHE BOOL "Build dwarfdump tool")
set(BUILD_DWARFGEN OFF CACHE BOOL "Build dwarfgen tool")
set(BUILD_DWARFEXAMPLE OFF CACHE BOOL "Build examples")

FetchContent_MakeAvailable(libdwarf)

message(STATUS "libdwarf downloaded to: ${DWARF_LIB_DIR}/libdwarf")

# ============================================================================
# 3. Optional: Download Microsoft's Debug Interface Access SDK headers
# ============================================================================
message(STATUS "Downloading Microsoft DIA SDK headers...")

FetchContent_Declare(
    dia_sdk_headers
    URL            https://raw.githubusercontent.com/microsoft/microsoft-pdb/master/include/cvinfo.h
    DOWNLOAD_NO_EXTRACT TRUE
    DOWNLOAD_DIR   ${PDB_LIB_DIR}/dia_headers
)

# For DIA, we also need to reference the Windows SDK
# DIA is typically installed with Visual Studio
if(WIN32)
    message(STATUS "On Windows: DIA SDK should be available via Visual Studio installation")
    message(STATUS "Typical location: C:/Program Files (x86)/Microsoft Visual Studio/*/DIA SDK/")

    # Try to find DIA SDK
    find_path(DIA_SDK_DIR
        NAMES include/dia2.h
        PATHS
            "C:/Program Files (x86)/Microsoft Visual Studio/2022/*/DIA SDK"
            "C:/Program Files (x86)/Microsoft Visual Studio/2019/*/DIA SDK"
            "C:/Program Files/Microsoft Visual Studio/2022/*/DIA SDK"
            "C:/Program Files/Microsoft Visual Studio/2019/*/DIA SDK"
            ENV VSINSTALLDIR
        PATH_SUFFIXES "DIA SDK"
    )

    if(DIA_SDK_DIR)
        message(STATUS "Found DIA SDK at: ${DIA_SDK_DIR}")
        set(DIA_INCLUDE_DIR "${DIA_SDK_DIR}/include" CACHE PATH "DIA SDK include directory")
        set(DIA_LIB_DIR "${DIA_SDK_DIR}/lib/amd64" CACHE PATH "DIA SDK library directory")
    else()
        message(WARNING "DIA SDK not found. You may need to install Visual Studio with C++ tools.")
    endif()
endif()

# ============================================================================
# 4. Download additional PDB utilities and documentation
# ============================================================================
message(STATUS "Downloading PDB format specifications...")

# Download Microsoft PDB format repository for reference
FetchContent_Declare(
    microsoft_pdb
    GIT_REPOSITORY https://github.com/microsoft/microsoft-pdb.git
    GIT_SHALLOW    TRUE
    SOURCE_DIR     ${PDB_LIB_DIR}/microsoft-pdb
)

FetchContent_MakeAvailable(microsoft_pdb)

message(STATUS "Microsoft PDB format specs downloaded to: ${PDB_LIB_DIR}/microsoft-pdb")

# ============================================================================
# 5. Download and Install MSVC Build Tools (Windows only)
# ============================================================================
if(WIN32 AND DOWNLOAD_MSVC)
    message(STATUS "")
    message(STATUS "=== Downloading MSVC Build Tools ===")

    set(MSVC_INSTALLER_URL "https://aka.ms/vs/17/release/vs_buildtools.exe")
    set(MSVC_INSTALLER "${CMAKE_CURRENT_BINARY_DIR}/vs_buildtools.exe")
    set(MSVC_INSTALL_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/install_msvc.bat")

    # Download the Build Tools installer
    if(NOT EXISTS ${MSVC_INSTALLER})
        message(STATUS "Downloading Visual Studio Build Tools installer...")
        file(DOWNLOAD ${MSVC_INSTALLER_URL} ${MSVC_INSTALLER}
             SHOW_PROGRESS
             STATUS download_status
             TIMEOUT 300)

        list(GET download_status 0 status_code)
        if(NOT status_code EQUAL 0)
            message(WARNING "Failed to download MSVC Build Tools installer")
            set(DOWNLOAD_MSVC OFF)
        else()
            message(STATUS "Downloaded Build Tools installer to: ${MSVC_INSTALLER}")
        endif()
    else()
        message(STATUS "Build Tools installer already exists: ${MSVC_INSTALLER}")
    endif()

    # Create installation script
    if(EXISTS ${MSVC_INSTALLER})
        message(STATUS "Creating MSVC installation script...")

        file(WRITE ${MSVC_INSTALL_SCRIPT} "@echo off\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "REM MSVC Build Tools Installation Script\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "REM This script installs MSVC Build Tools to ${MSVC_TOOLS_DIR}\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo ============================================\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo Installing MSVC Build Tools\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo ============================================\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo.\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo Installation directory: ${MSVC_TOOLS_DIR}\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo.\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo This will install:\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo   - MSVC C++ Compiler\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo   - Windows SDK\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo   - CMake\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo.\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo Press any key to continue or Ctrl+C to cancel...\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "pause >nul\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "\"${MSVC_INSTALLER}\" ^\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "  --installPath \"${MSVC_TOOLS_DIR}\" ^\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "  --add Microsoft.VisualStudio.Workload.VCTools ^\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "  --add Microsoft.VisualStudio.Component.Windows11SDK.22621 ^\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "  --add Microsoft.VisualStudio.Component.VC.CMake.Project ^\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "  --passive --wait --norestart\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "if errorlevel 1 (\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "    echo.\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "    echo Installation failed!\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "    exit /b 1\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} ")\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo.\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo ============================================\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo Installation complete!\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo ============================================\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo.\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo To use MSVC, run:\n")
        file(APPEND ${MSVC_INSTALL_SCRIPT} "echo   ${MSVC_TOOLS_DIR}\\VC\\Auxiliary\\Build\\vcvars64.bat\n")

        message(STATUS "")
        message(STATUS "================================================================")
        message(STATUS "MSVC Build Tools installer downloaded!")
        message(STATUS "")
        message(STATUS "To install MSVC to tools/msvc/, run:")
        message(STATUS "  ${MSVC_INSTALL_SCRIPT}")
        message(STATUS "")
        message(STATUS "Or install manually with custom options:")
        message(STATUS "  ${MSVC_INSTALLER} --help")
        message(STATUS "================================================================")
    endif()

elseif(WIN32 AND NOT DOWNLOAD_MSVC)
    message(STATUS "")
    message(STATUS "MSVC Build Tools download disabled.")
    message(STATUS "To enable, run: cmake -DDOWNLOAD_MSVC=ON ..")

    # Check if MSVC is already installed in tools/msvc
    if(EXISTS "${MSVC_TOOLS_DIR}/VC/Auxiliary/Build/vcvars64.bat")
        message(STATUS "Found existing MSVC installation at: ${MSVC_TOOLS_DIR}")
        set(MSVC_AVAILABLE TRUE)
    else()
        # Try to find system MSVC
        find_program(MSVC_CL cl.exe)
        if(MSVC_CL)
            message(STATUS "Using system MSVC: ${MSVC_CL}")
            set(MSVC_AVAILABLE TRUE)
        endif()
    endif()
endif()

# ============================================================================
# 6. Download MinGW Clang 64-bit (Windows/Cross-platform)
# ============================================================================
if(DOWNLOAD_MINGW_CLANG64)
    message(STATUS "")
    message(STATUS "=== Downloading MinGW Clang 64-bit ===")

    # Using LLVM MinGW distribution (best maintained)
    set(MINGW_CLANG64_VERSION "20240917")
    set(MINGW_CLANG64_ARCH "x86_64")
    set(MINGW_CLANG64_URL "https://github.com/mstorsjo/llvm-mingw/releases/download/${MINGW_CLANG64_VERSION}/llvm-mingw-${MINGW_CLANG64_VERSION}-ucrt-${MINGW_CLANG64_ARCH}.zip")
    set(MINGW_CLANG64_ARCHIVE "${CMAKE_CURRENT_BINARY_DIR}/llvm-mingw-clang64.zip")

    if(NOT EXISTS "${CLANG64_DIR}/bin/clang.exe" AND NOT EXISTS "${CLANG64_DIR}/bin/clang")
        message(STATUS "Downloading MinGW Clang 64-bit from ${MINGW_CLANG64_URL}")
        file(DOWNLOAD ${MINGW_CLANG64_URL} ${MINGW_CLANG64_ARCHIVE}
             SHOW_PROGRESS
             STATUS download_status
             TIMEOUT 600)

        list(GET download_status 0 status_code)
        if(NOT status_code EQUAL 0)
            message(WARNING "Failed to download MinGW Clang 64-bit")
        else()
            message(STATUS "Extracting MinGW Clang 64-bit to ${CLANG64_DIR}...")
            file(ARCHIVE_EXTRACT INPUT ${MINGW_CLANG64_ARCHIVE}
                 DESTINATION ${TOOLS_DIR})

            # Rename extracted directory to clang64
            file(GLOB EXTRACTED_DIR "${TOOLS_DIR}/llvm-mingw-*")
            if(EXTRACTED_DIR)
                file(RENAME ${EXTRACTED_DIR} ${CLANG64_DIR})
            endif()

            message(STATUS "MinGW Clang 64-bit installed to: ${CLANG64_DIR}")
            message(STATUS "  Compiler: ${CLANG64_DIR}/bin/clang.exe")
            message(STATUS "  C++ Compiler: ${CLANG64_DIR}/bin/clang++.exe")
            set(CLANG64_AVAILABLE TRUE CACHE BOOL "MinGW Clang 64-bit available")
        endif()
    else()
        message(STATUS "MinGW Clang 64-bit already installed at: ${CLANG64_DIR}")
        set(CLANG64_AVAILABLE TRUE CACHE BOOL "MinGW Clang 64-bit available")
    endif()
else()
    if(EXISTS "${CLANG64_DIR}/bin/clang.exe" OR EXISTS "${CLANG64_DIR}/bin/clang")
        message(STATUS "Found existing MinGW Clang 64-bit at: ${CLANG64_DIR}")
        set(CLANG64_AVAILABLE TRUE CACHE BOOL "MinGW Clang 64-bit available")
    endif()
endif()

# ============================================================================
# 7. Download MinGW GCC 32-bit (Windows)
# ============================================================================
if(DOWNLOAD_MINGW_GCC32)
    message(STATUS "")
    message(STATUS "=== Downloading MinGW GCC 32-bit ===")

    # Using WinLibs standalone MinGW-w64+GCC builds
    set(MINGW_GCC32_VERSION "13.2.0")
    set(MINGW_GCC32_RT_VERSION "11.0.1")
    # Use SourceForge mirror as backup (more reliable)
    set(MINGW_GCC32_URL "https://github.com/brechtsanders/winlibs_mingw/releases/download/13.2.0-16.0.6-11.0.1-ucrt-r1/winlibs-i686-posix-dwarf-gcc-13.2.0-llvm-16.0.6-mingw-w64ucrt-11.0.1-r1.zip")
    set(MINGW_GCC32_ARCHIVE "${CMAKE_CURRENT_BINARY_DIR}/mingw-gcc32.zip")

    if(NOT EXISTS "${GCC32_DIR}/bin/gcc.exe" AND NOT EXISTS "${GCC32_DIR}/bin/gcc")
        # Remove failed download if exists
        if(EXISTS ${MINGW_GCC32_ARCHIVE})
            file(SIZE ${MINGW_GCC32_ARCHIVE} archive_size)
            if(archive_size EQUAL 0)
                file(REMOVE ${MINGW_GCC32_ARCHIVE})
                message(STATUS "Removed failed download, retrying...")
            endif()
        endif()

        message(STATUS "Downloading MinGW GCC 32-bit from ${MINGW_GCC32_URL}")
        message(STATUS "This may take 5-10 minutes (file is ~250 MB)...")
        file(DOWNLOAD ${MINGW_GCC32_URL} ${MINGW_GCC32_ARCHIVE}
             SHOW_PROGRESS
             STATUS download_status
             TIMEOUT 1200
             TLS_VERIFY ON)

        list(GET download_status 0 status_code)
        if(NOT status_code EQUAL 0)
            message(WARNING "Failed to download MinGW GCC 32-bit")
        else()
            message(STATUS "Extracting MinGW GCC 32-bit to ${GCC32_DIR}...")
            file(ARCHIVE_EXTRACT INPUT ${MINGW_GCC32_ARCHIVE}
                 DESTINATION ${TOOLS_DIR})

            # Rename extracted directory to gcc32
            file(GLOB EXTRACTED_DIR "${TOOLS_DIR}/mingw*")
            if(EXTRACTED_DIR)
                file(RENAME ${EXTRACTED_DIR} ${GCC32_DIR})
            endif()

            message(STATUS "MinGW GCC 32-bit installed to: ${GCC32_DIR}")
            message(STATUS "  Compiler: ${GCC32_DIR}/bin/gcc.exe")
            message(STATUS "  C++ Compiler: ${GCC32_DIR}/bin/g++.exe")
            set(GCC32_AVAILABLE TRUE CACHE BOOL "MinGW GCC 32-bit available")
        endif()
    else()
        message(STATUS "MinGW GCC 32-bit already installed at: ${GCC32_DIR}")
        set(GCC32_AVAILABLE TRUE CACHE BOOL "MinGW GCC 32-bit available")
    endif()
else()
    if(EXISTS "${GCC32_DIR}/bin/gcc.exe" OR EXISTS "${GCC32_DIR}/bin/gcc")
        message(STATUS "Found existing MinGW GCC 32-bit at: ${GCC32_DIR}")
        set(GCC32_AVAILABLE TRUE CACHE BOOL "MinGW GCC 32-bit available")
    endif()
endif()

# ============================================================================
# 8. Download Catch2 Testing Framework
# ============================================================================
if(DOWNLOAD_CATCH2)
    message(STATUS "")
    message(STATUS "=== Downloading Catch2 Testing Framework ===")

    FetchContent_Declare(
        Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG        v3.5.1
        GIT_SHALLOW    TRUE
        SOURCE_DIR     ${CATCH2_DIR}
    )

    # Don't build tests and examples for Catch2 itself
    set(CATCH_BUILD_TESTING OFF CACHE BOOL "Build Catch2 tests")
    set(CATCH_BUILD_EXAMPLES OFF CACHE BOOL "Build Catch2 examples")
    set(CATCH_BUILD_EXTRA_TESTS OFF CACHE BOOL "Build Catch2 extra tests")
    set(CATCH_INSTALL_DOCS OFF CACHE BOOL "Install Catch2 docs")

    FetchContent_MakeAvailable(Catch2)

    message(STATUS "Catch2 downloaded to: ${CATCH2_DIR}")
    set(CATCH2_AVAILABLE TRUE CACHE BOOL "Catch2 available")
else()
    # Try to find Catch2 if not downloading
    find_package(Catch2 3 QUIET)
    if(Catch2_FOUND)
        message(STATUS "Using system Catch2")
        set(CATCH2_AVAILABLE TRUE CACHE BOOL "Catch2 available")
    elseif(EXISTS "${CATCH2_DIR}/src/catch2/catch_all.hpp")
        message(STATUS "Found existing Catch2 at: ${CATCH2_DIR}")
        set(CATCH2_AVAILABLE TRUE CACHE BOOL "Catch2 available")
    endif()
endif()

# ============================================================================
# 9. Set up interface targets for easy linking
# ============================================================================

# Create interface library for PDB support (using LLVM)
add_library(pdb_support INTERFACE)
target_include_directories(pdb_support INTERFACE
    ${PDB_LIB_DIR}/llvm-project/llvm/include
    ${PDB_LIB_DIR}/microsoft-pdb/include
)
if(DIA_INCLUDE_DIR)
    target_include_directories(pdb_support INTERFACE ${DIA_INCLUDE_DIR})
endif()

target_link_libraries(pdb_support INTERFACE
    LLVMDebugInfoPDB
    LLVMDebugInfoCodeView
    LLVMDebugInfoMSF
)

# Create interface library for DWARF support
add_library(dwarf_support INTERFACE)
target_include_directories(dwarf_support INTERFACE
    ${DWARF_LIB_DIR}/libdwarf/src/lib/libdwarf
)
target_link_libraries(dwarf_support INTERFACE
    dwarf
)

# ============================================================================
# Summary
# ============================================================================
message(STATUS "")
message(STATUS "=== Library and Tool Download Summary ===")
message(STATUS "")
message(STATUS "Debug Libraries:")
message(STATUS "  - LLVM PDB/CodeView: ${PDB_LIB_DIR}/llvm-project")
message(STATUS "  - Microsoft PDB specs: ${PDB_LIB_DIR}/microsoft-pdb")
if(DIA_SDK_DIR)
    message(STATUS "  - DIA SDK: ${DIA_SDK_DIR}")
endif()
message(STATUS "  - libdwarf: ${DWARF_LIB_DIR}/libdwarf")
message(STATUS "")
message(STATUS "Testing Framework:")
if(CATCH2_AVAILABLE)
    message(STATUS "  - Catch2: ${CATCH2_DIR}")
else()
    message(STATUS "  - Catch2: Not downloaded (use -DDOWNLOAD_CATCH2=ON to enable)")
endif()
message(STATUS "")
message(STATUS "Compilers & Build Tools:")
if(WIN32)
    # MSVC
    if(MSVC_AVAILABLE)
        message(STATUS "  - MSVC: Available")
        if(EXISTS "${MSVC_TOOLS_DIR}/VC/Auxiliary/Build/vcvars64.bat")
            message(STATUS "    Location: ${MSVC_TOOLS_DIR}")
        endif()
    elseif(DOWNLOAD_MSVC)
        message(STATUS "  - MSVC: Download enabled (run install script after CMake)")
    else()
        message(STATUS "  - MSVC: Not downloaded (use -DDOWNLOAD_MSVC=ON)")
    endif()
endif()

# MinGW Clang64
if(CLANG64_AVAILABLE)
    message(STATUS "  - MinGW Clang 64-bit: ${CLANG64_DIR}")
    message(STATUS "    Compiler: ${CLANG64_DIR}/bin/clang.exe")
elseif(DOWNLOAD_MINGW_CLANG64)
    message(STATUS "  - MinGW Clang 64-bit: Download in progress")
else()
    message(STATUS "  - MinGW Clang 64-bit: Not downloaded (use -DDOWNLOAD_MINGW_CLANG64=ON)")
endif()

# MinGW GCC32
if(GCC32_AVAILABLE)
    message(STATUS "  - MinGW GCC 32-bit: ${GCC32_DIR}")
    message(STATUS "    Compiler: ${GCC32_DIR}/bin/gcc.exe")
elseif(DOWNLOAD_MINGW_GCC32)
    message(STATUS "  - MinGW GCC 32-bit: Download in progress")
else()
    message(STATUS "  - MinGW GCC 32-bit: Not downloaded (use -DDOWNLOAD_MINGW_GCC32=ON)")
endif()

message(STATUS "")
message(STATUS "Available CMake interface targets:")
message(STATUS "  - pdb_support (links LLVM PDB libraries)")
message(STATUS "  - dwarf_support (links libdwarf)")
if(CATCH2_AVAILABLE)
    message(STATUS "  - Catch2::Catch2WithMain (unit testing)")
endif()
message(STATUS "")
message(STATUS "To use downloaded compilers:")
if(CLANG64_AVAILABLE)
    message(STATUS "  Clang64: cmake -DCMAKE_C_COMPILER=${CLANG64_DIR}/bin/clang.exe -DCMAKE_CXX_COMPILER=${CLANG64_DIR}/bin/clang++.exe ..")
endif()
if(GCC32_AVAILABLE)
    message(STATUS "  GCC32:   cmake -DCMAKE_C_COMPILER=${GCC32_DIR}/bin/gcc.exe -DCMAKE_CXX_COMPILER=${GCC32_DIR}/bin/g++.exe ..")
endif()
message(STATUS "================================")
