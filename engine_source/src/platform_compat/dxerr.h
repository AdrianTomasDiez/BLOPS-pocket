#pragma once

#include <stdint.h>
#include <stdio.h>

#if defined(__cplusplus)
extern "C" {
#endif

static inline const char *DXGetErrorDescriptionA(int32_t hr) {
    (void)hr;
    return "DirectX OK";
}

static inline const char *DXGetErrorStringA(int32_t hr) {
    (void)hr;
    return "D3D_OK";
}

#if defined(__cplusplus)
}
#endif
