#if defined(__APPLE__)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "win_types_compat.h"
#include <win32/win_local.h>
#include <win32/win_common.h>
#include <win32/win_shared.h>
#include <win32/win_main.h>
#include <qcommon/common.h>
#include <qcommon/cmd.h>
#include <qcommon/threads.h>
#include <qcommon/mem_track.h>
#include <universal/physicalmemory.h>
#include <universal/timing.h>
#include <universal/q_parse.h>

typedef void (*BO1_iOS_PresentCallback)(void);

extern "C" {

static bool s_engineInitialized = false;
static char s_gameDir[1024] = {0};

void bo1_ios_init(const char *gameDirectory)
{
    if (s_engineInitialized)
    {
        return;
    }
    s_engineInitialized = true;

    if (gameDirectory) {
        strncpy(s_gameDir, gameDirectory, sizeof(s_gameDir) - 1);
    }

    const char *home = getenv("HOME");
    char logFile[1024];
    if (home) {
        snprintf(logFile, sizeof(logFile), "%s/Documents/bo1_console.log", home);
    } else if (gameDirectory) {
        snprintf(logFile, sizeof(logFile), "%s/bo1_console.log", gameDirectory);
    } else {
        logFile[0] = '\0';
    }

    if (logFile[0]) {
        FILE *f = fopen(logFile, "a");
        if (f) {
            fprintf(f, "\n=== [BO1 iOS Engine Init] gameDirectory: %s ===\n", gameDirectory ? gameDirectory : "(null)");
            fclose(f);
        }
    }

    NSLog(@"[BO1 iOS] Starting Treyarch BO1 Zombies engine at: %s", gameDirectory);

    // Preparar línea de comandos para Treyarch engine
    static char s_cmdline[1024];
    snprintf(s_cmdline, sizeof(s_cmdline),
             "+set fs_basepath \"%s\" +set fs_homepath \"%s\" +set developer 0 +set bo1_zombies 1 +set sv_cheats 1 +devmap zombie_theater",
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

    if (logFile[0]) {
        FILE *f = fopen(logFile, "a");
        if (f) {
            fprintf(f, "=== [BO1 iOS Engine] Com_Init finalizado con éxito ===\n");
            fclose(f);
        }
    }

    NSLog(@"[BO1 iOS] Engine initialized successfully for Kino der Toten!");
}

void bo1_ios_frame(void)
{
    if (s_engineInitialized)
    {
        Com_Frame();
    }
}

void bo1_ios_send_key(int key, int down)
{
    Sys_QueEvent((unsigned int)Sys_Milliseconds(), SE_KEY, key, down, 0, NULL);
}

void bo1_ios_send_mouse(int dx, int dy)
{
    // Ratón / mirada en Treyarch engine
    (void)dx; (void)dy;
}

BO1_iOS_PresentCallback g_bo1_ios_present_callback = NULL;

void bo1_ios_set_present_callback(BO1_iOS_PresentCallback cb)
{
    g_bo1_ios_present_callback = cb;
}

void bo1_ios_execute_command(const char *cmd)
{
    if (s_engineInitialized && cmd && cmd[0])
    {
        Cbuf_AddText(0, cmd);
        Cbuf_AddText(0, "\n");
    }
}

const char *bo1_ios_get_gamedir(void)
{
    return s_gameDir;
}

}

// ----- Controlador de vista y App Delegate para iOS -----

@interface BO1ViewController : UIViewController
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation BO1ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docDir = paths.firstObject;
        NSString *gamesDir = [docDir stringByAppendingPathComponent:@"Games"];

        // Crear carpeta si no existe
        [[NSFileManager defaultManager] createDirectoryAtPath:gamesDir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];

        bo1_ios_init(gamesDir.UTF8String);
    });

    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(engineTick:)];
    if (@available(iOS 15.0, *)) {
        self.displayLink.preferredFrameRateRange = CAFrameRateRangeMake(60, 120, 60);
    }
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)engineTick:(CADisplayLink *)sender
{
    bo1_ios_frame();
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (void)dealloc
{
    [self.displayLink invalidate];
}

@end

@interface BO1AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation BO1AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[BO1ViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}

@end

// Note: The main entry point is driven by SwiftUI launcher (BLOPSPocketApp.swift).

#endif // __APPLE__
