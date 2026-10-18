#pragma once

#if defined(__APPLE__)

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sched.h>
#include <stdarg.h>
#include <fcntl.h>
#include <float.h>
#include <math.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include <sys/time.h>

#ifndef _time64
#define _time64 time
#endif

#ifndef _localtime64
#define _localtime64 localtime
#endif

#ifndef _gmtime64
#define _gmtime64 gmtime
#endif

#ifndef _ctime64
#define _ctime64 ctime
#endif

#ifdef __cplusplus
#include <new>
#endif

#ifndef _snprintf
#define _snprintf snprintf
#endif

#ifndef _vsnprintf
#define _vsnprintf vsnprintf
#endif

static inline char *_itoa(int value, char *buffer, int radix) {
    if (!buffer) return NULL;
    if (radix == 10) {
        sprintf(buffer, "%d", value);
    } else if (radix == 16) {
        sprintf(buffer, "%x", (unsigned int)value);
    } else if (radix == 8) {
        sprintf(buffer, "%o", (unsigned int)value);
    } else {
        char *p = buffer;
        unsigned int uval = (radix == 10 && value < 0) ? (unsigned int)(-value) : (unsigned int)value;
        if (radix == 10 && value < 0) {
            *p++ = '-';
        }
        char temp[64];
        int i = 0;
        do {
            int rem = uval % radix;
            temp[i++] = (rem < 10) ? ('0' + rem) : ('a' + rem - 10);
            uval /= radix;
        } while (uval > 0);
        while (i > 0) {
            *p++ = temp[--i];
        }
        *p = '\0';
    }
    return buffer;
}

static inline char *_ltoa(long value, char *buffer, int radix) {
    return _itoa((int)value, buffer, radix);
}

static inline char *_ui64toa(uint64_t value, char *buffer, int radix) {
    if (!buffer) return NULL;
    if (radix == 10) {
        sprintf(buffer, "%llu", (unsigned long long)value);
    } else if (radix == 16) {
        sprintf(buffer, "%llx", (unsigned long long)value);
    } else if (radix == 8) {
        sprintf(buffer, "%llo", (unsigned long long)value);
    } else {
        char *p = buffer;
        char temp[64];
        int i = 0;
        do {
            int rem = (int)(value % radix);
            temp[i++] = (rem < 10) ? ('0' + rem) : ('a' + rem - 10);
            value /= radix;
        } while (value > 0);
        while (i > 0) {
            *p++ = temp[--i];
        }
        *p = '\0';
    }
    return buffer;
}

static inline char *_i64toa(int64_t value, char *buffer, int radix) {
    if (!buffer) return NULL;
    if (radix == 10) {
        sprintf(buffer, "%lld", (long long)value);
    } else {
        return _ui64toa((uint64_t)value, buffer, radix);
    }
    return buffer;
}

// Desactivar static_assert específicos de tamaño de puntero de 32 bits en arquitecturas 64-bit
#if defined(__LP64__) || defined(_WIN64) || defined(__aarch64__)
#define static_assert(...)
#endif

// ----- Tipos básicos de Win32 -----
typedef uint32_t      DWORD;
typedef uint16_t      WORD;
typedef uint8_t       BYTE;
typedef int           BOOL;
typedef void*         HANDLE;
typedef HANDLE*        LPHANDLE;

struct HWND__ { int unused; };
typedef struct HWND__* HWND;

struct HINSTANCE__ { int unused; };
typedef struct HINSTANCE__* HINSTANCE;

struct HMODULE__ { int unused; };
typedef struct HMODULE__* HMODULE;

typedef void*         LPVOID;
typedef void*         PVOID;
typedef const void*   LPCVOID;
typedef char*         LPSTR;
typedef const char*   LPCSTR;
typedef wchar_t       WCHAR;
typedef wchar_t*      LPWSTR;
typedef const wchar_t* LPCWSTR;
typedef uint64_t      DWORD64;
typedef uint64_t*     PDWORD64;
typedef int32_t       LONG;
typedef int64_t       LONG64;
typedef uint32_t      ULONG;
typedef uint64_t      ULONG64;
typedef int64_t       LONGLONG;
typedef uint64_t      ULONGLONG;
typedef uint32_t      UINT;
typedef int32_t       INT;
typedef uint32_t      UINT32;
typedef int32_t       INT32;
typedef uint16_t      UINT16;
typedef int16_t       INT16;
typedef uint8_t       UINT8;
typedef int8_t        INT8;
typedef uint64_t      UINT64;
typedef int64_t       INT64;
typedef uintptr_t     DWORD_PTR;
typedef uintptr_t     ULONG_PTR;
typedef int32_t       HRESULT;
typedef DWORD*        LPDWORD;
typedef BOOL*         LPBOOL;
typedef BYTE*         LPBYTE;
typedef LONG*         PLONG;

typedef struct _OVERLAPPED {
    uintptr_t Internal;
    uintptr_t InternalHigh;
    union {
        struct {
            DWORD Offset;
            DWORD OffsetHigh;
        };
        PVOID Pointer;
    };
    HANDLE hEvent;
} OVERLAPPED, *LPOVERLAPPED;

typedef void (*LPOVERLAPPED_COMPLETION_ROUTINE)(DWORD dwErrorCode, DWORD dwNumberOfBytesTransfered, LPOVERLAPPED lpOverlapped);

typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
} FILETIME, *PFILETIME, *LPFILETIME;

static inline void GetSystemTimeAsFileTime(LPFILETIME lpSystemTimeAsFileTime) {
    if (!lpSystemTimeAsFileTime) return;
    struct timeval tv;
    gettimeofday(&tv, NULL);
    uint64_t t = ((uint64_t)tv.tv_sec * 10000000ULL) + ((uint64_t)tv.tv_usec * 10ULL) + 116444736000000000ULL;
    lpSystemTimeAsFileTime->dwLowDateTime = (DWORD)t;
    lpSystemTimeAsFileTime->dwHighDateTime = (DWORD)(t >> 32);
}

static inline LONG CompareFileTime(const FILETIME *lpFileTime1, const FILETIME *lpFileTime2) {
    if (!lpFileTime1 || !lpFileTime2) return 0;
    uint64_t t1 = ((uint64_t)lpFileTime1->dwHighDateTime << 32) | lpFileTime1->dwLowDateTime;
    uint64_t t2 = ((uint64_t)lpFileTime2->dwHighDateTime << 32) | lpFileTime2->dwLowDateTime;
    if (t1 < t2) return -1;
    if (t1 > t2) return 1;
    return 0;
}

struct HMONITOR__ { int unused; };
typedef struct HMONITOR__* HMONITOR;

struct HDC__ { int unused; };
typedef struct HDC__* HDC;

typedef struct tagRECT {
    LONG left;
    LONG top;
    LONG right;
    LONG bottom;
} RECT, *PRECT, *LPRECT;

typedef struct tagPOINT {
    LONG x;
    LONG y;
} POINT, *PPOINT, *LPPOINT;

typedef union _LARGE_INTEGER {
    struct {
        DWORD LowPart;
        LONG HighPart;
    };
    struct {
        DWORD LowPart;
        LONG HighPart;
    } u;
    LONGLONG QuadPart;
} LARGE_INTEGER, *PLARGE_INTEGER;

typedef struct _GUID {
    uint32_t Data1;
    uint16_t Data2;
    uint16_t Data3;
    uint8_t  Data4[8];
} GUID;
typedef const GUID *LPCGUID;
typedef GUID IID;
#ifdef __cplusplus
typedef const GUID &REFGUID;
typedef const IID &REFIID;
#endif

typedef struct _SYSTEMTIME {
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
} SYSTEMTIME, *PSYSTEMTIME, *LPSYSTEMTIME;

static inline BOOL SystemTimeToFileTime(const SYSTEMTIME *lpSystemTime, LPFILETIME lpFileTime) {
    if (!lpFileTime) return 0;
    GetSystemTimeAsFileTime(lpFileTime);
    return 1;
}

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

#ifndef WINAPI
#define WINAPI
#endif

#ifndef __stdcall
#define __stdcall
#endif

#ifndef __cdecl
#define __cdecl
#endif

#ifndef CALLBACK
#define CALLBACK
#endif

#ifndef S_OK
#define S_OK ((HRESULT)0L)
#endif

#ifndef S_FALSE
#define S_FALSE ((HRESULT)1L)
#endif

#ifndef FAILED
#define FAILED(hr) (((HRESULT)(hr)) < 0)
#endif

#ifndef SUCCEEDED
#define SUCCEEDED(hr) (((HRESULT)(hr)) >= 0)
#endif

#ifndef E_POINTER
#define E_POINTER ((HRESULT)0x80004003L)
#endif

#ifndef E_FAIL
#define E_FAIL ((HRESULT)0x80004005L)
#endif

#ifndef E_INVALIDARG
#define E_INVALIDARG ((HRESULT)0x80070057L)
#endif

#ifndef E_NOTIMPL
#define E_NOTIMPL ((HRESULT)0x80004001L)
#endif

#ifndef MAX_PATH
#define MAX_PATH 260
#endif

// ----- Sincronización POSIX equivalente a CRITICAL_SECTION -----
typedef pthread_mutex_t CRITICAL_SECTION;
typedef pthread_mutex_t _RTL_CRITICAL_SECTION;
typedef pthread_mutex_t* LPCRITICAL_SECTION;

static inline void InitializeCriticalSection(CRITICAL_SECTION *cs) {
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(cs, &attr);
    pthread_mutexattr_destroy(&attr);
}

static inline void EnterCriticalSection(CRITICAL_SECTION *cs) {
    pthread_mutex_lock(cs);
}

static inline void LeaveCriticalSection(CRITICAL_SECTION *cs) {
    pthread_mutex_unlock(cs);
}

static inline void DeleteCriticalSection(CRITICAL_SECTION *cs) {
    pthread_mutex_destroy(cs);
}

// ----- Operaciones atómicas y barreras de memoria -----
#define InterlockedIncrement(x) __sync_add_and_fetch((x), 1)
#define InterlockedDecrement(x) __sync_sub_and_fetch((x), 1)
#define InterlockedExchange(target, value) __sync_lock_test_and_set((target), (value))
#define InterlockedCompareExchange(destination, exchange, comperand) __sync_val_compare_and_swap((destination), (comperand), (exchange))

#define _InterlockedIncrement(x) __sync_add_and_fetch((x), 1)
#define _InterlockedDecrement(x) __sync_sub_and_fetch((x), 1)
#define _InterlockedExchange(target, value) __sync_lock_test_and_set((target), (value))
#define _InterlockedCompareExchange(destination, exchange, comperand) __sync_val_compare_and_swap((destination), (comperand), (exchange))
#define _InterlockedCompareExchange64(destination, exchange, comperand) __sync_val_compare_and_swap((destination), (comperand), (exchange))

#ifndef MemoryBarrier
#define MemoryBarrier() __sync_synchronize()
#endif

#ifndef _ReadWriteBarrier
#define _ReadWriteBarrier() __asm__ __volatile__("" ::: "memory")
#endif

// ----- Hilos y tiempo -----
static inline void Sleep(DWORD dwMilliseconds) {
    usleep(dwMilliseconds * 1000);
}

static inline BOOL SwitchToThread(void) {
    sched_yield();
    return 1;
}

static inline DWORD GetCurrentThreadId(void) {
    return (DWORD)(uintptr_t)pthread_self();
}

static inline HANDLE GetCurrentProcess(void) {
    return (HANDLE)(intptr_t)-1;
}

static inline DWORD GetCurrentProcessId(void) {
    return (DWORD)getpid();
}

static inline BOOL CloseHandle(HANDLE hObject) {
    return 1;
}

typedef struct _MEMORYSTATUS {
    DWORD dwLength;
    DWORD dwMemoryLoad;
    size_t dwTotalPhys;
    size_t dwAvailPhys;
    size_t dwTotalPageFile;
    size_t dwAvailPageFile;
    size_t dwTotalVirtual;
    size_t dwAvailVirtual;
} MEMORYSTATUS, *LPMEMORYSTATUS;

static inline void GlobalMemoryStatus(MEMORYSTATUS *lpBuffer) {
    if (lpBuffer) {
        memset(lpBuffer, 0, sizeof(*lpBuffer));
        lpBuffer->dwLength = sizeof(*lpBuffer);
        lpBuffer->dwTotalPhys = 1024ULL * 1024ULL * 1024ULL;
        lpBuffer->dwAvailPhys = 512ULL * 1024ULL * 1024ULL;
    }
}

static inline BOOL QueryPerformanceCounter(LARGE_INTEGER *lpPerformanceCount) {
    if (lpPerformanceCount) {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        lpPerformanceCount->QuadPart = (LONGLONG)ts.tv_sec * 1000000000ULL + (LONGLONG)ts.tv_nsec;
        return 1;
    }
    return 0;
}

static inline BOOL QueryPerformanceFrequency(LARGE_INTEGER *lpFrequency) {
    if (lpFrequency) {
        lpFrequency->QuadPart = 1000000000ULL;
        return 1;
    }
    return 0;
}

#ifndef INVALID_HANDLE_VALUE
#define INVALID_HANDLE_VALUE ((HANDLE)(intptr_t)-1)
#endif

static inline HANDLE CreateFileA(const char *lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, void *lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile) {
    if (!lpFileName) return INVALID_HANDLE_VALUE;
    char path[1024];
    strncpy(path, lpFileName, sizeof(path) - 1);
    path[sizeof(path) - 1] = '\0';
    for (char *p = path; *p; p++) {
        if (*p == '\\') *p = '/';
    }
    int flags = O_RDONLY;
    if (dwDesiredAccess & 0x40000000) {
        flags = O_RDWR | O_CREAT;
    }
    int fd = open(path, flags, 0644);
    if (fd < 0) return INVALID_HANDLE_VALUE;
    return (HANDLE)(intptr_t)(fd + 1);
}

static inline DWORD GetFileSize(HANDLE hFile, LPDWORD lpFileSizeHigh) {
    intptr_t val = (intptr_t)hFile;
    if (val <= 0) return 0xFFFFFFFF;
    int fd = (int)(val - 1);
    off_t cur = lseek(fd, 0, SEEK_CUR);
    off_t end = lseek(fd, 0, SEEK_END);
    lseek(fd, cur, SEEK_SET);
    if (lpFileSizeHigh) *lpFileSizeHigh = (DWORD)(end >> 32);
    return (DWORD)end;
}

static inline BOOL ReadFile(HANDLE hFile, void *lpBuffer, DWORD nNumberOfBytesToRead, LPDWORD lpNumberOfBytesRead, void *lpOverlapped) {
    intptr_t val = (intptr_t)hFile;
    if (val <= 0 || !lpBuffer) return 0;
    int fd = (int)(val - 1);
    ssize_t n = read(fd, lpBuffer, nNumberOfBytesToRead);
    if (n < 0) return 0;
    if (lpNumberOfBytesRead) *lpNumberOfBytesRead = (DWORD)n;
    return 1;
}

static inline BOOL ReadFileEx(HANDLE hFile, void *lpBuffer, DWORD nNumberOfBytesToRead, LPOVERLAPPED lpOverlapped, LPOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine) {
    intptr_t val = (intptr_t)hFile;
    if (val <= 0 || !lpBuffer) return 0;
    int fd = (int)(val - 1);
    if (lpOverlapped) {
        off_t offset = ((off_t)lpOverlapped->OffsetHigh << 32) | lpOverlapped->Offset;
        lseek(fd, offset, SEEK_SET);
    }
    ssize_t n = read(fd, lpBuffer, nNumberOfBytesToRead);
    if (n < 0) return 0;
    if (lpCompletionRoutine) {
        lpCompletionRoutine(0, (DWORD)n, lpOverlapped);
    }
    return 1;
}

static inline HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId) {
    return (HANDLE)(intptr_t)-1;
}

static inline void OutputDebugStringA(const char *lpOutputString) {
    fputs(lpOutputString, stderr);
}

#ifndef CREATE_SUSPENDED
#define CREATE_SUSPENDED 0x00000004
#endif

#ifndef WAIT_OBJECT_0
#define WAIT_OBJECT_0 0
#endif
#ifndef WAIT_TIMEOUT
#define WAIT_TIMEOUT 258L
#endif
#ifndef INFINITE
#define INFINITE 0xFFFFFFFF
#endif

typedef struct Win32Event Win32Event;
struct Win32Event {
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    bool manualReset;
    bool state;
};

static inline HANDLE CreateEventA(void *lpEventAttributes, BOOL bManualReset, BOOL bInitialState, const char *lpName) {
    Win32Event *ev = (Win32Event *)malloc(sizeof(Win32Event));
    if (!ev) return NULL;
    pthread_mutex_init(&ev->mutex, NULL);
    pthread_cond_init(&ev->cond, NULL);
    ev->manualReset = bManualReset != 0;
    ev->state = bInitialState != 0;
    return (HANDLE)ev;
}

static inline BOOL SetEvent(HANDLE hEvent) {
    if (!hEvent) return 0;
    Win32Event *ev = (Win32Event *)hEvent;
    pthread_mutex_lock(&ev->mutex);
    ev->state = true;
    if (ev->manualReset) {
        pthread_cond_broadcast(&ev->cond);
    } else {
        pthread_cond_signal(&ev->cond);
    }
    pthread_mutex_unlock(&ev->mutex);
    return 1;
}

static inline BOOL ResetEvent(HANDLE hEvent) {
    if (!hEvent) return 0;
    Win32Event *ev = (Win32Event *)hEvent;
    pthread_mutex_lock(&ev->mutex);
    ev->state = false;
    pthread_mutex_unlock(&ev->mutex);
    return 1;
}

static inline DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds) {
    if (!hHandle) return WAIT_TIMEOUT;
    Win32Event *ev = (Win32Event *)hHandle;
    pthread_mutex_lock(&ev->mutex);

    if (dwMilliseconds == 0) {
        DWORD res = ev->state ? WAIT_OBJECT_0 : WAIT_TIMEOUT;
        if (ev->state && !ev->manualReset) {
            ev->state = false;
        }
        pthread_mutex_unlock(&ev->mutex);
        return res;
    }

    if (dwMilliseconds == INFINITE) {
        while (!ev->state) {
            pthread_cond_wait(&ev->cond, &ev->mutex);
        }
        if (!ev->manualReset) {
            ev->state = false;
        }
        pthread_mutex_unlock(&ev->mutex);
        return WAIT_OBJECT_0;
    }

    struct timeval now;
    gettimeofday(&now, NULL);
    struct timespec ts;
    uint64_t ns = (uint64_t)now.tv_usec * 1000ULL + (uint64_t)dwMilliseconds * 1000000ULL;
    ts.tv_sec = now.tv_sec + (time_t)(ns / 1000000000ULL);
    ts.tv_nsec = (long)(ns % 1000000000ULL);

    while (!ev->state) {
        int r = pthread_cond_timedwait(&ev->cond, &ev->mutex, &ts);
        if (r != 0) {
            pthread_mutex_unlock(&ev->mutex);
            return WAIT_TIMEOUT;
        }
    }
    if (!ev->manualReset) {
        ev->state = false;
    }
    pthread_mutex_unlock(&ev->mutex);
    return WAIT_OBJECT_0;
}

typedef DWORD (WINAPI *LPTHREAD_START_ROUTINE)(LPVOID lpThreadParameter);

typedef struct Win32Thread Win32Thread;
struct Win32Thread {
    pthread_t thread;
    LPTHREAD_START_ROUTINE startRoutine;
    LPVOID param;
    pthread_mutex_t suspendMutex;
    pthread_cond_t suspendCond;
    bool suspended;
};

static inline void *Win32ThreadProc(void *arg) {
    Win32Thread *th = (Win32Thread *)arg;
    pthread_mutex_lock(&th->suspendMutex);
    while (th->suspended) {
        pthread_cond_wait(&th->suspendCond, &th->suspendMutex);
    }
    pthread_mutex_unlock(&th->suspendMutex);
    th->startRoutine(th->param);
    return NULL;
}

static inline HANDLE CreateThread(void *lpThreadAttributes, size_t dwStackSize, LPTHREAD_START_ROUTINE lpStartAddress, LPVOID lpParameter, DWORD dwCreationFlags, LPDWORD lpThreadId) {
    Win32Thread *th = (Win32Thread *)malloc(sizeof(Win32Thread));
    if (!th) return NULL;
    th->startRoutine = lpStartAddress;
    th->param = lpParameter;
    th->suspended = (dwCreationFlags & CREATE_SUSPENDED) != 0;
    pthread_mutex_init(&th->suspendMutex, NULL);
    pthread_cond_init(&th->suspendCond, NULL);

    pthread_attr_t attr;
    pthread_attr_init(&attr);
    if (dwStackSize > 0) {
        pthread_attr_setstacksize(&attr, dwStackSize);
    }

    int err = pthread_create(&th->thread, &attr, Win32ThreadProc, th);
    pthread_attr_destroy(&attr);
    if (err != 0) {
        free(th);
        return NULL;
    }
    if (lpThreadId) {
        *lpThreadId = (DWORD)(uintptr_t)th->thread;
    }
    return (HANDLE)th;
}

static inline DWORD ResumeThread(HANDLE hThread) {
    if (!hThread) return (DWORD)-1;
    Win32Thread *th = (Win32Thread *)hThread;
    pthread_mutex_lock(&th->suspendMutex);
    if (th->suspended) {
        th->suspended = false;
        pthread_cond_broadcast(&th->suspendCond);
    }
    pthread_mutex_unlock(&th->suspendMutex);
    return 1;
}

static inline HANDLE GetCurrentThread(void) {
    return (HANDLE)(intptr_t)-2;
}

static inline BOOL DuplicateHandle(HANDLE hSourceProcessHandle, HANDLE hSourceHandle, HANDLE hTargetProcessHandle, LPHANDLE lpTargetHandle, DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwOptions) {
    if (lpTargetHandle) *lpTargetHandle = hSourceHandle;
    return 1;
}

static inline DWORD SetThreadIdealProcessor(HANDLE hThread, DWORD dwIdealProcessor) {
    return 0;
}

static inline BOOL GetProcessAffinityMask(HANDLE hProcess, LPDWORD lpProcessAffinityMask, LPDWORD lpSystemAffinityMask) {
    if (lpProcessAffinityMask) *lpProcessAffinityMask = 0xFFFFFFFF;
    if (lpSystemAffinityMask) *lpSystemAffinityMask = 0xFFFFFFFF;
    return 1;
}

static inline DWORD_PTR SetThreadAffinityMask(HANDLE hThread, DWORD_PTR dwThreadAffinityMask) {
    return 1;
}

static inline BOOL SetThreadPriority(HANDLE hThread, int nPriority) {
    return 1;
}

static inline DWORD GetLastError(void) {
    return 0;
}

static inline void SetLastError(DWORD dwErrCode) {}

static inline void RaiseException(DWORD dwExceptionCode, DWORD dwExceptionFlags, DWORD nNumberOfArguments, const ULONG_PTR *lpArguments) {
}

#ifndef LittleShort
#define LittleShort(l) (l)
#endif
#ifndef LittleLong
#define LittleLong(l) (l)
#endif
#ifndef LittleFloat
#define LittleFloat(l) (l)
#endif

#endif // __APPLE__
