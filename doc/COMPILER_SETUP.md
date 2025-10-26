# Compiler Setup Guide

This guide explains how to download and use different compilers with the newDwarf2Pdb project.

## Available Compilers

The project supports automatic download of multiple compilers:

| Compiler | Architecture | Platform | Location | Download Option |
|----------|-------------|----------|----------|-----------------|
| MSVC | x64 | Windows | `tools/msvc/` | `-DDOWNLOAD_MSVC=ON` |
| MinGW Clang | x64 | Windows/Cross | `tools/clang64/` | `-DDOWNLOAD_MINGW_CLANG64=ON` |
| MinGW GCC | x86 (32-bit) | Windows | `tools/gcc32/` | `-DDOWNLOAD_MINGW_GCC32=ON` |

## Quick Start

### Download All Compilers

```bash
cmake -DDOWNLOAD_MSVC=ON \
      -DDOWNLOAD_MINGW_CLANG64=ON \
      -DDOWNLOAD_MINGW_GCC32=ON \
      -B build
```

### Download Specific Compiler

```bash
# MSVC only
cmake -DDOWNLOAD_MSVC=ON -B build

# MinGW Clang 64-bit only
cmake -DDOWNLOAD_MINGW_CLANG64=ON -B build

# MinGW GCC 32-bit only
cmake -DDOWNLOAD_MINGW_GCC32=ON -B build
```

## 1. MSVC (Microsoft Visual C++)

### Download and Install

```bash
# Step 1: Download installer
cmake -DDOWNLOAD_MSVC=ON -B build

# Step 2: Run installation script
build\install_msvc.bat

# Step 3: Activate environment
setup_msvc_env.bat
```

### Build with MSVC

```bash
# Configure
cmake -G "NMake Makefiles" -B build

# Build
nmake -C build

# Or use Ninja
cmake -G "Ninja" -B build
ninja -C build
```

**See [MSVC_SETUP.md](MSVC_SETUP.md) for detailed MSVC documentation.**

## 2. MinGW Clang 64-bit

### Overview

- **Distribution**: LLVM MinGW (by Martin Storsjö)
- **Version**: Latest stable (currently 2024-09-17)
- **Architecture**: x86_64 (64-bit)
- **C Runtime**: UCRT (Universal C Runtime)
- **Threading**: POSIX threads
- **Exception Handling**: SEH (Structured Exception Handling)

### Download and Setup

```bash
# Download MinGW Clang 64-bit
cmake -DDOWNLOAD_MINGW_CLANG64=ON -B build

# Activate environment
setup_clang64_env.bat
```

This downloads and extracts to `tools/clang64/`.

**Download Size**: ~200 MB
**Installed Size**: ~500 MB
**Time**: 2-5 minutes

### Build with Clang64

```bash
# Method 1: Use environment setup script
setup_clang64_env.bat
cmake -G "Ninja" -B build
ninja -C build

# Method 2: Specify compilers directly
cmake -DCMAKE_C_COMPILER=tools/clang64/bin/clang.exe \
      -DCMAKE_CXX_COMPILER=tools/clang64/bin/clang++.exe \
      -G "Ninja" -B build
cmake --build build

# Method 3: MinGW Makefiles
setup_clang64_env.bat
cmake -G "MinGW Makefiles" -B build
mingw32-make -C build
```

### Clang64 Features

- ✅ Full C++20 support
- ✅ LLVM toolchain (clang, lld, llvm-ar, etc.)
- ✅ Better error messages than GCC
- ✅ Faster compilation in many cases
- ✅ Cross-compilation support
- ✅ Compatible with MSVC libraries
- ✅ AddressSanitizer, UndefinedBehaviorSanitizer support

### Example CMake Toolchain File

Create `cmake/clang64-toolchain.cmake`:

```cmake
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(CLANG64_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/tools/clang64")

set(CMAKE_C_COMPILER "${CLANG64_ROOT}/bin/clang.exe")
set(CMAKE_CXX_COMPILER "${CLANG64_ROOT}/bin/clang++.exe")
set(CMAKE_AR "${CLANG64_ROOT}/bin/llvm-ar.exe")
set(CMAKE_RANLIB "${CLANG64_ROOT}/bin/llvm-ranlib.exe")

set(CMAKE_FIND_ROOT_PATH "${CLANG64_ROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
```

Use with:
```bash
cmake -DCMAKE_TOOLCHAIN_FILE=cmake/clang64-toolchain.cmake -B build
```

## 3. MinGW GCC 32-bit

### Overview

- **Distribution**: WinLibs standalone build
- **Version**: GCC 13.2.0
- **Architecture**: i686 (32-bit)
- **C Runtime**: UCRT
- **Threading**: POSIX threads
- **Exception Handling**: DWARF

### Download and Setup

```bash
# Download MinGW GCC 32-bit
cmake -DDOWNLOAD_MINGW_GCC32=ON -B build

# Activate environment
setup_gcc32_env.bat
```

This downloads and extracts to `tools/gcc32/`.

**Download Size**: ~250 MB
**Installed Size**: ~1 GB
**Time**: 3-7 minutes

### Build with GCC32

```bash
# Method 1: Use environment setup script
setup_gcc32_env.bat
cmake -G "MinGW Makefiles" -B build
mingw32-make -C build

# Method 2: Specify compilers directly
cmake -DCMAKE_C_COMPILER=tools/gcc32/bin/gcc.exe \
      -DCMAKE_CXX_COMPILER=tools/gcc32/bin/g++.exe \
      -G "MinGW Makefiles" -B build
cmake --build build

# Method 3: Ninja
setup_gcc32_env.bat
cmake -G "Ninja" -B build
ninja -C build
```

### GCC32 Features

- ✅ C++20 support
- ✅ 32-bit builds (useful for compatibility testing)
- ✅ GCC-specific extensions
- ✅ Better OpenMP support than Clang
- ✅ Traditional GCC diagnostics
- ✅ Full MinGW-w64 runtime

### Why 32-bit GCC?

- Testing 32-bit compatibility
- Working with legacy 32-bit libraries
- Debugging pointer size issues
- Smaller binaries for testing
- Compatibility with 32-bit Windows

## Compiler Comparison

| Feature | MSVC | Clang64 | GCC32 |
|---------|------|---------|-------|
| **Architecture** | x64 | x64 | x86 (32-bit) |
| **C++ Standard** | C++20 | C++20 | C++20 |
| **Standard Library** | MSVC STL | libc++ | libstdc++ |
| **Debugger** | VS Debugger | GDB/LLDB | GDB |
| **Build Speed** | Medium | Fast | Medium |
| **Error Messages** | Good | Excellent | Good |
| **Windows Integration** | Best | Good | Good |
| **Cross-platform** | No | Yes | Yes |
| **Install Size** | 5-8 GB | 500 MB | 1 GB |
| **License** | Proprietary | Apache 2.0 | GPL |

## Build Configurations

### Debug Build

```bash
# MSVC Debug
cmake -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Debug -B build-debug
nmake -C build-debug

# Clang64 Debug with sanitizers
setup_clang64_env.bat
cmake -G "Ninja" -DCMAKE_BUILD_TYPE=Debug \
      -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined" \
      -B build-debug
ninja -C build-debug

# GCC32 Debug
setup_gcc32_env.bat
cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Debug -B build-debug
mingw32-make -C build-debug
```

### Release Build

```bash
# MSVC Release
cmake -G "NMake Makefiles" -DCMAKE_BUILD_TYPE=Release -B build-release
nmake -C build-release

# Clang64 Release with LTO
setup_clang64_env.bat
cmake -G "Ninja" -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -B build-release
ninja -C build-release

# GCC32 Release
setup_gcc32_env.bat
cmake -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -B build-release
mingw32-make -C build-release
```

## Using Multiple Compilers

### Build with All Compilers

```bash
# MSVC build
setup_msvc_env.bat
cmake -G "NMake Makefiles" -B build-msvc
nmake -C build-msvc

# Clang64 build
setup_clang64_env.bat
cmake -G "Ninja" -B build-clang64
ninja -C build-clang64

# GCC32 build
setup_gcc32_env.bat
cmake -G "MinGW Makefiles" -B build-gcc32
mingw32-make -C build-gcc32
```

### Parallel Testing

```bash
# Run all builds in parallel (PowerShell)
$jobs = @(
    { setup_msvc_env.bat; cmake -G "NMake Makefiles" -B build-msvc; nmake -C build-msvc },
    { setup_clang64_env.bat; cmake -G "Ninja" -B build-clang64; ninja -C build-clang64 },
    { setup_gcc32_env.bat; cmake -G "Ninja" -B build-gcc32; ninja -C build-gcc32 }
)
$jobs | ForEach-Object { Start-Job $_ }
Get-Job | Wait-Job | Receive-Job
```

## Troubleshooting

### Clang64: "clang.exe not found"

```bash
# Check installation
dir tools\clang64\bin\clang.exe

# Re-download if missing
cmake -DDOWNLOAD_MINGW_CLANG64=ON -B build

# Add to PATH manually
set PATH=%CD%\tools\clang64\bin;%PATH%
```

### GCC32: "gcc.exe not found"

```bash
# Check installation
dir tools\gcc32\bin\gcc.exe

# Re-download if missing
cmake -DDOWNLOAD_MINGW_GCC32=ON -B build

# Add to PATH manually
set PATH=%CD%\tools\gcc32\bin;%PATH%
```

### "Incorrect architecture" errors

```bash
# Make sure you're using the right compiler for your target
# For 64-bit builds, use MSVC or Clang64
# For 32-bit builds, use GCC32

# Check current architecture
cl 2>&1 | findstr /C:"x64" /C:"x86"     # MSVC
clang --version | findstr /C:"x86_64"   # Clang64
gcc -dumpmachine                         # Shows target triplet
```

### Mixing compilers and libraries

**Don't mix!** Libraries compiled with one compiler may not work with another:

```bash
# ❌ BAD: Mixing MSVC and MinGW
# Build lib with MSVC, link with MinGW - will fail!

# ✅ GOOD: Use same compiler throughout
# Build everything with MSVC, or everything with MinGW
```

## IDE Integration

### Visual Studio Code

Create `.vscode/settings.json`:

```json
{
    "cmake.configureSettings": {
        "DOWNLOAD_MINGW_CLANG64": "ON"
    },
    "cmake.generator": "Ninja",
    "cmake.preferredGenerators": ["Ninja", "MinGW Makefiles"],
    "C_Cpp.default.compilerPath": "${workspaceFolder}/tools/clang64/bin/clang.exe"
}
```

### CLion

1. File → Settings → Build, Execution, Deployment → Toolchains
2. Add MinGW
3. Set Environment: `tools/clang64` or `tools/gcc32`
4. Apply and rebuild

## Performance Tips

### Faster Builds

```bash
# Use Ninja (faster than Make)
cmake -G "Ninja" -B build

# Enable parallel compilation
ninja -C build -j$(nproc)  # Linux/Git Bash
ninja -C build -j%NUMBER_OF_PROCESSORS%  # Windows CMD

# Use ccache (if available)
cmake -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -B build
```

### Smaller Binaries

```bash
# Clang64: Use LTO and strip
cmake -DCMAKE_BUILD_TYPE=MinSizeRel \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -B build-small
ninja -C build-small
llvm-strip build-small/executable.exe

# GCC32: Similar approach
cmake -DCMAKE_BUILD_TYPE=MinSizeRel \
      -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
      -B build-small
mingw32-make -C build-small
strip build-small/executable.exe
```

## References

- [LLVM MinGW](https://github.com/mstorsjo/llvm-mingw)
- [WinLibs](https://winlibs.com/)
- [MinGW-w64](https://www.mingw-w64.org/)
- [CMake Generator Documentation](https://cmake.org/cmake/help/latest/manual/cmake-generators.7.html)
