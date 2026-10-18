#pragma once

#if defined(__APPLE__)

#include "d3d9.h"

typedef enum _D3DXIMAGE_FILEFORMAT {
    D3DXIFF_BMP         = 0,
    D3DXIFF_JPG         = 1,
    D3DXIFF_TGA         = 2,
    D3DXIFF_PNG         = 3,
    D3DXIFF_DDS         = 4,
    D3DXIFF_PPM         = 5,
    D3DXIFF_DIB         = 6,
    D3DXIFF_HDR         = 7,
    D3DXIFF_PFM         = 8,
    D3DXIFF_FORCE_DWORD = 0x7fffffff
} D3DXIMAGE_FILEFORMAT;

struct ID3DXBuffer : public IUnknown {
    virtual void *GetBufferPointer() { return NULL; }
    virtual DWORD GetBufferSize() { return 0; }
};

struct ID3DXConstantTable : public IUnknown {
    virtual void *GetBufferPointer() { return NULL; }
    virtual DWORD GetBufferSize() { return 0; }
};
typedef struct ID3DXConstantTable *LPD3DXCONSTANTTABLE;

typedef struct _D3DXSHADER_CONSTANTTABLE {
    DWORD Size;
    DWORD Creator;
    DWORD Version;
    DWORD Constants;
    DWORD ConstantInfo;
    DWORD Flags;
    DWORD Target;
} D3DXSHADER_CONSTANTTABLE;

typedef struct _D3DXSHADER_CONSTANTINFO {
    DWORD Name;
    WORD  RegisterSet;
    WORD  RegisterIndex;
    WORD  RegisterCount;
    WORD  Reserved;
    DWORD TypeInfo;
    DWORD DefaultValue;
} D3DXSHADER_CONSTANTINFO;

typedef struct _D3DXSEMANTIC {
    DWORD Usage;
    DWORD UsageIndex;
} D3DXSEMANTIC;

static inline HRESULT D3DXSaveSurfaceToFileA(LPCSTR pDestFile, D3DXIMAGE_FILEFORMAT DestFormat, IDirect3DSurface9 *pSrcSurface, const PALETTEENTRY *pSrcPalette, const RECT *pSrcRect) {
    (void)pDestFile; (void)DestFormat; (void)pSrcSurface; (void)pSrcPalette; (void)pSrcRect;
    return 0;
}

static inline HRESULT D3DXCompileShader(LPCSTR pSrcData, UINT SrcDataLen, const void *pDefines, void *pInclude, LPCSTR pFunctionName, LPCSTR pProfile, DWORD Flags, ID3DXBuffer **ppShader, ID3DXBuffer **ppErrorMsgs, LPD3DXCONSTANTTABLE *ppConstantTable) {
    (void)pSrcData; (void)SrcDataLen; (void)pDefines; (void)pInclude; (void)pFunctionName; (void)pProfile; (void)Flags;
    if (ppShader) *ppShader = NULL;
    if (ppErrorMsgs) *ppErrorMsgs = NULL;
    if (ppConstantTable) *ppConstantTable = NULL;
    return 0;
}

static inline HRESULT D3DXCreateBuffer(DWORD NumBytes, ID3DXBuffer **ppBuffer) {
    (void)NumBytes;
    if (ppBuffer) *ppBuffer = NULL;
    return 0;
}

static inline HRESULT D3DXGetShaderConstantTable(const DWORD *pFunction, LPD3DXCONSTANTTABLE *ppConstantTable) {
    (void)pFunction;
    if (ppConstantTable) *ppConstantTable = NULL;
    return 0;
}

static inline HRESULT D3DXGetShaderInputSemantics(const DWORD *pFunction, D3DXSEMANTIC *pSemantics, UINT *pCount) {
    (void)pFunction; (void)pSemantics;
    if (pCount) *pCount = 0;
    return 0;
}

static inline HRESULT D3DXGetShaderOutputSemantics(const DWORD *pFunction, D3DXSEMANTIC *pSemantics, UINT *pCount) {
    (void)pFunction; (void)pSemantics;
    if (pCount) *pCount = 0;
    return 0;
}

#endif // __APPLE__
