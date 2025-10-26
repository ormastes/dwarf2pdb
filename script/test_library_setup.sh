#!/bin/bash
# Test script to verify library download setup

echo "===================================="
echo "Testing Library Download Setup"
echo "===================================="
echo ""

# Check if CMake is available
if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found. Please install CMake 3.14 or higher."
    exit 1
fi

echo "CMake found: $(cmake --version | head -n1)"
echo ""

# Create build directory
if [ ! -d "build_test" ]; then
    echo "Creating build_test directory..."
    mkdir build_test
else
    echo "Using existing build_test directory..."
fi

cd build_test

# Configure with library download
echo ""
echo "===================================="
echo "Configuring project..."
echo "===================================="
echo ""

cmake .. -DDOWNLOAD_LIBS=ON

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: CMake configuration failed!"
    cd ..
    exit 1
fi

echo ""
echo "===================================="
echo "Configuration successful!"
echo "===================================="
echo ""

# Check if libraries were downloaded
echo "Checking downloaded libraries..."
echo ""

if [ -d "../pdb_lib/llvm-project" ]; then
    echo "[OK] LLVM Project downloaded to pdb_lib/"
else
    echo "[WARN] LLVM Project not found in pdb_lib/"
fi

if [ -d "../dwarf_lib/libdwarf" ]; then
    echo "[OK] libdwarf downloaded to dwarf_lib/"
else
    echo "[WARN] libdwarf not found in dwarf_lib/"
fi

if [ -d "../pdb_lib/microsoft-pdb" ]; then
    echo "[OK] Microsoft PDB specs downloaded to pdb_lib/"
else
    echo "[WARN] Microsoft PDB specs not found in pdb_lib/"
fi

echo ""
echo "===================================="
echo "Library setup test complete!"
echo "===================================="
echo ""
echo "To build the project:"
echo "  cd build_test"
echo "  cmake --build . -j\$(nproc)"
echo ""

cd ..
