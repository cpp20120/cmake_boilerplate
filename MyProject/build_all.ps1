# All policy lives in presets and BuildMatrix.cmake.
& cmake "-DSOURCE_DIR=$PSScriptRoot" @args -P "$PSScriptRoot/lib/cmake/build/BuildMatrix.cmake"
exit $LASTEXITCODE
