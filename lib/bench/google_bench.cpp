#include <library1.hpp>
#include <benchmark/benchmark.h>
static void Sum(benchmark::State& state) {
  int value = 42;
  for (auto _ : state) {
    benchmark::DoNotOptimize(value);
    int result = lib1::sum_of_numbers(value, 1);
    benchmark::DoNotOptimize(result);
  }
}
BENCHMARK(Sum);
