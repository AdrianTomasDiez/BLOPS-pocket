cmake_minimum_required(VERSION 3.16)
project(blops_engine LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# miniz: zlib-compatible inflate/crc32, vendored so the engine builds
# identically on Windows, Linux, macOS and iOS with no external dependency.
add_library(miniz STATIC
    third_party/miniz/miniz.c
    third_party/miniz/miniz_tdef.c
    third_party/miniz/miniz_tinfl.c
    third_party/miniz/miniz_zip.c
)
target_include_directories(miniz PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/third_party/miniz)

add_library(blops_engine STATIC
    src/manifest.cpp
    src/zone.cpp
    src/iwd.cpp
    src/scan.cpp
    src/sha256.cpp
)
target_link_libraries(blops_engine PUBLIC miniz)
target_include_directories(blops_engine PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

enable_testing()
foreach(pair "blops_tests:test_manifest" "blops_sha_tests:test_sha256")
    string(REPLACE ":" ";" parts ${pair})
    list(GET parts 0 target)
    list(GET parts 1 file)
    add_executable(${target} tests/${file}.cpp)
    target_link_libraries(${target} PRIVATE blops_engine)
    add_test(NAME ${target} COMMAND ${target})
endforeach()

add_executable(blops_probe tools/probe.cpp)
target_link_libraries(blops_probe PRIVATE blops_engine)