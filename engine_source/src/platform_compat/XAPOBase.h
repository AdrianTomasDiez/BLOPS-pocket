#pragma once

#if defined(__APPLE__)

#include <ios/win_types_compat.h>
#include <platform_compat/d3d9.h>
#include <platform_compat/XAudio2.h>

typedef struct XAPO_REGISTRATION_PROPERTIES {
    GUID    clsid;
    WCHAR   FriendlyName[256];
    WCHAR   CopyrightInfo[256];
    WORD    MajorVersion;
    WORD    MinorVersion;
    DWORD   Flags;
    UINT32  MinInputBufferCount;
    UINT32  MaxInputBufferCount;
    UINT32  MinOutputBufferCount;
    UINT32  MaxOutputBufferCount;
} XAPO_REGISTRATION_PROPERTIES;

struct IXAPOParameters : public IUnknown {
    virtual void SetParameters(const void *pParameters, UINT32 ParameterByteSize) {}
    virtual void GetParameters(void *pParameters, UINT32 ParameterByteSize) {}
};

class CXAPOBase : public IUnknown {
public:
    LONG m_lReferenceCount;
    CXAPOBase() : m_lReferenceCount(1) {}
    virtual ~CXAPOBase() {}
    virtual HRESULT QueryInterface(REFIID riid, void **ppvObject) {
        if (!ppvObject) return E_POINTER;
        *ppvObject = this;
        AddRef();
        return S_OK;
    }
    virtual ULONG AddRef() { return InterlockedIncrement(&m_lReferenceCount); }
    virtual ULONG Release() {
        LONG count = InterlockedDecrement(&m_lReferenceCount);
        if (count == 0) delete this;
        return count;
    }
};

#ifndef __uuidof
#define __uuidof(type) (HACK_IID_IXAPOParameters)
#endif

#endif // __APPLE__
