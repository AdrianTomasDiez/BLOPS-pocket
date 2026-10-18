#if defined(__APPLE__)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "win_types_compat.h"
#include <win32/win_local.h>
#include <win32/win_common.h>
#include <win32/win_main.h>
#include <qcommon/common.h>
#include <qcommon/threads.h>
#include <qcommon/mem_track.h>
#include <universal/physicalmemory.h>
#include <universal/timing.h>

extern "C" {

void bo1_ios_init(const char *gameDirectory)
{
    NSLog(@"[BO1 iOS] Starting Treyarch BO1 Zombies engine at: %s", gameDirectory);

    // Preparar línea de comandos para Treyarch engine
    static char s_cmdline[1024];
    snprintf(s_cmdline, sizeof(s_cmdline),
             "+set fs_basepath \"%s\" +set fs_homepath \"%s\" +set developer 0",
             gameDirectory, gameDirectory);

    // Inicializaciones de subsistemas
    Sys_InitializeCriticalSections();
    Sys_InitMainThread();
    PMem_Init();
    track_init();

    Com_InitParse();
    Dvar_Init();
    InitTiming();
    Sys_FindInfo();

    // Inicializar el ciclo central de Call of Duty
    Com_Init(s_cmdline);

    NSLog(@"[BO1 iOS] Engine initialized successfully!");
}

void bo1_ios_frame(void)
{
    Com_Frame();
}

}

#endif // __APPLE__
