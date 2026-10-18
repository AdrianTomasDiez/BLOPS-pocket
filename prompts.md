# prompts.md: BLOPS pocket

> Usa un prompt por fase. Antes de cada fase, lee `continuar.md` y las secciones 1, 2 y 5–8 de `reglas.md`; el resto, bajo demanda. Al terminar, actualiza la sección 7 de `reglas.md`.

---

## Prompt 1: Investigación (hecha)

```
Estudia los repositorios de referencia (IW4-Pocket, KisakBlack, bo1-zombies-decompiled) y crea reglas.md con la arquitectura, la legalidad y las decisiones pendientes. No escribas código.
```

---

## Prompt 2: Decisiones previas (hecho)

```
Antes de escribir código, pregúntame con ask_questions: licencia de la app (GPL-3.0 si usamos KisakBlack, Apache 2.0 si solo es referencia), nombre de la app, si hay un Mac para compilar o solo GitHub Actions, y si la distribución es personal o pública. Registra mis respuestas en la sección 6 de reglas.md.
```

---

## Prompt 3: Estructura del proyecto y CI para IPA (hecho)

```
Crea la estructura mínima del proyecto según la sección 4 de reglas.md y un workflow de GitHub Actions que compile un placeholder y genere una IPA sin firmar, siguiendo el flujo de IW4-Pocket. Añade .gitignore para datos del juego. No añadas código del motor.
```

---

## Prompt 4: Launcher: selección y validación de la carpeta del juego (hecho)

```
Crea el launcher iOS que deja elegir la carpeta del juego del usuario (con subcarpeta zone), valida que existe y muestra un mensaje claro si falta algo. No cargues ni leas los archivos del juego todavía. Sigue el modelo de IW4-Pocket para la ruta en Archivos.
```

---

## Prompt 5: Lectura de archivos de BO1 (hecho: contenedor y catálogo; la tabla de assets pasa a la fase 6)

```
Investiga y documenta en reglas.md el formato de los archivos de zona de Black Ops 1 (FastFile). Después implementa un lector que liste los archivos de zona disponibles sin cargarlos en memoria. Verifica con una copia de prueba propia. No copies código de bo1-zombies-decompiled.
```

---

## Prompt 6: Importación y estructura de bo1-zombies-decompiled (hecho)

```
Clona bo1-zombies-decompiled en engine_source/ e inspecciona CMakeLists.txt y su estructura de módulos (game, bgame, cgame, clientscript, physics, gfx_d3d, xanim). Actualiza AGENTS.md y reglas.md para blindar el proyecto contra inventar motores caseros en Swift.
```

---

## Prompt 7: Limpieza y poda de dependencias Win32 / x86 de PC

```
Estamos en la Fase de Port C++ de BLOPS pocket. Lee continuar.md y reglas.md.
Objetivo: Podar y desacoplar las dependencias obsoletas de Windows x86 de PC del motor bo1-zombies-decompiled:
1. Eliminar módulos de campaña y multijugador no utilizados (client_mp, game_mp, server_mp).
2. Desacoplar librerías de 32 bits de PC (DirectX 9 SDK 2010, XAudio2, Bink32, Steamworks, NVAPI).
3. Configurar CMakeLists.txt para permitir compilación cruzada a ARM64 (aarch64-apple-ios).
4. Verificar que no se rompan las dependencias fundamentales de la lógica de Zombies (bgame, cgame, game, clientscript, physics, xanim).
```

---

## Prompt 8: Capa de plataforma iOS (Ventana, Render y Entrada)

```
Estamos en la Fase de Plataforma iOS de BLOPS pocket. Lee continuar.md y reglas.md.
Objetivo: Implementar la capa puente de plataforma para iOS:
1. Integrar SDL2 / backend de ventana para iOS con contexto Metal (MoltenVK o puente Metal nativo).
2. Conectar la capa de audio a CoreAudio / OpenAL.
3. Conectar el sistema de entrada nativo de Apple (GameController) a los comandos del motor (+forward, +back, +attack, +reload, etc.).
4. Configurar el sandbox de archivos para leer desde Documents/Games.
```

---

## Prompt 9: Pipeline de carga de FastFiles y ejecución de Kino der Toten

```
Estamos en la Fase de Carga y Ejecución de Kino der Toten. Lee continuar.md y reglas.md.
Objetivo: Conectar el motor para cargar los FastFiles originales del juego:
1. Inicializar el subsistema de assets (DB_Init y XAssetList) sobre zombie_theater.ff y common_zombie.ff.
2. Ejecutar la máquina de scripts GSC de Treyarch para Kino der Toten (iniciar partidas en solo).
3. Cargar el mapa con sus shaders, modelos esqueléticos, animaciones de zombis y sonidos originales.
```

---

## Prompt 10: Integración en CI, compilación IPA y verificación en iPhone

```
Estamos en la Fase de CI y Empaquetado de BLOPS pocket. Lee continuar.md y reglas.md.
Objetivo: Automatizar la compilación del binario nativo ARM64 en GitHub Actions y generar la IPA:
1. Configurar el workflow de GitHub Actions con el toolchain de iOS SDK en macOS runner.
2. Compilar el ejecutable BO1Zombies para iOS y empaquetarlo en Payload/BLOPSPocket.app.
3. Publicar el .ipa en GitHub Releases para instalación directa con AltStore / SideStore / TrollStore.
4. Documentar la checklist de pruebas en el iPhone (arranque, menú de zombies, control con mando y rendimiento).
```

---

## Prompts de utilidad

### Retomar tras perder contexto

```
Has perdido el contexto. Lee BLOPS pocket/continuar.md y las secciones 1, 2 y 5–8 de reglas.md. Resúmeme en 10 líneas: en qué fase estamos, qué falta y cuál es el siguiente paso. No escribas código hasta que yo confirme.
```

### Cierre de fase

```
Hemos terminado la fase actual. Actualiza la sección 7 de reglas.md, lista los archivos creados o modificados y comprueba que no hay datos del juego ni código sin licencia registrada.
```

### Revisión legal

```
Revisa el código y la documentación actuales de BLOPS pocket y dime si incumplen alguna regla de la sección 2 de reglas.md (datos del juego, marcas, código de terceros sin licencia).
```
