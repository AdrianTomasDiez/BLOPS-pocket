#if defined(__APPLE__)

#include "win_types_compat.h"
#include <win32/win_local.h>
#include <win32/win_common.h>
#include <win32/win_main.h>
#include <qcommon/common.h>
#include <universal/q_shared.h>

#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <time.h>

// ----- Critical sections -----
_RTL_CRITICAL_SECTION s_criticalSection[75];

void __cdecl Sys_InitializeCriticalSections()
{
    for (int i = 0; i < 75; i++)
    {
        InitializeCriticalSection(&s_criticalSection[i]);
    }
}

void __cdecl Sys_EnterCriticalSection(CriticalSection critSect)
{
    if ((int)critSect >= 0 && (int)critSect < 75)
    {
        EnterCriticalSection(&s_criticalSection[critSect]);
    }
}

void __cdecl Sys_LeaveCriticalSection(CriticalSection critSect)
{
    if ((int)critSect >= 0 && (int)critSect < 75)
    {
        LeaveCriticalSection(&s_criticalSection[critSect]);
    }
}

// ----- Directorios y rutas -----
static char s_cwd[512] = "";
static char s_installPath[512] = "";

void __cdecl Sys_Mkdir(const char *path)
{
    mkdir(path, 0755);
}

char *__cdecl Sys_Cwd()
{
    if (!s_cwd[0])
    {
        getcwd(s_cwd, sizeof(s_cwd) - 1);
    }
    return s_cwd;
}

const char *__cdecl Sys_DefaultCDPath()
{
    return "";
}

char *__cdecl Sys_DefaultInstallPath()
{
    if (!s_installPath[0])
    {
        const char *home = getenv("HOME");
        if (home)
        {
            snprintf(s_installPath, sizeof(s_installPath), "%s/Documents/Games", home);
        }
        else
        {
            strncpy(s_installPath, ".", sizeof(s_installPath));
        }
    }
    return s_installPath;
}

// ----- Tiempo -----
int __cdecl Sys_Milliseconds()
{
    static uint64_t s_start = 0;
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    uint64_t now = (uint64_t)ts.tv_sec * 1000 + (uint64_t)ts.tv_nsec / 1000000;
    if (!s_start)
    {
        s_start = now;
    }
    return (int)(now - s_start);
}

// ----- Salida de texto y errores -----
void __cdecl Sys_Print(char *msg)
{
    fputs(msg, stdout);

    const char *home = getenv("HOME");
    if (home) {
        char logPath[1024];
        snprintf(logPath, sizeof(logPath), "%s/Documents/Games/bo1_console.log", home);
        FILE *f = fopen(logPath, "a");
        if (f) {
            fputs(msg, f);
            fclose(f);
        }
    }
}

void Sys_Error(char *error, ...)
{
    char buffer[4096];
    va_list argptr;
    va_start(argptr, error);
    vsnprintf(buffer, sizeof(buffer), error, argptr);
    va_end(argptr);

    fprintf(stderr, "\n[BO1 NATIVE FATAL ERROR]: %s\n\n", buffer);

    const char *home = getenv("HOME");
    if (home) {
        char logPath[1024];
        snprintf(logPath, sizeof(logPath), "%s/Documents/Games/bo1_error.log", home);
        FILE *f = fopen(logPath, "a");
        if (f) {
            fprintf(f, "\n[BO1 NATIVE FATAL ERROR]: %s\n\n", buffer);
            fclose(f);
        }
    }

    abort();
}

void __cdecl Sys_Quit()
{
    exit(0);
}

void Sys_SpawnQuitProcess()
{
    exit(0);
}

void __cdecl Sys_NormalExit()
{
    exit(0);
}

char *__cdecl Sys_GetClipboardData()
{
    return (char *)"";
}

void __cdecl Sys_LoadingKeepAlive()
{
}

// ----- Cola de eventos -----
#define MAX_SYS_EVENTS 256
static sysEvent_t s_eventQueue[MAX_SYS_EVENTS];
static int s_eventHead = 0;
static int s_eventTail = 0;

void __cdecl Sys_QueEvent(unsigned int time, sysEventType_t type, int value, int value2, int ptrLength, void *ptr)
{
    sysEvent_t *ev = &s_eventQueue[s_eventHead & (MAX_SYS_EVENTS - 1)];
    ev->evTime = (int)time;
    ev->evType = type;
    ev->evValue = value;
    ev->evValue2 = value2;
    ev->evPtrLength = ptrLength;
    ev->evPtr = ptr;
    s_eventHead++;
}

sysEvent_t *__cdecl Sys_GetEvent(sysEvent_t *result)
{
    if (s_eventTail >= s_eventHead)
    {
        memset(result, 0, sizeof(*result));
        result->evTime = Sys_Milliseconds();
        return result;
    }
    *result = s_eventQueue[s_eventTail & (MAX_SYS_EVENTS - 1)];
    s_eventTail++;
    return result;
}

sysEvent_t *__cdecl Win_GetEvent(sysEvent_t *result)
{
    return Sys_GetEvent(result);
}

void Sys_ShutdownEvents()
{
    s_eventHead = 0;
    s_eventTail = 0;
}

// ----- Información del sistema -----
int s_nosnd = 0;
SysInfo sys_info;
bool g_allowMature = true;

const dvar_t *sys_configureGHz = nullptr;
const dvar_t *sys_sysMB = nullptr;
const dvar_t *sys_gpu = nullptr;
const dvar_t *sys_configSum = nullptr;
const dvar_t *sys_SSE = nullptr;

bool __cdecl PC_StartWithNoSounds() { return false; }
bool __cdecl Sys_IsHeadless() { return false; }
bool __cdecl Sys_IsHeadlessClient() { return false; }
void __cdecl Sys_HeadlessNoteHud(int pmType, bool hudDrawn) {}
void __cdecl Sys_HeadlessTimeline(const char *what) {}
void __cdecl Sys_HeadlessLevelNotify(const char *name) {}
void __cdecl Sys_HeadlessLogAssert(const char *filename, int line, const char *message) {}
unsigned int __cdecl Sys_HitchWatchBegin() { return 0; }
void __cdecl Sys_HitchWatchEnd() {}
void __cdecl Sys_SetQuitRequested() {}
bool __cdecl Sys_IsQuitRequested() { return false; }
void __cdecl Sys_QuitWithLostDevice(int lostMs) {}
unsigned int __cdecl Sys_FramePerfHitchMs() { return 0; }
int __cdecl Sys_CheckCrashOrRerun() { return 1; }
int Sys_GetSemaphoreFileName() { return 0; }
void Win_RegisterClass() {}
void PrintWorkingDir() {}
char __cdecl CheckRemoteSession() { return 0; }
bool __cdecl StartingDedicatedServer(char *cmdline) { return false; }

void Sys_FindInfo()
{
    sys_info.logicalCpuCount = 6;
    sys_info.cpuGHz = 3.2;
    sys_info.sysMB = 4096;
    strncpy(sys_info.gpuDescription, "Apple GPU Metal", sizeof(sys_info.gpuDescription) - 1);
    sys_info.SSE = 0;
    strncpy(sys_info.cpuVendor, "Apple", sizeof(sys_info.cpuVendor) - 1);
    strncpy(sys_info.cpuName, "Apple Silicon ARM64", sizeof(sys_info.cpuName) - 1);
}

void Sys_RegisterInfoDvars() {}
bool __cdecl Sys_HasInfoChanged() { return false; }
bool __cdecl Sys_ShouldUpdateForInfoChange() { return false; }
void __cdecl Sys_ArchiveInfo(int checksum) {}
void __cdecl Sys_DirectXFatalError()
{
    Sys_Error((char *)"Fatal rendering error");
}
void __cdecl Sys_OutOfMemErrorInternal(const char *filename, int line)
{
    Sys_Error((char *)"Out of memory at %s:%d", filename, line);
}
void __cdecl Sys_QuitAndStartProcess(const char *exeName) { exit(0); }
void __cdecl Sys_OpenURL(const char *url, int doexit) {}
void Sys_NoFreeFilesError()
{
    Sys_Error((char *)"Sys_NoFreeFilesError: No free files");
}
int __cdecl Sys_IsGameProcess(unsigned int id) { return 1; }

void __cdecl Sys_Init() {}
void __cdecl Sys_In_Restart_f() {}
void __cdecl Sys_Net_Restart_f() {}
void __cdecl Sys_Mjpeg() {}
void __cdecl Sys_MjpegClose() {}

#endif // __APPLE__
