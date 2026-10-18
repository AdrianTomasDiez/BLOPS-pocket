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

static inline void OutputDebugStringA(const char *lpOutputString) {
    fputs(lpOutputString, stderr);
}

#endif // __APPLE__
