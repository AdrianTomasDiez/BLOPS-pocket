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

typedef struct IDirect3D9 IDirect3D9;
typedef struct IDirect3DDevice9 IDirect3DDevice9;
typedef struct IDirect3DDevice9Ex IDirect3DDevice9Ex;
typedef struct IDirect3DVertexBuffer9 IDirect3DVertexBuffer9;
typedef struct IDirect3DIndexBuffer9 IDirect3DIndexBuffer9;
typedef struct IDirect3DTexture9 IDirect3DTexture9;
typedef struct IDirect3DVertexDeclaration9 IDirect3DVertexDeclaration9;
typedef struct IDirect3DVertexShader9 IDirect3DVertexShader9;
typedef struct IDirect3DPixelShader9 IDirect3DPixelShader9;
typedef struct IDirect3DQuery9 IDirect3DQuery9;
typedef struct IDirect3DSurface9 IDirect3DSurface9;
typedef struct IDirect3DStateBlock9 IDirect3DStateBlock9;
typedef struct IDirect3DVolumeTexture9 IDirect3DVolumeTexture9;
typedef struct IDirect3DCubeTexture9 IDirect3DCubeTexture9;
typedef struct IDirect3DSwapChain9 IDirect3DSwapChain9;

#define D3D_OK 0
#define D3DERR_DEVICELOST 0x88760868
#define D3DERR_DEVICENOTRESET 0x88760869

#endif // __APPLE__
