# continuar.md: por dónde vamos y cómo seguir

> **Para el agente de IA o para Adri al retomar:** este archivo es el punto de entrada rápido. Las **reglas y la legalidad** están en [reglas.md](reglas.md) (secciones 1, 2 y 5–8 antes de tocar código; el resto bajo demanda) y las **pruebas en el iPhone** en [pruebas-iphone.md](pruebas-iphone.md). Aquí solo va el estado del trabajo y el siguiente paso exacto.

Fecha de esta anotación: **2026-10-18**. **Actualización del 2026-10-18 (Fase 6c.3):** Integración de instancias de modelos estáticos (`smodelDrawInsts`) y modo de cámara libre en primera persona (FPS) en iOS/Metal. Se resolvió la aritmética de punteros virtuales de ZoneCode: `assetIndex = ((modelPtr & 0x1FFFFFFF) - 17137) / 8` sobre la tabla `XAssetList` @ 17135 de `zombie_theater.ff`, enlazando **3.070 de 3.326 instancias (92,3 %)** directamente con los 242 `XModel` inline del mapa (las 256 restantes son modelos externos declarados en `common_zombie.ff`). Cada instancia se transforma al espacio del mundo con `origin + scale * (vertex * axis)`. Se añadieron pruebas unitarias en [tools/zgfxworld.test.mjs](tools/zgfxworld.test.mjs) (51/51 tests pasan). En SwiftUI/Metal ([launcher/BLOPSPocket/XModelMetalView.swift](launcher/BLOPSPocket/XModelMetalView.swift)), se implementó el selector de cámara (`Orbital` vs `1ª Persona (FPS)`), proyección perspectiva a 65° FOV, control de mirada táctil (pitch/yaw), cruceta virtual D-pad para desplazamiento horizontal y elevación vertical en Z, ajuste de paso (50–600 u), botón de spawn automático a altura de ojos (`mins.z + 65.0`) y badge con coordenadas `(X, Y, Z)` en tiempo real.

---

## 1. Resumen en dos frases

Fases **0–5 hechas**: launcher iOS, acceso persistente a la carpeta del juego y catálogo de las 143 zonas. El **motor (fase 6) avanza**: 6a (lista de assets), 6b.1/6b.2 (medición secuencial completa y assets de mundo), **6c.0 (primer modelo 3D real XModel en Metal)**, **6c.1 (geometría `GFXWORLD`)**, **6c.2 (reconstrucción espacial de salas PVS y texturas inline)** y **6c.3 (instancias de modelos estáticos `smodelDrawInsts` y cámara libre en 1ª persona en Metal)** implementadas en código Swift/Metal y herramientas Node verificables.

**Todavía no se puede jugar.** Lo que hay es un launcher con catálogo, visor 3D nativo en Metal capaz de renderizar modelos, salas espaciales combinables de Kino der Toten con props estáticos posicionados en coordenadas de mapa, modo de cámara libre FPS interactivo con cruceta táctil, y herramientas que decodifican el formato.

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

### Fase 7.2: Poda de dependencias Win32 / x86 de PC y Capa iOS (Completada)
- [x] Eliminar visores y mocks ficticios en Swift (`KinoGameView.swift`, `XModelMesh.swift`, `XModelMetalView.swift`).
- [x] Crear vista puente del motor nativo (`NativeEngineView.swift` con `MTKView` y `CADisplayLink`).
- [x] Desacoplar librerías de 32 bits de PC (`d3d9.lib`, `dsound.lib`, `binkw32.lib`, `steam_api.lib`, `nvapi.lib`) en `cmake_files.cmake`.
- [x] Crear capa de compatibilidad POSIX/Apple (`win_types_compat.h`, `platform_compat/Windows.h`, `direct.h`, `io.h`, `xmmintrin.h`, `mmintrin.h`).
- [x] Agregar shims de DirectX 9 (`d3d9.h` con tipos de display, caps y vertex elements) y audio (`XAudio2.h`, `XAPOBase.h`).
- [x] Añadir tipos de 64 bits (`LONG64`, `ULONG64`), `SwitchToThread` y estructuras GDI (`HMONITOR`, `HDC`, `RECT`, `POINT`, `GUID`).
- [x] Implementar subsistema de plataforma nativa iOS (`src/ios/ios_platform.cpp` y `src/ios/ios_main.mm`).
- [x] Adaptar `CMakeLists.txt` con bundle iOS y frameworks nativos (Metal, GameController, AudioToolbox).
- [x] Conectar la compilación de CMake en CI (`.github/workflows/ios-ipa.yml`) para verificar compilación ARM64 en runner macOS.

### Fase 7.3: Capa de plataforma iOS (Ventana, Metal y Entrada)
- [ ] Integrar capa de ventana iOS con contexto Metal (usando SDL2 o capa puente nativa).
- [ ] Conectar el subsistema de audio con CoreAudio / OpenAL.
- [ ] Conectar mandos y touch nativos con `GameController` (+forward, +attack, +speed, etc.).
- [ ] Conectar sandbox de lectura de archivos a `Documents/Games`.

### Fase 7.4: Carga y Ejecución de Kino der Toten
- [ ] Inicializar subsistema de FastFiles (`DB_Init`, `XAssetList`) sobre `zombie_theater.ff` y `common_zombie.ff`.
- [ ] Ejecutar la máquina virtual GSC para iniciar la partida en solo en Kino der Toten.
- [ ] Verificar renderizado nativo con shaders, modelos animados y audio real de Zombies.

### Fase 7.5: Compilación en CI y Release de IPA
- [x] Configurar GitHub Actions para compilar el binario nativo ARM64 en macOS runner.
- [x] Empaquetar el ejecutable en la IPA sin firmar y publicar en GitHub Releases.
- [ ] Probar la partida en el iPhone.

---

## 6. Estado del repositorio (2026-10-18)

- **Rama:** `main`.
- **Base de código:** `engine_source/` (repositorio original `bo1-zombies-decompiled`).
- **Pruebas:** `node --test tools/*.test.mjs` → 51/51 pasando. `git diff --check` limpio.
- **Siguiente paso:** Completar la integración del backend Metal (`r_metal.mm`) y mapear controles táctiles a `Sys_QueEvent`.
