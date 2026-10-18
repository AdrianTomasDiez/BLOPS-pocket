#pragma once

#if defined(__APPLE__)

#include <ios/win_types_compat.h>
#include <platform_compat/d3d9.h>

#ifndef STDMETHODCALLTYPE
#define STDMETHODCALLTYPE
#endif

#ifndef STDMETHOD
#define STDMETHOD(method) virtual HRESULT STDMETHODCALLTYPE method
#endif

#ifndef STDMETHOD_
#define STDMETHOD_(type, method) virtual type STDMETHODCALLTYPE method
#endif

#ifndef THIS
#define THIS void
#endif

#ifndef THIS_
#define THIS_
#endif

#ifndef PURE
#define PURE = 0
#endif

typedef struct tWAVEFORMATEX {
    WORD        wFormatTag;
    WORD        nChannels;
    DWORD       nSamplesPerSec;
    DWORD       nAvgBytesPerSec;
    WORD        nBlockAlign;
    WORD        wBitsPerSample;
    WORD        cbSize;
} WAVEFORMATEX, *PWAVEFORMATEX, *LPWAVEFORMATEX;

typedef struct tADPCMCOEFSET {
    short iCoef1;
    short iCoef2;
} ADPCMCOEFSET;

typedef struct XAUDIO2_BUFFER {
    UINT32 Flags;
    UINT32 AudioBytes;
    const BYTE *pAudioData;
    UINT32 PlayBegin;
    UINT32 PlayLength;
    UINT32 LoopBegin;
    UINT32 LoopLength;
    UINT32 LoopCount;
    void *pContext;
} XAUDIO2_BUFFER;

typedef struct XAUDIO2_DEVICE_DETAILS {
    WCHAR DeviceID[256];
    WCHAR DisplayName[256];
    int Role;
    WAVEFORMATEX OutputFormat;
} XAUDIO2_DEVICE_DETAILS;

typedef struct XAUDIO2_VOICE_DETAILS {
    UINT32 CreationFlags;
    UINT32 InputChannels;
    UINT32 InputSampleRate;
} XAUDIO2_VOICE_DETAILS;

typedef struct XAUDIO2_PERFORMANCE_DATA {
    UINT64 AudioCyclesSinceLastQuery;
    UINT64 TotalCyclesSinceLastQuery;
    UINT32 MinimumCyclesPerQuantum;
    UINT32 MaximumCyclesPerQuantum;
    UINT32 MemoryUsageInBytes;
    UINT32 CurrentLatencyInSamples;
    UINT32 GlitchesSinceEngineStarted;
    UINT32 ActiveSourceVoiceCount;
    UINT32 TotalSourceVoiceCount;
    UINT32 ActiveSubmixVoiceCount;
    UINT32 ActiveResamplerCount;
    UINT32 ActiveMatrixMixCount;
    UINT32 ActiveXmaSourceVoices;
    UINT32 ActiveXmaStreams;
} XAUDIO2_PERFORMANCE_DATA;

typedef UINT32 XAUDIO2_WINDOWS_PROCESSOR_SPECIFIER;

struct IXAudio2Voice : public IUnknown {};
struct IXAudio2 : public IUnknown {};
struct IXAudio2SourceVoice : public IXAudio2Voice {};
struct IXAudio2MasteringVoice : public IXAudio2Voice {};
struct IXAudio2SubmixVoice : public IXAudio2Voice {};

struct IXAudio2VoiceCallback {
    virtual ~IXAudio2VoiceCallback() {}
    virtual void STDMETHODCALLTYPE OnVoiceProcessingPassStart(UINT32 BytesRequired) {}
    virtual void STDMETHODCALLTYPE OnVoiceProcessingPassEnd() {}
    virtual void STDMETHODCALLTYPE OnStreamEnd() {}
    virtual void STDMETHODCALLTYPE OnBufferStart(void *pBufferContext) {}
    virtual void STDMETHODCALLTYPE OnBufferEnd(void *pBufferContext) {}
    virtual void STDMETHODCALLTYPE OnLoopEnd(void *pBufferContext) {}
    virtual void STDMETHODCALLTYPE OnVoiceError(void *pBufferContext, HRESULT Error) {}
};

#endif // __APPLE__
