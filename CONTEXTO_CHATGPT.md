# BLOPS pocket — Documento de Contexto Técnico para Asistentes de IA

Este documento describe la arquitectura, el estado real verificado, las herramientas, las decisiones de diseño y los problemas abiertos del proyecto **BLOPS pocket**. Está concebido para que un asistente de IA externo o un desarrollador sin acceso al entorno local pueda entender el proyecto en profundidad y guiar las siguientes fases de desarrollo sin repetir investigaciones ya resueltas.

---

## 1. Descripción General del Proyecto

### 1.1. Qué es BLOPS pocket
**BLOPS pocket** es un proyecto en desarrollo cuyo objetivo final es ejecutar el modo Zombies de **Call of Duty: Black Ops 1 (T5, versión PC / Steam)** en dispositivos **iOS (iPhone, iOS 15+)** utilizando exclusivamente los archivos legítimos del juego proporcionados por el usuario.

El proyecto está diseñado bajo dos pilares estrictos:
1. **Legalidad e integridad (§2 de `reglas.md`):** Ningún asset del juego (`*.ff`, texturas, scripts, audio) se distribuye con la app, ni se almacena en el repositorio Git, ni se empaqueta en la IPA. La app no contiene código decompilado sin licencia (no se usa código de `bo1-zombies-decompiled`). La referencia de código libre es **KisakBlack** (GPL-3.0, solo como referencia de arquitectura) y **OpenAssetTools** (GPL-3.0, para especificación de formatos).
2. **Arquitectura sin Mac local:** El desarrollo se realiza en un entorno Windows/Linux sin Xcode local; la compilación de Swift y el empaquetado de la IPA sin firmar se realiza automáticamente en GitHub Actions (macOS arm64) con `XcodeGen`. Las pruebas manuales en hardware se realizan instalando la IPA mediante SideStore en el iPhone de pruebas.

### 1.2. Relación con Call of Duty: Black Ops 1 y FastFiles
En el motor de Black Ops 1 (evolución del motor id Tech 3 / IW engine), todos los recursos del juego (modelos 3D, animaciones, mapas, texturas, scripts compilados, audio, tablas de cadenas) se empaquetan en archivos binarios monolíticos llamados **FastFiles** con extensión `.ff`.

Para poder inicializar el motor del juego en iOS, el primer requisito absoluto es ser capaz de leer secuencialmente el contenido del FastFile, deserializar la tabla de assets y situar cada recurso en memoria exactamente con la misma topología de punteros con la que fue serializado en PC.

### 1.3. Papel de `oat-ref-src` (OpenAssetTools)
Para evitar la ingeniería inversa a ciegas, se utiliza como fuente de verdad declarativa el código de **OpenAssetTools (OAT)**, situado fuera del repositorio en `%USERPROFILE%/oat-ref-src`:
- `Common/Game/T5/T5_Assets.h`: Cabecera en C/C++ que contiene las declaraciones `struct` y `union` exactas de los 44 tipos de assets de Black Ops 1, junto con sus tamaños fijos, campos y directivas de alineación (`type_align32`, `gcc_align`, `tdef_align`).
- `ZoneCode/T5/*.txt`: Archivos de directivas de serialización (lenguaje ZoneCode). Describen cómo se escribe y lee cada struct en el flujo binario: orden de campos (`reorder`), punteros dinámicos (`count`), objetos reutilizables (`reusable`), cadenas C (`string`), identificadores de cadena (`scriptstring`), arrays flexibles (`arraysize`) y ramas condicionales (`condition`).

### 1.4. Estado actual de las fases del proyecto
- **Fases 0 a 5 (Launcher iOS): HECHO.**
  - Launcher en SwiftUI para iOS 15+.
  - Dos vías de acceso a archivos: almacenamiento interno (`Documents/Games/`) y selector de carpetas externas con persistencia segura mediante `Security-Scoped Bookmarks` (`GameFolderBookmark.swift`).
  - Lector de cabeceras `.ff` (`ZoneFileHeader.swift`) y catálogo de zonas (`ZoneCatalog.swift`) que clasifica 143 zonas del juego por grupos (Zombies, Multijugador, Campaña) leyendo solo 12 bytes por archivo sin descomprimir zlib.
  - Verificado en hardware real (10 de 12 pruebas de `pruebas-iphone.md` superadas en iPhone).
- **Fase 6 (Motor en iOS): EN CURSO.**
  - **Subfase 6a (Tabla de assets de zona): HECHO en Node.** Decodificación de cabeceras internas y tablas de nombres/tipos (`tools/zoneassets.mjs`).
  - **Subfase 6b.1 (Recorrido secuencial de `common_zombie.ff`): HECHO.** 2.693 de 2.693 assets medidos sin fallos, con 105 de 105 anclas RAWFILE emparejadas con precisión de 0 bytes de discrepancia.
  - **Subfase 6b.2 (Recorrido de mapas con tipos de mundo): EN CURSO.** `zombie_theater.ff` probado; recorre 908/908 assets sintácticamente, pero presenta desfase de offsets tras los assets de mundo (`GFXWORLD`, `GAMEWORLD_SP`, `CLIPMAP`).
  - **Subfases 6c–6e (Render Metal, VM de GSC, Audio, Física): PENDIENTES.**

---

## 2. Arquitectura y Flujo de Datos

El procesamiento de un FastFile sigue un flujo lineal rigurosamente validado:

```
[ Archivo .ff en disco ]
         │
         ▼  (Lectura de 12 B de cabecera: magic 'IWffu100' + versión 0x1D9)
    tools/ffprobe.mjs
         │
         ▼  (Descompresión zlib / Deflate sin cabecera de 12 B)
[ Stream Descomprimido en Memoria ]
         │
         ├─────────────────────────────────────────┐
         ▼                                         ▼
   tools/zoneassets.mjs                     tools/zrawfile.mjs
(Parsea cabecera interna 36 B,         (Escaneo independiente por firmas
 tabla de 44 tipos y cadenas)           localiza RAWFILEs: *.gsc, *.csc)
         │                                         │
         │  Lista de assets (tipos e índices)      │  Offsets y tamaños
         │                                         │  reales de anclas
         └────────────────────┬────────────────────┘
                              ▼
                     tools/zassetsize.mjs
     ┌────────────────────────┴────────────────────────┐
     │ Lee modelo estructural:                         │
     │   - tools/zsizeof.mjs (sizeof C, offsets, bits) │
     │   - tools/ztypemods.mjs (directivas ZoneCode)   │
     │ Simula el cursor de serialización del stream    │
     │ sumando fijo + regiones FOLLOWING dinámicas.    │
     └────────────────────────┬────────────────────────┘
                              │
                              ▼
                  tools/zvalidarbloques.mjs
  (Coteja en bloques de 100 assets que cada RAWFILE caiga
   exactamente en el offset y tamaño medido por zrawfile)
```

### Detalle de herramientas en `tools/`

| Herramienta | Entrada | Salida | Función principal |
|---|---|---|---|
| [`tools/ffprobe.mjs`](tools/ffprobe.mjs) | `archivo.ff` | Metadatos en consola | Valida magic (`IWffu100`), versión (`0x1D9` para BO1 PC), integridad del primer bloque zlib y ratio de compresión. |
| [`tools/zonescan.mjs`](tools/zonescan.mjs) | Carpeta de juego | Catálogo clasificado | Agrupa zonas por modo (Zombies, MP, SP), verifica versiones y detecta archivos corruptos sin descomprimir. |
| [`tools/zoneassets.mjs`](tools/zoneassets.mjs) | `archivo.ff` | Conteo de assets por tipo | Lee la cabecera interna descomprimida (36 B), extrae la lista secuencial de tipos de asset y la tabla de cadenas de nombres. |
| [`tools/zsizeof.mjs`](tools/zsizeof.mjs) | `T5_Assets.h` | Tamaños, alineaciones y offsets | Analizador de C en Node (sin dependencias). Calcula `sizeof`, `alignof` y offsets de structs, campos de bits, typedefs y enums. |
| [`tools/ztypemods.mjs`](tools/ztypemods.mjs) | Directorio `ZoneCode/T5` | AST de directivas | Analiza los archivos `.txt` de directivas de ZoneCode (`counts`, `reusables`, `strings`, `reorder`, `conditions`). |
| [`tools/zassetsize.mjs`](tools/zassetsize.mjs) | `oat-ref-src` + `.ff` | Tamaños exactos de assets | Motor central de medición. Combina el modelo C y las directivas para recorrer secuencialmente el stream descomprimido. |
| [`tools/zrawfile.mjs`](tools/zrawfile.mjs) | `archivo.ff` | Lista de anclas RAWFILE | Busca por firma en el stream descomprimido todos los archivos de script/texto incrustados (`.gsc`, `.csc`, `.vision`). |
| [`tools/zvalidarbloques.mjs`](tools/zvalidarbloques.mjs) | `oat-ref-src` + `.ff` | Informe de discrepancias por bloques | Valida el recorrido en bloques de 100 assets contra las anclas RAWFILE empíricas, guardando progreso atómico en JSON. |

---

## 3. Conceptos Técnicos Esenciales

### 3.1. Estructura de un FastFile (.ff)
- **Contenedor:** Primeros 12 bytes sin comprimir:
  - Bytes 0..7: Magic `IWffu100` (FastFile de Infinity Ward / Treyarch).
  - Bytes 8..11: Versión en entero LE de 32 bits (`0x1D9` = 473 para Black Ops 1 PC).
- **Cuerpo:** Desde el byte 12 hasta EOF es un único flujo continuo comprimido con Zlib (Deflate estándar).

### 3.2. Estructura interna descomprimida
Al descomprimir el cuerpo zlib se obtiene el stream plano de la zona:
1. **Cabecera interna (36 bytes):** Contiene punteros de memoria virtual y metadatos de carga.
2. **Estructura de conteo (`XAssetList`):** Número de assets de cada uno de los 44 tipos soportados por T5.
3. **Array de tipos:** Array plano de `uint32_t` con el identificador de tipo de cada asset en el orden exacto en que sus datos siguen en el stream.
4. **Tabla de cadenas de nombres:** Nombres de assets terminados en `\0`.
5. **Cuerpo de assets (`bodyOffset`):** Comienza inmediatamente después de la tabla de cadenas. Aquí residen consecutivamente las estructuras de cada asset.

### 3.3. Región Fija vs. Datos FOLLOWING
Cada asset en el stream se serializa en dos etapas consecutivas:
1. **Región Fija:** Copia binaria directa (`memcpy`) de la estructura C del asset (`sizeof(AssetStruct)` de `T5_Assets.h`). Los punteros de memoria dentro de esta estructura se sustituyen en el archivo por marcadores:
   - `0xffffffff` (`FOLLOWING`): El puntero tiene datos asociados y sus datos serializados vienen **inmediatamente detrás** en el stream.
   - Puntero nulo (`0x00000000`): El puntero es nulo; no hay datos en el stream.
   - Puntero de memoria interna / duplicado: Dirección ya resuelta o compartida; no ocupa espacio en el stream.
   - `0xfffffffe` (`LOADDEF_FOLLOWING`): Marcador específico de `GfxTexture` en BO1 que indica que los datos de carga de textura (`GfxImageLoadDef`) vienen detrás.
2. **Región FOLLOWING:** Los buffers, arrays y estructuras anidadas a las que apuntaban los punteros con marcador `0xffffffff`.

### 3.4. Directivas de ZoneCode
El archivo de directivas de cada struct indica al compilador de zonas cómo interpretar los punteros:
- `set count member: expr;`: El miembro es un puntero a un array de elementos. El número de elementos se calcula evaluando `expr` sobre campos ya leídos en la región fija o en ámbitos padres (ej. `set count surfs: numSurfs;`).
- `set reusable: member;`: El miembro apunta a una estructura reutilizable o compartida. Si su marcador es `0xffffffff`, se serializa la estructura completa (y sus regiones hijas); si no, se omite.
- `set string: member;`: El miembro es un puntero `char*` a una cadena C terminada en byte nulo (`\0`) escrita inline en el stream.
- `set scriptstring: member;`: **CRÍTICO:** Representa un identificador de script `ScriptString` (`scr_string_t`). Es un entero sin signo de **16 bits** (`uint16_t`) que indexa la tabla `stringList`, **NO** una cadena de texto inline.
- `set arraysize member: expr;`: Array flexible al final de un struct (estilo C99 `elem[1]`), cuyo número de elementos adicionales depende de `expr`.
- `reorder StructName: campo1, campo2, ...`: Sobrescribe el orden natural de declaración de miembros al serializar los datos following. Si incluye `...`, indica que los miembros no listados conservan su posición relativa original.
- `set condition member: expr;`: El miembro solo se serializa si la expresión condicional se evalúa como verdadera (`!= 0`). Permite discriminar uniones (`union`) en structs dinámicos.

### 3.5. Anclas RAWFILE como Patrón Oro de Validación
Los assets de tipo `RAWFILE` contienen scripts (`.gsc`, `.csc`), archivos de efectos o archivos de configuración. Poseen una firma binaria inconfundible en el stream (byte separador, tamaño comprimido y descomprimido, seguidos del bloque zlib del script o texto plano).

La herramienta `zrawfile.mjs` escanea el stream descomprimido independientemente del modelo de assets y encuentra la posición exacta (offset en bytes) de cada RAWFILE. **Estas posiciones son verdades físicas incontrovertibles.**
- Si el parser de assets mide todos los assets previos con absoluta exactitud, su cursor al llegar a un asset `RAWFILE` coincidirá **exactamente al byte** con el offset del ancla.
- Si un solo asset previo calcula 1 byte de más o de menos, todos los offsets posteriores quedan desalineados, el RAWFILE caerá en una posición falsa y `zvalidarbloques.mjs` detectará una discrepancia.
- **Importante:** Un recorrido que termine sin lanzar excepciones solo demuestra que el stream no se desbordó; **solo el emparejamiento con anclas RAWFILE demuestra que la medición es correcta.**

---

## 4. Historial Técnico y Decisiones Clave

### 4.1. Caso `ScriptString` y el desfase de `XMODEL` (Asset 213)
- **Problema:** En `common_zombie.ff`, el asset 213 (`XMODEL`, `"viewmodel_knife"`, offset `467325`) provocaba un desalineamiento fatal de 2 bytes. Al llegar a su subestructura `XSurface`, los punteros de buffers `triIndices`, `verts0` y `vertList` se leían desplazados como `0x0000ffff` en lugar del marcador `0xffffffff`, desincronizando los assets posteriores hasta fallar en el asset 226 (`XANIMPARTS`).
- **Causa raíz:** En `tools/zassetsize.mjs`, la función `recogerPasos()` incluía `dir.scriptstrings` dentro del clasificador `esTexto`. En `XModel`, el miembro `boneNames` es un array de `ScriptString` (`numBones = 49`, `49 * 2 = 98` bytes). Como el último valor de 16 bits era `0x0b00`, contenía un byte `0x00` en su byte alto. Al tratarlo erróneamente como cadena C terminada en NUL, el lector se detenía 2 bytes antes, desfasando todo el struct de `XSurface`.
- **Solución implementada:**
  1. Se eliminó `scriptstrings` de la condición `esTexto`.
  2. En `recogerPasos()`, se evaluó la condición `if (cuenta)` antes que `if (esTexto)`.
  3. `ScriptString` se mide siempre como un escalar entero de 2 bytes (`uint16_t`).

### 4.2. Correcciones en Directivas Multilínea (`tools/ztypemods.mjs`)
- **Problema:** Expresiones de directivas `set` partidas en más de dos líneas perdían términos intermedios (como `XSurfaceVertexInfo::vertsBlend` en `XModel.txt`: `+ 3 * vertCount[1] + 5 * vertCount[2]`).
- **Solución:** En `parseDirectives()`, se acumula la línea en `pendiente` de forma continua hasta encontrar explícitamente el carácter de terminación `;`.

### 4.3. Indexación de Arrays Escalares (`tools/zassetsize.mjs`)
- **Problema:** Al evaluar expresiones que indexaban miembros tipo array (por ejemplo `vertCount[1]`), la función `leerValor()` multiplicaba el índice por `m.size` (tamaño de todo el array) en lugar del tamaño del elemento individual `modelo.sizeOf(m.type)`.
- **Solución:** Corrección del cálculo de offset: `salto += index * elemTam`.

### 4.4. Precedencia y Operadores Lógicos en `evalExpr()`
- **Problema:** Expresiones complejas con comparaciones entre paréntesis como `(numframes < 256) == 0` fallaban porque `primario()` llamaba a `suma()` en lugar de reiniciar el árbol de precedencia desde el operador de menor precedencia.
- **Solución:** `primario()` evalúa `oLogica()` al abrir paréntesis `(...)`, asegurando la precedencia C estándar: `()` > `* / %` > `+ -` > comparaciones (`==`, `!=`, `<`, etc.) > `&&` > `||`.

### 4.5. Uniones Dinámicas y Ramas Hoja (`hojaUnion`)
- **Problema:** En estructuras de animación como `XAnimPartTransData` y `XAnimDeltaPartQuatData`, las uniones seleccionan dinámicamente si los frames van en un array flexible (`arraysize`) o si ocupan un único frame embebido (`frame0`). Al seleccionarse la rama `frame0` (que no tiene directivas de extensión), el medidor no avanzaba los bytes de la estructura hoja.
- **Solución:** Se implementó el encadenamiento condicional por offset de unión (`condPorOffset`: `if ... else if ... else`) y la emisión de pasos `hojaUnion` que avanzan el cursor hasta el tamaño del struct hoja (`base + offset + size`).

### 4.6. Literales Hexadecimales en Expresiones
- **Problema:** En mapas como `zombie_theater.ff`, el asset 538 (`GFXWORLD`) fallaba con:
  `sobra "x200" en "cellCount * 0x200"`.
  El tokenizer de expresiones solo reconocía dígitos decimales `\d+`, partiendo `0x200` en `0` y `x200`.
- **Solución:** Se añadió `/0[xX][0-9a-zA-Z_]*/` al tokenizer de `zassetsize.mjs` y la evaluación con `parseInt(t, 16)` en `primario()`, rechazando literales mal formados como `0xG` o `0x`.

---

## 5. Estado de Validación

### 5.1. `common_zombie.ff` (FastFile base de Zombies)
- **Estado:** **100 % VERIFICADO Y CERRADO (Subfase 6b.1 cumplida).**
- **Assets:** 2.693 assets (índices 0 a 2.692).
- **Validación por bloques:** 27 de 27 bloques de 100 assets validados sin discrepancias.
- **Anclas RAWFILE:** **105 de 105 anclas emparejadas con exactitud de 0 bytes de diferencia.**
- **Criterio de cierre 6b.1:** El tramo 0..1 mide exactamente 843 bytes (`node tools/zassetsize.mjs <src> common_zombie.ff --walk 0 1 --expect 843 --sep 0` sale con código 0).
- **Pruebas unitarias asociadas:** 41/41 pruebas superadas en `node --test tools/*.test.mjs`.

### 5.2. `zombie_theater.ff` (Mapa Kino der Toten)
- **Ubicación probada:** Copia del juego en PC (`Call of Duty Black Ops\zone\Common\zombie_theater.ff`).
- **Assets:** 908 assets en catálogo (328 `XMODEL`, 198 `TECHNIQUE_SET`, 177 `XANIMPARTS`, 129 `FX`, 50 `RAWFILE`, 13 `WEAPON`, 5 `MATERIAL`, 1 `GFXWORLD`, 1 `CLIPMAP`, 1 `COMWORLD`, 1 `GAMEWORLD_SP`, etc.).
- **Anclas RAWFILE:** 54 anclas detectadas por `zrawfile.mjs`.
- **Recorrido secuencial del stream:** Los 908 assets (0 a 907) se recorren sin abortar acumulando 82.622.201 bytes.
- **Validación contra anclas:**
  - Bloques 0 a 599: **15/15 anclas emparejadas con 0 discrepancias.**
  - Bloque 600–699: **Primer desfase detectado.** El asset 601 (RAWFILE) se calcula en el offset `82.608.492`, mientras que el ancla física real (`zombie_theater.gsc`) está en `86.663.773` (desfase de **4.055.281 bytes**, ~4,05 MB).
- **Comprobación del tramo 538..541:**
  - Asset 538 (`GFXWORLD`): Fijo 1.084 B, Total 33.595.453 B.
  - Asset 539 (`GAMEWORLD_SP`): Fijo 44 B, Total 44 B.
  - Asset 540 (`CLIPMAP`, `clipMap_t`): **Fijo 332 B, Total 332 B.**

---

## 6. Bloqueo Actual y Siguiente Paso: `CLIPMAP` en Mapas (Fase 6b.2)

### 6.1. Diagnóstico del Problema de `CLIPMAP`
En el mapa `zombie_theater.ff`, el asset 540 es de tipo `CLIPMAP` (struct `clipMap_t`).
1. **Comportamiento observado:** El medidor reporta que `CLIPMAP` ocupa únicamente **332 bytes** (exactamente su región fija), omitiendo por completo sus datos following.
2. **Definición de `clipMap_t` en ZoneCode (`clipMap_t.txt`):**
   Declara 34 directivas `count`, 2 `reusable` (`planes`, `box_brush`) y 1 `string` (`name`).
3. **Discrepancia en directivas con subíndices de arrays:**
   Al generar el plan de `CLIPMAP`, el medidor emite 12 avisos:
   ```
   clipMap_t: directiva sobre un miembro que no existe (dynEntDefList[0])
   clipMap_t: directiva sobre un miembro que no existe (dynEntDefList[1])
   clipMap_t: directiva sobre un miembro que no existe (dynEntPoseList[0])
   clipMap_t: directiva sobre un miembro que no existe (dynEntPoseList[1])
   ...
   ```
   **Causa:** En `T5_Assets.h`, los miembros son arrays de punteros:
   ```c
   DynEntityDef* dynEntDefList[2];
   DynEntityPose* dynEntPoseList[2];
   DynEntityClient* dynEntClientList[2];
   DynEntityServer* dynEntServerList[2];
   DynEntityColl* dynEntCollList[4];
   ```
   Las directivas en `clipMap_t.txt` especifican el conteo para cada elemento del array por separado:
   ```zonecode
   set count dynEntDefList[0]: dynEntCount[0];
   set count dynEntDefList[1]: dynEntCount[1];
   ```
   Sin embargo, en `tools/zassetsize.mjs`, `recogerPasos()` busca coincidencias exactas por nombre de miembro (`m.name === "dynEntDefList"`). Al no coincidir con `dynEntDefList[0]`, la directiva se ignora.

4. **Hipótesis vs. Hechos comprobados:**
   - **Hecho comprobado:** `clipMap_t` genera avisos por subíndices `[0]`, `[1]` y no mide las listas de entidades dinámicas.
   - **Hecho comprobado:** En el offset calculado para el asset 540 (`82601920`), los punteros `name` y `planes` no contienen `0xffffffff`, sino valores arbitrarios (`0x52265352`, `0x1230f313`).
   - **Hipótesis con alta probabilidad:** El desfase de ~4,05 MB entre el asset 540 y el ancla del asset 601 (`86.663.773`) se debe a dos factores combinados:
     1. `GFXWORLD` (asset 538) contiene miembros que son arrays de punteros (por ejemplo `GfxWorldDpvsStatic::surfaceVisData` con `dims: [3]`, `char* surfaceVisData[3]`), donde el medidor actual solo procesa 1 buffer en vez de iterar sobre los elementos del array de punteros.
     2. `CLIPMAP` (asset 540) contiene tanto arrays de punteros como tablas de geometría y colisión que requieren asociar las directivas indexadas `miembro[i]` a cada puntero del array.

### 6.2. Condición Objetiva de Resolución
El problema de la fase 6b.2 se considerará resuelto cuando el recorrido de `zombie_theater.ff`:
1. Empareje las anclas RAWFILE del bloque 600..699 (a partir del asset 601 en `86.663.773`) con **0 discrepancias**.
2. Los 908 assets de `zombie_theater.ff` alcancen una correspondencia exacta con las 54 anclas RAWFILE del mapa.

---

## 7. Pruebas y Comandos Reproducibles

Todos los comandos se ejecutan desde la raíz del repositorio (`c:\Proyectos IA\BLOPS pocket`). La referencia de OAT se toma de `%USERPROFILE%/oat-ref-src`.

### 7.1. Suite de pruebas automatizadas
```powershell
# Ejecutar todas las pruebas unitarias (Node, sin dependencias)
node --test tools/*.test.mjs

# Ejecutar una prueba específica (evaluador y medidor de assets)
node --test tools/zassetsize.test.mjs

# Verificar formato, saltos de línea y espacios en Git
git diff --check
```

### 7.2. Inspección y diagnóstico de FastFiles
```powershell
# Inspeccionar cabecera, magic y compresión zlib de un .ff
node tools/ffprobe.mjs common_zombie.ff

# Listar catálogo y conteo de assets por tipo
node tools/zoneassets.mjs common_zombie.ff

# Localizar anclas RAWFILE físicas y sus offsets
node tools/zrawfile.mjs common_zombie.ff
```

### 7.3. Recorrido y validación secuencial
```powershell
# Comprobación de cierre de 6b.1 (debe salir con código 0 y medir 843 bytes)
node tools/zassetsize.mjs "$env:USERPROFILE/oat-ref-src" common_zombie.ff --walk 0 1 --expect 843 --sep 0

# Validación por bloques de common_zombie.ff contra sus 105 anclas
node tools/zvalidarbloques.mjs "$env:USERPROFILE/oat-ref-src" common_zombie.ff

# Recorrer un mapa (zombie_theater.ff) comprobando offsets de assets
node tools/zassetsize.mjs "$env:USERPROFILE/oat-ref-src" "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops\zone\Common\zombie_theater.ff" --walk 0 907 --sep 0

# Validar bloques de zombie_theater.ff contra sus anclas RAWFILE (reproduce fallo en bloque 600-699)
node tools/zvalidarbloques.mjs "$env:USERPROFILE/oat-ref-src" "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops\zone\Common\zombie_theater.ff" "$env:TEMP/zvalidar-theater.json"
```

---

## 8. Archivos y Estado del Repositorio

### 8.1. Archivos principales del proyecto
- `launcher/`: Código en Swift para iOS (`GameFolderLocator.swift`, `GameFolderBookmark.swift`, `ZoneCatalog.swift`, `ZoneFileHeader.swift`, `project.yml`).
- `tools/`: Herramientas de análisis y parsing en Node.js ES Modules sin dependencias externas.
- `continuar.md`: Cuaderno de bitácora principal. Contiene el estado actual, comandos de referencia y plan de ruta detallado.
- `reglas.md`: Reglas del proyecto, directivas legales, inventario de assets y decisiones de diseño confirmadas.
- `pruebas-iphone.md`: Protocolo de pruebas manuales en el dispositivo físico.
- `AGENTS.md`: Guía de directivas y gobernanza para agentes de IA que trabajan en el repositorio.

### 8.2. Estado actual de Git (solo lectura, sin commits)
- **Modificados sin commitear (`M`):**
  - `tools/zassetsize.mjs`: Correcciones de parsing, evaluación de expresiones, literales `0x`, punteros dobles y uniones.
  - `tools/zassetsize.test.mjs`: Tests de regresión para `ScriptString`, literales `0x` y precedencia.
  - `tools/zsizeof.mjs`: Soporte de constantes enum en dimensiones de arrays, typedefs y punteros a función.
  - `tools/ztypemods.mjs`: Directivas multilínea, `reorder StructName:`, expansión `...` y constantes enum.
  - `continuar.md`, `reglas.md`, `README.md`, `prompts.md`, `pruebas-iphone.md`: Actualizaciones documentales de estado.
- **Sin seguimiento relevantes (`??`):**
  - `AGENTS.md`: Documento de instrucciones operativas para agentes.
  - `tools/zvalidarbloques.mjs`: Validador incremental por bloques contra anclas RAWFILE.
  - `.freebuff/`: Directorio de trabajo local (ignorado explícitamente en `reglas.md` §7).

---

## 9. Guía para el Siguiente Asistente de IA

Si continúas el desarrollo de **BLOPS pocket**, sigue estas directrices estrictas:

1. **Lectura obligatoria inicial:**
   - Lee [continuar.md](continuar.md) y las secciones 1, 2, 5 y 6 de [reglas.md](reglas.md). No leas archivos innecesarios.
2. **Lo que debes dar por confirmado y NO volver a investigar:**
   - `common_zombie.ff` está completamente resuelto (2.693/2.693 assets y 105/105 anclas). **No toques la lógica que valida `common_zombie.ff`.**
   - `ScriptString` es un entero de 16 bits (`uint16_t`). Nunca lo trates como cadena C.
   - La suite de pruebas de `tools/*.test.mjs` (41 pruebas) debe permanecer siempre en verde.
3. **El siguiente paso técnico concreto:**
   - Resolver el soporte de directivas indexadas sobre arrays de punteros en `recogerPasos()` de `tools/zassetsize.mjs` (para miembros como `dynEntDefList[0]`, `dynEntPoseList[0]` en `clipMap_t` y arrays de punteros en `GfxWorldDpvsStatic` como `surfaceVisData[3]`).
4. **Criterio de éxito antes de dar por buena una solución:**
   - Ejecutar la validación de bloques de `zombie_theater.ff` y comprobar que las anclas RAWFILE a partir del asset 601 (offset `86.663.773`) coincidan exactamente con 0 discrepancias.
   - Ejecutar `node --test tools/*.test.mjs` asegurando que no existan regresiones.
   - Ejecutar `git diff --check` para garantizar limpieza de formato.
5. **Invariantes:**
   - No hagas `git commit` ni `git push` a menos que el usuario lo solicite expresamente.
   - No utilices código de `bo1-zombies-decompiled`. Todo el formato se extrae de `oat-ref-src`.
