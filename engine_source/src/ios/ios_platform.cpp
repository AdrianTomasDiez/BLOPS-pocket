#if defined(__APPLE__)

#include "win_types_compat.h"
#include <win32/win_local.h>
#include <win32/win_common.h>
#include <win32/win_main.h>
#include <qcommon/common.h>
#include <universal/q_shared.h>
#include "ios_engine_bridge.h"

#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <time.h>
#include <signal.h>
#include <execinfo.h>

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
    const char *gdir = bo1_ios_get_gamedir();
    if (gdir && gdir[0])
    {
        strncpy(s_installPath, gdir, sizeof(s_installPath) - 1);
        s_installPath[sizeof(s_installPath) - 1] = '\0';
        return s_installPath;
    }
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

extern "C" const char *bo1_ios_get_gamedir(void);

// ----- Salida de texto y errores -----
// ----- Salida de texto y errores -----
static void write_to_log_file(const char *path, const char *text)
{
    if (!path || !path[0]) return;
    FILE *f = fopen(path, "a");
    if (f) {
        fputs(text, f);
        fflush(f);
        fclose(f);
    }
}

void __cdecl Sys_Print(char *msg)
{
    fputs(msg, stdout);

    const char *home = getenv("HOME");
    if (home) {
        char log1[1024];
        char log2[1024];
        char blopsDir[1024];
        snprintf(log1, sizeof(log1), "%s/Documents/bo1_console.log", home);
        snprintf(blopsDir, sizeof(blopsDir), "%s/Documents/BLOPS", home);
        mkdir(blopsDir, 0755);
        snprintf(log2, sizeof(log2), "%s/Documents/BLOPS/bo1_console.log", home);
        write_to_log_file(log1, msg);
        write_to_log_file(log2, msg);
    }

    const char *gdir = bo1_ios_get_gamedir();
    if (gdir && gdir[0]) {
        char log3[1024];
        snprintf(log3, sizeof(log3), "%s/bo1_console.log", gdir);
        write_to_log_file(log3, msg);
    }
}

void Sys_Error(char *error, ...)
{
    char buffer[4096];
    va_list argptr;
    va_start(argptr, error);
    vsnprintf(buffer, sizeof(buffer), error, argptr);
    va_end(argptr);

    char errText[4200];
    snprintf(errText, sizeof(errText), "\n[BO1 NATIVE FATAL ERROR]: %s\n\n", buffer);
    fprintf(stderr, "%s", errText);

    Sys_Print(errText);

    bo1_ios_set_error(buffer);

    const char *home = getenv("HOME");
    if (home) {
        char log1[1024];
        char log2[1024];
        snprintf(log1, sizeof(log1), "%s/Documents/bo1_error.log", home);
        snprintf(log2, sizeof(log2), "%s/Documents/BLOPS/bo1_error.log", home);
        write_to_log_file(log1, errText);
        write_to_log_file(log2, errText);
    }

    // Esperar brevemente para permitir a la UI de SwiftUI mostrar el banner de error
    for (int i = 0; i < 50; ++i) {
        usleep(100000);
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

void __cdecl Sys_HeadlessLogAssert(const char *filename, int line, const char *message)
{
    char buf[2048];
    snprintf(buf, sizeof(buf), "\n[BO1 ASSERTION FAILED] %s:%d: %s\n", filename ? filename : "unknown", line, message ? message : "");
    fprintf(stderr, "%s", buf);
    Sys_Print(buf);
    bo1_ios_set_error(buf);
}

static void bo1_crash_signal_handler(int sig, siginfo_t *info, void *ucontext)
{
    signal(sig, SIG_DFL);

    const char *sigName = "UNKNOWN";
    switch (sig) {
        case SIGSEGV: sigName = "SIGSEGV (Segmentation Fault / Bad Memory Access)"; break;
        case SIGBUS:  sigName = "SIGBUS (Bus Error / Alignment)"; break;
        case SIGABRT: sigName = "SIGABRT (Abort)"; break;
        case SIGILL:  sigName = "SIGILL (Illegal Instruction)"; break;
        case SIGFPE:  sigName = "SIGFPE (Floating Point Exception)"; break;
        case SIGTRAP: sigName = "SIGTRAP (Trap / Breakpoint / Assert)"; break;
    }

    char crashMsg[4096];
    snprintf(crashMsg, sizeof(crashMsg),
             "\n=======================================================\n"
             "[BO1 NATIVE CRASH] Caught signal %d: %s\n"
             "Faulting address: %p\n"
             "=======================================================\n",
             sig, sigName, info ? info->si_addr : nullptr);

    fprintf(stderr, "%s", crashMsg);
    Sys_Print(crashMsg);

    void *callstack[64];
    int frames = backtrace(callstack, 64);
    char **symbols = backtrace_symbols(callstack, frames);
    if (symbols) {
        Sys_Print((char *)"[BO1 Callstack]:\n");
        for (int i = 0; i < frames; ++i) {
            char lineBuf[512];
            snprintf(lineBuf, sizeof(lineBuf), "  [%02d] %s\n", i, symbols[i]);
            Sys_Print(lineBuf);
            fprintf(stderr, "%s", lineBuf);
        }
        free(symbols);
    }

    bo1_ios_set_error(crashMsg);

    usleep(500000);
    _exit(128 + sig);
}

void Sys_InstallCrashHandlers()
{
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = bo1_crash_signal_handler;
    sa.sa_flags = SA_SIGINFO | SA_RESETHAND;

    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGFPE, &sa, NULL);
    sigaction(SIGTRAP, &sa, NULL);

    Sys_Print((char *)"[BO1 iOS] Posix crash & assert signal handlers installed successfully\n");
}

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
