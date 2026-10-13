# prompts.md: BLOPS pocket

> Usa un prompt por fase. Antes de cada fase, lee `reglas.md` completo. Al terminar, actualiza la sección 7 de `reglas.md`.

---

## Prompt 1: Investigación (hecha)

```
Estudia los repositorios de referencia (IW4-Pocket, KisakBlack, bo1-zombies-decompiled) y crea reglas.md con la arquitectura, la legalidad y las decisiones pendientes. No escribas código.
```

---

## Prompt 2: Decisiones previas

```
Antes de escribir código, pregúntame con ask_questions: licencia de la app (GPL-3.0 si usamos KisakBlack, Apache 2.0 si solo es referencia), nombre de la app, si hay un Mac para compilar o solo GitHub Actions, y si la distribución es personal o pública. Registra mis respuestas en la sección 6 de reglas.md.
```

---

## Prompt 3: Estructura del proyecto y CI para IPA

```
Crea la estructura mínima del proyecto según la sección 4 de reglas.md y un workflow de GitHub Actions que compile un placeholder y genere una IPA sin firmar, siguiendo el flujo de IW4-Pocket. Añade .gitignore para datos del juego. No añadas código del motor.
```

---

## Prompt 4: Launcher: selección y validación de la carpeta del juego

```
Crea el launcher iOS que deja elegir la carpeta del juego del usuario (con subcarpeta zone), valida que existe y muestra un mensaje claro si falta algo. No cargues ni leas los archivos del juego todavía. Sigue el modelo de IW4-Pocket para la ruta en Archivos.
```

---

## Prompt 5: Lectura de archivos de BO1

```
Investiga y documenta en reglas.md el formato de los archivos de zona de Black Ops 1 (FastFile). Después implementa un lector que liste los archivos de zona disponibles sin cargarlos en memoria. Verifica con una copia de prueba propia. No copies código de bo1-zombies-decompiled.
```

---

## Prompt 6: Motor en iOS

```
Define en reglas.md la estrategia del motor (adaptar KisakBlack bajo GPL, reescribir desde cero, o usar otro enfoque) con sus riesgos de memoria y licencia. Espera mi confirmación antes de implementar cualquier parte del motor.
```

---

## Prompt 7: Pruebas en iPhone y documentación

```
Escribe el README para el usuario (requisitos, cómo copiar la carpeta del juego con SideStore, limitaciones conocidas) y una lista de pruebas manuales en iPhone: arranque, validación de la carpeta, uso de memoria y cierre con el juego en curso. Ejecuta lo que se pueda automatizar y dime qué debo probar yo.
```

---

## Prompts de utilidad

### Retomar tras perder contexto

```
Has perdido el contexto. Lee BLOPS pocket/reglas.md completo. Resúmeme en 10 líneas: en qué fase estamos, qué falta y cuál es el siguiente paso. No escribas código hasta que yo confirme.
```

### Cierre de fase

```
Hemos terminado la fase actual. Actualiza la sección 7 de reglas.md, lista los archivos creados o modificados y comprueba que no hay datos del juego ni código sin licencia registrada.
```

### Revisión legal

```
Revisa el código y la documentación actuales de BLOPS pocket y dime si incumplen alguna regla de la sección 2 de reglas.md (datos del juego, marcas, código de terceros sin licencia).
```
