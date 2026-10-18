#if defined(__APPLE__)
#include <mjpeg/mjpeg.h>
#include <mjpeg/yuv.h>
#include <cstddef>

bool mjpeg_run_encoder = false;

void mjpeg_initonce() {}
void __cdecl mjpeg_set_callback(void (__cdecl *)(unsigned __int8 *, unsigned __int8 *, unsigned __int8 *)) {}
void __cdecl mjpeg_init() {}
bool __cdecl mjpeg_is_encoding() { return false; }
void __stdcall mjpeg_thread(void *) {}
void __cdecl mjpeg_close() {}
void __cdecl mjpeg_draw() {}

void __cdecl yuv_init_internal() {}
void __cdecl yuv_init(int width, int height, bool double_buffer) {}
char __cdecl yuv_encode_frame() { return 0; }
void __cdecl yuv_get_buffers(unsigned __int8 **y, unsigned __int8 **u, unsigned __int8 **v) {
    if (y) *y = NULL;
    if (u) *u = NULL;
    if (v) *v = NULL;
}
void __cdecl yuv_shutdown_internal() {}
void __cdecl yuv_shutdown() {}
void __cdecl yuv_lost_device() {}
void __cdecl yuv_recover_device() {}

#endif // __APPLE__
