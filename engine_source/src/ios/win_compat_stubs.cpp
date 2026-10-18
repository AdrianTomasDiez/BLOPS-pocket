#if defined(__APPLE__)

#include "win_types_compat.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include <universal/q_shared.h>
#include <qcommon/threads.h>
#include <tl/jobqueue/jobqueue_all.h>
#include <universal/com_workercmds.h>
#include <win32/win_workercmds.h>
#include <win32/win_gamerprofile.h>
#include <win32/win_gamepad.h>
#include <gfx_d3d/r_model_skin.h>
#include <gfx_d3d/r_buffers.h>
#include <sound/snd_local.h>

// ---------------------------------------------------------
// 1. Endianness
// ---------------------------------------------------------
extern "C" __int16 __cdecl BigShort(__int16 l)
{
    return (short)ShortSwap(l);
}

// ---------------------------------------------------------
// 2. Localization
// ---------------------------------------------------------
extern "C" char *__cdecl Win_GetLanguage()
{
    static char s_lang[] = "english";
    return s_lang;
}

// ---------------------------------------------------------
// 3. Worker commands / Multithreading / Tasks
// ---------------------------------------------------------
int __cdecl SetupWorkerThread(jqBatch *batch)
{
    Sys_InitThread(batch->ParamData[0] + 2);
    return 0;
}

volatile unsigned int nuge_physicsLimit = 1;
jqModule nuge_physicsModule =
{
    .Name = "nuge_physics",
    .Type = JQ_WORKER_GENERIC,
    .Code = nuge_physicsCallback,
};
jqWorkerCmd nuge_physicsWorkerCmd = { &nuge_physicsModule, sizeof(jqBatch), 0, 0, &nuge_physicsLimit, NULL, 0u};

jqModule setup_worker_threadsModule =
{
    .Name = "setup_worker_threads",
    .Type = JQ_WORKER_GENERIC,
    .Code = SetupWorkerThread,
};

int __cdecl nuge_physicsCallback(jqBatch *batch)
{
    jqBatch *realbatch = (jqBatch *)jqLockData(batch);
    if (realbatch && realbatch->Module && realbatch->Module->Code)
    {
        realbatch->Module->Code(realbatch);
    }
    jqUnlockData(batch);
    return 0;
}

void __cdecl IW_task_manager_add_batch(jqBatch *ptr)
{
    if (ptr) {
        Sys_AddWorkerCmdInternal(&nuge_physicsWorkerCmd, (unsigned __int8 *)ptr, 0);
    }
}

void __cdecl IW_task_manager_flush()
{
    Sys_WaitWorkerCmdInternal(&nuge_physicsWorkerCmd);
}

void __cdecl R_InitWorkerCmds()
{
    jqInit();
    jqEnableWorkers(4);
    jqSetBatchDataHeapSize(0x4000u, 0x10u);
    jqStart();

    jqBatch batch;
    batch.Module = &setup_worker_threadsModule;
    batch.ParamData[0] = 0;
    jqAddBatch(&batch, jqGetWorkerQueue(4));

    batch.ParamData[0] = 1;
    jqAddBatch(&batch, jqGetWorkerQueue(8));

    jqFlush(0, 0);
    Sys_InitWorkerThreadContext();
    Sys_WorkerCmdInit();
}

void __cdecl R_InitWorkerThreads()
{
    R_InitWorkerCmds();
}

void __cdecl TaskManager_ClearOverlappedTasks(overlappedTask *tasks) {}

// ---------------------------------------------------------
// 4. Content / DLC
// ---------------------------------------------------------
int __cdecl Content_GetAvailableContentPacks()
{
    return 2;
}

// ---------------------------------------------------------
// 5. Gamer Profile
// ---------------------------------------------------------
static GamerSettingState s_iosGamerSettings;

GamerSettingState *__cdecl GamerProfile_GetProfileSettings(int controllerIndex)
{
    return &s_iosGamerSettings;
}

bool __cdecl GamerProfile_IsProfileLoggedIn(int controllerIndex)
{
    return true;
}

void __cdecl GamerProfile_LogInProfile(int controllerIndex) {}
void __cdecl GamerProfile_UpdateDvarsFromProfile(int controllerIndex) {}
void __cdecl GamerProfile_UpdateProfileFromDvars(int controllerIndex, profileWriteState_t profileWriteState) {}
void __cdecl GamerProfile_ExecControllerBindings(int controllerIndex) {}
int __cdecl GamerProfile_GetPlaylistNum(int controllerIndex) { return 0; }
void __cdecl GamerProfile_SetPlaylistNum(int controllerIndex, int playlistNum) {}

// ---------------------------------------------------------
// 6. GamePad / Input
// ---------------------------------------------------------
const dvar_t *gpad_enabled = nullptr;

bool __cdecl GPad_IsActive(int controllerIndex) { return false; }
bool __cdecl GPad_GetButton(int controllerIndex, GamePadButton button) { return false; }
bool __cdecl GPad_IsButtonPressed(int controllerIndex, GamePadButton button) { return false; }
float __cdecl GPad_GetStick(int controllerIndex, GamePadStick stick) { return 0.0f; }

void __cdecl IN_Frame() {}
void __cdecl IN_SetCursorPos(unsigned int x, unsigned int y) {}

// ---------------------------------------------------------
// 7. Network / Sockets
// ---------------------------------------------------------
void __cdecl NET_Init() {}
void __cdecl NET_Sleep(unsigned int msec) {}
void __cdecl NET_RestartDebug() {}
void __cdecl NET_ShutdownDebug() {}
int __cdecl Sys_GetPacket(netadr_t *net_from, msg_t *net_message) { return 0; }
char __cdecl Sys_SendPacket(unsigned int length, unsigned __int8 *data, netadr_t to) { return 1; }
int __cdecl Sys_StringToAdr(const char *s, netadr_t *a) { return 0; }
int __cdecl Sys_IsLANAddress(netadr_t adr) { return 1; }
void __cdecl Sys_CheckForNATOverflow() {}
int __cdecl Sys_SocketPool_GetPacket(netadr_t *net_from, msg_t *net_message) { return 0; }
int __cdecl Sys_IsRemoteDebugServer() { return 0; }
bool __cdecl Sys_DebugSocketReady(int channel) { return false; }
void __cdecl Sys_AckDebugSocket() {}
void __cdecl Sys_EndWriteDebugSocket() {}
void __cdecl Sys_FlushDebugSocketData() {}
int __cdecl Sys_ReadDebugSocketInt() { return 0; }
char *__cdecl Sys_ReadDebugSocketString() { return (char *)""; }
int __cdecl Sys_UpdateDebugSocket() { return 0; }
void __cdecl Sys_WriteDebugSocketData(unsigned char *buf, int len) {}
void __cdecl Sys_WriteDebugSocketInt(int v) {}
void __cdecl Sys_WriteDebugSocketMessageType(unsigned char type) {}
void __cdecl Sys_WriteDebugSocketString(char *text) {}

// ---------------------------------------------------------
// 8. Sound (SD_ / Voice_)
// ---------------------------------------------------------
char __cdecl SD_Init() { return 1; }
void __cdecl SD_Shutdown() {}
void __cdecl SD_PreUpdate() {}
void __cdecl SD_UpdateVoice(unsigned int index) {}
void __cdecl SD_StopVoice(int index) {}
void __cdecl SD_PauseVoice(int index) {}
void __cdecl SD_UnpauseVoice(int index) {}
void __cdecl SD_BO1SamplesPlayed(int count) {}
void __cdecl SD_StartAlias(SndStartAliasInfo *info, unsigned int index) {}
void __cdecl SD_TruncateAudioDeviceNames(Font_s *font, float scale, int width) {}

void __cdecl Voice_Init() {}
void __cdecl Voice_Shutdown() {}
void __cdecl Voice_Playback() {}
int __cdecl Voice_GetLocalVoiceData() { return 0; }
int __cdecl Voice_GetVoiceLevel() { return 0; }
void __cdecl Voice_IncomingVoiceData(unsigned char clientNum, unsigned char *data, int size) {}
bool __cdecl Voice_IsClientTalking(unsigned int clientNum) { return false; }
void __cdecl Voice_StopClientSamples() {}

// ---------------------------------------------------------
// 9. Streaming / Splash / Misc Sys
// ---------------------------------------------------------
void __cdecl Stream_Init() {}
void __cdecl Sys_DestroySplashWindow() {}
void __cdecl Sys_HideSplashWindow() {}
void __cdecl Sys_ShowConsole() {}
void __cdecl Sys_UpdateHotkeyBlock() {}
bool __cdecl Sys_DirectoryHasContents(char const *path) { return false; }
bool __cdecl Sys_HasConfigureChecksumChanged(int sum) { return false; }
int __cdecl Sys_ListFiles(char *directory, char *extension, char *filter, int *numfiles, int flag)
{
    if (numfiles) *numfiles = 0;
    return 0;
}
unsigned int __cdecl Sys_MillisecondsRaw()
{
    return (unsigned int)Sys_Milliseconds();
}
void __cdecl Sys_SnapVector(float *v)
{
    if (v) {
        v[0] = (float)(int)v[0];
        v[1] = (float)(int)v[1];
        v[2] = (float)(int)v[2];
    }
}
bool __cdecl Sys_TryEnterCriticalSection(CriticalSection critSect)
{
    Sys_EnterCriticalSection(critSect);
    return true;
}

// ---------------------------------------------------------
// 10. Monkey / QA Testing Harness
// ---------------------------------------------------------
void __cdecl Monkey_DisconnectAndExit() {}
void __cdecl Monkey_ShutdownCommunication() {}
bool __cdecl Monkey_Recv(char *type, int type_size, char *string, int string_size) { return false; }

// ---------------------------------------------------------
// 11. Live & Steam
// ---------------------------------------------------------
int __cdecl Live_GetClientNumForXuid(SessionData_s const *session, unsigned long long xuid) { return -1; }

bool _g_steamAPIInitialized = false;
bool _g_steamInitialized = false;

void __cdecl Steam_CancelClientTicket() {}
bool __cdecl Steam_CheckClientTicket(void const *ticket, unsigned int ticketSize, unsigned long long steamID) { return true; }
void __cdecl Steam_CheckClients() {}
unsigned long long __cdecl Steam_GetClientSteamID64() { return 0ULL; }
void __cdecl Steam_GetRawClientTicket(unsigned char **ticket, unsigned int *ticketSize)
{
    if (ticket) *ticket = NULL;
    if (ticketSize) *ticketSize = 0;
}
void __cdecl Steam_OnClientDropped(unsigned long long steamID) {}

extern "C" {
void *__cdecl SteamAPI_GetHSteamUser() { return NULL; }
void __cdecl SteamAPI_RegisterCallback(void *pCallback, int iCallback) {}
void __cdecl SteamAPI_RunCallbacks() {}
void __cdecl SteamAPI_UnregisterCallback(void *pCallback) {}
void *__cdecl SteamGameServer_GetHSteamUser() { return NULL; }
void __cdecl SteamGameServer_RunCallbacks() {}
void *__cdecl SteamInternal_ContextInit(void *pContext) { return NULL; }
void *__cdecl SteamInternal_FindOrCreateGameServerInterface(void *hSteamUser, const char *pchVersion) { return NULL; }
void *__cdecl SteamInternal_FindOrCreateUserInterface(void *hSteamUser, const char *pchVersion) { return NULL; }
}

// ---------------------------------------------------------
// 12. Bink Video Stubs
// ---------------------------------------------------------
extern "C" {
void __cdecl BinkClose(void *bink) {}
void __cdecl BinkControlBackgroundIO(void *bink, unsigned int control) {}
int __cdecl BinkDoFrame(void *bink) { return 0; }
char *__cdecl BinkGetError() { return (char *)""; }
void __cdecl BinkGetFrameBuffersInfo(void *bink, void *fb) {}
int __cdecl BinkGetRealtime(void *bink, void *realtime, unsigned int flags) { return 0; }
void __cdecl BinkNextFrame(void *bink) {}
void *__cdecl BinkOpen(const char *name, unsigned int flags) { return NULL; }
void __cdecl BinkPause(void *bink, int pause) {}
int __cdecl BinkRegisterFrameBuffers(void *bink, void *fb) { return 0; }
void __cdecl BinkSetIOSize(unsigned int size) {}
void __cdecl BinkSetMemory(void *allocFunc, void *freeFunc) {}
int __cdecl BinkSetSoundSystem(void *open, uintptr_t param) { return 0; }
void __cdecl BinkSetSoundTrack(unsigned int track, void *sound) {}
void __cdecl BinkSetVolume(void *bink, unsigned int track, int volume) {}
int __cdecl BinkShouldSkip(void *bink) { return 0; }
int __cdecl BinkWait(void *bink) { return 0; }
}

// ---------------------------------------------------------
// 13. NvAPI (Stereo / 3D Vision) Stubs
// ---------------------------------------------------------
extern "C" {
int __cdecl NvAPI_Initialize() { return 0; }
int __cdecl NvAPI_Stereo_CreateHandleFromIUnknown(void *d3d, void *handle) { return 0; }
int __cdecl NvAPI_Stereo_DestroyHandle(void *handle) { return 0; }
int __cdecl NvAPI_Stereo_IsActivated(void *handle, unsigned char *activated)
{
    if (activated) *activated = 0;
    return 0;
}
int __cdecl NvAPI_Stereo_SetConvergence(void *handle, float convergence) { return 0; }
}

// ---------------------------------------------------------
// 14. Skinning SSE fallback for ARM64
// ---------------------------------------------------------
void __cdecl R_SkinXSurfaceSkinnedSse(
    const XSurface *xsurf,
    const DObjSkelMat *boneMatrix,
    GfxPackedVertexNormal *skinVertNormalIn,
    GfxPackedVertexNormal *skinVertNormalOut,
    GfxPackedVertex *skinVerticesOut)
{
    R_SkinXSurfaceSkinned(xsurf, boneMatrix, skinVerticesOut);
}

#endif // __APPLE__
