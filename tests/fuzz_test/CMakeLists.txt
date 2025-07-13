find_package(fmt REQUIRED)

if(ENABLE_FUZZING)
    if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        message(WARNING "Fuzzing is fully supported only with Clang compiler")
    endif()

    add_executable(fuzz_target fuzz_target.cpp)
    target_link_libraries(fuzz_target PRIVATE 
        ${CMAKE_PROJECT_NAME}
        fmt::fmt
    )
    
    target_compile_options(fuzz_target PRIVATE
        -fsanitize=fuzzer-no-link,address,undefined
        -fno-omit-frame-pointer
        -gline-tables-only
    )
    
    target_link_options(fuzz_target PRIVATE
        -fsanitize=fuzzer,address,undefined
    )

    file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/corpus)
    file(COPY corpus/ DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/corpus)

    set(FUZZ_RUNTIME 10 CACHE STRING "Number of seconds to run fuzz tests")

    add_custom_target(run_fuzz
        COMMAND $<TARGET_FILE:fuzz_target> ${CMAKE_CURRENT_BINARY_DIR}/corpus -max_total_time=${FUZZ_RUNTIME}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Running fuzzer for ${FUZZ_RUNTIME} seconds..."
        DEPENDS fuzz_target
    )

    if(ENABLE_CODE_COVERAGE)
        target_compile_options(fuzz_target PRIVATE --coverage)
        target_link_options(fuzz_target PRIVATE --coverage)
    endif()

    add_test(
        NAME fuzz_target_test
        COMMAND $<TARGET_FILE:fuzz_target> ${CMAKE_CURRENT_BINARY_DIR}/corpus -max_total_time=${FUZZ_RUNTIME}
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
endif()
