#pragma once

#if defined(__APPLE__)

#include <ios/win_types_compat.h>

typedef struct IDirectSound IDirectSound;
typedef struct IDirectSound8 IDirectSound8;
typedef struct IDirectSoundBuffer IDirectSoundBuffer;
typedef struct IDirectSoundCapture IDirectSoundCapture;
typedef struct IDirectSoundCaptureBuffer IDirectSoundCaptureBuffer;

typedef IDirectSound *LPDIRECTSOUND;
typedef IDirectSound8 *LPDIRECTSOUND8;
typedef IDirectSoundBuffer *LPDIRECTSOUNDBUFFER;
typedef IDirectSoundCapture *LPDIRECTSOUNDCAPTURE;
typedef IDirectSoundCaptureBuffer *LPDIRECTSOUNDCAPTUREBUFFER;

#endif
