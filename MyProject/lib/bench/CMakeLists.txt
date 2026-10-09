if(BOILERPLATE_BUILD_BENCHMARKS)
  boilerplate_add_benchmark(library1_bench SOURCES sum_bench.cpp
    GROUP custom LIBRARIES library1::library1 ARGS 1000000)
  if(TARGET library1_bench)
    boilerplate_add_scenario(sum_small TARGET library1_bench GROUP custom
      ARGS 10000 SMOKE SMOKE_ARGS 1 PGO PGO_ARGS 1000)
  endif()
endif()
if(BOILERPLATE_BUILD_GOOGLE_BENCHMARKS)
  boilerplate_add_google_benchmark(library1_google_bench SOURCES google_bench.cpp
    GROUP google LIBRARIES library1::library1)
endif()
