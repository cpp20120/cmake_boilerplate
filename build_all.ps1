# Create and build Debug
New-Item -ItemType Directory -Path "build/debug" -Force
Copy-Item "CMakePresets.json" -Destination "build/debug" -Force
cd "build/debug"
cmake ../.. --preset debug
cmake --build --preset build-debug
cd ../..

# Create and build Release
New-Item -ItemType Directory -Path "build/release" -Force
Copy-Item "CMakePresets.json" -Destination "build/release" -Force
cd "build/release"
cmake ../.. --preset release
cmake --build --preset build-release
cd ../..

