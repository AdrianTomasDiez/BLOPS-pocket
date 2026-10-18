#pragma once

#if defined(__APPLE__)

#if defined(__arm64__) || defined(__aarch64__)
#include <arm_neon.h>
#endif

// Intrínsecos comunes de MSVC adaptados para Clang/ARM64
#ifndef _BitScanForward
static inline unsigned char _BitScanForward(unsigned long *index, unsigned long mask) {
    if (mask == 0) return 0;
    *index = (unsigned long)__builtin_ctzl(mask);
    return 1;
}
#endif

#ifndef _BitScanReverse
static inline unsigned char _BitScanReverse(unsigned long *index, unsigned long mask) {
    if (mask == 0) return 0;
    *index = (unsigned long)(31 - __builtin_clzl(mask));
    return 1;
}
#endif

#endif // __APPLE__
