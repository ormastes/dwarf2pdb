@echo off
REM Setup MinGW Clang 64-bit Environment Script

set CLANG64_ROOT=%~dp0tools\clang64

if not exist "%CLANG64_ROOT%\bin\clang.exe" (
    echo ERROR: MinGW Clang 64-bit not found at %CLANG64_ROOT%
    echo.
    echo To install MinGW Clang 64-bit, run:
    echo   cmake -DDOWNLOAD_MINGW_CLANG64=ON -B build
    echo.
    exit /b 1
)

echo ============================================
echo Setting up MinGW Clang 64-bit Environment
echo ============================================
echo.
echo Clang Location: %CLANG64_ROOT%
echo.

REM Add MinGW Clang to PATH
set PATH=%CLANG64_ROOT%\bin;%PATH%

REM Set compiler environment variables
set CC=%CLANG64_ROOT%\bin\clang.exe
set CXX=%CLANG64_ROOT%\bin\clang++.exe
set AR=%CLANG64_ROOT%\bin\llvm-ar.exe
set RANLIB=%CLANG64_ROOT%\bin\llvm-ranlib.exe

echo MinGW Clang 64-bit Environment Ready!
echo.
echo Compilers:
clang --version | findstr /C:"clang version"
echo.
echo You can now build with:
echo   cmake -G "Ninja" -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -B build
echo   ninja -C build
echo.
echo Or:
echo   cmake -G "MinGW Makefiles" -B build
echo   cmake --build build
echo.
