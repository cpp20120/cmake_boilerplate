#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif
extern "C" int external_leaf_increment();
extern "C" EXPORT int external_increment() { return external_leaf_increment(); }
