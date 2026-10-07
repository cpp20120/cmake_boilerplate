#include "math.hpp"
#include <cstdio>
#include <cstdlib>
#include <cstring>
int main(int argc, char** argv) {
#ifdef EXPECT_EMULATOR
    if (!std::getenv("CROSS_TEST_EMULATED")) return 5;
#endif
    if (argc > 1 && std::strcmp(argv[1], "--gtest_list_tests") == 0) {
        std::puts("Cross.\n  Probe");
        return 0;
    }
    std::puts("{\"status\":\"ok\",\"value\":1,\"checksum\":42}");
    return cross_value() == 42 ? 0 : 1;
}
