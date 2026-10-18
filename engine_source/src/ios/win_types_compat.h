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
#include <sys/stat.h>
#include <sys/types.h>
#include <ctype.h>
#include <strings.h>
#include <setjmp.h>

typedef FILE _iobuf;

static inline int64_t _time64(int64_t *t) {
    time_t tt = 0;
    time_t res = time(&tt);
    if (t) *t = (int64_t)tt;
    return (int64_t)res;
}

static inline struct tm *_localtime64(const int64_t *t) {
    if (!t) return NULL;
    time_t tt = (time_t)*t;
    return localtime(&tt);
}

static inline struct tm *_gmtime64(const int64_t *t) {
    if (!t) return NULL;
    time_t tt = (time_t)*t;
    return gmtime(&tt);
}

static inline char *_ctime64(const int64_t *t) {
    if (!t) return NULL;
    time_t tt = (time_t)*t;
    return ctime(&tt);
}

#ifdef __cplusplus
#include <new>
#endif

typedef int (*_CoreCrtNonSecureSearchSortCompareFunction)(const void *, const void *);

#ifndef _snprintf
#define _snprintf snprintf
#endif

#ifndef _vsnprintf
#define _vsnprintf vsnprintf
#endif

#define strcpy_s(dst, size, src) strncpy((dst), (src), (size))
#define sprintf_s(buf, size, ...) snprintf((buf), (size), __VA_ARGS__)

#ifndef _TRUNCATE
#define _TRUNCATE ((size_t)-1)
#endif

#define _snprintf_s(buf, size, count, ...) snprintf((buf), (size), __VA_ARGS__)
#define strncpy_s(dst, size, src, count) strncpy((dst), (src), (size))


#ifndef min
#define min(a,b) (((a)<(b))?(a):(b))
#endif
#ifndef max
#define max(a,b) (((a)>(b))?(a):(b))
#endif

#ifndef _stricmp
#define _stricmp strcasecmp
#endif

#ifndef _strnicmp
#define _strnicmp strncasecmp
#endif

#ifndef stricmp
#define stricmp strcasecmp
#endif

#ifndef strnicmp
#define strnicmp strncasecmp
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

static inline int64_t _atoi64(const char *str) {
    return str ? (int64_t)strtoll(str, NULL, 10) : 0;
}

static inline int64_t _strtoi64(const char *str, char **endptr, int base) {
    return str ? (int64_t)strtoll(str, endptr, base) : 0;
}

static inline uint64_t _strtoui64(const char *str, char **endptr, int base) {
    return str ? (uint64_t)strtoull(str, endptr, base) : 0;
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
typedef HINSTANCE HMODULE;

struct HMENU__ { int unused; };
typedef struct HMENU__* HMENU;

typedef void*         LPVOID;
typedef void*         PVOID;
typedef const void*   LPCVOID;
typedef char*         LPSTR;
typedef const char*   LPCSTR;
typedef char          CHAR;
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
typedef uintptr_t     WPARAM;
typedef intptr_t      LPARAM;
typedef intptr_t      LRESULT;
typedef int32_t       HRESULT;
typedef DWORD*        LPDWORD;
typedef BOOL*         LPBOOL;
typedef BYTE*         LPBYTE;
typedef LONG*         PLONG;
typedef ULONG*        PULONG;

#ifndef CONST
#define CONST const
#endif

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

typedef struct _RGNDATAHEADER {
    DWORD dwSize;
    DWORD iType;
    DWORD nCount;
    DWORD nRgnSize;
    RECT  rcBound;
} RGNDATAHEADER;

typedef struct _RGNDATA {
    RGNDATAHEADER rdh;
    char          Buffer[1];
} RGNDATA, *PRGNDATA, *NPRGNDATA, *LPRGNDATA;

typedef struct tagPALETTEENTRY {
    BYTE peRed;
    BYTE peGreen;
    BYTE peBlue;
    BYTE peFlags;
} PALETTEENTRY, *PPALETTEENTRY, *LPPALETTEENTRY;

typedef struct tagMONITORINFO {
    DWORD cbSize;
    RECT  rcMonitor;
    RECT  rcWork;
    DWORD dwFlags;
} MONITORINFO, *LPMONITORINFO;

typedef struct tagPOINT {
    LONG x;
    LONG y;
} POINT, *PPOINT, *LPPOINT;

#ifndef MONITOR_DEFAULTTONULL
#define MONITOR_DEFAULTTONULL    0x00000000
#endif
#ifndef MONITOR_DEFAULTTOPRIMARY
#define MONITOR_DEFAULTTOPRIMARY 0x00000001
#endif
#ifndef MONITOR_DEFAULTTONEAREST
#define MONITOR_DEFAULTTONEAREST 0x00000002
#endif

static inline HMONITOR MonitorFromWindow(HWND hwnd, DWORD dwFlags) {
    (void)hwnd; (void)dwFlags;
    return (HMONITOR)(intptr_t)1;
}

static inline HMONITOR MonitorFromPoint(POINT pt, DWORD dwFlags) {
    (void)pt; (void)dwFlags;
    return (HMONITOR)(intptr_t)1;
}

static inline BOOL GetMonitorInfoA(HMONITOR hMonitor, LPMONITORINFO lpmi) {
    (void)hMonitor;
    if (!lpmi) return 0;
    lpmi->rcMonitor.left = 0;
    lpmi->rcMonitor.top = 0;
    lpmi->rcMonitor.right = 1920;
    lpmi->rcMonitor.bottom = 1080;
    lpmi->rcWork = lpmi->rcMonitor;
    lpmi->dwFlags = 1;
    return 1;
}

static inline BOOL ClientToScreen(HWND hWnd, LPPOINT lpPoint) {
    (void)hWnd; (void)lpPoint;
    return 1;
}

static inline BOOL GetClientRect(HWND hWnd, LPRECT lpRect) {
    (void)hWnd;
    if (lpRect) {
        lpRect->left = 0;
        lpRect->top = 0;
        lpRect->right = 1920;
        lpRect->bottom = 1080;
    }
    return 1;
}

#ifndef SM_CXSCREEN
#define SM_CXSCREEN 0
#endif
#ifndef SM_CYSCREEN
#define SM_CYSCREEN 1
#endif

static inline int GetSystemMetrics(int nIndex) {
    if (nIndex == SM_CXSCREEN) return 1920;
    if (nIndex == SM_CYSCREEN) return 1080;
    return 0;
}

#ifndef GWL_STYLE
#define GWL_STYLE (-16)
#endif
#ifndef GWL_EXSTYLE
#define GWL_EXSTYLE (-20)
#endif

static inline LONG GetWindowLongA(HWND hWnd, int nIndex) {
    (void)hWnd; (void)nIndex;
    return 0;
}

static inline LONG SetWindowLongA(HWND hWnd, int nIndex, LONG dwNewLong) {
    (void)hWnd; (void)nIndex; (void)dwNewLong;
    return 0;
}

#ifndef WS_POPUP
#define WS_POPUP 0x80000000L
#endif

#ifndef WS_VISIBLE
#define WS_VISIBLE 0x10000000L
#endif

#ifndef HWND_NOTOPMOST
#define HWND_NOTOPMOST ((HWND)(intptr_t)-2)
#endif
#ifndef HWND_TOPMOST
#define HWND_TOPMOST   ((HWND)(intptr_t)-1)
#endif
#ifndef HWND_TOP
#define HWND_TOP       ((HWND)(intptr_t)0)
#endif
#ifndef HWND_BOTTOM
#define HWND_BOTTOM    ((HWND)(intptr_t)1)
#endif

static inline HWND SetFocus(HWND hWnd) {
    (void)hWnd;
    return hWnd;
}

#ifndef SWP_NOSIZE
#define SWP_NOSIZE 0x0001
#endif
#ifndef SWP_NOMOVE
#define SWP_NOMOVE 0x0002
#endif
#ifndef SWP_NOZORDER
#define SWP_NOZORDER 0x0004
#endif
#ifndef SWP_SHOWWINDOW
#define SWP_SHOWWINDOW 0x0040
#endif

static inline BOOL AdjustWindowRectEx(LPRECT lpRect, DWORD dwStyle, BOOL bMenu, DWORD dwExStyle) {
    (void)lpRect; (void)dwStyle; (void)bMenu; (void)dwExStyle;
    return 1;
}

static inline BOOL SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int X, int Y, int cx, int cy, UINT uFlags) {
    (void)hWnd; (void)hWndInsertAfter; (void)X; (void)Y; (void)cx; (void)cy; (void)uFlags;
    return 1;
}

static inline BOOL ShowWindow(HWND hWnd, int nCmdShow) {
    (void)hWnd; (void)nCmdShow;
    return 1;
}

static inline BOOL IsWindow(HWND hWnd) {
    (void)hWnd;
    return 1;
}

static inline BOOL DestroyWindow(HWND hWnd) {
    (void)hWnd;
    return 1;
}

static inline BOOL IsIconic(HWND hWnd) {
    (void)hWnd;
    return 0;
}

static inline HWND GetForegroundWindow(void) {
    static struct HWND__ dummyHwnd;
    return &dummyHwnd;
}

static inline BOOL IsProcessDPIAware(void) {
    return 1;
}

typedef const RECT *LPCRECT;
typedef BOOL (*MONITORENUMPROC)(HMONITOR, HDC, LPRECT, LPARAM);

static inline BOOL EnumDisplayMonitors(HDC hdc, LPCRECT lprcClip, MONITORENUMPROC lpfnEnum, LPARAM dwData) {
    (void)hdc; (void)lprcClip;
    if (lpfnEnum) {
        RECT rc = { 0, 0, 1920, 1080 };
        lpfnEnum((HMONITOR)(intptr_t)1, (HDC)(intptr_t)1, &rc, dwData);
    }
    return 1;
}

static inline HMODULE GetModuleHandleA(LPCSTR lpModuleName) {
    (void)lpModuleName;
    return (HMODULE)(intptr_t)1;
}

static inline void *GetProcAddress(HMODULE hModule, LPCSTR lpProcName) {
    (void)hModule; (void)lpProcName;
    return NULL;
}

typedef struct tagMSG {
    HWND   hwnd;
    UINT   message;
    WPARAM wParam;
    LPARAM lParam;
    DWORD  time;
    POINT  pt;
} MSG, *PMSG, *LPMSG;

static inline BOOL PeekMessageA(LPMSG lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg) {
    (void)lpMsg; (void)hWnd; (void)wMsgFilterMin; (void)wMsgFilterMax; (void)wRemoveMsg;
    return 0;
}

static inline BOOL GetMessageA(LPMSG lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax) {
    (void)lpMsg; (void)hWnd; (void)wMsgFilterMin; (void)wMsgFilterMax;
    return 0;
}

static inline BOOL TranslateMessage(const MSG *lpMsg) {
    (void)lpMsg;
    return 0;
}

static inline LRESULT DispatchMessageA(const MSG *lpMsg) {
    (void)lpMsg;
    return 0;
}

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

static inline void GetSystemTime(SYSTEMTIME *lpSystemTime) {
    if (!lpSystemTime) return;
    time_t rawtime;
    time(&rawtime);
    struct tm *ti = gmtime(&rawtime);
    if (ti) {
        lpSystemTime->wYear = ti->tm_year + 1900;
        lpSystemTime->wMonth = ti->tm_mon + 1;
        lpSystemTime->wDayOfWeek = ti->tm_wday;
        lpSystemTime->wDay = ti->tm_mday;
        lpSystemTime->wHour = ti->tm_hour;
        lpSystemTime->wMinute = ti->tm_min;
        lpSystemTime->wSecond = ti->tm_sec;
        lpSystemTime->wMilliseconds = 0;
    }
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
#define InterlockedCompareExchangePointer(destination, exchange, comperand) __sync_val_compare_and_swap((destination), (comperand), (exchange))
#define InterlockedExchangePointer(target, value) __sync_lock_test_and_set((target), (value))
#define InterlockedExchangeAdd(addend, value) __sync_fetch_and_add((addend), (value))

#define _InterlockedIncrement(x) __sync_add_and_fetch((x), 1)
#define _InterlockedDecrement(x) __sync_sub_and_fetch((x), 1)
#define _InterlockedExchange(target, value) __sync_lock_test_and_set((target), (value))
#define _InterlockedCompareExchange(destination, exchange, comperand) __sync_val_compare_and_swap((destination), (comperand), (exchange))
#define _InterlockedCompareExchangePointer(destination, exchange, comperand) __sync_val_compare_and_swap((destination), (comperand), (exchange))
#define _InterlockedExchangePointer(target, value) __sync_lock_test_and_set((target), (value))
#define _InterlockedExchangeAdd(addend, value) __sync_fetch_and_add((addend), (value))
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

static inline DWORD SleepEx(DWORD dwMilliseconds, BOOL bAlertable) {
    (void)bAlertable;
    if (dwMilliseconds == 0xFFFFFFFF || dwMilliseconds == (DWORD)-1) {
        // En Windows, SleepEx(INFINITE, TRUE) espera hasta que se ejecute la rutina de completado APC.
        // En nuestro shim POSIX, ReadFileEx ejecuta el callback síncronamente al leer,
        // por lo que no debe bloquearse en un bucle infinito. Retornar WAIT_IO_COMPLETION (0x000000C0L).
        return 0x000000C0L;
    }
    usleep(dwMilliseconds * 1000);
    return 0;
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

static inline void ExitProcess(UINT uExitCode) {
    exit((int)uExitCode);
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

#define MEM_COMMIT             0x00001000
#define MEM_RESERVE            0x00002000
#define MEM_DECOMMIT           0x00004000
#define MEM_RELEASE            0x00008000
#define MEM_RESET              0x00080000
#define PAGE_NOACCESS          0x01
#define PAGE_READONLY          0x02
#define PAGE_READWRITE         0x04
#define PAGE_EXECUTE           0x10
#define PAGE_EXECUTE_READ      0x20
#define PAGE_EXECUTE_READWRITE 0x40

static inline void *VirtualAlloc(void *lpAddress, size_t dwSize, DWORD flAllocationType, DWORD flProtect) {
    (void)flAllocationType;
    (void)flProtect;
    if (lpAddress) {
        return lpAddress;
    }
    void *ptr = malloc(dwSize);
    if (ptr) {
        memset(ptr, 0, dwSize);
    }
    return ptr;
}

static inline BOOL VirtualFree(void *lpAddress, size_t dwSize, DWORD dwFreeType) {
    (void)dwSize;
    (void)dwFreeType;
    if (lpAddress) {
        free(lpAddress);
    }
    return 1;
}

static inline BOOL VirtualProtect(void *lpAddress, size_t dwSize, DWORD flNewProtect, DWORD *lpflOldProtect) {
    (void)lpAddress;
    (void)dwSize;
    (void)flNewProtect;
    if (lpflOldProtect) *lpflOldProtect = PAGE_READWRITE;
    return 1;
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

#ifndef INVALID_FILE_ATTRIBUTES
#define INVALID_FILE_ATTRIBUTES ((DWORD)-1)
#endif
#define FILE_ATTRIBUTE_READONLY             0x00000001
#define FILE_ATTRIBUTE_HIDDEN               0x00000002
#define FILE_ATTRIBUTE_SYSTEM               0x00000004
#define FILE_ATTRIBUTE_DIRECTORY            0x00000010
#define FILE_ATTRIBUTE_ARCHIVE              0x00000020
#define FILE_ATTRIBUTE_NORMAL               0x00000080

#ifdef __cplusplus
extern "C" {
#endif
const char *bo1_ios_get_gamedir(void);
#ifdef __cplusplus
}
#endif

static inline DWORD GetFileAttributesA(const char *lpFileName) {
    if (!lpFileName || !*lpFileName) return INVALID_FILE_ATTRIBUTES;
    char path[1024];
    strncpy(path, lpFileName, sizeof(path) - 1);
    path[sizeof(path) - 1] = '\0';
    for (char *p = path; *p; p++) {
        if (*p == '\\') *p = '/';
    }
    struct stat st;
    if (stat(path, &st) != 0) {
        const char *slash = strrchr(path, '/');
        const char *base = slash ? slash + 1 : path;
        const char *gdir = bo1_ios_get_gamedir();
        if (gdir && gdir[0]) {
            char alt[1024];
            snprintf(alt, sizeof(alt), "%s/%s", gdir, base);
            if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
            snprintf(alt, sizeof(alt), "%s/zone/%s", gdir, base);
            if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
            snprintf(alt, sizeof(alt), "%s/zone/Common/%s", gdir, base);
            if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
        }
        if (strstr(base, ".ff")) {
            const char *home = getenv("HOME");
            if (home) {
                char alt[1024];
                snprintf(alt, sizeof(alt), "%s/Documents/Games/Call of Duty Black Ops/%s", home, base);
                if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
                snprintf(alt, sizeof(alt), "%s/Documents/Games/Call of Duty Black Ops/zone/%s", home, base);
                if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
                snprintf(alt, sizeof(alt), "%s/Documents/Games/Call of Duty Black Ops/zone/Common/%s", home, base);
                if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;

                snprintf(alt, sizeof(alt), "%s/Documents/Games/%s", home, base);
                if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
                snprintf(alt, sizeof(alt), "%s/Documents/Games/zone/%s", home, base);
                if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
                snprintf(alt, sizeof(alt), "%s/Documents/Games/zone/Common/%s", home, base);
                if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;

                snprintf(alt, sizeof(alt), "%s/Documents/%s", home, base);
                if (stat(alt, &st) == 0) return S_ISDIR(st.st_mode) ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
            }
        }
        return INVALID_FILE_ATTRIBUTES;
    }
    if (S_ISDIR(st.st_mode)) return FILE_ATTRIBUTE_DIRECTORY;
    return FILE_ATTRIBUTE_NORMAL;
}

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
        // Asegurar que el directorio padre existe para escrituras
        char dir[1024];
        strncpy(dir, path, sizeof(dir) - 1);
        dir[sizeof(dir) - 1] = '\0';
        char *lastSlash = strrchr(dir, '/');
        if (lastSlash) {
            *lastSlash = '\0';
            mkdir(dir, 0755);
        }
    }
    int fd = open(path, flags, 0644);
    if (fd < 0) {
        const char *slash = strrchr(path, '/');
        const char *base = slash ? slash + 1 : path;
        const char *gdir = bo1_ios_get_gamedir();
        if (gdir && gdir[0]) {
            char alt[1024];
            snprintf(alt, sizeof(alt), "%s/%s", gdir, base);
            fd = open(alt, flags, 0644);
            if (fd < 0) {
                snprintf(alt, sizeof(alt), "%s/zone/%s", gdir, base);
                fd = open(alt, flags, 0644);
            }
            if (fd < 0) {
                snprintf(alt, sizeof(alt), "%s/zone/Common/%s", gdir, base);
                fd = open(alt, flags, 0644);
            }
        }
        if (fd < 0 && strstr(base, ".ff")) {
            const char *home = getenv("HOME");
            if (home) {
                char alt[1024];
                snprintf(alt, sizeof(alt), "%s/Documents/Games/Call of Duty Black Ops/%s", home, base);
                fd = open(alt, flags, 0644);
                if (fd < 0) {
                    snprintf(alt, sizeof(alt), "%s/Documents/Games/Call of Duty Black Ops/zone/%s", home, base);
                    fd = open(alt, flags, 0644);
                }
                if (fd < 0) {
                    snprintf(alt, sizeof(alt), "%s/Documents/Games/Call of Duty Black Ops/zone/Common/%s", home, base);
                    fd = open(alt, flags, 0644);
                }
                if (fd < 0) {
                    snprintf(alt, sizeof(alt), "%s/Documents/Games/%s", home, base);
                    fd = open(alt, flags, 0644);
                }
                if (fd < 0) {
                    snprintf(alt, sizeof(alt), "%s/Documents/Games/zone/%s", home, base);
                    fd = open(alt, flags, 0644);
                }
                if (fd < 0) {
                    snprintf(alt, sizeof(alt), "%s/Documents/Games/zone/Common/%s", home, base);
                    fd = open(alt, flags, 0644);
                }
                if (fd < 0) {
                    snprintf(alt, sizeof(alt), "%s/Documents/%s", home, base);
                    fd = open(alt, flags, 0644);
                }
            }
        }
    }
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

static inline DWORD SetFilePointer(HANDLE hFile, LONG lDistanceToMove, PLONG lpDistanceToMoveHigh, DWORD dwMoveMethod) {
    intptr_t val = (intptr_t)hFile;
    if (val <= 0) return 0xFFFFFFFF;
    int fd = (int)(val - 1);
    off_t dist = (off_t)lDistanceToMove;
    if (lpDistanceToMoveHigh) {
        dist |= ((off_t)*lpDistanceToMoveHigh << 32);
    }
    int whence = SEEK_SET;
    if (dwMoveMethod == 1) whence = SEEK_CUR;
    else if (dwMoveMethod == 2) whence = SEEK_END;
    off_t res = lseek(fd, dist, whence);
    if (res == (off_t)-1) return 0xFFFFFFFF;
    if (lpDistanceToMoveHigh) {
        *lpDistanceToMoveHigh = (LONG)(res >> 32);
    }
    return (DWORD)res;
}

static inline BOOL WriteFile(HANDLE hFile, LPCVOID lpBuffer, DWORD nNumberOfBytesToWrite, LPDWORD lpNumberOfBytesWritten, void *lpOverlapped) {
    intptr_t val = (intptr_t)hFile;
    if (val <= 0 || !lpBuffer) return 0;
    int fd = (int)(val - 1);
    ssize_t n = write(fd, lpBuffer, nNumberOfBytesToWrite);
    if (n < 0) return 0;
    if (lpNumberOfBytesWritten) *lpNumberOfBytesWritten = (DWORD)n;
    return 1;
}

static inline HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId) {
    return (HANDLE)(intptr_t)-1;
}

static inline void OutputDebugStringA(const char *lpOutputString) {
    fputs(lpOutputString, stderr);
}

#ifndef MAX_PATH
#define MAX_PATH 260
#endif

typedef struct _WIN32_FIND_DATAA {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    dwReserved0;
    DWORD    dwReserved1;
    CHAR     cFileName[MAX_PATH];
    CHAR     cAlternateFileName[14];
} WIN32_FIND_DATAA, *PWIN32_FIND_DATAA, *LPWIN32_FIND_DATAA;

static inline HANDLE FindFirstFileA(LPCSTR lpFileName, LPWIN32_FIND_DATAA lpFindFileData) {
    (void)lpFileName; (void)lpFindFileData;
    return (HANDLE)(intptr_t)-1;
}

static inline BOOL FindNextFileA(HANDLE hFindFile, LPWIN32_FIND_DATAA lpFindFileData) {
    (void)hFindFile; (void)lpFindFileData;
    return 0;
}

static inline BOOL FindClose(HANDLE hFindFile) {
    (void)hFindFile;
    return 1;
}

static inline BOOL DeleteFileA(LPCSTR lpFileName) {
    if (!lpFileName) return 0;
    return unlink(lpFileName) == 0;
}

static inline BOOL RemoveDirectoryA(LPCSTR lpPathName) {
    if (!lpPathName) return 0;
    return rmdir(lpPathName) == 0;
}

static inline DWORD GetFullPathNameA(LPCSTR lpFileName, DWORD nBufferLength, LPSTR lpBuffer, LPSTR *lpFilePart) {
    if (!lpFileName || !lpBuffer || nBufferLength == 0) return 0;
    if (realpath(lpFileName, lpBuffer)) {
        if (lpFilePart) {
            char *lastSlash = strrchr(lpBuffer, '/');
            *lpFilePart = lastSlash ? lastSlash + 1 : lpBuffer;
        }
        return (DWORD)strlen(lpBuffer);
    }
    strncpy(lpBuffer, lpFileName, nBufferLength - 1);
    lpBuffer[nBufferLength - 1] = '\0';
    if (lpFilePart) {
        char *lastSlash = strrchr(lpBuffer, '/');
        *lpFilePart = lastSlash ? lastSlash + 1 : lpBuffer;
    }
    return (DWORD)strlen(lpBuffer);
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

typedef pthread_mutex_t SRWLOCK, *PSRWLOCK;
#define SRWLOCK_INIT PTHREAD_MUTEX_INITIALIZER

static inline void InitializeSRWLock(PSRWLOCK SRWLock) {
    if (SRWLock) pthread_mutex_init(SRWLock, NULL);
}

static inline void AcquireSRWLockExclusive(PSRWLOCK SRWLock) {
    if (SRWLock) pthread_mutex_lock(SRWLock);
}

static inline void ReleaseSRWLockExclusive(PSRWLOCK SRWLock) {
    if (SRWLock) pthread_mutex_unlock(SRWLock);
}

static inline void AcquireSRWLockShared(PSRWLOCK SRWLock) {
    if (SRWLock) pthread_mutex_lock(SRWLock);
}

static inline void ReleaseSRWLockShared(PSRWLOCK SRWLock) {
    if (SRWLock) pthread_mutex_unlock(SRWLock);
}

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

static inline HANDLE CreateMutexA(void *lpMutexAttributes, BOOL bInitialOwner, const char *lpName) {
    (void)lpMutexAttributes; (void)lpName;
    return CreateEventA(NULL, FALSE, !bInitialOwner, NULL);
}

static inline BOOL ReleaseMutex(HANDLE hMutex) {
    if (!hMutex) return 0;
    Win32Event *ev = (Win32Event *)hMutex;
    pthread_mutex_lock(&ev->mutex);
    ev->state = true;
    pthread_cond_signal(&ev->cond);
    pthread_mutex_unlock(&ev->mutex);
    return 1;
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

#ifndef EXCEPTION_EXECUTE_HANDLER
#define EXCEPTION_EXECUTE_HANDLER 1
#endif

typedef struct _EXCEPTION_RECORD _EXCEPTION_RECORD;
typedef struct _CONTEXT _CONTEXT;
typedef struct _EXCEPTION_POINTERS {
    _EXCEPTION_RECORD *ExceptionRecord;
    _CONTEXT *ContextRecord;
} _EXCEPTION_POINTERS, *PEXCEPTION_POINTERS;

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

static inline DWORD SuspendThread(HANDLE hThread) {
    if (!hThread) return (DWORD)-1;
    Win32Thread *th = (Win32Thread *)hThread;
    pthread_mutex_lock(&th->suspendMutex);
    th->suspended = true;
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

static inline int ShowCursor(BOOL bShow) {
    (void)bShow;
    return 0;
}

static inline DWORD GetLastError(void) {
    return 0;
}

static inline void RaiseException(DWORD dwExceptionCode, DWORD dwExceptionFlags, DWORD nNumberOfArguments, const ULONG_PTR *lpArguments) {
}

static inline const char *GetCommandLineA(void) {
    return "+set bo1_zombies 1 +devmap zombie_theater";
}

static inline HWND CreateWindowExA(DWORD dwExStyle, const char *lpClassName, const char *lpWindowName, DWORD dwStyle, int X, int Y, int nWidth, int nHeight, HWND hWndParent, HMENU hMenu, HINSTANCE hInstance, LPVOID lpParam) {
    static struct HWND__ dummyHwnd;
    return &dummyHwnd;
}

static inline int MessageBoxA(HWND hWnd, const char *lpText, const char *lpCaption, UINT uType) {
    fprintf(stderr, "[BO1 MSG BOX] %s: %s\n", lpCaption ? lpCaption : "Alert", lpText ? lpText : "");
    return 1;
}

static inline DWORD GetCurrentDirectoryA(DWORD nBufferLength, char *lpBuffer) {
    if (lpBuffer && nBufferLength > 0) {
        if (getcwd(lpBuffer, nBufferLength)) {
            return (DWORD)strlen(lpBuffer);
        }
        lpBuffer[0] = '\0';
    }
    return 0;
}

static inline uintptr_t ShellExecuteA(HWND hwnd, const char *lpOperation, const char *lpFile, const char *lpParameters, const char *lpDirectory, int nShowCmd) {
    return 42;
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

#if defined(__arm64__) || defined(__aarch64__)
#ifndef _mm_prefetch
#define _mm_prefetch(p, hint) __builtin_prefetch((p))
#endif
static inline void _mm_empty(void) {}
static inline void _m_empty(void) {}
#endif

#endif // __APPLE__
