#pragma once

#if defined(__APPLE__)

#include <ios/win_types_compat.h>
#include <platform_compat/d3d9.h>

typedef struct tWAVEFORMATEX {
    WORD        wFormatTag;
    WORD        nChannels;
    DWORD       nSamplesPerSec;
    DWORD       nAvgBytesPerSec;
    WORD        nBlockAlign;
    WORD        wBitsPerSample;
    WORD        cbSize;
} WAVEFORMATEX, *PWAVEFORMATEX, *LPWAVEFORMATEX;

struct IXAudio2 : public IUnknown {};
struct IXAudio2SourceVoice : public IUnknown {};
struct IXAudio2MasteringVoice : public IUnknown {};
struct IXAudio2SubmixVoice : public IUnknown {};

#endif // __APPLE__
