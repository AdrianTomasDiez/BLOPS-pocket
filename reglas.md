# reglas.md: BLOPS pocket (Call of Duty: Black Ops 1 en iOS)

> **Para el agente de IA:** lee este archivo COMPLETO antes de tocar código. Si hay conflicto entre reglas, prevalece la más restrictiva. Mantén la sección 7 (estado) al día al cerrar cada fase.

---

## 1. Objetivo

Lanzador para iPhone (iOS) que ejecute **Call of Duty: Black Ops 1** leyendo los archivos del juego que el propio usuario posee, sin incluir ningún archivo del juego en el repositorio ni en la app.

- **Modo Zombies** es el objetivo principal (Adri lo quiere jugar en el móvil). Multijugador queda como opción posterior.
- **Modelo de referencia de arquitectura:** [IW4-Pocket](https://github.com/MarkusSela/IW4-Pocket) (MW2 en iOS).
- **Estado:** fase de estudio. Todavía no hay código.

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

## 4. Estructura prevista

```
BLOPS pocket/
├── reglas.md             → este archivo
├── prompts.md            → prompts de cada fase
├── .gitignore            → excluye datos del juego, build e IPA
├── README.md             → instrucciones para el usuario (fase 7)
├── launcher/
│   ├── project.yml       → especificación de XcodeGen (genera el .xcodeproj)
│   └── BLOPSPocket/      → código SwiftUI de la app
├── engine/               → runtime (fase 6, sin decidir)
└── .github/workflows/
    └── ios-ipa.yml       → compila y genera la IPA sin firmar (GitHub solo lee workflows desde esta ruta)
```

No crear carpetas hasta que la fase lo requiera. El bundle id `com.example.blopspocket` es provisional: cámbialo antes de instalar en el iPhone.

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

## 7. Estado actual

| Fase | Descripción | Estado |
|---|---|---|
| 0 | Contexto, reglas y legalidad | Hecho |
| 1 | Investigación de referencias | Hecho (este documento) |
| 2 | Decisiones: licencia, nombre, base de código | Parcial: licencia, nombre, CI y distribución decididos; base de código pendiente |
| 3 | Estructura del proyecto y CI para IPA sin firmar | Hecho en código; compilación en CI sin verificar (no hay Mac ni runner local) |
| 4 | Launcher: selección y validación de la carpeta del juego | Hecho en código (GameFolderValidator + selector); sin compilar, sin verificar en iPhone. No persiste el acceso entre aperturas |
| 5 | Lectura de archivos de BO1 (formato y carga) | Pendiente |
| 6 | Motor en iOS (Metal, audio, entrada, memoria) | Pendiente |
| 7 | Pruebas en iPhone y documentación para el usuario | Pendiente |

**Fase en curso:** 5 (lectura de archivos de BO1), pendiente de decidir la base de código de la fase 2
**Próximo paso:** decidir si KisakBlack es base o referencia; después, el formato de los archivos de zona.

## 8. Decisiones abiertas (por confirmar con Adri)

- **Licencia de la app:** Apache 2.0 (decidido). Si más adelante se copia código de KisakBlack, habrá que cambiar a GPL-3.0.
- **Nombre de la app:** BLOPS pocket (decidido, provisional).
- **Dispositivo y entorno de build:** solo GitHub Actions, sin Mac (decidido).
- **Distribución:** uso personal con SideStore (decidido).

Pendiente: decidir si se usa código de KisakBlack (lo que obligaría a GPL-3.0) o solo como referencia.

## 9. Problemas conocidos

- Sin código todavía. Ninguna prueba ejecutada.
- Los tres repositorios de referencia están en Windows o son experimentales. Ninguno está probado en iOS.
- IW4-Pocket tiene problemas de memoria en iPhone; el motor de BO1 puede tener problemas parecidos.
