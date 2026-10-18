#pragma once

#include <stdlib.h>

#if defined(__APPLE__)
#include <malloc/malloc.h>

static inline void* _aligned_malloc(size_t size, size_t alignment) {
    void *ptr = NULL;
    size_t align = alignment < sizeof(void*) ? sizeof(void*) : alignment;
    if (posix_memalign(&ptr, align, size) != 0) {
        return NULL;
    }
    return ptr;
}

static inline void _aligned_free(void *ptr) {
    free(ptr);
}

static inline void* _aligned_realloc(void *ptr, size_t size, size_t alignment) {
    void *new_ptr = _aligned_malloc(size, alignment);
    if (new_ptr && ptr) {
        memcpy(new_ptr, ptr, size);
        _aligned_free(ptr);
    }
    return new_ptr;
}

#endif // __APPLE__
