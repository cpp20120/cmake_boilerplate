# CTest and CDash dashboard

The optional `dashboard` project capability runs the existing CTest suite through
CTest's dashboard client. CTest owns test discovery, durations, labels, stdout,
stderr and XML reports. CDash is an external service that stores those reports
over time. `cmake --workflow --preset app-debug` is the normal preset sequence;
it does not create a CDash dashboard report or submit anything.

## Local run

```sh
cmake --preset app-dashboard
cmake --build --preset app-dashboard
```

This configures the usual `app-debug` project and runs Start, Configure, Build
and Test. The `boilerplate_dashboard` target is available when the capability is
enabled; it has no build-target dependency that could prevent reporting a failed
build. It neither updates the checkout nor deletes the build tree. An existing
configured build can also opt in with
`cmake --preset app-debug -DBOILERPLATE_DASHBOARD=ON`, followed by
`cmake --build --preset app-debug --target boilerplate_dashboard`.

Reports are in `out/build/app-dashboard/Testing/<TAG>/Configure.xml`, `Build.xml`
and `Test.xml`; `Testing/TAG` identifies the current run. Step logs are under
`Testing/Temporary/`. Test failures still produce `Test.xml` and a nonzero exit
code. Build warnings/errors are parsed into `Build.xml`. Test labels, timeouts,
skips, fixtures and resource specifications come from existing CTest properties.
Projects can emit [additional test measurements](https://cmake.org/cmake/help/latest/manual/ctest.1.html#additional-test-measurements)
in test output without adopting a Boilerplate-specific schema.

The capability can also be selected explicitly with
`-DBOILERPLATE_PROJECT_CAPABILITIES=testing;dashboard` (quote the list in a
shell). `BOILERPLATE_DASHBOARD=OFF` is the default. Normal configure, build,
`ctest --preset app-debug` and `coverage-report` keep their existing behavior.

## Options

`BOILERPLATE_DASHBOARD_MODEL` is `Experimental`, `Nightly` or `Continuous`;
the latter two do **not** run `ctest_update`. `BOILERPLATE_DASHBOARD_CONFIGURATION`
selects the configuration in multi-config builds (or must match the configured
single-config build). `BOILERPLATE_DASHBOARD_SITE` and
`BOILERPLATE_DASHBOARD_BUILD_NAME` override names; the default build name
contains OS, architecture, compiler/version, configuration and
`BOILERPLATE_DASHBOARD_VARIANT` (`local` by default).

`BOILERPLATE_DASHBOARD_LABEL` is a CTest label regex.
`BOILERPLATE_DASHBOARD_PARALLEL` controls build/test parallelism;
`BOILERPLATE_DASHBOARD_TEST_TIMEOUT` sets the default test timeout. Optional
`BOILERPLATE_DASHBOARD_TEST_LOAD` and `BOILERPLATE_DASHBOARD_RESOURCE_SPEC`
apply CTest load/resource limits. Test-specific `TIMEOUT` values still take
precedence.

## Coverage

For GCC/gcov or Clang's gcov-compatible format, use the existing coverage
instrumentation. The dashboard resets only `.gcda` counters immediately before
its one Test stage, then calls `ctest_coverage()` to create real `Coverage.xml`
and `CoverageLog-*.xml`. It does not rerun tests or rename `coverage.info`.

```sh
cmake --preset app-coverage -DCMAKE_CXX_COMPILER=g++ \
  -DBOILERPLATE_DASHBOARD=ON -DBOILERPLATE_DASHBOARD_COVERAGE=ON
cmake --build --preset app-coverage --target boilerplate_dashboard
```

Clang gcov-compatible builds use `llvm-cov gcov`; the existing
`BOILERPLATE_COVERAGE_GCOV_TOOL` override also applies. Keep using
`coverage-report` for LCOV/genhtml. CTest coverage and LCOV are separate views
of the same instrumentation and should not run concurrently in one build tree.

On CMake/CTest 4.4+ an explicitly instrumented Clang source-based build can use
`BOILERPLATE_LLVM_SOURCE_COVERAGE=ON`,
`BOILERPLATE_DASHBOARD_COVERAGE_BACKEND=llvm-cov` and
`BOILERPLATE_DASHBOARD_COVERAGE=ON`. `ctest_test(COVERAGE_TOOL LLVM-COV)` creates
per-test `.profdata`. CTest 4.4 script mode can fail to propagate the LLVM data
tool to `ctest_coverage()`; the dashboard falls back to CTest's own `-T Coverage`
step, using the same tag and test data. Earlier CTest versions reject this
backend. GCC/Clang gcov and LLVM source-based figures are not equivalent
measurements. No coverage XML is accepted without fresh counters and measured
source lines.

## Memory checks

`BOILERPLATE_DASHBOARD_MEMCHECK=ON` adds a separate `ctest_memcheck()` pass with
Valgrind (or `BOILERPLATE_DASHBOARD_MEMCHECK_COMMAND`). It reports defects in
CTest's `DynamicAnalysis.xml` files and fails clearly if the tool is absent.
Do not combine it with sanitizer-instrumented builds. MemCheck runs tests again
by explicit opt-in and can be much slower; Valgrind results are not a substitute
for ASan or TSan diagnostics, and support differs by platform.

## CDash submission

Submission is **off** unless `BOILERPLATE_DASHBOARD_SUBMIT=ON`. Set an HTTP(S)
CDash submit URL without credentials and the project name. For example:

```sh
cmake --preset app-dashboard \
  -DBOILERPLATE_DASHBOARD_SUBMIT=ON \
  -DBOILERPLATE_DASHBOARD_URL='https://cdash.example.org/submit.php?project=MyProject' \
  -DBOILERPLATE_DASHBOARD_PROJECT=MyProject
cmake --build --preset app-dashboard
```

Use `BOILERPLATE_CDASH_BEARER_TOKEN` as an environment/CI secret if the CDash
server requires bearer authentication. Never place it in a preset, URL or cache.
`BOILERPLATE_DASHBOARD_RETRY_COUNT` and `_RETRY_DELAY` control retries for
timed-out submissions. `BOILERPLATE_DASHBOARD_SUBMIT_FAILURE_FATAL=OFF` allows
an unavailable server without hiding configure/build/test failures. Failed tests
are submitted before the dashboard target returns failure.

GitHub Actions runs local dashboard regression checks on Linux, Windows and
macOS without HTTP. The separate `cdash-submit` job runs only on trusted pushes
when repository variable `BOILERPLATE_CDASH_SUBMIT=true` is set. It reads
`BOILERPLATE_CDASH_URL` and `BOILERPLATE_CDASH_PROJECT` repository variables,
and optional `BOILERPLATE_CDASH_BEARER_TOKEN` secret. Fork pull requests cannot
use that job or its secret.
