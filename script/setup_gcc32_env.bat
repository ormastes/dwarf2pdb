@echo off
REM Setup MinGW GCC 32-bit Environment Script

set GCC32_ROOT=%~dp0tools\gcc32

if not exist "%GCC32_ROOT%\bin\gcc.exe" (
    echo ERROR: MinGW GCC 32-bit not found at %GCC32_ROOT%
    echo.
    echo To install MinGW GCC 32-bit, run:
    echo   cmake -DDOWNLOAD_MINGW_GCC32=ON -B build
    echo.
    exit /b 1
)

echo ============================================
echo Setting up MinGW GCC 32-bit Environment
echo ============================================
echo.
echo GCC Location: %GCC32_ROOT%
echo.

REM Add MinGW GCC to PATH
set PATH=%GCC32_ROOT%\bin;%PATH%

REM Set compiler environment variables
set CC=%GCC32_ROOT%\bin\gcc.exe
set CXX=%GCC32_ROOT%\bin\g++.exe
set AR=%GCC32_ROOT%\bin\ar.exe
set RANLIB=%GCC32_ROOT%\bin\ranlib.exe

echo MinGW GCC 32-bit Environment Ready!
echo.
echo Compilers:
gcc --version | findstr /C:"gcc"
echo.
echo You can now build with:
echo   cmake -G "MinGW Makefiles" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -B build
echo   mingw32-make -C build
echo.
echo Or:
echo   cmake -G "Ninja" -B build
echo   ninja -C build
echo.
