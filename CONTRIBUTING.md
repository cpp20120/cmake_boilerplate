# Contributing

Issues, bug fixes, tests, documentation improvements, and platform support
are welcome.

## Report issues

Please include the host OS, CMake version, compiler and generator, the command
and preset used, and a minimized reproduction or relevant CI log. For a
security-sensitive issue, **do not create a public issue**; follow
[SECURITY.md](SECURITY.md) instead.

## Propose changes

1. Open an issue for significant changes to public CMake APIs, bootstrap
   behavior, generated templates, or compatibility contracts.
2. Keep changes narrowly scoped; add regression tests for behavior changes.
3. Run the relevant checks, including:

   ```sh
   cmake -P scripts/TemplateManifest.cmake
   bash scripts/test-entry.sh  # Linux/macOS
   cmake --preset app-release
   cmake --build --preset app-release --parallel 2
   ctest --preset app-release --output-on-failure
   ```

4. Open a pull request explaining affected platforms, compatibility impact,
   and the tests you performed. Maintainer reviews contributions as time permits.

Code is MIT licensed; contributions are submitted under the repository license.
