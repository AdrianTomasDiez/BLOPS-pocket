#include <stdio.h>
#include <stdint.h>

// Puente de símbolos C entre el launcher Swift y el motor nativo de Treyarch C++
// Se definen con enlace débil (weak) para enlazarse limpiamente en standalone y
// sustituirse por la implementación real de ios_main.mm al vincular el motor.

__attribute__((weak, visibility("default")))
void bo1_ios_init(const char *gameDirectory) {
    printf("[BLOPS Launcher] Inicializando puente de motor Treyarch en: %s\n", gameDirectory ? gameDirectory : "(null)");
    const char *home = getenv("HOME");
    if (home) {
        char path[1024];
        snprintf(path, sizeof(path), "%s/Documents/bo1_console.log", home);
        FILE *f = fopen(path, "a");
        if (f) {
            fprintf(f, "[AVISO] bo1_ios_init del launcher stub ejecutado con gameDirectory: %s\n", gameDirectory ? gameDirectory : "(null)");
            fclose(f);
        }
    }
}

__attribute__((weak, visibility("default")))
void bo1_ios_frame(void) {
    // Frame tick nativo
}

__attribute__((weak, visibility("default")))
void bo1_ios_send_key(int key, int down) {
    // Inyección de tecla/botón hacia Sys_QueEvent
}

__attribute__((weak, visibility("default")))
void bo1_ios_send_mouse(int dx, int dy) {
    // Inyección de delta de ratón/mirada hacia Sys_QueEvent
}

__attribute__((weak, visibility("default")))
void bo1_ios_execute_command(const char *cmd) {
    // Inyección de comandos Treyarch
}

typedef void (*BO1_iOS_PresentCallback)(void);
__attribute__((weak, visibility("default")))
void bo1_ios_set_present_callback(BO1_iOS_PresentCallback cb) {
    // Registro de callback de presentación de pantalla
}

