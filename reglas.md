# reglas.md: BLOPS pocket (Call of Duty: Black Ops 1 en iOS)

> **Para el agente de IA:** lee este archivo COMPLETO antes de tocar código. Si hay conflicto entre reglas, prevalece la más restrictiva. Mantén la sección 7 (estado) al día al cerrar cada fase.

---

## 1. Objetivo

Lanzador para iPhone (iOS) que ejecute **Call of Duty: Black Ops 1** leyendo los archivos del juego que el propio usuario posee, sin incluir ningún archivo del juego en el repositorio ni en la app.

- **Modo Zombies** es el objetivo principal (Adri lo quiere jugar en el móvil). Multijugador queda como opción posterior.
- **Modelo de referencia de arquitectura:** [IW4-Pocket](https://github.com/MarkusSela/IW4-Pocket) (MW2 en iOS).
- **Estado:** fases 0–5 hechas (launcher, acceso persistente a la carpeta y catálogo de zonas). El motor (fases 6–7) está pendiente de decisión.

## 2. Restricciones legales (obligatorias)

1. **No distribuir recursos del juego.** Ni en el repositorio, ni en la IPA, ni en releases, ni en capturas con datos extraídos. La app solo lee la copia que el usuario tiene.
2. **Propiedad del juego:** el launcher exige una copia legítima de la que el usuario sea titular. Mostrarlo en el README y en la pantalla de inicio.
3. **Marcas:** no usar logotipos ni nombres de Activision/Treyarch como nombre de la app o icono. Nombre provisional a definir (ver sección 8).
4. **Código de terceros:**
   - **KisakBlack** (GPL-3.0): se puede estudiar. Si se copia o enlaza código suyo, el proyecto pasa a GPL-3.0. Decisión pendiente de Adri (ver sección 8).
   - **bo1-zombies-decompiled**: **sin licencia**. No copiar código, ni tomar fragmentos, ni traducirlo. Solo se puede consultar para entender el formato o la lógica del juego, y dejar constancia en la sección 6.
   - **IW4-Pocket** (Apache 2.0): se puede reutilizar código respetando la licencia, el `NOTICE` y la atribución.
5. **Consultar a un abogado** antes de publicar la app (App Store o sideload público). Esto no lo puede decidir el agente.

## 3. Hallazgos de la investigación (fase 1)

### 3.1 IW4-Pocket (referencia de arquitectura)

- Port no oficial del runtime IW4L para **MW2 (2009)**, escrito en **Rust** con **Bevy**. Renderiza con **Metal** en iOS.
- Flujo de compilación: GitHub Actions con runner macOS, target `aarch64-apple-ios`, se empaqueta en `.app` con `Info.plist` e iconos, y se comprime en **IPA sin firmar**. Se instala con **SideStore**.
- Mínimo declarado: iOS 15 (sin probar).
- Usuario: copia de MW2 de Steam. La carpeta del juego se copia a **Archivos → En mi iPhone → IW4 Pocket → Games**. Debe contener una subcarpeta `zone`.
- Lee los recursos mediante lectores nativos del formato **FastFile**.
- Estado: activo (versión 0.3.3, octubre 2026), experimental. Problemas abiertos: **memoria** (con ~3 GB concedidos por iOS, el juego se cierra al cargar mapas), parpadeo de render en algunos iPhone, y cambios en la configuración de bots.
- Lección: el cuello de botella es la **memoria** en iOS, no solo la compatibilidad.

Fuentes: [README](https://github.com/MarkusSela/IW4-Pocket/blob/main/README.md), [Cargo.toml](https://github.com/MarkusSela/IW4-Pocket/blob/main/Cargo.toml), [workflow iOS](https://github.com/MarkusSela/IW4-Pocket/blob/main/.github/workflows/ios-release.yml), [NOTICE](https://github.com/MarkusSela/IW4-Pocket/blob/main/NOTICE), [Issues](https://github.com/MarkusSela/IW4-Pocket/issues).

### 3.2 KisakBlack (referencia para BO1 multijugador)

- Reimplementación del **ejecutable de multijugador de Black Ops 1 (T5)**. No cubre Zombies ni campaña.
- C++20, CMake, Visual Studio 2022. Destino: **Windows 32 bits**, Direct3D 9, XAudio y bibliotecas de MSVC.
- Requiere DirectX SDK de 2010 y una copia de Black Ops de Steam.
- Licencia: **GPL-3.0**.
- **Conclusión:** sirve para estudiar la lógica de red, los formatos y el arranque del juego. **No es base para iOS**: habría que sustituir la capa gráfica, audio, entrada, archivos y red.

Fuentes: [README](https://github.com/SwagSoftware/KisakBlack), [CMakeLists.txt](https://github.com/SwagSoftware/KisakBlack/blob/master/CMakeLists.txt), [LICENSE](https://github.com/SwagSoftware/KisakBlack/blob/master/LICENSE), [blog del autor](https://lwss.github.io/Kisak-Black/).

### 3.3 bo1-zombies-decompiled (referencia de Zombies)

- Código del motor de **Black Ops 1 Zombies** decompilado, en C++20. Estructura: `bgame`, `cgame`, `game`, `physics`, `sound`, `ui`, `gfx_d3d`, `win32`. También trae scripts de mods `.gsc` y `.csc`.
- Objetivo de compilación: **Windows 32 bits** (MSVC, DirectX 9, Steam, Bink). No hay una configuración verificada.
- `setup.ps1` copia archivos desde una instalación local del juego.
- **Sin licencia** (`license: null`). Por defecto, todos los derechos reservados. **No se puede reutilizar su código.**
- **Conclusión:** es la referencia más útil para entender la lógica de Zombies, pero es el más arriesgado legalmente. Úsalo solo como guía de lectura.

Fuentes: [README](https://raw.githubusercontent.com/MisaDev4/bo1-zombies-decompiled/main/README.md), [CMakeLists.txt](https://raw.githubusercontent.com/MisaDev4/bo1-zombies-decompiled/main/CMakeLists.txt), [API del repositorio](https://api.github.com/repos/MisaDev4/bo1-zombies-decompiled).

### 3.4 Conclusión de la investigación

El launcher se diseña como **IW4-Pocket**: runtime propio, lectura de la carpeta del juego del usuario, IPA generada en CI. Como base de código **no existe ninguna opción lista para iOS**. La parte difícil es el **motor**:

| Pieza | Fuente de inspiración | Riesgo |
|---|---|---|
| Launcher iOS (UI, carpeta del usuario, validación) | IW4-Pocket | Bajo |
| Lectura de archivos del juego (`zone`, FastFile de BO1) | IW4-Pocket (formato MW2, adaptar a BO1) | Medio |
| Motor de Zombies en iOS | KisakBlack (MP, GPL) como referencia; bo1-zombies solo para leer | Alto |
| Render Metal y audio en iOS | Desarrollo propio | Alto |

**Recomendación:** empezar por el **launcher y la lectura de archivos** (bajo riesgo, valor inmediato) y dejar el motor para después, cuando esté decidida la licencia.

### 3.5 Formato del FastFile de BO1 (medido sobre la copia de Adri, 2026-10-13)

Todo lo de esta sección está **medido directamente** sobre las 143 zonas de la copia de Adri en Steam, con [tools/ffprobe.mjs](tools/ffprobe.mjs) y [tools/zonescan.mjs](tools/zonescan.mjs) (Node, sin dependencias). No se copió código de ningún proyecto de terceros: son medidas propias. Donde digo "hipótesis" es porque no está confirmado.

#### Contenedor `.ff` — confirmado en los 143 archivos

| Offset | Bytes | Contenido |
|---|---|---|
| 0 | 8 | ASCII `IWffu100` (magic de BO1 PC) |
| 8 | 4 | versión de zona, uint32 little-endian: **`0x1D9` (473)** en los 143 |
| 12 | hasta EOF | **un único stream zlib** (CMF `0x78`, FLG `0x01`), sin firma |

- El stream zlib **llega exactamente a EOF**: 0 bytes de cola medidos en 6 archivos (incluidos 4 de Zombies). No hay bloques de 64 KiB ni cabecera de firma en la versión de Steam, contra lo que se repite en foros.
- La versión 473 es la de BO1 PC y no coincide con CoD4 (`0x5`), WaW (`0x183`) ni MW2 (`0x114`).
- Consecuencia para el launcher: **identificar una zona cuesta 12 bytes de lectura**, nunca descomprimir. Así funciona ya [ZoneFileHeader.swift](launcher/BLOPSPocket/ZoneFileHeader.swift) y `peek_zone_version` de IW4-Pocket.

#### Zona descomprimida — observado, sin decodificar

- Los primeros **36 bytes** son un prefijo. Su primer uint32 LE es siempre `tamañoDescomprimido − 36` (verificado en 7 archivos de tamaños muy distintos). El resto del prefijo no está identificado.
- Tras el prefijo aparecen tablas de entradas de 4 bytes donde `0xFFFFFFFF` hace de puntero nulo (hipótesis: offsets de 32 bits, como en IW4).
- **La tabla de assets (recuento, tipos y nombres) no está identificada todavía.** No se implementa nada sobre ella hasta tenerla verificada. Referencia externa de tipos para comparar más adelante: enum de T5 de OpenAssetTools (`XMODELPIECES`=0 … `EMBLEMSET`=42; `RAWFILE`=36, `STRINGTABLE`=37) — GPL-3.0, solo lectura.

#### Tamaños inflados — dato clave para la regla 5 (memoria)

| Zona | En disco | Descomprimida |
|---|---|---|
| common_zombie.ff | 49 MiB | **76 MiB** |
| zombie_cosmodrome.ff | 51 MiB | **114 MiB** |
| zombie_theater.ff | 47 MiB | **106 MiB** |
| zombietron.ff | 87 MiB | (no medido) |
| common_zombie_patch.ff | 766 KiB | 1.1 MiB |

Una partida de Zombies necesita `common_zombie.ff` (76 MiB) + una zona de mapa (106–114 MiB) + `frontend.ff` (≈40 MiB) **solo en imágenes descomprimidas**, antes de GPU y audio. Es el mismo tipo de presión que tumbó a IW4-Pocket con ~3 GB. Previsiblemente habrá que ir a lectura por bloques/streaming en la fase 6.

#### Inventario de `zone/`

143 archivos `.ff`, 2.61 GiB: 71 en `Common/` (2.59 GiB) + 72 en `Spanish/` (20 MiB, traducción `sp_*`).

| Grupo | Archivos | Tamaño |
|---|---|---|
| Campaña | 21 | 1535.2 MiB |
| Multijugador | 18 | 673.9 MiB |
| **Zombies** | **5** | **279.7 MiB** |
| Interfaz | 9 | 82.6 MiB |
| Comunes | 2 | 74.1 MiB |
| Traducciones | 72 | 20.2 MiB |
| Parches | 12 | 3.8 MiB |
| Código | 4 | 3.1 MiB |

Zonas de Zombies: `common_zombie.ff`, `zombie_theater.ff`, `zombie_cosmodrome.ff`, `zombie_pentagon.ff`, `zombietron.ff`.

#### Fuentes y licencias consultadas para el formato

Ninguna se ha usado como código; varias son GPL-3.0 o sin licencia, así que solo sirven como lectura:

- [OpenAssetTools](https://github.com/Laupetin/OpenAssetTools) y su [enum de T5](https://git.alterware.dev/zone/OpenAssetTools/src/commit/0c22dddd0ef9991be32f115fe1947ea09a1ade3b/src/Common/Game/T5/T5.h) — **GPL-3.0**.
- [ZoneTool](https://github.com/ZoneTool/zonetool) — **GPL-3.0**.
- [CoD-FF-Tools](https://github.com/primetime43/CoD-FF-Tools/blob/main/docs/SupportedFormats.md) — **GPL-3.0** (sus tablas Cubren CoD4/WaW/MW2, **no BO1**).
- [Wiki de modding de CoD5/WaW](https://wiki.zeroy.com/index.php?title=Call_of_Duty_5:_FastFile_Format) — contenido **CC BY-NC-SA 3.0**; solo lectura, sin copiar texto.
- [Guía de modding de Black Ops (Steam)](https://steamcommunity.com/sharedfiles/filedetails/?id=2494448328) — nombres de archivos; sin licencia de reutilización.
- [atian-cod-tools](https://github.com/ate47/atian-cod-tools) — doble licencia GPL-3.0 **o MIT**; si algún día se reutiliza código, solo la parte MIT.

> Aviso registrado: el 2026-10-13 una búsqueda web no encontró especificación pública del contenedor T5; los valores de arriba son medidas propias. Cualquier dato no medido aquí se trata como hipótesis.

## 4. Estructura prevista

```
BLOPS pocket/
├── reglas.md             → este archivo
├── prompts.md            → prompts de cada fase
├── .gitignore            → excluye datos del juego, build e IPA
├── README.md             → instrucciones para el usuario (fase 7, hecho)
├── pruebas-iphone.md     → comprobaciones manuales en el iPhone (fase 7)
├── LICENSE               → GNU GPL v3.0 (texto oficial)
├── NOTICE                → propiedad, licencia y atribuciones
├── launcher/
│   ├── project.yml       → especificación de XcodeGen (genera el .xcodeproj)
│   └── BLOPSPocket/      → código SwiftUI de la app
├── tools/                → sondas de verificación del formato (Node, sin dependencias)
│   ├── ffprobe.mjs       → cabecera, descompresión y primeros bytes de una zona
│   ├── zonescan.mjs      → catálogo de todas las zonas de una carpeta
│   └── zonescan.test.mjs → 6 pruebas con archivos .ff sintéticos: `node --test tools/zonescan.test.mjs`
├── engine/               → runtime (fase 6, sin decidir)
└── .github/workflows/
    └── ios-ipa.yml       → compila y genera la IPA sin firmar (GitHub solo lee workflows desde esta ruta)
```

No crear carpetas hasta que la fase lo requiera. El bundle id definitivo es `com.adriantomasdiez.blopspocket`; si se cambia, hay que regenerar el proyecto con XcodeGen y reinstalar la IPA.

## 5. Reglas de funcionamiento

1. **Una fase cada vez** (ver `prompts.md`). No avanzar sin que la fase compile o se pueda verificar.
2. **Sin copias de código de terceros** sin registrar la licencia en la sección 6.
3. **Sin datos del juego en git.** Añadir al `.gitignore` cualquier carpeta de juego o `zone` que aparezca en pruebas.
4. **Logs sin datos del usuario:** no registrar rutas completas de la carpeta del juego.
5. **Memoria primero:** en iOS, cargar recursos en streaming o por demanda. Medir el uso de memoria antes de dar una fase por terminada.
6. **Cambios mínimos y verificados:** toda decisión técnica nueva se anota en la sección 6.
7. **No inventar formatos:** si no está confirmado el formato FastFile de BO1, consultar la documentación o el código de referencia antes de implementarlo.

## 6. Decisiones y dependencias

| Fecha | Decisión | Motivo |
|---|---|---|
| 2026-10-13 | Objetivo: Zombies de BO1 en iOS | Pedido de Adri |
| 2026-10-13 | Modelo de arquitectura: IW4-Pocket | Runtime propio + archivos del usuario; probado en iOS |
| 2026-10-13 | No usar código de bo1-zombies-decompiled | Sin licencia; derechos reservados |
| 2026-10-13 | KisakBlack solo como referencia por ahora | GPL-3.0 obliga a licenciar todo el proyecto como GPL; decisión pendiente |
| 2026-10-13 | Empezar por launcher y lectura de archivos | Menor riesgo técnico y legal que el motor |
| 2026-10-13 | Licencia de la app: Apache 2.0 | Elegida por Adri. Válida mientras no se copie código de KisakBlack (GPL-3.0) |
| 2026-10-13 | Nombre de la app: BLOPS pocket | Elegido por Adri. Nombre de trabajo, sin marcas de Activision |
| 2026-10-13 | Compilación solo con GitHub Actions (sin Mac) | Elegido por Adri. La IPA se genera en un runner macOS en la nube |
| 2026-10-13 | Distribución: uso personal con SideStore | Elegida por Adri. Sin publicación pública por ahora |
| 2026-10-13 | KisakBlack solo como referencia (no se copia código) | Elegido por Adri. Mantiene la licencia Apache 2.0 |
| 2026-10-13 | Repositorio privado en GitHub: AdrianTomasDiez/BLOPS-pocket | Creado con `gh`. Rama por defecto `main` (el workflow solo se activa en `main`) |
| 2026-10-13 | Commits con identidad de Adrian Tomás Diez | El commit inicial se reescribió (`85cefbd`) porque tenía un autor provisional |
| 2026-10-13 | El token de `gh` necesita scope `workflow` para subir `.github/workflows/` | GitHub lo exige; añadido con `gh auth refresh -s workflow` y `gh auth setup-git` |
| 2026-10-13 | Contenedor `.ff` de BO1 PC: magic `IWffu100` + versión `0x1D9` + un zlib hasta EOF | Medido en las 143 zonas de la copia de Adri; refuta lo que se repite en foros |
| 2026-10-13 | Identificar una zona leyendo 12 bytes, nunca descomprimiendo | Regla 5 (memoria): descomprimir una zona de Zombies cuesta 76 MiB |
| 2026-10-13 | Herramientas propias en `tools/` (Node, sin dependencias) para verificar el formato | No se copia código de terceros; sirven de referencia ejecutable del lector Swift |
| 2026-10-13 | La tabla de assets de T5 no se implementa hasta estar verificada | Regla 5.7: no inventar formatos |
| 2026-10-13 | El acceso a la carpeta del juego persiste con un bookmark en `UserDefaults` | iOS no admite `.withSecurityScope` (es de macOS); el bookmark de la URL del selector ya lleva el acceso. Cierra el pendiente de la fase 4 |
| 2026-10-13 | El bookmark se guarda pero no se registra en logs | Regla 4: los logs no llevan datos del usuario; el bookmark contiene la ruta elegida |
| 2026-10-13 | `LICENSE` (Apache 2.0 oficial) y `NOTICE` añadidos | La decisión de licencia de la fase 2 no estaba materializada (auditoría, sección 10) |
| 2026-10-13 | Modelo de carpeta: copia dentro de la app como vía principal + selector externo como alternativa | Elegido por Adri; coincide con IW4-Pocket, RetroArch y PPSSPP y evita la fragilidad de iCloud con 2,6 GB |
| 2026-10-13 | `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` y carpeta `Documents/Games` | Para que el juego aparezca en Archivos → En mi iPhone → BLOPS pocket → Games |
| 2026-10-13 | Bundle id definitivo: `com.adriantomasdiez.blopspocket` | Elegido por Adri; sustituye al provisional `com.example.blopspocket` |
| 2026-10-13 | Se adelanta la fase 7 (README y pruebas manuales) antes de la fase 6 | Elegido por Adri. La documentación no depende del motor y desbloquea la prueba en el iPhone; el motor sigue sin decidir |
| 2026-10-14 | Pruebas en iPhone completadas: la app lee la copia (143 zonas, 2,8 GB, Zombies 5) | Verificado por Adri con capturas |
| 2026-10-14 | Estrategia del motor: adaptar KisakBlack | Elegido por Adri |
| 2026-10-14 | Motor: motor propio en Metal, KisakBlack solo como referencia | Elegido por Adri tras revisar KisakBlack: es Windows, Direct3D 9 y multijugador, sin Zombies. Portarlo exigiría reescribir plataforma y render, y tampoco aporta Zombies. Sin copia de código, la licencia puede volver a Apache 2.0 (pendiente de decidir) |
| 2026-10-14 | Licencia de la app: vuelve a Apache 2.0 (revierte el cambio a GPL-3.0 de este mismo día) | Decidido por Adri al elegir motor propio con KisakBlack solo como referencia. Sin copia de código GPL, Apache 2.0 es válido. Registro previo: Licencia de la app: GPL-3.0 (cambio desde Apache 2.0) | Elegido por Adri para poder adaptar KisakBlack. `LICENSE` (GPL-3.0 oficial, descargado de gnu.org) y `NOTICE` actualizados. La implementación del motor sigue pendiente de confirmación |

## 7. Estado actual

| Fase | Descripción | Estado |
|---|---|---|
| 0 | Contexto, reglas y legalidad | Hecho |
| 1 | Investigación de referencias | Hecho (este documento) |
| 2 | Decisiones: licencia, nombre, base de código | Hecho (KisakBlack solo como referencia) |
| 3 | Estructura del proyecto y CI para IPA sin firmar | Hecho. El CI en macOS ejecuta las pruebas de `tools/` y publica el artefacto `BLOPSPocket-unsigned`. Runs en verde (comprobados por Adri el 2026-10-13): `434f521`, `85cefbd`, `2564356`, `2f050ac`, `0683fa6` y `1a65063` |
| 4 | Launcher: selección y validación de la carpeta del juego | Hecho. Dos vías: la copia en `Documents/Games` (principal, `GameFolderLocator.swift`) y una carpeta externa recordada con bookmark (`GameFolderBookmark.swift`). **Compilado en CI** (run de `2f050ac`, `success`). Sin probar en iPhone |
| 5 | Lectura de archivos de BO1 (formato y carga) | **Hecho en lo verificable**: formato del contenedor documentado y medido (sección 3.5) y catálogo de zonas en la app (`ZoneFileHeader.swift`, `ZoneCatalog.swift`). **Compilado en CI** (run de `2564356`, `success`); falta probarlo en el iPhone. La tabla de assets queda para la fase 6 |
| 6 | Motor en iOS (Metal, audio, entrada, memoria) | **Motor propio en Metal**, KisakBlack solo como referencia (decidido por Adri). Riesgos: memoria en iPhone (IW4-Pocket ya la tiene al límite), Metal y audio sin probar en iOS, y la lectura por zona sin cargar 2,8 GB. Pendiente: diseño propuesto y aprobación antes de programar |
| 7 | Pruebas en iPhone y documentación para el usuario | **Documentación hecha** (`README.md` y `pruebas-iphone.md`, 12 comprobaciones). Las pruebas en el iPhone están pendientes de que Adri pueda instalar la IPA |

**Fase en curso:** 7 (documentación hecha; faltan las pruebas en el iPhone). La verificación en CI de las fases 3–5 está completa. La fase 6 (motor) queda aplazada por decisión de Adri.
**Verificado en dispositivo (Adri, 2026-10-13):** la copia del PC tiene 143 zonas, todas con versión `0x1D9`, y el grupo Zombies con 5 zonas · 279,7 MiB, igual que lo medido con `tools/`.
**Próximo paso:** Adri instala la IPA con SideStore y recorre `pruebas-iphone.md`. Después, prompt 6: definir la estrategia del motor (KisakBlack bajo GPL, reescritura propia, u otra) con sus riesgos de memoria y de licencia, y esperar su confirmación antes de implementar nada.
**Estado del repositorio:** todo commiteado y subido a `origin/main` (fases 4 y 5, y esta auditoría). **Sin commitear a propósito:** `.freebuff/`. El workflow del CI ejecuta también las pruebas de `tools/` antes de compilar.

## 8. Decisiones abiertas (por confirmar con Adri)

- **Licencia de la app:** Apache 2.0 (decidido por Adri el 2026-10-14). Vuelve a Apache porque el motor no copia código de KisakBlack (GPL-3.0). Si algún día se copia, habrá que cambiar a GPL-3.0.
- **Nombre de la app:** BLOPS pocket (decidido, provisional).
- **Dispositivo y entorno de build:** solo GitHub Actions, sin Mac (decidido).
- **Distribución:** uso personal con SideStore (decidido).
- **Base de código:** KisakBlack solo como referencia; no se copia código (decidido).

### Pendientes abiertos

- Probar en el iPhone el catálogo de zonas y la persistencia del acceso (fases 4 y 5).
- Probar la IPA en un iPhone con SideStore (instalación y selección de carpeta). Hoy solo sabemos que compila.
- Probar en el iPhone las dos vías de carpeta: la copia en `Documents/Games` y el selector externo con bookmark.
- Recorrer `pruebas-iphone.md` en el iPhone y anotar los resultados (incluye el aviso de que desinstalar borra la copia y la comprobación de espacio).
- Decidir la estrategia del motor (fase 6) cuando Adri quiera: es la única decisión técnica abierta que queda.
- Comprobar el resultado del CI de la fase 4/5 (aquí no hay `gh` ni token: se mira en GitHub Actions).
- Revisar el CI en cada cambio: el primer run tardó por la cola de runners macOS arm64.

Hecho: repositorio remoto creado y commits subidos a origin (ramas `main`).

## 9. Problemas conocidos

- La cabecera interna de la zona (prefijo de 36 bytes) y la tabla de assets **no** están decodificadas: el launcher enumera zonas, no assets.
- Las zonas traducidas `Spanish/sp_*.ff` (20 MiB) se listan, pero aún no se sabe cómo elige el juego entre `Common/` y `Spanish/`.
- Sin Xcode ni Mac en el entorno de desarrollo: el Swift solo se compila en GitHub Actions, así que el resultado de un `push` tarda y no se puede comprobar desde aquí.
- Los tres repositorios de referencia están en Windows o son experimentales. Ninguno está probado en iOS.
- IW4-Pocket tiene problemas de memoria en iPhone; el motor de BO1 puede tener problemas parecidos.

## 10. Auditoría de las fases 0–4 (2026-10-13)

Revisión de qué pedía cada fase contra lo que hay de verdad en el repositorio. La conclusión: no se saltó ninguna fase, pero había **tareas de la fase 2 y 3 que nunca se materializaron** y una decisión de la fase 4 sin cerrar.

| Fase | Qué existía | Hueco encontrado |
|---|---|---|
| 0 | `reglas.md` | Ninguno |
| 1 | §3 y §3.5 | Ninguno |
| 2 | Decisiones en §6 | La licencia elegida (Apache 2.0) **no tenía archivo `LICENSE`** |
| 3 | `project.yml`, workflow, `.gitignore` | Faltaba `LICENSE`/`NOTICE`; bundle id provisional; `Info.plist` generado sin ignorar |
| 4 | Selector, validador, bookmark | Sin decidir el modelo de carpeta del juego |

**Corregido en esta auditoría:**

- `LICENSE` añadido con el texto oficial de Apache 2.0 (11 358 bytes, descargado de apache.org).
- `NOTICE` añadido: propiedad del proyecto, licencia y atribuciones, con el aviso de que ninguna referencia aportó código y de que copiar GPL-3.0 obligaría a cambiar la licencia.
- §1 decía "Todavía no hay código": corregido.
- `prompts.md` no marcaba las fases 2–5 ya hechas: marcadas.
- `launcher/BLOPSPocket/Info.plist` (generado por XcodeGen) añadido a `.gitignore`.

**Modelo de carpeta del juego (fase 4) — decidido el 2026-10-13.** Investigación previa:

- Elegir una carpeta externa con el selector de Archivos y un bookmark **funciona** (Apple lo documenta desde iOS 13), pero para 2.6 GB es frágil: iCloud puede desalojar los archivos y dejar la carpeta "válida pero sin bytes", el proveedor tiene que cooperar, y desinstalar la app borra el bookmark guardado.
- El patrón que usan los proyectos equivalentes (IW4-Pocket, RetroArch, PPSSPP, Provenance) es **copiar el juego dentro de la app** y que el usuario lo vea en Archivos → En mi iPhone → nombre de la app, con `UIFileSharingEnabled` y `LSSupportsOpeningDocumentsInPlace`.
- No hay cuota documentada del contenedor de la app: el límite es el espacio libre del dispositivo, y hay que comprobarlo antes de copiar 2.6 GB.
- **Decidido:** vía principal copiar el juego en `Documents/Games` (que aparece en Archivos como En mi iPhone → BLOPS pocket) y mantener el selector externo como alternativa. Implementado con `GameFolderLocator.swift` y las claves de Info.plist `UIFileSharingEnabled` y `LSSupportsOpeningDocumentsInPlace`.

Fuentes: [Apple: acceso a directorios](https://developer.apple.com/documentation/uikit/providing-access-to-directories), [UIFileSharingEnabled](https://developer.apple.com/documentation/bundleresources/information-property-list/uifilesharingenabled), [capacidad del volumen](https://developer.apple.com/documentation/foundation/checking-volume-storage-capacity), [README de IW4-Pocket](https://github.com/MarkusSela/IW4-Pocket), [guía iOS de RetroArch](https://docs.libretro.com/guides/install-ios/).

## 11. Diseño propuesto del motor en Metal (fase 6, pendiente de aprobación)

Estado: **propuesta, sin código.** Según `prompts.md`, no se programa ninguna parte del motor hasta que Adri lo apruebe. Base decidida: motor propio en Metal, con KisakBlack solo como referencia (ver §6).

**Principio:** no cargar el juego entero. Los FastFile de BO1 pesan varios GB; el motor lee solo el índice y los assets que pide la escena actual.

**Capas:**

1. **Índice de zona:** leer la cabecera (ya existe en `ZoneFileHeader.swift`) y la tabla de assets sin cargar el bloque de datos. Es lo que hace la fase 5 ya implementada en el catálogo.
2. **Lector por rangos:** `FileHandle` con lecturas por desplazamiento a partir del índice. Un asset = una lectura, sin mapear el archivo completo.
3. **Caché acotada:** LRU con tope de memoria fijo (propuesta inicial: 400 MB de assets decodificados). Al superar el tope se descarta lo menos usado. El tope se ajusta con medidas reales en el iPhone (fase 7).
4. **Decodificación:** formato de compresión de los bloques, **por verificar** antes de escribir nada. Se documentará aquí con fuente propia, no con código copiado.
5. **Render Metal:** un `MTKView`, buffers de vértices y texturas creados a demanda desde la caché. Sin shaders de terceros.
6. **Audio:** AVAudioEngine para reproducción de efectos. Pendiente de decidir si entra en la fase 6 o queda para más adelante.

**Subfases propuestas (cada una con criterio de salida):**

- 6a. Leer y listar la tabla de assets de un archivo de zona de prueba. Salida: nombres y conteos por tipo. Los tamaños por asset pasan a 6b (requieren decodificar cada tipo).
- 6b. Decodificar un asset y comprobar que el tamaño descomprimido es correcto.
- 6c. Dibujar un modelo estático en Metal en el simulador o en el iPhone.
- 6d. Caché acotada: cargar y descargar assets sin superar el tope medido.
- 6e. Escena mínima con varios assets y medida de memoria (Instruments en Mac, o contador interno si no hay Mac).

**Riesgos:**

- **Memoria en iPhone:** el sistema puede cerrar la app por presión de memoria. Mitigación: tope de caché y medición en fase 7.
- **Metal y audio sin probar en iOS:** no hay CI para pruebas de render. Las pruebas de render serán manuales en el iPhone.
- **Formato:** la decodificación depende de documentación verificada; si no se encuentra fuente fiable, la subfase 6b se bloquea y se avisa.
- **Licencia:** cualquier código de referencia que se copie cambia la licencia. Solo se aportan ideas y se escribe código propio.

**Bloqueo de 6a (2026-10-14):** la regla 7 exige formato verificado antes de implementar, y la búsqueda de documentación no lo confirmó. Fuentes leídas: [OpenAssetTools, documentación de zone files](https://openassettools.dev/reference/zone-file.html) (confirma nombres de categorías T5, no el layout binario) y [wiki de COD5 FastFile](https://wiki.zeroy.com/index.php?title=Call_of_Duty_5:_FastFile_Format) (es de WaW, no de BO1, no sirve como prueba). Sin fuente fiable no se escribe el lector de la tabla.

**Decisión que necesito de ti:** aprobar este diseño y el orden de subfases, o pedir cambios. Si lo apruebas, empiezo por 6a, que no toca Metal y se puede verificar con la copia de prueba.

**Pausa de la fase 6 (2026-10-14, decidida por Adri).** Hallazgos verificados en la referencia OpenAssetTools (solo lectura) y en la copia de prueba:

- Cabecera de 12 bytes: `IWffu100`, versión 473. Desde el byte 12 hay un stream zlib continuo (`ProcessorInflate`).
- Tras descomprimir: `u32` tamaño, `u32` tamaño externo, un `u32` por bloque XFile (7 bloques en T5) y luego el contenido.
- La lista de assets (`XAssetList`) usa tokens de puntero de 32 bits con bloques y `FOLLOWING`/`INSERT`. Leerla exige reproducir `LoadWithFill` y `AddPointerLookup` de `ContentLoaderT5`.
- Sin verificar: en `mp_firingrange.ff`, la suma de bloques difiere del tamaño total en ~2,8 MB. Sin explicar.

No hay código del motor. Se retoma cuando se decida; el lanzador sigue siendo la versión de esta etapa.

**Cierre de la fase 6 como pausada (2026-10-14).** Motivo: los cargadores de tipos de asset de T5 se generan desde plantillas de ZoneCodeGenerator (decenas de tipos). Listar nombres (6a) exige seguir los punteros de cada asset, y los cuerpos vienen en orden de stream, así que no basta con leer la tabla. Portar eso es un trabajo grande, sin garantía de cierre. Además, 6c–6e requieren Xcode y un iPhone, que no están disponibles en esta sesión. Estado: 6a, 6b, 6d y 6e no hechas; 6c no comprobable aquí. Pendiente sin resolver: la diferencia de ~2,8 MB en la suma de bloques de `mp_firingrange.ff`.

**Fase 6a: lista de assets por tipo (2026-10-14, retomada a petición de Adri).** Entregado: `tools/zoneassets.mjs` (CLI y `parseAssetList`) y `tools/zoneassets.test.mjs`. Lee la `XAssetList` tras los 36 bytes de cabecera XFile (8 de tamaños y 7 bloques) y cuenta los assets por tipo con los nombres del enum de T5.

- Verificado: `node --test tools/zoneassets.test.mjs` pasa 6/6 con datos sintéticos. El CLI sobre `common_zombie.ff` da 2.693 assets y 858 cadenas, con 1.882 XANIMPARTS, 190 FX, 184 XMODEL, 150 MATERIAL, 105 RAWFILE, 83 TECHNIQUE_SET, 79 WEAPON, 13 STRINGTABLE, 4 IMAGE, 1 SOUND, 1 MENULIST y 1 IMPACT_FX. Uso incorrecto sale con código 2.
- Aclarado: los tamaños de bloque XFile son memoria a reservar (`StepAllocXBlocks`), no bytes del stream. Por eso su suma (80,8 MB) supera el stream (79,66 MB) sin contradicción. Esto explica la diferencia pendiente de `mp_firingrange.ff`, aunque no se ha comprobado en ese archivo.
- No verificado: comparación de nombres y conteos con una herramienta de referencia ejecutada (OpenAssetTools no se ha ejecutado aquí). Tamaños por asset: movidos a 6b.

**6a cerrada (2026-10-14, decidida por Adri):** el criterio queda en nombres y conteos por tipo. Pendiente de 6b: tamaños por asset. Pendiente de verificación: comparar con OpenAssetTools sobre `common_zombie.ff`.

**Fase 6b, primer paso: RAWFILE (2026-10-14).** Entregado: `tools/zrawfile.mjs` (CLI, `decodeRawFile`, `findRawFiles`, `readRawFileContent`) y `tools/zrawfile.test.mjs`. Es una sonda de solo lectura: localiza los RAWFILE y valida cada uno (los comprimidos, descomprimiendo su buffer con zlib y comprobando el tamaño).

- **Formato verificado empíricamente** sobre `common_zombie.ff` (no hay compilador para ejecutar OpenAssetTools aquí; la verificación es por la propia firma del registro). Un RAWFILE es: `u32 marca FOLLOWING` + `u32 tamaño del bloque` + `u32 marca FOLLOWING del nombre` + nombre ASCIIZ + bloque de datos de `tamaño` bytes, donde el bloque es
  - **comprimido:** `u32 len` (descomprimido) + `u32 clen` + `clen` bytes zlib (por eso `tamaño = 8 + clen`); se valida con `inflate(clen) == len`;
  - **sin comprimir:** los propios bytes del buffer (`tamaño = len`).
- **Resultado:** `node tools/zrawfile.mjs <common_zombie.ff>` encuentra **105 RAWFILE, que es exactamente lo que declara la tabla: 80 comprimidos (1.672.410 bytes descomprimidos; los `.gsc` de `animscripts/` y `aitype/`) y 25 sin comprimir (15.196 bytes; los `.rmb` de `rumble/`, los `.atr` de `animtrees/`, los `.vision`, dos `.cfg` y un RAWFILE vacío al final, `common_zombie`)**. `node --test tools/zrawfile.test.mjs` pasa 7/7 con datos sintéticos; uso incorrecto sale con código 2. El contenido es real (p. ej. `mp/zm_challenges_reset.cfg` empieza por `// reset the coop challenges`).
- **Último asset:** el RAWFILE con índice 2692 (el último de la tabla de assets) es la cola del stream; su bloque va vacío y no lleva marca de registro detrás, solo el byte de separación. Por eso la sonda acepta el final del stream como cierre válido.
- **No verificado / pendiente:** (1) Entre el final de un registro y la marca del siguiente hay **1 byte** (0x00 en los no comprimidos; su significado no está confirmado); por eso la sonda busca por firma en lugar de recorrer de corrido, y arranca tras la lista de assets (`bodyOffset` de `zoneassets.mjs`) para no confundirla con la cabecera. (2) No se ha ejecutado OpenAssetTools como referencia. (3) Un recorrido del stream por orden de assets (necesario para tamaños del resto de tipos) sigue bloqueado por el tamaño del port de ZoneCodeGenerator.

**Fase 6b.1: recorrido secuencial del stream (2026-10-14, iniciada).** Objetivo: avanzar asset a asset en el orden de la tabla y verificar el recorrido con las **105 anclas** de RAWFILE (offsets ya conocidos).

- **Modelo de serialización confirmado** (leído en `ZoneWriteTemplate.cpp`, función `PrintWriteMethod`): por cada asset se escribe primero la **región fija** del struct (`m_stream->Write<Tipo>(...)`, `sizeof` del struct con sus punteros inline) y, después, en orden de declaración, los **datos "following"** de los miembros que los tienen (cadenas, arrays, punteros no nulos).
- **Primer asset (índice 0, `TECHNIQUE_SET`) verificado:** su región fija mide **528 bytes** (`name` 4 + `worldVertFormat` 1 + `unused[1]` 1 + `techsetFlags` 2 + `techniques[130]` 520), que es exactamente lo que ocupa antes del primer dato. Empieza en `bodyOffset` = 39270. Los 130 punteros de `techniques` van a 0 (nulos), así que no hay datos following por ellos.
- **Sin confirmar:** el nombre del techset que se lee tras la región fija es `",2d"`, un nombre inusual; no descarto que el tamaño de la región fija esté desviado por alineación y que ese texto pertenezca a otro campo. El `material` (índice 1) empieza entonces en 39802, y el primer RAWFILE en 40113: entre ambos hay 311 bytes que aún no cuadran con el `sizeof` calculado de `Material` (`MaterialInfo` + `stateBitsEntry[130]` + 6 + 4 punteros ≈ 184).
- **Qué falta para cerrar 6b.1:** fijar los `sizeof` exactos (con alineación) de `MaterialInfo`/`GfxDrawSurf`, `Material`, y los arrays following (`textureTable`, `constantTable`, `stateBitsTable`), y el tratamiento de `techniques`/shaders del techset. Es el mismo trabajo que hace ZoneCodeGenerator; conviene portarlo por tipos y validar con las anclas.
- **Entorno:** no hay compilador para ejecutar OpenAssetTools y comparar.
- **Nota de entorno:** la copia de prueba del juego ya no está en una carpeta normal; los `.ff` solo aparecen en la Papelera de reciclaje (`$Recycle.Bin/.../$R4QGBD9/zone/`). Se han leído de ahí, en solo lectura. Conviene restaurarlos antes de la prueba en iPhone.
