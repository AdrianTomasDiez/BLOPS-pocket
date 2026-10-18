#pragma once

#if defined(__APPLE__)

#if defined(__arm64__) || defined(__aarch64__)
#include <stdint.h>

typedef uint64_t __m64;

static inline void _mm_empty(void) {}

#endif // __arm64__

#endif // __APPLE__
