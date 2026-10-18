#pragma once
#include <ios/win_types_compat.h>

#ifndef CSIDL_PERSONAL
#define CSIDL_PERSONAL 0x0005
#endif

#ifndef CSIDL_LOCAL_APPDATA
#define CSIDL_LOCAL_APPDATA 0x001c
#endif

#ifndef CSIDL_FLAG_CREATE
#define CSIDL_FLAG_CREATE 0x8000
#endif

static inline long SHGetFolderPathA(void *hwndOwner, int nFolder, void *hToken, unsigned long dwFlags, char *pszPath) {
    (void)hwndOwner; (void)nFolder; (void)hToken; (void)dwFlags;
    const char *home = getenv("HOME");
    if (!home) home = ".";
    snprintf(pszPath, 260, "%s/Documents", home);
    return 0; // S_OK
}
