@echo off
REM Setup MSVC Environment Script
REM This script sets up the environment to use the locally installed MSVC

set MSVC_ROOT=%~dp0tools\msvc

if not exist "%MSVC_ROOT%\VC\Auxiliary\Build\vcvars64.bat" (
    echo ERROR: MSVC not found at %MSVC_ROOT%
    echo.
    echo To install MSVC, run:
    echo   cmake -DDOWNLOAD_MSVC=ON ..
    echo   install_msvc.bat
    echo.
    exit /b 1
)

echo ============================================
echo Setting up MSVC Environment
echo ============================================
echo.
echo MSVC Location: %MSVC_ROOT%
echo.

REM Call vcvars64.bat to set up environment
call "%MSVC_ROOT%\VC\Auxiliary\Build\vcvars64.bat"

echo.
echo ============================================
echo MSVC Environment Ready!
echo ============================================
echo.
echo Compiler:
cl /version
echo.
echo You can now build with:
echo   cmake -G "NMake Makefiles" ..
echo   nmake
echo.
echo Or:
echo   cmake -G "Ninja" ..
echo   ninja
echo.
