#pragma once

#if defined(__APPLE__)

#include <ios/win_types_compat.h>

typedef struct _D3DMATRIX {
    union {
        struct {
            float        _11, _12, _13, _14;
            float        _21, _22, _23, _24;
            float        _31, _32, _33, _34;
            float        _41, _42, _43, _44;
        };
        float m[4][4];
    };
} D3DMATRIX;

typedef struct _D3DVECTOR {
    float x;
    float y;
    float z;
} D3DVECTOR;

typedef struct _D3DCOLORVALUE {
    float r;
    float g;
    float b;
    float a;
} D3DCOLORVALUE;

typedef DWORD D3DCOLOR;

typedef enum _D3DFORMAT {
    D3DFMT_UNKNOWN              =  0,
    D3DFMT_R8G8B8               = 20,
    D3DFMT_A8R8G8B8             = 21,
    D3DFMT_X8R8G8B8             = 22,
    D3DFMT_R5G6B5               = 23,
    D3DFMT_X1R5G5B5             = 24,
    D3DFMT_A1R5G5B5             = 25,
    D3DFMT_A4R4G4B4             = 26,
    D3DFMT_R3G3B2               = 27,
    D3DFMT_A8                   = 28,
    D3DFMT_A8R3G3B2             = 29,
    D3DFMT_X4R4G4B4             = 30,
    D3DFMT_A2B10G10R10          = 31,
    D3DFMT_A8B8G8R8             = 32,
    D3DFMT_X8B8G8R8             = 33,
    D3DFMT_G16R16               = 34,
    D3DFMT_A2R10G10B10          = 35,
    D3DFMT_A16B16G16R16         = 36,
    D3DFMT_DXT1                 = 0x31545844,
    D3DFMT_DXT2                 = 0x32545844,
    D3DFMT_DXT3                 = 0x33545844,
    D3DFMT_DXT4                 = 0x34545844,
    D3DFMT_DXT5                 = 0x35545844,
    D3DFMT_D24S8                = 75,
    D3DFMT_D24X8                = 77,
    D3DFMT_D16                  = 80,
    D3DFMT_FORCE_DWORD          = 0x7fffffff
} D3DFORMAT;

typedef struct _D3DDISPLAYMODE {
    UINT            Width;
    UINT            Height;
    UINT            RefreshRate;
    D3DFORMAT       Format;
} D3DDISPLAYMODE;

typedef enum _D3DMULTISAMPLE_TYPE {
    D3DMULTISAMPLE_NONE            =  0,
    D3DMULTISAMPLE_NONMASKABLE     =  1,
    D3DMULTISAMPLE_2_SAMPLES       =  2,
    D3DMULTISAMPLE_3_SAMPLES       =  3,
    D3DMULTISAMPLE_4_SAMPLES       =  4,
    D3DMULTISAMPLE_5_SAMPLES       =  5,
    D3DMULTISAMPLE_6_SAMPLES       =  6,
    D3DMULTISAMPLE_7_SAMPLES       =  7,
    D3DMULTISAMPLE_8_SAMPLES       =  8,
    D3DMULTISAMPLE_9_SAMPLES       =  9,
    D3DMULTISAMPLE_10_SAMPLES      = 10,
    D3DMULTISAMPLE_11_SAMPLES      = 11,
    D3DMULTISAMPLE_12_SAMPLES      = 12,
    D3DMULTISAMPLE_13_SAMPLES      = 13,
    D3DMULTISAMPLE_14_SAMPLES      = 14,
    D3DMULTISAMPLE_15_SAMPLES      = 15,
    D3DMULTISAMPLE_16_SAMPLES      = 16,
    D3DMULTISAMPLE_FORCE_DWORD     = 0x7fffffff
} D3DMULTISAMPLE_TYPE;

typedef enum _D3DTEXTUREFILTERTYPE {
    D3DTEXF_NONE            = 0,
    D3DTEXF_POINT           = 1,
    D3DTEXF_LINEAR          = 2,
    D3DTEXF_ANISOTROPIC     = 3,
    D3DTEXF_PYRAMIDALQUAD   = 6,
    D3DTEXF_GAUSSIANQUAD    = 7,
    D3DTEXF_CONVOLUTIONMONO = 8,
    D3DTEXF_FORCE_DWORD     = 0x7fffffff
} D3DTEXTUREFILTERTYPE;

typedef enum _D3DSWAPEFFECT {
    D3DSWAPEFFECT_DISCARD       = 1,
    D3DSWAPEFFECT_FLIP          = 2,
    D3DSWAPEFFECT_COPY          = 3,
    D3DSWAPEFFECT_OVERLAY       = 4,
    D3DSWAPEFFECT_FLIPEX        = 5,
    D3DSWAPEFFECT_FORCE_DWORD   = 0x7fffffff
} D3DSWAPEFFECT;

typedef struct _D3DPRESENT_PARAMETERS_ {
    UINT                BackBufferWidth;
    UINT                BackBufferHeight;
    D3DFORMAT           BackBufferFormat;
    UINT                BackBufferCount;
    D3DMULTISAMPLE_TYPE MultiSampleType;
    DWORD               MultiSampleQuality;
    D3DSWAPEFFECT       SwapEffect;
    HWND                hDeviceWindow;
    BOOL                Windowed;
    BOOL                EnableAutoDepthStencil;
    D3DFORMAT           AutoDepthStencilFormat;
    DWORD               Flags;
    UINT                FullScreen_RefreshRateInHz;
    UINT                PresentationInterval;
} D3DPRESENT_PARAMETERS;

typedef struct _D3DCAPS9 {
    DWORD   DeviceType;
    UINT    AdapterOrdinal;
    DWORD   Caps;
    DWORD   Caps2;
    DWORD   Caps3;
    DWORD   PresentationIntervals;
    DWORD   CursorCaps;
    DWORD   DevCaps;
    DWORD   PrimitiveMiscCaps;
    DWORD   RasterCaps;
    DWORD   ZCmpCaps;
    DWORD   SrcBlendCaps;
    DWORD   DestBlendCaps;
    DWORD   AlphaCmpCaps;
    DWORD   ShadeCaps;
    DWORD   TextureCaps;
    DWORD   TextureFilterCaps;
    DWORD   TextureAddressCaps;
    DWORD   LineCaps;
    DWORD   MaxTextureWidth, MaxTextureHeight;
    DWORD   MaxVolumeExtent;
    DWORD   MaxTextureRepeat;
    DWORD   MaxTextureAspectRatio;
    DWORD   MaxAnisotropy;
    float   MaxVertexW;
    float   GuardBandLeft;
    float   GuardBandTop;
    float   GuardBandRight;
    float   GuardBandBottom;
    float   ExtentsAdjust;
    DWORD   StencilCaps;
    DWORD   FVFCaps;
    DWORD   TextureOpCaps;
    DWORD   MaxTextureBlendStages;
    DWORD   MaxSimultaneousTextures;
    DWORD   VertexProcessingCaps;
    DWORD   MaxActiveLights;
    DWORD   MaxUserClipPlanes;
    DWORD   MaxVertexBlendMatrices;
    DWORD   MaxVertexBlendMatrixIndex;
    float   MaxPointSize;
    DWORD   MaxPrimitiveCount;
    DWORD   MaxVertexIndex;
    DWORD   MaxStreams;
    DWORD   MaxStreamStride;
    DWORD   VertexShaderVersion;
    DWORD   MaxVertexShaderConst;
    DWORD   PixelShaderVersion;
    float   PixelShader1xMaxValue;
    DWORD   DevCaps2;
    float   MaxNpatchTessellationLevel;
    DWORD   Reserved5;
    UINT    MasterAdapterOrdinal;
    DWORD   AdapterOrdinalInGroup;
    DWORD   NumberOfAdaptersInGroup;
    DWORD   DeclTypes;
    DWORD   NumSimultaneousRTs;
    DWORD   StretchRectFilterCaps;
    DWORD   VS20Caps;
    DWORD   PS20Caps;
    DWORD   VertexTextureFilterCaps;
    DWORD   MaxVShaderInstructionsExecuted;
    DWORD   MaxPShaderInstructionsExecuted;
    DWORD   MaxVertexShader30InstructionSlots;
    DWORD   MaxPixelShader30InstructionSlots;
} D3DCAPS9;

typedef struct _D3DVERTEXELEMENT9 {
    WORD    Stream;
    WORD    Offset;
    BYTE    Type;
    BYTE    Method;
    BYTE    Usage;
    BYTE    UsageIndex;
} D3DVERTEXELEMENT9;

typedef enum _D3DPOOL {
    D3DPOOL_DEFAULT     = 0,
    D3DPOOL_MANAGED     = 1,
    D3DPOOL_SYSTEMMEM   = 2,
    D3DPOOL_SCRATCH     = 3,
    D3DPOOL_FORCE_DWORD = 0x7fffffff
} D3DPOOL;

typedef struct _D3DLOCKED_RECT {
    INT     Pitch;
    void    *pBits;
} D3DLOCKED_RECT;

#ifdef __cplusplus
struct IUnknown {
    virtual ~IUnknown() {}
    virtual ULONG Release() { return 0; }
    virtual ULONG AddRef() { return 1; }
    virtual HRESULT QueryInterface(void*, void**) { return 0; }
};
struct IDirect3DResource9 : public IUnknown {};
struct IDirect3DSurface9 : public IDirect3DResource9 {};
struct IDirect3DBaseTexture9 : public IDirect3DResource9 {};
struct IDirect3DTexture9 : public IDirect3DBaseTexture9 {
    virtual HRESULT GetSurfaceLevel(UINT Level, IDirect3DSurface9 **ppSurfaceLevel) { return 0; }
    virtual HRESULT LockRect(UINT Level, D3DLOCKED_RECT *pLockedRect, const RECT *pRect, DWORD Flags) { return 0; }
    virtual HRESULT UnlockRect(UINT Level) { return 0; }
};
struct IDirect3DCubeTexture9 : public IDirect3DBaseTexture9 {};
struct IDirect3DVolumeTexture9 : public IDirect3DBaseTexture9 {};
struct IDirect3DVertexBuffer9 : public IDirect3DResource9 {
    virtual HRESULT Lock(UINT OffsetToLock, UINT SizeToLock, void **ppbData, DWORD Flags) { return 0; }
    virtual HRESULT Unlock() { return 0; }
};
struct IDirect3DIndexBuffer9 : public IDirect3DResource9 {
    virtual HRESULT Lock(UINT OffsetToLock, UINT SizeToLock, void **ppbData, DWORD Flags) { return 0; }
    virtual HRESULT Unlock() { return 0; }
};
struct IDirect3DVertexDeclaration9 : public IUnknown {};
struct IDirect3DVertexShader9 : public IUnknown {};
struct IDirect3DPixelShader9 : public IUnknown {};
struct IDirect3DQuery9 : public IUnknown {};
struct IDirect3DStateBlock9 : public IUnknown {};
struct IDirect3DSwapChain9 : public IUnknown {};
struct IDirect3DDevice9 : public IUnknown {
    virtual HRESULT CreateTexture(UINT, UINT, UINT, DWORD, D3DFORMAT, D3DPOOL, IDirect3DTexture9**, HANDLE*) { return 0; }
    virtual HRESULT CreateVertexBuffer(UINT, DWORD, DWORD, D3DPOOL, IDirect3DVertexBuffer9**, HANDLE*) { return 0; }
    virtual HRESULT CreateIndexBuffer(UINT, DWORD, D3DFORMAT, D3DPOOL, IDirect3DIndexBuffer9**, HANDLE*) { return 0; }
    virtual HRESULT CreateVertexDeclaration(const D3DVERTEXELEMENT9*, IDirect3DVertexDeclaration9**) { return 0; }
    virtual HRESULT CreateVertexShader(const DWORD*, IDirect3DVertexShader9**) { return 0; }
    virtual HRESULT CreatePixelShader(const DWORD*, IDirect3DPixelShader9**) { return 0; }
};
struct IDirect3DDevice9Ex : public IDirect3DDevice9 {};
struct IDirect3D9 : public IUnknown {};

typedef struct IDirect3D9 *LPDIRECT3D9;
typedef struct IDirect3DDevice9 *LPDIRECT3DDEVICE9;
typedef struct IDirect3DDevice9Ex *LPDIRECT3DDEVICE9EX;
typedef struct IDirect3DTexture9 *LPDIRECT3DTEXTURE9;
typedef struct IDirect3DCubeTexture9 *LPDIRECT3DCUBETEXTURE9;
typedef struct IDirect3DVolumeTexture9 *LPDIRECT3DVOLUMETEXTURE9;
typedef struct IDirect3DSurface9 *LPDIRECT3DSURFACE9;
typedef struct IDirect3DVertexBuffer9 *LPDIRECT3DVERTEXBUFFER9;
typedef struct IDirect3DIndexBuffer9 *LPDIRECT3DINDEXBUFFER9;
typedef struct IDirect3DVertexDeclaration9 *LPDIRECT3DVERTEXDECLARATION9;
typedef struct IDirect3DVertexShader9 *LPDIRECT3DVERTEXSHADER9;
typedef struct IDirect3DPixelShader9 *LPDIRECT3DPIXELSHADER9;
typedef struct IDirect3DQuery9 *LPDIRECT3DQUERY9;
typedef struct IDirect3DStateBlock9 *LPDIRECT3DSTATEBLOCK9;
typedef struct IDirect3DSwapChain9 *LPDIRECT3DSWAPCHAIN9;
#endif

#define D3D_OK 0
#define D3DERR_DEVICELOST 0x88760868
#define D3DERR_DEVICENOTRESET 0x88760869

#endif // __APPLE__
