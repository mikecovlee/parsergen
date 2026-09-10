@echo off
if not exist cmake-build\mingw-w64 mkdir cmake-build\mingw-w64
cd    cmake-build\mingw-w64
cmake -G "MinGW Makefiles" ..\..\cpp
if errorlevel 1 exit /b 1
cmake --build . -- -j4
if errorlevel 1 exit /b 1
cd ..\..
if not exist build\imports mkdir build\imports
copy /Y cmake-build\mingw-w64\parsergen_cxx.cse build\imports\
