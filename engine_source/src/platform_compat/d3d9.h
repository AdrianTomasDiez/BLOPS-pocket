#pragma once

#if defined(__APPLE__)

#ifndef _D3D9_H_
#define _D3D9_H_
#endif

#ifndef D3D_SDK_VERSION
#define D3D_SDK_VERSION 32
#endif

#ifndef D3DCREATE_MULTITHREADED
#define D3DCREATE_MULTITHREADED 0x00000004L
#endif

#ifndef D3DCREATE_PUREDEVICE
#define D3DCREATE_PUREDEVICE 0x00000010L
#endif

#ifndef D3DCREATE_SOFTWARE_VERTEXPROCESSING
#define D3DCREATE_SOFTWARE_VERTEXPROCESSING 0x00000020L
#endif

#ifndef D3DCREATE_HARDWARE_VERTEXPROCESSING
#define D3DCREATE_HARDWARE_VERTEXPROCESSING 0x00000040L
#endif

#ifndef D3DCREATE_MIXED_VERTEXPROCESSING
#define D3DCREATE_MIXED_VERTEXPROCESSING 0x00000080L
#endif

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
    D3DFMT_L8                   = 50,
    D3DFMT_A8L8                 = 51,
    D3DFMT_D16_LOCKABLE         = 70,
    D3DFMT_D32                  = 71,
    D3DFMT_D15S1                = 73,
    D3DFMT_D24S8                = 75,
    D3DFMT_D24X8                = 77,
    D3DFMT_D16                  = 80,
    D3DFMT_D24FS8               = 82,
    D3DFMT_R16F                 = 111,
    D3DFMT_G16R16F              = 112,
    D3DFMT_A16B16G16R16F        = 113,
    D3DFMT_R32F                 = 114,
    D3DFMT_G32R32F              = 115,
    D3DFMT_A32B32G32R32F        = 116,
    D3DFMT_FORCE_DWORD          = 0x7fffffff
} D3DFORMAT;

typedef struct _D3DDISPLAYMODE {
    UINT            Width;
    UINT            Height;
    UINT            RefreshRate;
    D3DFORMAT       Format;
} D3DDISPLAYMODE;

typedef enum _D3DDEVTYPE {
    D3DDEVTYPE_HAL         = 1,
    D3DDEVTYPE_NULLREF     = 2,
    D3DDEVTYPE_REF         = 3,
    D3DDEVTYPE_SW          = 4,
    D3DDEVTYPE_FORCE_DWORD = 0x7fffffff
} D3DDEVTYPE;

typedef enum _D3DRESOURCETYPE {
    D3DRTYPE_SURFACE                = 1,
    D3DRTYPE_VOLUME                 = 2,
    D3DRTYPE_TEXTURE                = 3,
    D3DRTYPE_VOLUMETEXTURE          = 4,
    D3DRTYPE_CUBETEXTURE            = 5,
    D3DRTYPE_VERTEXBUFFER           = 6,
    D3DRTYPE_INDEXBUFFER            = 7,
    D3DRTYPE_FORCE_DWORD            = 0x7fffffff
} D3DRESOURCETYPE;

typedef struct _D3DADAPTER_IDENTIFIER9 {
    char            Driver[512];
    char            Description[512];
    char            DeviceName[32];
    LARGE_INTEGER   DriverVersion;
    DWORD           VendorId;
    DWORD           DeviceId;
    DWORD           SubSysId;
    DWORD           Revision;
    GUID            DeviceIdentifier;
    DWORD           WHQLLevel;
} D3DADAPTER_IDENTIFIER9;


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

typedef enum _D3DCUBEMAP_FACES {
    D3DCUBEMAP_FACE_POSITIVE_X     = 0,
    D3DCUBEMAP_FACE_NEGATIVE_X     = 1,
    D3DCUBEMAP_FACE_POSITIVE_Y     = 2,
    D3DCUBEMAP_FACE_NEGATIVE_Y     = 3,
    D3DCUBEMAP_FACE_POSITIVE_Z     = 4,
    D3DCUBEMAP_FACE_NEGATIVE_Z     = 5,
    D3DCUBEMAP_FACE_FORCE_DWORD    = 0x7fffffff
} D3DCUBEMAP_FACES;

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

typedef struct _D3DBOX {
    UINT    Left;
    UINT    Top;
    UINT    Right;
    UINT    Bottom;
    UINT    Front;
    UINT    Back;
} D3DBOX;

typedef struct _D3DLOCKED_BOX {
    INT     RowPitch;
    INT     SlicePitch;
    void    *pBits;
} D3DLOCKED_BOX;

typedef struct _D3DRECT {
    LONG x1;
    LONG y1;
    LONG x2;
    LONG y2;
} D3DRECT;

typedef struct _D3DVIEWPORT9 {
    DWORD       X;
    DWORD       Y;
    DWORD       Width;
    DWORD       Height;
    float       MinZ;
    float       MaxZ;
} D3DVIEWPORT9;

typedef struct _D3DSURFACE_DESC {
    D3DFORMAT           Format;
    DWORD               Type;
    DWORD               Usage;
    D3DPOOL             Pool;
    D3DMULTISAMPLE_TYPE MultiSampleType;
    DWORD               MultiSampleQuality;
    UINT                Width;
    UINT                Height;
} D3DSURFACE_DESC;

typedef struct _D3DGAMMARAMP {
    WORD                red[256];
    WORD                green[256];
    WORD                blue[256];
} D3DGAMMARAMP;

typedef enum _D3DBACKBUFFER_TYPE {
    D3DBACKBUFFER_TYPE_MONO         = 0,
    D3DBACKBUFFER_TYPE_LEFT         = 1,
    D3DBACKBUFFER_TYPE_RIGHT        = 2,
    D3DBACKBUFFER_TYPE_FORCE_DWORD  = 0x7fffffff
} D3DBACKBUFFER_TYPE;

typedef enum _D3DPRIMITIVETYPE {
    D3DPT_POINTLIST             = 1,
    D3DPT_LINELIST              = 2,
    D3DPT_LINESTRIP             = 3,
    D3DPT_TRIANGLELIST          = 4,
    D3DPT_TRIANGLESTRIP         = 5,
    D3DPT_TRIANGLEFAN           = 6,
    D3DPT_FORCE_DWORD           = 0x7fffffff
} D3DPRIMITIVETYPE;

typedef enum _D3DRENDERSTATETYPE {
    D3DRS_ZENABLE                   = 7,
    D3DRS_FILLMODE                  = 8,
    D3DRS_SHADEMODE                 = 9,
    D3DRS_ZWRITEENABLE              = 14,
    D3DRS_ALPHATESTENABLE           = 15,
    D3DRS_LASTPIXEL                 = 16,
    D3DRS_SRCBLEND                  = 19,
    D3DRS_DESTBLEND                 = 20,
    D3DRS_CULLMODE                  = 22,
    D3DRS_ZFUNC                     = 23,
    D3DRS_ALPHAREF                  = 24,
    D3DRS_ALPHAFUNC                 = 25,
    D3DRS_DITHERENABLE              = 26,
    D3DRS_ALPHABLENDENABLE          = 27,
    D3DRS_FOGENABLE                 = 28,
    D3DRS_SPECULARENABLE            = 29,
    D3DRS_FOGCOLOR                  = 34,
    D3DRS_FOGTABLEMODE              = 35,
    D3DRS_FOGSTART                  = 36,
    D3DRS_FOGEND                    = 37,
    D3DRS_FOGDENSITY                = 38,
    D3DRS_RANGEFOGENABLE            = 48,
    D3DRS_STENCILENABLE             = 52,
    D3DRS_STENCILFAIL               = 53,
    D3DRS_STENCILZFAIL              = 54,
    D3DRS_STENCILPASS               = 55,
    D3DRS_STENCILFUNC               = 56,
    D3DRS_STENCILREF                = 57,
    D3DRS_STENCILMASK               = 58,
    D3DRS_STENCILWRITEMASK          = 59,
    D3DRS_TEXTUREFACTOR             = 60,
    D3DRS_WRAP0                     = 128,
    D3DRS_CLIPPING                  = 136,
    D3DRS_LIGHTING                  = 137,
    D3DRS_AMBIENT                   = 139,
    D3DRS_COLORVERTEX               = 141,
    D3DRS_LOCALVIEWER               = 142,
    D3DRS_NORMALIZENORMALS          = 143,
    D3DRS_DIFFUSEMATERIALSOURCE     = 145,
    D3DRS_SPECULARMATERIALSOURCE    = 146,
    D3DRS_AMBIENTMATERIALSOURCE     = 147,
    D3DRS_EMISSIVEMATERIALSOURCE    = 148,
    D3DRS_VERTEXBLEND               = 151,
    D3DRS_CLIPPLANEENABLE           = 152,
    D3DRS_POINTSIZE                 = 154,
    D3DRS_POINTSIZE_MIN             = 155,
    D3DRS_POINTSPRITEENABLE         = 156,
    D3DRS_POINTSCALEENABLE          = 157,
    D3DRS_POINTSCALE_A              = 158,
    D3DRS_POINTSCALE_B              = 159,
    D3DRS_POINTSCALE_C              = 160,
    D3DRS_MULTISAMPLEANTIALIAS      = 161,
    D3DRS_MULTISAMPLEMASK           = 162,
    D3DRS_PATCHEDGESTYLE            = 163,
    D3DRS_DEBUGMONITORTOKEN         = 165,
    D3DRS_POINTSIZE_MAX             = 166,
    D3DRS_INDEXEDVERTEXBLENDENABLE  = 167,
    D3DRS_COLORWRITEENABLE          = 168,
    D3DRS_TWEENFACTOR               = 170,
    D3DRS_BLENDOP                   = 171,
    D3DRS_POSITIONDEGREE            = 172,
    D3DRS_NORMALDEGREE              = 173,
    D3DRS_SCISSORTESTENABLE         = 174,
    D3DRS_SLOPESCALEDEPTHBIAS       = 175,
    D3DRS_ANTIALIASEDLINEENABLE     = 176,
    D3DRS_MINTESSELLATIONLEVEL      = 178,
    D3DRS_MAXTESSELLATIONLEVEL      = 179,
    D3DRS_ADAPTIVETESS_X            = 180,
    D3DRS_ADAPTIVETESS_Y            = 181,
    D3DRS_ADAPTIVETESS_Z            = 182,
    D3DRS_ADAPTIVETESS_W            = 183,
    D3DRS_ENABLEADAPTIVETESSELLATION = 184,
    D3DRS_TWOSIDEDSTENCILMODE       = 185,
    D3DRS_CCW_STENCILFAIL           = 186,
    D3DRS_CCW_STENCILZFAIL          = 187,
    D3DRS_CCW_STENCILPASS           = 188,
    D3DRS_CCW_STENCILFUNC           = 189,
    D3DRS_COLORWRITEENABLE1         = 190,
    D3DRS_COLORWRITEENABLE2         = 191,
    D3DRS_COLORWRITEENABLE3         = 192,
    D3DRS_BLENDFACTOR               = 193,
    D3DRS_SRGBWRITEENABLE           = 194,
    D3DRS_DEPTHBIAS                 = 195,
    D3DRS_WRAP8                     = 198,
    D3DRS_SEPARATEALPHABLENDENABLE  = 206,
    D3DRS_SRCBLENDALPHA             = 207,
    D3DRS_DESTBLENDALPHA            = 208,
    D3DRS_BLENDOPALPHA              = 209,
    D3DRS_FORCE_DWORD               = 0x7fffffff
} D3DRENDERSTATETYPE;

typedef enum _D3DSAMPLERSTATETYPE {
    D3DSAMP_ADDRESSU       = 1,
    D3DSAMP_ADDRESSV       = 2,
    D3DSAMP_ADDRESSW       = 3,
    D3DSAMP_BORDERCOLOR    = 4,
    D3DSAMP_MAGFILTER      = 5,
    D3DSAMP_MINFILTER      = 6,
    D3DSAMP_MIPFILTER      = 7,
    D3DSAMP_MIPMAPLODBIAS  = 8,
    D3DSAMP_MAXMIPLEVEL    = 9,
    D3DSAMP_MAXANISOTROPY  = 10,
    D3DSAMP_SRGBTEXTURE    = 11,
    D3DSAMP_ELEMENTINDEX   = 12,
    D3DSAMP_DMAPOFFSET     = 13,
    D3DSAMP_FORCE_DWORD    = 0x7fffffff
} D3DSAMPLERSTATETYPE;

#ifdef __cplusplus
struct IUnknown {
    virtual ~IUnknown() {}
    virtual ULONG Release() { return 0; }
    virtual ULONG AddRef() { return 1; }
    virtual HRESULT QueryInterface(void*, void**) { return 0; }
};
struct IDirect3DResource9 : public IUnknown {};
struct IDirect3DSurface9 : public IDirect3DResource9 {
    virtual HRESULT GetDesc(D3DSURFACE_DESC *pDesc) {
        if (pDesc) {
            memset(pDesc, 0, sizeof(*pDesc));
            pDesc->Width = 1920;
            pDesc->Height = 1080;
            pDesc->Format = D3DFMT_A8R8G8B8;
        }
        return 0;
    }
    virtual HRESULT LockRect(D3DLOCKED_RECT *pLockedRect, const RECT *pRect, DWORD Flags) { return 0; }
    virtual HRESULT UnlockRect() { return 0; }
};
struct IDirect3DBaseTexture9 : public IDirect3DResource9 {
    virtual void PreLoad() {}
};
typedef struct _D3DSURFACE_DESC _D3DSURFACE_DESC;

struct IDirect3DTexture9 : public IDirect3DBaseTexture9 {
    virtual DWORD GetLevelCount() { return 1; }
    virtual HRESULT GetLevelDesc(UINT Level, D3DSURFACE_DESC *pDesc) { return 0; }
    virtual HRESULT GetSurfaceLevel(UINT Level, IDirect3DSurface9 **ppSurfaceLevel) { return 0; }
    virtual HRESULT LockRect(UINT Level, D3DLOCKED_RECT *pLockedRect, const RECT *pRect, DWORD Flags) { return 0; }
    virtual HRESULT UnlockRect(UINT Level) { return 0; }
};
struct IDirect3DCubeTexture9 : public IDirect3DBaseTexture9 {
    virtual HRESULT GetCubeMapSurface(D3DCUBEMAP_FACES FaceType, UINT Level, IDirect3DSurface9 **ppCubeMapSurface) { return 0; }
    virtual HRESULT LockRect(D3DCUBEMAP_FACES FaceType, UINT Level, D3DLOCKED_RECT *pLockedRect, const RECT *pRect, DWORD Flags) { return 0; }
    virtual HRESULT UnlockRect(D3DCUBEMAP_FACES FaceType, UINT Level) { return 0; }
};
struct IDirect3DVolumeTexture9 : public IDirect3DBaseTexture9 {
    virtual HRESULT LockBox(UINT Level, D3DLOCKED_BOX *pLockedVolumeBox, const D3DBOX *pBox, DWORD Flags) {
        if (pLockedVolumeBox) {
            memset(pLockedVolumeBox, 0, sizeof(*pLockedVolumeBox));
        }
        return 0;
    }
    virtual HRESULT UnlockBox(UINT Level) { return 0; }
};
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
typedef enum _D3DQUERYTYPE {
    D3DQUERYTYPE_VCACHE                 = 4,
    D3DQUERYTYPE_RESOURCEMANAGER        = 5,
    D3DQUERYTYPE_VERTEXSTATS            = 6,
    D3DQUERYTYPE_EVENT                  = 8,
    D3DQUERYTYPE_OCCLUSION              = 9,
    D3DQUERYTYPE_TIMESTAMP              = 10,
    D3DQUERYTYPE_TIMESTAMPDISJOINT      = 11,
    D3DQUERYTYPE_TIMESTAMPFREQ          = 12,
    D3DQUERYTYPE_PIPELINETIMINGS        = 13,
    D3DQUERYTYPE_INTERFACETIMINGS       = 14,
    D3DQUERYTYPE_VERTEXTIMINGS          = 15,
    D3DQUERYTYPE_PIXELTIMINGS           = 16,
    D3DQUERYTYPE_BANDWIDTHTIMINGS       = 17,
    D3DQUERYTYPE_CACHEUTILIZATION       = 18
} D3DQUERYTYPE;

#ifndef D3DISSUE_BEGIN
#define D3DISSUE_BEGIN (1 << 1)
#endif
#ifndef D3DISSUE_END
#define D3DISSUE_END   (1 << 0)
#endif
#ifndef D3DGETDATA_FLUSH
#define D3DGETDATA_FLUSH (1 << 0)
#endif

struct IDirect3DDevice9;
struct IDirect3DQuery9 : public IUnknown {
    virtual HRESULT GetDevice(IDirect3DDevice9** ppDevice) { return 0; }
    virtual D3DQUERYTYPE GetType() { return (D3DQUERYTYPE)0; }
    virtual DWORD GetDataSize() { return 0; }
    virtual HRESULT Issue(DWORD dwIssueFlags) { return 0; }
    virtual HRESULT GetData(void* pData, DWORD dwSize, DWORD dwGetDataFlags) { return 0; }
};
struct IDirect3DStateBlock9 : public IUnknown {};
struct IDirect3DSwapChain9 : public IUnknown {
    virtual HRESULT Present(const RECT *pSourceRect, const RECT *pDestRect, HWND hDestWindowOverride, const void *pDirtyRegion, DWORD dwFlags) { return 0; }
    virtual HRESULT GetFrontBufferData(IDirect3DSurface9 *pDestSurface) { return 0; }
    virtual HRESULT GetBackBuffer(UINT iBackBuffer, D3DBACKBUFFER_TYPE Type, IDirect3DSurface9 **ppBackBuffer) {
        static IDirect3DSurface9 s_backBuffer;
        if (ppBackBuffer) *ppBackBuffer = &s_backBuffer;
        return 0;
    }
};
struct IDirect3DDevice9 : public IUnknown {
    virtual HRESULT CreateTexture(UINT, UINT, UINT, DWORD, D3DFORMAT, D3DPOOL, IDirect3DTexture9**, HANDLE*) { return 0; }
    virtual HRESULT CreateCubeTexture(UINT, UINT, DWORD, D3DFORMAT, D3DPOOL, IDirect3DCubeTexture9**, HANDLE*) { return 0; }
    virtual HRESULT CreateVolumeTexture(UINT, UINT, UINT, UINT, DWORD, D3DFORMAT, D3DPOOL, IDirect3DVolumeTexture9**, HANDLE*) { return 0; }
    virtual HRESULT CreateVertexBuffer(UINT, DWORD, DWORD, D3DPOOL, IDirect3DVertexBuffer9**, HANDLE*) { return 0; }
    virtual HRESULT CreateIndexBuffer(UINT, DWORD, D3DFORMAT, D3DPOOL, IDirect3DIndexBuffer9**, HANDLE*) { return 0; }
    virtual HRESULT CreateRenderTarget(UINT, UINT, D3DFORMAT, D3DMULTISAMPLE_TYPE, DWORD, BOOL, IDirect3DSurface9**, HANDLE*) { return 0; }
    virtual HRESULT CreateDepthStencilSurface(UINT, UINT, D3DFORMAT, D3DMULTISAMPLE_TYPE, DWORD, BOOL, IDirect3DSurface9**, HANDLE*) { return 0; }
    virtual HRESULT CreateOffscreenPlainSurface(UINT, UINT, D3DFORMAT, D3DPOOL, IDirect3DSurface9**, HANDLE*) { return 0; }
    virtual HRESULT CreateVertexDeclaration(const D3DVERTEXELEMENT9*, IDirect3DVertexDeclaration9**) { return 0; }
    virtual HRESULT CreateVertexShader(const DWORD*, IDirect3DVertexShader9**) { return 0; }
    virtual HRESULT CreatePixelShader(const DWORD*, IDirect3DPixelShader9**) { return 0; }
    virtual HRESULT CreateQuery(D3DQUERYTYPE, IDirect3DQuery9**) { return 0; }

    virtual HRESULT BeginScene() { return 0; }
    virtual HRESULT EndScene() { return 0; }
    virtual HRESULT Clear(DWORD, const D3DRECT*, DWORD, D3DCOLOR, float, DWORD) { return 0; }
    virtual HRESULT SetRenderState(D3DRENDERSTATETYPE, DWORD) { return 0; }
    virtual HRESULT SetSamplerState(DWORD, D3DSAMPLERSTATETYPE, DWORD) { return 0; }
    virtual HRESULT SetTexture(DWORD, IDirect3DBaseTexture9*) { return 0; }
    virtual HRESULT SetRenderTarget(DWORD, IDirect3DSurface9*) { return 0; }
    virtual HRESULT SetDepthStencilSurface(IDirect3DSurface9*) { return 0; }
    virtual HRESULT SetVertexDeclaration(IDirect3DVertexDeclaration9*) { return 0; }
    virtual HRESULT SetVertexShader(IDirect3DVertexShader9*) { return 0; }
    virtual HRESULT SetPixelShader(IDirect3DPixelShader9*) { return 0; }
    virtual HRESULT SetVertexShaderConstantF(UINT, const float*, UINT) { return 0; }
    virtual HRESULT SetPixelShaderConstantF(UINT, const float*, UINT) { return 0; }
    virtual HRESULT SetStreamSource(UINT, IDirect3DVertexBuffer9*, UINT, UINT) { return 0; }
    virtual HRESULT SetIndices(IDirect3DIndexBuffer9*) { return 0; }
    virtual HRESULT SetViewport(const D3DVIEWPORT9*) { return 0; }
    virtual HRESULT SetScissorRect(const RECT*) { return 0; }

    virtual HRESULT DrawPrimitive(D3DPRIMITIVETYPE, UINT, UINT) { return 0; }
    virtual HRESULT DrawIndexedPrimitive(D3DPRIMITIVETYPE, INT, UINT, UINT, UINT, UINT) { return 0; }
    virtual HRESULT DrawPrimitiveUP(D3DPRIMITIVETYPE, UINT, const void*, UINT) { return 0; }

    virtual HRESULT StretchRect(IDirect3DSurface9*, const RECT*, IDirect3DSurface9*, const RECT*, D3DTEXTUREFILTERTYPE) { return 0; }
    virtual HRESULT UpdateSurface(IDirect3DSurface9*, const RECT*, IDirect3DSurface9*, const POINT*) { return 0; }
    virtual HRESULT GetRenderTargetData(IDirect3DSurface9*, IDirect3DSurface9*) { return 0; }
    virtual HRESULT GetBackBuffer(UINT, UINT, D3DBACKBUFFER_TYPE, IDirect3DSurface9**) { return 0; }
    virtual HRESULT GetSwapChain(UINT, IDirect3DSwapChain9**) { return 0; }
    virtual HRESULT GetDeviceCaps(D3DCAPS9*) { return 0; }
    virtual UINT GetAvailableTextureMem() { return 1024 * 1024 * 1024; }
    virtual HRESULT TestCooperativeLevel() { return 0; }
    virtual HRESULT Reset(D3DPRESENT_PARAMETERS*) { return 0; }
    virtual void SetGammaRamp(UINT, DWORD, const D3DGAMMARAMP*) {}
};

struct IDirect3DDevice9Ex : public IDirect3DDevice9 {};


struct IDirect3D9 : public IUnknown {
    virtual HRESULT CheckDeviceMultiSampleType(UINT, D3DDEVTYPE, D3DFORMAT, BOOL, D3DMULTISAMPLE_TYPE, DWORD*) { return 0; }
    virtual HRESULT CreateDevice(UINT, D3DDEVTYPE, HWND, DWORD, D3DPRESENT_PARAMETERS*, IDirect3DDevice9 **ppDev) {
        static IDirect3DDevice9 s_dev;
        if (ppDev) *ppDev = &s_dev;
        return 0;
    }
    virtual HRESULT CreateDeviceEx(UINT, D3DDEVTYPE, HWND, DWORD, D3DPRESENT_PARAMETERS*, void*, IDirect3DDevice9Ex **ppDev) {
        static IDirect3DDevice9Ex s_devex;
        if (ppDev) *ppDev = &s_devex;
        return 0;
    }
    virtual HRESULT GetAdapterDisplayMode(UINT, D3DDISPLAYMODE *pMode) {
        if (pMode) { pMode->Width = 1920; pMode->Height = 1080; pMode->RefreshRate = 60; pMode->Format = D3DFMT_X8R8G8B8; }
        return 0;
    }
    virtual HMONITOR GetAdapterMonitor(UINT) { return (HMONITOR)(intptr_t)1; }
    virtual UINT GetAdapterCount() { return 1; }
    virtual HRESULT GetAdapterIdentifier(UINT, DWORD, D3DADAPTER_IDENTIFIER9 *pId) {
        if (pId) {
            memset(pId, 0, sizeof(*pId));
            strncpy(pId->Description, "Apple Metal Renderer", sizeof(pId->Description) - 1);
            strncpy(pId->Driver, "Metal", sizeof(pId->Driver) - 1);
            pId->VendorId = 0x106B; // Apple Inc.
            pId->DeviceId = 0x0001;
        }
        return 0;
    }
    virtual HRESULT GetDeviceCaps(UINT, D3DDEVTYPE, D3DCAPS9 *pCaps) {
        if (pCaps) memset(pCaps, 0, sizeof(*pCaps));
        return 0;
    }
    virtual HRESULT CheckDeviceFormat(UINT, D3DDEVTYPE, D3DFORMAT, DWORD, D3DRESOURCETYPE, D3DFORMAT) { return 0; }
    virtual HRESULT CheckDepthStencilMatch(UINT, D3DDEVTYPE, D3DFORMAT, D3DFORMAT, D3DFORMAT) { return 0; }
    virtual UINT GetAdapterModeCount(UINT, D3DFORMAT) { return 1; }
    virtual HRESULT EnumAdapterModes(UINT, D3DFORMAT, UINT, D3DDISPLAYMODE *pMode) {
        if (pMode) { pMode->Width = 1920; pMode->Height = 1080; pMode->RefreshRate = 60; pMode->Format = D3DFMT_X8R8G8B8; }
        return 0;
    }
};

struct IDirect3D9Ex : public IDirect3D9 {};

static inline IDirect3D9 *Direct3DCreate9(UINT SDKVersion) {
    (void)SDKVersion;
    static IDirect3D9 s_d3d9;
    return &s_d3d9;
}

static inline HRESULT Direct3DCreate9Ex(UINT SDKVersion, IDirect3D9Ex **ppD3D) {
    (void)SDKVersion;
    static IDirect3D9Ex s_d3d9ex;
    if (ppD3D) *ppD3D = &s_d3d9ex;
    return 0;
}


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
#define S_PRESENT_OCCLUDED 0x0876087B

#define D3DUSAGE_RENDERTARGET       0x00000001L
#define D3DUSAGE_DEPTHSTENCIL       0x00000002L
#define D3DUSAGE_DYNAMIC            0x00000200L
#define D3DUSAGE_WRITEONLY          0x00000008L

static inline int D3DPERF_BeginEvent(D3DCOLOR col, const wchar_t *wszName) { (void)col; (void)wszName; return 0; }
static inline int D3DPERF_EndEvent(void) { return 0; }
static inline void D3DPERF_SetMarker(D3DCOLOR col, const wchar_t *wszName) { (void)col; (void)wszName; }

#endif // __APPLE__
