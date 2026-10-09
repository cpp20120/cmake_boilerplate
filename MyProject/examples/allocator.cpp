#include <cstdlib>
#if defined(BOILERPLATE_USE_MIMALLOC)
#include <mimalloc.h>
#elif defined(BOILERPLATE_USE_TBBMALLOC)
#include <tbb/scalable_allocator.h>
#endif
int main() {
#if defined(BOILERPLATE_USE_MIMALLOC)
  auto* memory = mi_malloc(64);
#elif defined(BOILERPLATE_USE_TBBMALLOC)
  auto* memory = scalable_malloc(64);
#else
  auto* memory = std::malloc(64);
#endif
  if (!memory) return 1;
  static_cast<unsigned char*>(memory)[0] = 42;
#if defined(BOILERPLATE_USE_MIMALLOC)
  mi_free(memory);
#elif defined(BOILERPLATE_USE_TBBMALLOC)
  scalable_free(memory);
#else
  std::free(memory);
#endif
  return 0;
}
