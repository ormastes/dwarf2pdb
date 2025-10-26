# Library Setup Guide

This guide explains how to download and set up the MS PDB and DWARF5 libraries needed for the newDwarf2Pdb project.

## Overview

The `download_tool_libs.cmake` script automatically downloads:

1. **PDB Libraries** (to `pdb_lib/`):
   - LLVM Project (for PDB/CodeView support via LLVMDebugInfoPDB)
   - Microsoft PDB format specifications
   - DIA SDK headers and detection (Windows only)

2. **DWARF Libraries** (to `dwarf_lib/`):
   - libdwarf (for DWARF5 reading and writing)

## Quick Start

### Option 1: Automatic Download (Recommended)

```bash
# Create build directory
mkdir build
cd build

# Configure with automatic library download
cmake ..

# Build the project
cmake --build .
```

The libraries will be automatically downloaded to:
- `pdb_lib/` - MS PDB libraries
- `dwarf_lib/` - DWARF5 libraries

### Option 2: Download Libraries Only

If you just want to download the libraries without building:

```bash
mkdir build
cd build
cmake -DDOWNLOAD_LIBS=ON ..
```

### Option 3: Use Pre-installed Libraries

If you already have LLVM and libdwarf installed:

```bash
mkdir build
cd build
cmake -DDOWNLOAD_LIBS=OFF ..
```

## Downloaded Libraries

### PDB Support (pdb_lib/)

1. **LLVM Project** (`pdb_lib/llvm-project/`)
   - Provides: LLVMDebugInfoPDB, LLVMDebugInfoCodeView, LLVMDebugInfoMSF
   - Used for: Reading/writing PDB files, CodeView type records
   - Version: 17.0.6

2. **Microsoft PDB Specs** (`pdb_lib/microsoft-pdb/`)
   - Provides: Format specifications and reference headers
   - Used for: Understanding PDB format details
   - Source: https://github.com/microsoft/microsoft-pdb

3. **DIA SDK** (Windows only)
   - Automatically detected from Visual Studio installation
   - Typical location: `C:\Program Files (x86)\Microsoft Visual Studio\*\DIA SDK\`
   - Used for: Native Windows PDB access (optional)

### DWARF Support (dwarf_lib/)

1. **libdwarf** (`dwarf_lib/libdwarf/`)
   - Provides: DWARF reading and writing capabilities
   - Used for: Parsing and generating DWARF5 debug information
   - Version: 0.9.2
   - Source: https://github.com/davea42/libdwarf-code

## Using the Libraries in Your Code

The CMake script creates two interface targets for easy linking:

### 1. PDB Support

```cmake
target_link_libraries(your_target PRIVATE pdb_support)
```

This provides:
- LLVM PDB/CodeView headers
- Microsoft PDB headers
- DIA SDK headers (if available on Windows)
- Linked libraries: LLVMDebugInfoPDB, LLVMDebugInfoCodeView, LLVMDebugInfoMSF

### 2. DWARF Support

```cmake
target_link_libraries(your_target PRIVATE dwarf_support)
```

This provides:
- libdwarf headers
- Linked library: dwarf (static)

### Example in Your CMakeLists.txt

```cmake
# Your executable
add_executable(myapp
    src/main.cpp
    src/dwarf/DwarfReader.cpp
    src/pdb/PdbWriter.cpp
)

# Link both PDB and DWARF support
target_link_libraries(myapp PRIVATE
    pdb_support
    dwarf_support
)
```

## Directory Structure After Download

```
newDwarf2Pdb/
├── CMakeLists.txt
├── download_tool_libs.cmake
├── pdb_lib/
│   ├── llvm-project/          # LLVM source with PDB support
│   │   └── llvm/
│   │       ├── include/       # LLVM headers
│   │       └── lib/           # LLVM libraries
│   └── microsoft-pdb/         # PDB format specs
│       └── include/           # cvinfo.h, etc.
├── dwarf_lib/
│   └── libdwarf/              # libdwarf source
│       └── src/
│           └── lib/
│               └── libdwarf/  # Headers and source
└── src/                       # Your source code
```

## Requirements

- CMake 3.14 or higher
- C++17 compatible compiler
- Git (for cloning repositories)
- Internet connection (for initial download)

### Windows-Specific

- Visual Studio 2019 or later (for DIA SDK, optional)
- Windows SDK

### Linux-Specific

- GCC 7+ or Clang 5+
- zlib development files (`zlib1g-dev` on Debian/Ubuntu)

## Build Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `DOWNLOAD_LIBS` | ON | Automatically download PDB and DWARF libraries |
| `PDB_LIB_DIR` | `${CMAKE_CURRENT_SOURCE_DIR}/pdb_lib` | Directory for PDB libraries |
| `DWARF_LIB_DIR` | `${CMAKE_CURRENT_SOURCE_DIR}/dwarf_lib` | Directory for DWARF libraries |

### Example: Custom Library Directories

```bash
cmake -DPDB_LIB_DIR=/path/to/pdb_libs -DDWARF_LIB_DIR=/path/to/dwarf_libs ..
```

## Troubleshooting

### LLVM Build Takes Too Long

The LLVM download and build can be time-consuming. To speed it up:

```bash
# Use ninja instead of make (if available)
cmake -G Ninja ..

# Build with multiple cores
cmake --build . -j$(nproc)  # Linux
cmake --build . -j%NUMBER_OF_PROCESSORS%  # Windows
```

### DIA SDK Not Found (Windows)

If CMake cannot find the DIA SDK:

1. Verify Visual Studio is installed with C++ tools
2. Manually set the DIA SDK path:
   ```bash
   cmake -DDIA_SDK_DIR="C:/Program Files (x86)/Microsoft Visual Studio/2022/Community/DIA SDK" ..
   ```

### libdwarf Build Fails

If libdwarf fails to build:

1. Ensure zlib is installed:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install zlib1g-dev

   # Windows (vcpkg)
   vcpkg install zlib
   ```

2. Check CMake output for specific error messages

### Git Clone Fails

If you're behind a proxy or firewall:

```bash
# Configure git proxy
git config --global http.proxy http://proxy.example.com:8080

# Or download libraries manually and place in pdb_lib/ and dwarf_lib/
```

## Manual Installation Alternative

If automatic download doesn't work, you can manually install:

### LLVM
```bash
# Linux (apt)
sudo apt-get install llvm-dev libclang-dev

# macOS (homebrew)
brew install llvm
```

### libdwarf
```bash
# Linux (apt)
sudo apt-get install libdwarf-dev

# Build from source
git clone https://github.com/davea42/libdwarf-code.git
cd libdwarf-code
mkdir build && cd build
cmake ..
make install
```

Then use:
```bash
cmake -DDOWNLOAD_LIBS=OFF ..
```

## Next Steps

After libraries are downloaded:

1. Implement source files as per `FIRST_IMPLEMENTATION.md`
2. Uncomment executable creation in `CMakeLists.txt`
3. Build and test the converter

## References

- [LLVM Debug Info Documentation](https://llvm.org/docs/SourceLevelDebugging.html)
- [libdwarf Documentation](https://github.com/davea42/libdwarf-code)
- [Microsoft PDB Format](https://github.com/microsoft/microsoft-pdb)
- [CodeView Format](https://llvm.org/docs/PDB/index.html)
