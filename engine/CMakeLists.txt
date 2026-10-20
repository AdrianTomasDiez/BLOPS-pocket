cmake_minimum_required(VERSION 3.16)
project(blops_engine LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(blops_engine STATIC
    src/manifest.cpp
)
target_include_directories(blops_engine PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

enable_testing()
add_executable(blops_tests tests/test_manifest.cpp)
target_link_libraries(blops_tests PRIVATE blops_engine)
add_test(NAME blops_tests COMMAND blops_tests)