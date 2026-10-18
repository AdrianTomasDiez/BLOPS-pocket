#pragma once

#if defined(__APPLE__)

#include <ios/win_types_compat.h>
#include <platform_compat/d3d9.h>

#ifdef __cplusplus
struct IDirectSound8 : public IUnknown {
    virtual HRESULT SetCooperativeLevel(HWND hwnd, DWORD dwLevel) { return 0; }
};
struct IDirectSound : public IDirectSound8 {};
struct IDirectSoundBuffer : public IUnknown {};
struct IDirectSoundCapture : public IUnknown {};
struct IDirectSoundCaptureBuffer : public IUnknown {};

static inline HRESULT DirectSoundCreate8(const void *pcGuidDevice, IDirectSound8 **ppDS8, void *pUnkOuter) {
    if (ppDS8) *ppDS8 = nullptr;
    return 1;
}
#else
typedef struct IDirectSound IDirectSound;
typedef struct IDirectSound8 IDirectSound8;
typedef struct IDirectSoundBuffer IDirectSoundBuffer;
typedef struct IDirectSoundCapture IDirectSoundCapture;
typedef struct IDirectSoundCaptureBuffer IDirectSoundCaptureBuffer;
#endif

typedef IDirectSound *LPDIRECTSOUND;
typedef IDirectSound8 *LPDIRECTSOUND8;
typedef IDirectSoundBuffer *LPDIRECTSOUNDBUFFER;
typedef IDirectSoundCapture *LPDIRECTSOUNDCAPTURE;
typedef IDirectSoundCaptureBuffer *LPDIRECTSOUNDCAPTUREBUFFER;

#endif
