#!/usr/bin/env bash
set -e
mkdir -p cmake-build/unix
cd       cmake-build/unix
cmake -G "Unix Makefiles" ../../cpp
cmake --build . -- -j4
cd ../..
mkdir -p build/imports
cp cmake-build/unix/parsergen_cxx.cse build/imports/
