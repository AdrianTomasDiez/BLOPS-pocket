# continuar.md: por dónde vamos y cómo seguir

> **Para el agente de IA o para Adri al retomar:** este archivo es el punto de entrada rápido. Las **reglas y la legalidad** están en [reglas.md](reglas.md) (leerlo completo antes de tocar código) y las **pruebas en el iPhone** en [pruebas-iphone.md](pruebas-iphone.md). Aquí solo va el estado del trabajo y el siguiente paso exacto.

Fecha de esta anotación: **2026-10-15**.

---

## 1. Resumen en dos frases

Fases **0–5 hechas**: launcher iOS, acceso persistente a la carpeta del juego y catálogo de las 143 zonas (probado en el iPhone salvo los dos puntos que dependen del motor). El **motor (fase 6) está empezando**: 6a hecha (lista de assets), **6b.1 en marcha** (leer tamaños y nombres de cada asset del stream) y **6c–6e pendientes**, que son la parte grande y necesitan Xcode y un iPhone.

**Todavía no se puede jugar.** Lo que hay es un launcher que valida y cataloga la copia del juego, más herramientas que decodifican el formato.

## 2. Estado verificado (byte a byte sobre `common_zombie.ff`)

Todo esto está medido y es reproducible con las herramientas de la sección 3.

| Dato | Valor | Cómo se comprueba |
|---|---|---|
| `common_zombie.ff` | 2693 assets, 858 cadenas, `bodyOffset` **39270** | `node tools/zoneassets.mjs common_zombie.ff` |
| Asset 0 (`TECHNIQUE_SET`) | **532** B = 528 fijos + `name` (4, `",2d\0`), empieza en 39270 | `node tools/zassetsize.mjs <src> common_zombie.ff --type TECHNIQUE_SET --sep 0` |
| Asset 1 (`MATERIAL`) | empieza en **39802** = 39270 + 532 | el ancla anterior |
| `MATERIAL` real | **311** B (39802..40112) | descomposición medida en reglas.md §6 |
| Primer RAWFILE | **40113** = 39802 + 311 | `node tools/zrawfile.mjs common_zombie.ff` |
| Modelo de tipos | 44 nombres del enum, **33 con struct + directiva + región fija**; 11 sin struct propio | `node tools/ztypemods.mjs <src>` |
| Anclas RAWFILE | **105/105** cuadran en `common_zombie`; 468 leídas en `common_mp` | `node tools/zstreamwalk.mjs` |

**Criterio de 6b.1 cumplido:** entre `bodyOffset` y el primer RAWFILE hay **843** B y el recorrido del modelo mide **843**. La pieza que faltaba era la imagen anidada de `textureTable[0]` (`u::image` con marcador `0xffffffff`, no agua): un `GfxImage` (52 fijos + nombre de 13) y su cabecera `GfxImageLoadDef` (12 B, sin el `data[1]` flexible). Un `texture` con valor `0xfffffffe` indica ese `loadDef`. El `MATERIAL` mide 311 (antes 234).

```bash
# Comprobación de cierre (sale con 0):
node tools/zassetsize.mjs <src> common_zombie.ff --walk 0 1 --expect 843 --sep 0
```

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
| [tools/zstreamwalk.mjs](tools/zstreamwalk.mjs) | Recorrido por tramos de RAWFILE contra las anclas | `node tools/zstreamwalk.mjs <archivo.ff> [--json]` |

Códigos de salida en todas: **0** correcto, **1** error de formato/lectura o comprobación fallida, **2** uso incorrecto (y **3** discrepancias en `zstreamwalk`).

**Pruebas:** `node --test tools/*.test.mjs` → **39/39**. Ese mismo comando está en `.github/workflows/ios-ipa.yml`: al añadir un `.test.mjs` hay que añadirlo ahí también.

## 4. Lo que falta para cerrar 6b.1, en orden

1. ~~**Expansión anidada según el marcador del stream.**~~ Hecho solo para la imagen de `textureTable` (ver arriba). Pendiente generalizar: un puntero `0xffffffff` a otro struct debe seguirse con plan propio y guarda contra recursión. Ojo con el `+1` de `RawFile::buffer` (la directiva dice `len + 1` y el stream guarda `len`).
2. ~~**`condition` con valores de enum.**~~ Hecho: el evaluador admite `==` y nombres de enum (`TS_WATER_MAP`) vía `enumValor`. Pendiente: otros usos de `condition` no probados.
3. ~~Constante nula~~: el `count` solo suma si su puntero es `0xffffffff` (así `constantTable` con puntero 0 no suma).
3. **El byte propio de los registros RAWFILE** y la semántica de `reusable` cuando no hay `count`.
4. **Validar el recorrido completo** de los 2693 assets contra las 105 anclas con `zstreamwalk.mjs` (hoy solo se siembran 15 tramos) y con las 465 de `common_mp`.

Criterio de cierre de 6b.1: `--walk 0 1 --expect 843 --sep 0` sale con 0 y el recorrido de `common_zombie` no necesita las anclas para avanzar.

## 5. Dependencias y entorno

- **La copia de referencia** (código fuente de OpenAssetTools) se lee de `C:\Users\adri3\AppData\Local\Temp\oat-ref\src`. Si Windows limpia `Temp`, `ztypemods.mjs` y `zassetsize.mjs` salen con 1. **Hecha:** copia fuera del repo en `%USERPROFILE%/oat-ref-src` (solo se leen sus datos y cabeceras como texto; no se copia código). Los stubs locales `tools/oat-ref/` se borraron por código muerto.
- **`common_zombie.ff`** se lee de la raíz del proyecto; `*.ff` está en `.gitignore`, así que no puede acabar en un commit por descuido (regla 1 de reglas.md §2).
- Sin Xcode ni Mac aquí: el Swift solo compila en GitHub Actions. El iPhone lo usa Adri.

## 6. Estado del repositorio (nada commiteado de esta fase)

- Modificados: [reglas.md](reglas.md) y [.github/workflows/ios-ipa.yml](.github/workflows/ios-ipa.yml).
- Nuevos, sin seguimiento: este [continuar.md](continuar.md), [tools/zassetsize.mjs](tools/zassetsize.mjs), [tools/zassetsize.test.mjs](tools/zassetsize.test.mjs), [tools/ztypemods.mjs](tools/ztypemods.mjs) y [tools/zstreamwalk.mjs](tools/zstreamwalk.mjs). También `.freebuff/` (se deja sin commitear a propósito) y un fichero basura `h origin main` que conviene borrar.
- **Recomendado al retomar:** commitear `tools/` + `reglas.md` + el workflow + este archivo antes de seguir, para que el punto de retorno no dependa de una carpeta temporal.

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
