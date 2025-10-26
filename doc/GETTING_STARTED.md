# Getting Started with newDwarf2Pdb

Quick reference guide for setting up the development environment.

## Prerequisites

- **CMake** 3.14 or higher
- **Git** (for downloading libraries)
- **C++20 compiler** (MSVC, GCC 10+, or Clang 10+)
- **Internet connection** (for initial library download)

## Setup Steps

### 1️⃣ Download Debug Libraries

```bash
# Quick test
./test_library_setup.bat      # Windows
./test_library_setup.sh        # Linux/Mac

# Or manually
mkdir build && cd build
cmake ..
```

**Downloads:**
- `pdb_lib/llvm-project/` - LLVM PDB/CodeView libraries
- `pdb_lib/microsoft-pdb/` - PDB format specifications
- `dwarf_lib/libdwarf/` - DWARF5 read/write library

**Time:** 5-15 minutes (depending on internet speed)
**Size:** ~2-3 GB

### 2️⃣ Optional: Download MSVC Build Tools (Windows Only)

If you don't have Visual Studio installed or want a local compiler:

```bash
# Step 1: Download installer
cmake -DDOWNLOAD_MSVC=ON -B build

# Step 2: Install MSVC (takes 15-30 minutes)
build\install_msvc.bat

# Step 3: Activate MSVC environment
setup_msvc_env.bat
```

**Installs to:** `tools/msvc/`
**Time:** 15-30 minutes
**Size:** ~5-8 GB

See **[MSVC_SETUP.md](MSVC_SETUP.md)** for detailed instructions.

### 3️⃣ Build the Project

```bash
# With system compiler
mkdir build && cd build
cmake ..
cmake --build .

# With local MSVC (Windows)
setup_msvc_env.bat
mkdir build && cd build
cmake -G "NMake Makefiles" ..
nmake
```

## CMake Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `DOWNLOAD_LIBS` | ON | Download PDB and DWARF libraries |
| `DOWNLOAD_MSVC` | OFF | Download MSVC Build Tools installer (Windows) |
| `PDB_LIB_DIR` | `pdb_lib` | Where to store PDB libraries |
| `DWARF_LIB_DIR` | `dwarf_lib` | Where to store DWARF libraries |
| `MSVC_TOOLS_DIR` | `tools/msvc` | Where to install MSVC |

### Examples

```bash
# Download everything including MSVC
cmake -DDOWNLOAD_LIBS=ON -DDOWNLOAD_MSVC=ON -B build

# Use custom library directories
cmake -DPDB_LIB_DIR=/opt/pdb_libs -DDWARF_LIB_DIR=/opt/dwarf_libs ..

# Skip library download (use pre-installed)
cmake -DDOWNLOAD_LIBS=OFF ..
```

## Project Structure After Setup

```
newDwarf2Pdb/
├── CMakeLists.txt                    # Main build config
├── download_tool_libs.cmake          # Library downloader
├── install_msvc.bat                  # MSVC installer (generated)
├── setup_msvc_env.bat                # MSVC environment setup
│
├── pdb_lib/                          # PDB libraries (auto-downloaded)
│   ├── llvm-project/                 # LLVM with PDB support
│   └── microsoft-pdb/                # PDB format specs
│
├── dwarf_lib/                        # DWARF libraries (auto-downloaded)
│   └── libdwarf/                     # libdwarf source + build
│
├── tools/                            # Local tools (optional)
│   └── msvc/                         # Local MSVC installation
│       └── VC/
│           └── Tools/
│               └── MSVC/
│                   └── 14.xx/
│                       └── bin/
│                           └── Hostx64/x64/
│                               └── cl.exe
│
├── doc/                              # Documentation
│   ├── LIBRARY_SETUP.md              # Library setup guide
│   └── LIBRARY_USAGE_EXAMPLES.md     # API usage examples
│
└── src/                              # Source code (to be implemented)
    ├── dwarf/                        # DWARF reader/writer
    ├── pdb/                          # PDB reader/writer
    ├── ir/                           # Intermediate representation
    └── pipeline/                     # Conversion pipeline
```

## Quick Commands Reference

### Library Management

```bash
# Download all libraries
cmake -DDOWNLOAD_LIBS=ON ..

# Check what was downloaded
ls pdb_lib/
ls dwarf_lib/

# Clean and re-download
rm -rf pdb_lib dwarf_lib build
cmake ..
```

### MSVC Management (Windows)

```bash
# Download MSVC installer
cmake -DDOWNLOAD_MSVC=ON -B build

# Install MSVC
build\install_msvc.bat

# Activate environment
setup_msvc_env.bat

# Check MSVC version
cl /version

# Check installation
dir tools\msvc\VC\Tools\MSVC
```

### Building

```bash
# Configure
cmake -B build

# Build
cmake --build build

# Build with specific generator
cmake -G "Ninja" -B build
cmake --build build

# Clean build
cmake --build build --target clean
```

## Verification

After setup, verify everything is ready:

```bash
# 1. Check libraries exist
ls pdb_lib/llvm-project
ls dwarf_lib/libdwarf

# 2. Check MSVC (if installed)
tools\msvc\VC\Tools\MSVC\*\bin\Hostx64\x64\cl.exe

# 3. Test build
cmake -B build_test
cmake --build build_test
```

## Troubleshooting

### Libraries Download Failed

```bash
# Check internet connection
ping github.com

# Try with verbose output
cmake --debug-output ..

# Manual download
git clone https://github.com/llvm/llvm-project.git pdb_lib/llvm-project
git clone https://github.com/davea42/libdwarf-code.git dwarf_lib/libdwarf
```

### MSVC Installation Failed

```bash
# Check disk space (need ~8 GB free)
# Check permissions
# Try manual installation:
build\vs_buildtools.exe --installPath "tools\msvc" ^
  --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ^
  --passive
```

### Build Failed

```bash
# Ensure environment is set (Windows with local MSVC)
setup_msvc_env.bat

# Clear CMake cache
rm -rf build/CMakeCache.txt

# Reconfigure
cmake -B build

# Check compiler
cmake --version
where cl      # Windows
which gcc     # Linux
```

## Documentation

- **[PROJECT_README.md](PROJECT_README.md)** - Project overview
- **[MSVC_SETUP.md](MSVC_SETUP.md)** - MSVC installation guide (Windows)
- **[doc/LIBRARY_SETUP.md](doc/LIBRARY_SETUP.md)** - Detailed library setup
- **[doc/LIBRARY_USAGE_EXAMPLES.md](doc/LIBRARY_USAGE_EXAMPLES.md)** - Code examples
- **[FIRST_IMPLEMENTATION.md](FIRST_IMPLEMENTATION.md)** - Architecture reference
- **[README.md](README.md)** - Architecture discussion

## Next Steps

1. ✅ Libraries downloaded
2. ✅ Compiler ready
3. ⏳ Implement source code (see [FIRST_IMPLEMENTATION.md](FIRST_IMPLEMENTATION.md))
4. ⏳ Build and test
5. ⏳ Create conversion pipeline

## Getting Help

If you encounter issues:

1. Check troubleshooting sections in documentation
2. Verify all prerequisites are installed
3. Check CMake output for error messages
4. Ensure adequate disk space (~10-15 GB total)
5. Try clean rebuild: `rm -rf build && cmake -B build`

## What's Different About This Setup?

This project's build system features:

- ✅ **Automatic library download** - No manual git clones
- ✅ **Local MSVC option** - Portable development environment
- ✅ **Interface targets** - Easy linking with `pdb_support` and `dwarf_support`
- ✅ **Separation of concerns** - Libraries and tools in separate directories
- ✅ **CI/CD friendly** - Reproducible builds
- ✅ **Cross-platform** - Works on Windows, Linux, and macOS
