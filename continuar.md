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

## 4. Estado de las fases de medición y transición a motor

1. ~~**Fase 6b.1 (Medición secuencial de `common_zombie.ff`)**~~: Completa (2693/2693 assets, 105/105 anclas exactas).
2. ~~**Fase 6b.2 (Assets de mundo en mapas como `zombie_theater.ff`)**~~: Completa (`GFXWORLD`, `GAMEWORLD_SP`, `CLIPMAP` sincronizados, asset 601 en offset exacto 97141921 con diferencia 0).
3. ~~**Fase 6c.0 (Primer modelo 3D real en iPhone con Metal)**~~: Implementada (`tools/zxmodel.mjs` + lector Swift `XModelMesh.swift` y renderizador `MTKView` en `XModelMetalView.swift`).
4. ~~**Fase 6c.1 (Geometría real del mapa `GFXWORLD` en Metal)**~~: Implementada (`tools/zgfxworld.mjs` + extractor Swift y modo mapa en `XModelMetalView.swift`).
5. ~~**Fase 6c.2 (Reconstrucción visual y espacial de Kino der Toten, materiales y texturas inline)**~~: Implementada (`srfTriangles_t::firstVertex`, 33 celdas PVS agrupadas en salas reconocibles, acumulación progresiva de salas, 812 materiales mapeados y textura `GfxImageLoadDef` decodificada en `MTLTexture`).
6. ~~**Fase 6c.3 (Instancias de modelos estáticos `smodelDrawInsts` y cámara libre en 1ª persona FPS)**~~: Implementada (3.326 smodels decodificados, 3.070 enlazados a XModel inline, colocación en mundo por matriz de ejes y escala, y controles de cámara FPS interactivos con cruceta táctil en Metal).
7. **Fase 6c.4 (Malla de colisión de `clipMap_t` y física básica de jugador / caminar sobre el suelo)**: Siguiente paso para impedir atravesar paredes y mantener los pies sobre las superficies transitables de Kino der Toten.

Criterio de cierre de 6b.1: `--walk 0 1 --expect 843 --sep 0` sale con 0 y el recorrido de `common_zombie` no necesita las anclas para avanzar.

## 5. Dependencias y entorno

- **La copia de referencia** (código fuente de OpenAssetTools) se lee de `C:\Users\adri3\AppData\Local\Temp\oat-ref\src`. Si Windows limpia `Temp`, `ztypemods.mjs` y `zassetsize.mjs` salen con 1. **Hecha:** copia fuera del repo en `%USERPROFILE%/oat-ref-src` (solo se leen sus datos y cabeceras como texto; no se copia código). Los stubs locales `tools/oat-ref/` se borraron por código muerto.
- **`common_zombie.ff`** se lee de la raíz del proyecto; `*.ff` está en `.gitignore`, así que no puede acabar en un commit por descuido (regla 1 de reglas.md §2).
- Sin Xcode ni Mac aquí: el Swift solo compila en GitHub Actions. El iPhone lo usa Adri.

## 6. Estado del repositorio (2026-10-17)

- Las herramientas, `reglas.md`, el workflow y este archivo ya están commiteados (HEAD `769765b`). `main` va **2 commits por delante** de `origin/main`, sin push.
- Sin commitear: cambios en [tools/zassetsize.mjs](tools/zassetsize.mjs) y el nuevo [tools/zvalidarbloques.mjs](tools/zvalidarbloques.mjs) (valida el recorrido por bloques de 100 contra las anclas), además de `AGENTS.md` y los ajustes de documentación del 2026-10-17. `.freebuff/` se deja sin commitear a propósito.

## 7. Después de 6b: el motor (lo grande)

**6c–6e no están empezadas** y son el grueso del proyecto. Los tres problemas duros, por orden de dificultad:

1. **Render en Metal.** Los materiales de BO1 PC son **shaders DX9**; hay que reescribir el sistema de materiales con shaders propios o traducir bytecode. No hay base de código legal y lista para iOS (KisakBlack es Windows/D3D9 y solo multijugador; `bo1-zombies-decompiled` no tiene licencia y no se puede copiar).
2. **Lógica y scripts.** Hace falta una **VM de GSC** (los scripts de Zombies vienen en los `.ff` del propio usuario), sistema de entidades, colisiones y física.
3. **Memoria.** `common_zombie` son 76 MiB descomprimidos y cada mapa 106–114 MiB, antes de GPU y audio. IW4-Pocket (MW2) se cierra al cargar mapas con ~3 GB: previsiblemente habrá que leer por bloques, como ya se anotó en reglas.md.

Y un bloqueo práctico: 6c–6e necesitan **Xcode y un iPhone**, que no están en el entorno del agente. Lo que se puede adelantar aquí es diseño, formato y las piezas de Node.

## 8. Porcentaje de avance (estimación por esfuerzo, 2026-10-15)

Sin medir líneas de código: **en torno al 10 %**, tirando a 12–15 % si se cuenta lo cerrado del launcher. El 90 % que queda es la parte difícil, no la mecánica.

| Bloque | Peso | Estado | % del bloque |
|---|---|---|---|
| Launcher, CI, IPA, documentación (fases 0–5 y 7) | ~10 % | Hecho; 10 de 12 pruebas de dispositivo (las 2 restantes dependen del motor) | ~95 % |
| Lectura de las zonas `.ff` (6a/6b) | ~10 % | RAWFILE al 100 %, modelo de 33 de 44 tipos, tamaños ya medidos; falta la expansión anidada | ~50–60 % |
| Render en Metal (mundo, materiales, shaders DX9) | ~30 % | Sin empezar | 0 % |
| Sistemas de juego: entidades, VM de GSC, Zombies, UI, física, audio | ~35 % | Sin empezar | 0 % |
| Memoria, rendimiento y pulido hasta que sea jugable | ~15 % | Sin empezar | 0 % |

Dos avisos sobre este número: (1) el porcentaje por esfuerzo no es lineal, porque lo que queda incluye **incógnitas de viabilidad** (shaders DX9→Metal, VM de GSC), no solo trabajo; (2) la referencia más cercana, IW4-Pocket (MW2, con un runtime ya diseñado que copiar), sigue cerrandose al cargar mapas.

## 9. Plan por pasos

El orden recomendado **no** es terminar 6b antes de tocar el motor: conviene hacer 1–4, saltar al primer hito visual (8–10) y volver a la cobertura completa solo cuando haga falta. Lo que cambia el proyecto de ánimo es ver algo en pantalla.

**A. Cerrar 6b.1 (todo verificable sin dispositivo)**

1. **Commit del punto de retorno:** hecho en local (el fichero basura `h origin main` ya está borrado). Sin verificación: es higiene.
2. **Referencia fijada** (antes en `C:\Users\adri3\AppData\Local\Temp\oat-ref`) en `%USERPROFILE%/oat-ref-src`. Comprobación: `ztypemods` y `zassetsize` arrancan con la carpeta temporal borrada.
3. **Diagnóstico nuevo (2026-10-15), sin cambiar código:** (a) con `--sep 0` la base del `MATERIAL` es 0x9b7a y las lecturas de `textureCount`/`constantCount`/`stateBitsCount` (offsets 0xaa, 0xab, 0xac) salen bien: 1, 0, 1. Con el `--sep 1` por defecto la base cae en 0x9b7b y los conteos salen mal. (b) `constantTable` tiene puntero **nulo** (`0x00000000`) y el medidor igualmente suma `constantCount × 32`: hay que contar un bloque solo si su puntero vale `0xffffffff`. (c) Tras eso, falta la expansión del `textureTable[0]`: su `u::image` es `0xffffffff` y lleva un `GfxImage` (52 fijos + nombre) con su `GfxImageLoadDef` (12). Todo esto da 192+18+16+8+65+12 = 311 bytes.
4. **Expansión anidada según el marcador.** Comprobación: `node tools/zassetsize.mjs <src> common_zombie.ff --walk 0 1 --expect 843 --sep 0` sale con **0** (hoy 766, −77).
5. **`condition` sobre miembros de elementos** (`u::water`, `u::literalConst`…): exige el mapa de valores del enum del header. Comprobación: el plan de `MATERIAL` con una textura de agua no se desborda.
5. **El `+1` de `RawFile::buffer` y el byte propio de los RAWFILE.** Comprobación: el tramo de 35 RAWFILE recorre encadenado sin usar las anclas.
6. **Recorrido completo de los 2693 assets** contra las 105 anclas de `common_zombie` (y 468 de `common_mp`), y lectura de **nombres** de todos los tipos, que es lo que consume un cargador. Comprobación: `zstreamwalk` con cobertura 2693/2693 y 0 discrepancias.

**B. Decisiones de Adri (bloquean o abren el resto)**

7. **Probar xtool** en Windows/WSL: primero si compila un `.metal` (decide si el render se puede iterar sin runner macOS), y después si reconstruye el launcher como paquete SwiftPM. Con eso se reabre o se cierra la decisión de `reglas.md` §8.
8. **Forma del primer hito visual:** qué se considera "ya se ve algo" (una geometría con cámara fija en un mapa concreto), para no discutirlo a mitad.

**C. Primer hito visual (6c mínimo)**

9. **Cargar un trozo de mapa en el iPhone:** `GfxWorld` de un mapa pequeño (no `common_zombie`) con cámara fija y geometría sin sombras. Comprobación: se ve la geometría en el dispositivo, sin cierres.
10. **Pipeline de shaders propio** (fuera de DX9): empezar por un shader unlit genérico y medir el coste de traducir los materiales reales.
11. **Presupuesto de memoria y lectura por bloques.** Comprobación: medir memoria real con un mapa cargado y fijar el límite (los mapas son 106–114 MiB descomprimidos; IW4-Pocket cae con ~3 GB).

**D. Motor de juego**

12. **Entidades y tipos que Zombies necesita:** `XModel`, `XAnimParts`, `clipMap_t`, `FxEffectDef`, `SndBank`…
13. **VM de GSC.** Primer hito: ejecutar el script de arranque de Zombies de un mapa hasta que empiece la ronda 1.
14. **UI de menús** (`menuDef_t`, dirigida por datos) y entrada.
15. **Audio** de los assets del usuario.
16. **Física y colisiones** (`clipMap_t`) y IA básica de zombis.
17. **Pulido:** sin cierres en partidas largas, objetivo de fotogramas, guardado de ronda.
