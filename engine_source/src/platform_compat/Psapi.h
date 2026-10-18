#pragma once

#if defined(__APPLE__)
#include <ios/win_types_compat.h>

typedef struct _PROCESS_MEMORY_COUNTERS {
    DWORD  cb;
    DWORD  PageFaultCount;
    size_t PeakWorkingSetSize;
    size_t WorkingSetSize;
    size_t QuotaPeakPagedPoolUsage;
    size_t QuotaPagedPoolUsage;
    size_t QuotaPeakNonPagedPoolUsage;
    size_t QuotaNonPagedPoolUsage;
    size_t PagefileUsage;
    size_t PeakPagefileUsage;
} PROCESS_MEMORY_COUNTERS, *PPROCESS_MEMORY_COUNTERS;

typedef struct _PROCESS_MEMORY_COUNTERS_EX {
    DWORD  cb;
    DWORD  PageFaultCount;
    size_t PeakWorkingSetSize;
    size_t WorkingSetSize;
    size_t QuotaPeakPagedPoolUsage;
    size_t QuotaPagedPoolUsage;
    size_t QuotaPeakNonPagedPoolUsage;
    size_t QuotaNonPagedPoolUsage;
    size_t PagefileUsage;
    size_t PeakPagefileUsage;
    size_t PrivateUsage;
} PROCESS_MEMORY_COUNTERS_EX, *PPROCESS_MEMORY_COUNTERS_EX;

static inline BOOL GetProcessMemoryInfo(HANDLE Process, PPROCESS_MEMORY_COUNTERS ppsmemCounters, DWORD cb) {
    if (ppsmemCounters) {
        memset(ppsmemCounters, 0, cb);
        ppsmemCounters->cb = cb;
        ppsmemCounters->WorkingSetSize = 64 * 1024 * 1024;
        ppsmemCounters->PeakWorkingSetSize = 64 * 1024 * 1024;
    }
    return TRUE;
}

#ifndef K32GetProcessMemoryInfo
#define K32GetProcessMemoryInfo GetProcessMemoryInfo
#endif

#endif // __APPLE__
