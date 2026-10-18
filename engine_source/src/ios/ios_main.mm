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

static bool s_engineInitialized = false;

void bo1_ios_init(const char *gameDirectory)
{
    if (s_engineInitialized)
    {
        return;
    }
    s_engineInitialized = true;

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
    if (s_engineInitialized)
    {
        Com_Frame();
    }
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

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([BO1AppDelegate class]));
    }
}

#endif // __APPLE__
