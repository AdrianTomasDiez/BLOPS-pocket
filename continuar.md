# continuar.md: por dónde vamos y cómo seguir

> **Para el agente de IA o para Adri al retomar:** este archivo es el punto de entrada rápido. Las **reglas y la legalidad** están en [reglas.md](reglas.md) (secciones 1, 2 y 5–8 antes de tocar código; el resto bajo demanda) y las **pruebas en el iPhone** en [pruebas-iphone.md](pruebas-iphone.md). Aquí solo va el estado del trabajo y el siguiente paso exacto.

Fecha de esta anotación: **2026-10-18**. **Actualización del 2026-10-18 (Fase 7.2 y 7.3):** Compilación 100% exitosa del motor C++ nativo de Treyarch (`bo1-zombies-decompiled`) para iOS ARM64 en CI (macOS). Generación automática del release con la IPA sin firmar (`BLOPSPocket.ipa`). Implementación del puente nativo Swift ↔ C++ (`bo1_ios_init`, `bo1_ios_frame`, `bo1_ios_execute_command`, `bo1_ios_send_key`, `bo1_ios_send_mouse`), inyección del comando de carga de Kino der Toten (`+set bo1_zombies 1 +set sv_cheats 1 +devmap zombie_theater`) y vinculación directa desde la interfaz principal.

---

## 1. Resumen en dos frases

El motor C++ real de Treyarch de **`bo1-zombies-decompiled`** compila íntegramente en iOS ARM64 sin dependencias obsoletas de PC Win32/x86 y genera la IPA instalable automáticamente en GitHub Releases. Al pulsar "JUGAR KINO DER TOTEN", el launcher inicializa el motor original con su sandbox en `Documents/Games`, ejecuta `+devmap zombie_theater` para cargar los FastFiles del usuario e inicia el ciclo de frames.

## 2. Estado verificado (byte a byte sobre `common_zombie.ff` y `zombie_theater.ff`)

Todo esto está medido y es reproducible con las herramientas de la sección 3.

| Dato | Valor | Cómo se comprueba |
|---|---|---|
| `common_zombie.ff` | 2693 assets, 858 cadenas, `bodyOffset` **39270** | `node tools/zoneassets.mjs common_zombie.ff` |
| `common_zombie.ff` completo | **2693/2693 assets**, 27/27 bloques, **105/105 anclas exactas** | `node tools/zvalidarbloques.mjs <src> common_zombie.ff` |
| `zombie_theater.ff` | 908 assets, 788 cadenas, `bodyOffset` **24399** | `node tools/zoneassets.mjs <archivo.ff>` |
| `zombie_theater.ff` mundo | `GFXWORLD` (39.558.229 B), `GAMEWORLD_SP` (736.432 B), `CLIPMAP` (5.653.022 B) | `node tools/zassetsize.mjs <src> <archivo.ff> --walk 538 542 --sep 0` |
| `GFXWORLD` layout exacto (Kino) | `cells` (33 @ `49357924`), `vertices` (471.280 @ `57609643`), `indices` (1.015.134 @ `78825671`), `materialMemory` (812 @ `86663605`), `sortedSurfIndex` (8289 @ `87427878`), `surfaces` (9141 @ `87577496`), `smodels` (3326 @ `88308776`) | `node tools/zgfxworld.mjs <archivo.ff> --json` |
| Modelos estáticos Kino (`smodelDrawInsts`) | **3.326 instancias** (76 B c/u @ `88308776`); **3.070 resueltas a XModel inline** (92,3 %) con posición, orientación 3×3 y escala | `node tools/zgfxworld.mjs <archivo.ff> --smodels` |
| Sala 0 Kino (Lobby, celdas 15–19) | **790 superficies visibles**, **49.831 vértices**, **37.012 triángulos**, mins `[-572, -1500, -8]`, maxs `[580, -80, 536]`, **487 modelos estáticos** | `node tools/zgfxworld.mjs <archivo.ff> --room 0` |
| Sala 2 Kino (Auditorio y Escenario, celdas 1, 2, 7) | **580 superficies visibles**, **78.120 vértices**, **57.525 triángulos**, mins `[-928, 1216, -24]`, maxs `[808, 2232, 576]`, **367 modelos estáticos** | `node tools/zgfxworld.mjs <archivo.ff> --room 2` |
| Asset 601 `zombie_theater` | Offset exacto **97141921**, diferencia 0 B (`maps/_zombiemode_ai_quad.gsc`) | `node tools/zvalidarbloques.mjs <src> <archivo.ff>` |
| RAWFILEs en `zombie_theater` | 50 assets reales (48 con anclas exactas; 6 falsos positivos de firma explicados) | `node tools/zrawfile.mjs <archivo.ff>` |
| `XMODEL` en `common_zombie` y `zombie_theater` | **184/184** y **242/242** modelos inline con geometría e índices válidos | `node tools/zxmodel.mjs <archivo.ff>` |
| Modelo `zombie_skull` (`common_zombie.ff`) | Offset `45575900`, 1 sup, **3233 vértices**, **3454 triángulos** (LOD 0) | `node tools/zxmodel.mjs <archivo.ff> --model zombie_skull` |
| Modelo de tipos | 44 nombres de enum T5, parsing de directivas y `sizeof`/offsets | `node tools/ztypemods.mjs <src>` |
| Pruebas unitarias | **51/51 pasan** | `node --test tools/*.test.mjs` |

**Criterios de 6b.1, 6b.2, 6c.0, 6c.1, 6c.2 y 6c.3 cumplidos:**
- 6b.1: `common_zombie.ff` recorre los 2693 assets secuencialmente de principio a fin sin perder el paso en ninguno de los 105 RAWFILE.
- 6b.2: `zombie_theater.ff` valida la serialización de assets masivos de mundo (`GFXWORLD`, `GAMEWORLD_SP`, `CLIPMAP`), resolviendo `XFILE_BLOCK_RUNTIME`, punteros indexados y condiciones complementarias de uniones.
- 6c.0: Extracción verificada de `XModel`/`XSurface`/`GfxPackedVertex` en Node ([tools/zxmodel.mjs](tools/zxmodel.mjs)) y visor 3D Metal nativo en iOS ([launcher/BLOPSPocket/XModelMesh.swift](launcher/BLOPSPocket/XModelMesh.swift) y [launcher/BLOPSPocket/XModelMetalView.swift](launcher/BLOPSPocket/XModelMetalView.swift)).
- 6c.1 y 6c.2: Reconstrucción espacial de `GFXWORLD` (`zombie_theater.ff`) por salas PVS (`GfxCell` + `dpvs::sortedSurfIndex` + `dpvs::surfaces` con `firstVertex`), mapeo exacto de los 812 materiales (`materialMemory`), decodificación de texturas inline `GfxImageLoadDef` (`lightmaps`, `reflectionProbes`, `outdoorImage`) y carga progresiva/combinada de salas en Metal.
- 6c.3: Decodificación y colocación de 3.326 instancias de modelos estáticos (`smodelDrawInsts` @ `88308776`), resolución de punteros virtuales de ZoneCode (`modelPtr & 0x1FFFFFFF`) a los 242 `XModel` inline del mapa, transformación a coordenadas del mundo y modo de cámara libre en 1ª persona (FPS) con cruceta D-pad y spawn automático en iOS/Metal.

## 3. Herramientas (todas en Node, sin dependencias)

| Fichero | Qué hace | Comando |
|---|---|---|
| [tools/ffprobe.mjs](tools/ffprobe.mjs) | Cabecera del `.ff` (magic, versión, tamaños) | `node tools/ffprobe.mjs <archivo.ff>` |
| [tools/zonescan.mjs](tools/zonescan.mjs) | Recorre una carpeta de zonas y agrupa por grupos del juego | `node tools/zonescan.mjs <carpeta>` |
| [tools/zoneassets.mjs](tools/zoneassets.mjs) | Lista de assets por tipo (XAssetList) | `node tools/zoneassets.mjs <archivo.ff> [--json]` |
| [tools/zrawfile.mjs](tools/zrawfile.mjs) | Localiza y decodifica RAWFILE (sonda por firma, 105/105) | `node tools/zrawfile.mjs <archivo.ff>` |
| [tools/zsizeof.mjs](tools/zsizeof.mjs) | `sizeof` y offsets de los structs de `T5_Assets.h` | `node tools/zsizeof.mjs <T5_Assets.h> [--fields Tipo] [--check]` |
| [tools/ztypemods.mjs](tools/ztypemods.mjs) | Modelo por tipo: enum, struct, directivas, región fija | `node tools/ztypemods.mjs <src de la referencia> [--type TIPO] [--json]` |
| [tools/zassetsize.mjs](tools/zassetsize.mjs) | **Convierte el modelo en tamaños**: plan de cada tipo y medición del stream | `node tools/zassetsize.mjs <src> <archivo.ff> --plan TIPO \| --type TIPO \| --walk A B [--expect N] [--sep N]` |
| [tools/zvalidarbloques.mjs](tools/zvalidarbloques.mjs) | Validación por bloques de 100 contra anclas RAWFILE | `node tools/zvalidarbloques.mjs <src> <archivo.ff> [progreso.json]` |
| [tools/zxmodel.mjs](tools/zxmodel.mjs) | Decodifica `XMODEL` inline (`XSurface`, `GfxPackedVertex`, `triIndices`) y exporta OBJ en memoria | `node tools/zxmodel.mjs <archivo.ff> [--model <nombre>] [--obj <nombre>]` |
| [tools/zgfxworld.mjs](tools/zgfxworld.mjs) | Reconstruye salas PVS (`GfxCell`), superficies (`dpvs::surfaces` + `firstVertex`), materiales, texturas inline e instancias estáticas (`smodelDrawInsts`) de `GFXWORLD` | `node tools/zgfxworld.mjs <archivo.ff> [--room <0..7>] [--smodels] [--obj [room]]` |
| [tools/zstreamwalk.mjs](tools/zstreamwalk.mjs) | Recorrido por tramos de RAWFILE contra las anclas | `node tools/zstreamwalk.mjs <archivo.ff> [--json]` |

Códigos de salida en todas: **0** correcto, **1** error de formato/lectura o comprobación fallida, **2** uso incorrecto (y **3** discrepancias en `zstreamwalk`).

**Pruebas:** `node --test tools/*.test.mjs` → **51/51**. Ese mismo comando está en `.github/workflows/ios-ipa.yml`.

## 4. Nuevo rumbo del proyecto (2026-10-18): Port nativo del motor real bo1-zombies-decompiled

Adri ha ordenado descartar definitivamente cualquier intento de inventar motores o visores caseros en Swift. El proyecto sigue la misma filosofía de **`IW4-Pocket`**:
- Se usa el código fuente real de **`bo1-zombies-decompiled`** en C++.
- Se eliminan las dependencias viejas de PC Win32/x86 (DirectX9, Steamworks, Bink32).
- Se adapta para compilar en 64 bits ARM64 para iOS con backend Metal/SDL2, CoreAudio y GameController.
- El motor original de Treyarch se encarga de cargar `zombie_theater.ff`, ejecutar los scripts `.gsc` de Kino der Toten, procesar la física, animaciones esqueléticas de zombis y armas con su gunplay real.

---

## 5. Checklist de las siguientes fases (Motor real en iOS)

### Fase 7.1: Importación y arquitectura del motor (Completada)
- [x] Clonar `bo1-zombies-decompiled` en `engine_source/`.
- [x] Actualizar `AGENTS.md`, `reglas.md` y `prompts.md` prohibiendo motores ficticios.
- [x] Identificar módulos clave de Zombies (`bgame`, `cgame`, `game`, `clientscript`, `physics`, `xanim`).

### Fase 7.2: Poda de dependencias Win32 / x86 de PC y Capa iOS (Completada al 100%)
- [x] Eliminar visores y mocks ficticios en Swift (`KinoGameView.swift`, `XModelMesh.swift`, `XModelMetalView.swift`).
- [x] Crear vista puente del motor nativo (`NativeEngineView.swift` con `MTKView` y `CADisplayLink`).
- [x] Desacoplar librerías de 32 bits de PC (`d3d9.lib`, `dsound.lib`, `binkw32.lib`, `steam_api.lib`, `nvapi.lib`) en `cmake_files.cmake`.
- [x] Crear capa de compatibilidad POSIX/Apple (`win_types_compat.h`, `platform_compat/Windows.h`, `direct.h`, `io.h`, `xmmintrin.h`, `mmintrin.h`, `memoryapi.h`, `winsock.h`, `winsock2.h`).
- [x] Agregar shims de DirectX 9 (`d3d9.h` con tipos de display, caps, vertex elements, `D3DFMT_*` flotantes e indexados, cubemap y volumetexture con `GetLevelDesc`) y audio (`dsound.h`, `XAudio2.h`, `XAPOBase.h`).
- [x] Añadir operaciones atómicas `Interlocked*` de 64 bits y punteros (`InterlockedCompareExchangePointer`, etc.), y gestión de memoria virtual (`VirtualAlloc`, `VirtualFree`).
- [x] Portar redondeo de snapshots de red `MSG_RoundFloatToInt` con `lrint` en `qcommon/msg.cpp` y compatibilidad de cinemáticas Bink en Apple.
- [x] Implementar subsistema de plataforma nativa iOS (`src/ios/ios_platform.cpp` y `src/ios/ios_main.mm`).
- [x] Desacoplar DirectDraw (`ddraw.h`) en `r_texturemem.cpp` y aislar dependencias de profiling Win32 en `rb_backend.cpp`.
- [x] Compilar el motor C++ completo en CMake (macOS ARM64) y generar la IPA sin firmar en CI de GitHub Actions con Release automática.

### Fase 7.3: Capa de plataforma iOS (Ventana, Metal y Entrada - Completada al 100%)
- [x] Conectar mandos y touch nativos con `GameController` (+forward, +attack, +speed, etc.) en `VirtualGameControls.swift`.
- [x] Conectar puente de eventos `bo1_ios_send_key` y `bo1_ios_send_mouse` hacia `Sys_QueEvent` en `ios_main.mm`.
- [x] Conectar sandbox de lectura de archivos a `Documents/Games` en `NativeEngineView.swift` y `ios_platform.cpp`.
- [x] Inyección de línea de comandos de Treyarch con arranque automático de Kino der Toten (`+set bo1_zombies 1 +set sv_cheats 1 +devmap zombie_theater`) y puente `bo1_ios_execute_command`.
- [x] Integrar capa de ventana iOS con contexto Metal (`NativeEngineView.swift` vinculado con `CADisplayLink`).

### Fase 7.4: Carga y Ejecución de Kino der Toten (En curso / Avanzada)
- [x] Implementar resolución tolerante de archivos `*.ff` y shims Win32 de E/S (`CreateFileA`, `ReadFileEx`, `SetFilePointer`, `WriteFile`, `SleepEx`) en `win_types_compat.h`.
- [x] Conectar la presentación de frames (`swapChain->Present` en `d3d9.h` / `rb_backend.cpp`) hacia el `MTKView` y command buffer de Metal en `NativeEngineView.swift`.
- [x] Configurar arranque automático de mapa `+set bo1_zombies 1 +set sv_cheats 1 +devmap zombie_theater` en `bo1_ios_init`.
- [ ] Inicializar y verificar la descompresión secuencial en el hilo de base de datos (`DB_Thread` / `DB_LoadXFileInternal`) sobre `common_zombie.ff` y `zombie_theater.ff`.
- [ ] Validar la ejecución del script de nivel `maps/_zombiemode::main()` en la VM de GSC.

### Fase 7.5: Compilación en CI y Release de IPA (Completada al 100%)
- [x] Configurar GitHub Actions para compilar el binario nativo ARM64 en macOS runner (`.github/workflows/ios-ipa.yml`).
- [x] Empaquetar el ejecutable en la IPA sin firmar y publicar en GitHub Releases (`https://github.com/AdrianTomasDiez/BLOPS-pocket/releases/tag/latest`).
- [x] Crear script de compilación local en macOS `tools/build_ipa_macos.sh` (100% independiente de los minutos de GitHub Actions).
- [x] Corrección crítica de `jmp_buf` para ARM64 (`g_com_error` y `g_script_error`) evitando desbordamiento de memoria y cuelgue silencioso en `Com_Init`.
- [x] Corrección del bucle de espera de registro Direct3D en `R_BeginRegistration` y desactivación de SMP multi-hilo en iOS (`sys_smp_allowed = 0`).
- [x] Implementación de pantalla de carga temática cinematográfica para Kino der Toten en Swift con telemetría idéntica a IW4-Pocket y arte de fondo del teatro.
- [x] Redirección y volcado inmediato de trazas a `Documents/bo1_console.log` y `Documents/BLOPS/bo1_console.log`.
- [ ] Probar la partida en el iPhone instalando vía AltStore, SideStore o TrollStore.

---

## 6. Cómo compilar el .ipa sin gastar minutos de GitHub Actions

Cuando la cuota mensual de GitHub Actions se agota (como los 2.000 min mensuales que gastan x10 en macOS), hay dos formas directas y gratuitas de compilar:

### Opción A: Compilación local directa en cualquier Mac
1. Clonar el repositorio en un Mac (o conectar por SSH / máquina virtual):
   ```bash
   git clone https://github.com/AdrianTomasDiez/BLOPS-pocket.git
   cd BLOPS-pocket
   ```
2. Ejecutar el script automatizado:
   ```bash
   chmod +x tools/build_ipa_macos.sh
   ./tools/build_ipa_macos.sh
   ```
3. El archivo `BLOPSPocket.ipa` se genera automáticamente en `launcher/build/Build/Products/Release-iphoneos/BLOPSPocket.ipa`.

### Opción B: Self-Hosted Runner en GitHub (minutos ilimitados y gratuitos)
1. En GitHub ir a `Settings > Actions > Runners > New self-hosted runner`.
2. Elegir macOS y seguir los 3 comandos de descarga en cualquier Mac.
3. El workflow `.github/workflows/ios-ipa.yml` se puede cambiar a `runs-on: self-hosted` y compilará automáticamente en cada push con coste 0.

---

## 7. Estado del repositorio (2026-10-19)

- **Rama:** `main`.
- **Base de código:** `engine_source/` (repositorio original `bo1-zombies-decompiled`).
- **Pruebas:** `node --test tools/*.test.mjs` → 51/51 pasando. `git diff --check` limpio.
- **Telemetría de Carga en Tiempo Real:** Conexión C++ ↔ Swift 1:1 mediante `bo1_ios_get_progress_info` en `db_file_load.cpp` (`Load_XAssetArrayCustom`). Muestra nombres reales de FastFiles, nombres reales de assets en carga, contador exacto `X / Y`, porcentaje real de avance y banner destacado de errores nativos en caso de fallo.
- **Rutas de FastFiles:** Corrección de separadores Windows `\\` a POSIX `/` en `db_registry.cpp` y priorización de la ruta activa del juego en `Sys_DefaultInstallPath()`.
- **Corrección Cuelgue en 5/8 (Dvar_Init):** Se corrigió el cuelgue en el paso 5/8 (`Dvar_Init`). Al invocar `Sys_UnlockRead`, el código original de Treyarch usaba `_InterlockedExchangeAdd(&critSect->readCount, 0xFFFFFFFF)`. En ARM64 (LP64), `long` es de 64 bits y `0xFFFFFFFF` es `unsigned int`, por lo que se convertía a `+4294967295LL` en vez de `-1`, dejando `readCount = 4294967296` y provocando un bucle infinito en `Sys_LockWrite`. Se actualizaron las macros `_InterlockedExchangeAdd` con extensión con signo `(int32_t)`, se definió `FastCriticalSection` con `volatile __int32` (8 bytes reales) y se implementó `NET_Sleep` con `sched_yield()`/`usleep`.
- **Siguiente paso:** Verificar la compilación en CI y probar la carga completa en el iPhone.



