@echo off
REM Test script to verify library download setup

echo ====================================
echo Testing Library Download Setup
echo ====================================
echo.

REM Check if CMake is available
cmake --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: CMake not found. Please install CMake 3.14 or higher.
    exit /b 1
)

echo CMake found.
echo.

REM Create build directory
if not exist build_test (
    echo Creating build_test directory...
    mkdir build_test
) else (
    echo Using existing build_test directory...
)

cd build_test

REM Configure with library download
echo.
echo ====================================
echo Configuring project...
echo ====================================
echo.

cmake .. -DDOWNLOAD_LIBS=ON

if errorlevel 1 (
    echo.
    echo ERROR: CMake configuration failed!
    cd ..
    exit /b 1
)

echo.
echo ====================================
echo Configuration successful!
echo ====================================
echo.

REM Check if libraries were downloaded
echo Checking downloaded libraries...
echo.

if exist ..\pdb_lib\llvm-project (
    echo [OK] LLVM Project downloaded to pdb_lib/
) else (
    echo [WARN] LLVM Project not found in pdb_lib/
)

if exist ..\dwarf_lib\libdwarf (
    echo [OK] libdwarf downloaded to dwarf_lib/
) else (
    echo [WARN] libdwarf not found in dwarf_lib/
)

if exist ..\pdb_lib\microsoft-pdb (
    echo [OK] Microsoft PDB specs downloaded to pdb_lib/
) else (
    echo [WARN] Microsoft PDB specs not found in pdb_lib/
)

echo.
echo ====================================
echo Library setup test complete!
echo ====================================
echo.
echo To build the project:
echo   cd build_test
echo   cmake --build .
echo.

cd ..
