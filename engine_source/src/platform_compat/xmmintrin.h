#pragma once

#if defined(__APPLE__)

#if defined(__arm64__) || defined(__aarch64__)
#include <arm_neon.h>
#include <math.h>

typedef float32x4_t __m128;

static inline __m128 _mm_set_ss(float a) {
    float32x4_t v = vdupq_n_f32(0.0f);
    return vsetq_lane_f32(a, v, 0);
}

static inline int _mm_cvtss_si32(__m128 a) {
    return (int)roundf(vgetq_lane_f32(a, 0));
}

#ifndef _mm_prefetch
#define _mm_prefetch(p, hint) __builtin_prefetch((p))
#endif

#endif // __arm64__

#endif // __APPLE__
