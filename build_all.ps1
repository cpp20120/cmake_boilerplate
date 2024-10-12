# Create and build Debug
New-Item -ItemType Directory -Path "build/debug" -Force
cd "build/debug"
cmake -DCMAKE_BUILD_TYPE=Debug ..\..
cmake --build .
cd ..\..

# Create and build Release
New-Item -ItemType Directory -Path "build/release" -Force
cd "build/release"
cmake -DCMAKE_BUILD_TYPE=Release ..\..
cmake --build .
cd ..\..

# Create and build RelWithDebInfo
New-Item -ItemType Directory -Path "build/relwithdebinfo" -Force
cd "build/relwithdebinfo"
cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..\..
cmake --build .
cd ..\..

# Create and build MinSizeRel
New-Item -ItemType Directory -Path "build/minsizerel" -Force
cd "build/minsizerel"
cmake -DCMAKE_BUILD_TYPE=MinSizeRel ..\..
cmake --build .
cd ..\..
