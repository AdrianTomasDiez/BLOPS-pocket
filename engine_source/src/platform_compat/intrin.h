#pragma once

#if defined(__APPLE__)

#include <stdint.h>
#include <pthread.h>

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

#ifndef _InterlockedExchangeAdd
#define _InterlockedExchangeAdd(target, val) \
    ((sizeof(*(target)) == 8) \
        ? (long)__sync_fetch_and_add((volatile int64_t*)(target), (int64_t)(int32_t)(val)) \
        : (long)__sync_fetch_and_add((volatile int32_t*)(target), (int32_t)(val)))
#endif

static inline uint64_t __rdtsc(void) {
#if defined(__arm64__) || defined(__aarch64__)
    uint64_t val;
    __asm__ __volatile__("mrs %0, cntvct_el0" : "=r"(val));
    return val;
#else
    return 0;
#endif
}

static inline uint32_t __readfsdword(unsigned long offset) {
    return (uint32_t)(uintptr_t)pthread_self();
}

#endif // __APPLE__
