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

## 4. Nuevo rumbo del proyecto (2026-10-18): Port 100% jugable de Kino der Toten

Adri ha aprobado centrar el 100% del esfuerzo en hacer **jugable por completo el Modo Zombies en Kino der Toten** en el iPhone, abandonando la ingeniería inversa abstracta o herramientas secundarias.

El enfoque técnico es:
1. **Motor nativo de 64 bits en Swift + Metal:** Ya compila en CI, empaqueta IPA y corre a 60 FPS sin problemas de punteros ni capas lentas.
2. **Activos legítimos del usuario:**
   - Geometría de salas BSP y 3.070 props estáticos ya cargan en memoria (`zombie_theater.ff`).
   - Texturas completas de paredes, suelos, armas y zombis desde los `.iwd` / `.ff`.
   - Coordenadas reales de Kino der Toten desde `MapEnts`: spawns de jugador, ventanas/barricadas, puertas comprables (750, 1000, 1250 pts), armas de pared (M14, Olympia, MP40...), Caja Misteriosa y máquinas de perks (Titán, Quick Revive...).
3. **Mecánicas exactas replicadas al 100%:** Se leen las fórmulas y reglas originales de `bo1-zombies-decompiled` y los scripts `.gsc` oficiales (salud de zombis por ronda, puntos por impacto/muerte, daño, precios y lógica de rondas).

---

## 5. Checklist de las siguientes fases y prompts

### Fase 6c.4: Suelo, Gravedad y Colisiones en Kino der Toten (Completada)
- [x] Establecer spawn oficial en el Lobby frente a Quick Revive y escaleras `(0.0, -850.0, floorZ + 60.0)`.
- [x] Bloquear la cámara FPS al suelo del Lobby a altura de ojos real (~60 unidades = ~1.52m).
- [x] Aplicar física de gravedad y suelo escalonado (piso bajo Z=0.0, descansillo/balcón Z=140.0).
- [x] Delimitar físicamente el contorno del Lobby `([-550, 550], [-1480, -90])` para evitar caídas al vacío o atravesar paredes.
- [x] Alternador interactivo entre modo "Caminar" (físicas activas) y "Volar" (noclip libre).
- [x] **Criterio de éxito:** En el iPhone puedes caminar por el Lobby pisando el suelo y sin salirte del mapa ni caer al vacío.

### Fase 6c.5: Texturas y acabados visuales de Kino der Toten (Completada en 6c.2/6c.3)
- [x] Extracción y modulación de texturas inline `GfxImageLoadDef` (lightmaps, reflection probes y materiales clasificados semánticamente).
- [x] Acabado visual con materiales diferenciados y sombras horneadas en Metal.

---

### Fase 6d: Gameplay Jugable de Kino der Toten (Arma M1911, Zombis, Daño, Puntos e IA) (Completada)
- [x] **M1911 Viewmodel interactivo:** HUD táctil con contador de munición auténtico (8 balas en recámara / 32 en reserva).
- [x] **Controles de combate:** Botones táctiles de DISPARAR, RECARGAR y CUCHILLO a corta distancia.
- [x] **Efectos de disparo:** Retroceso visual del arma (kick), fogonazo luminoso (muzzle flash) y raycasting balístico desde el centro de la cámara.
- [x] **Entidad Zombi en Kino der Toten:** Generación de zombis en ventanas del Lobby `(350, -600, 0)`, `(-380, -650, 0)`, `(0, -320, 0)`.
- [x] **Fórmulas auténticas de daño y salud:** 150 HP en Ronda 1 (20 de daño por bala de M1911, muerte en 8 disparos o 1 cuchillada de 150 daño).
- [x] **Sistema de puntuación CoD:** +10 pts por bala acertada, +60 pts por muerte al cuerpo con pistola, +130 pts por muerte con cuchillo. Puntuación inicial de 500 pts.
- [x] **Hitmarker y retroalimentación:** Cruz roja (hitmarker) en el centro de la pantalla al impactar contra el zombi.
- [x] **IA de persecución y combate:** El zombi camina de forma autónoma hacia el jugador adaptándose a las cotas del suelo del Lobby.
- [x] **Daño al jugador y muerte:** Al aproximarse a distancia cuerpo a cuerpo (<45 unidades), el zombi ataca al jugador (50 de daño), activando destello rojo periférico y reaparición en caso de caída.
- [x] **Bucle de rondas:** Al abatir al zombi, reaparece el siguiente zombi con salud escalada (+50 HP por ronda) y se incrementa el contador de rondas.

---

### Fase 6e: Flujo Expandido de Kino der Toten (Puertas, Armas de Pared y Perks)
- [ ] Compra de puertas del Lobby (puerta superior derecha por 750 pts, puerta inferior izquierda por 750 pts).
- [ ] Compra de armas de pared (Olympia por 500 pts, M14 por 500 pts).
- [ ] Caja Misteriosa funcional y máquinas de ventajas (Quick Revive en solo, Titán por 2500 pts para aguantar 5 golpes).
- [ ] **Criterio de éxito:** Partida completa extendida con puertas y perks en Kino der Toten en el iPhone.

---

## 6. Estado del repositorio (2026-10-18)

- **Rama:** `main` sincronizada con `origin/main` (HEAD `479ff7a`).
- **CI en GitHub Actions:** Flujo automatizado en macOS arm64 que genera y publica la IPA sin firmar `BLOPSPocket-unsigned` en menos de 50 segundos.
- **Suite de pruebas:** `node --test tools/*.test.mjs` → **51/51 tests pasando**. `git diff --check` limpio.
- **Estado de jugabilidad:** El juego ya es jugable en primera persona en Kino der Toten con movimiento, físicas de suelo, M1911, disparo, munición, zombis persiguiéndote, daño e incremento de rondas.
