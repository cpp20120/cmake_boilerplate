#!/bin/bash

# Create and build Debug
mkdir -p build/debug
cp CMakePresets.json
cd build/debug
cmake --preset debug
cmake --build --preset build-debug
cd ../..

# Create and build Release
mkdir -p build/release
cp CMakePresets.json
cd build/debug
cmake --preset release
cmake --build --preset build-release
cd ../..

# Create and build RelWithDebInfo
mkdir -p build/relwithdebinfo
cd build/relwithdebinfo
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ../..
cmake --build .
cd ../..

# Create and build MinSizeRel
mkdir -p build/minsizerel
cd build/minsizerel
cmake -DCMAKE_BUILD_TYPE=MinSizeRel ../..
cmake --build .
cd ../..
