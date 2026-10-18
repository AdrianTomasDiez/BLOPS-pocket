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

## Prompt 6: Motor e Hito 6c (Hecho: visor 3D Metal, Kino der Toten, props estáticos e icono oficial)

```
Implementa el decodificador de XModel y reconstructor de GFXWORLD de Kino der Toten en Metal con cámara libre FPS táctil y empaquetado en IPA.
```

---

## Prompt 8: Fase 6c.4 — Suelo, gravedad y colisiones en Kino der Toten

```
Estamos en la Fase 6c.4 de BLOPS pocket. Lee continuar.md y reglas.md.
Objetivo: Implementar la detección de suelo, gravedad y colisión contra paredes en el Lobby de Kino der Toten para el modo FPS.
1. Bloquea la cámara al suelo real del Lobby a altura de ojos (~60-65 unidades).
2. Añade física de pisada y gravedad para que el jugador camine sobre el piso sin caer al vacío.
3. Limita el movimiento contra las paredes y puertas cerradas del Lobby para no atravesarlas.
4. Asegura que los controles táctiles D-pad y giro respondan fluidamente.
5. Ejecuta las pruebas de regresión, git diff --check y prepara la app para compilar la nueva IPA.
```

---

## Prompt 9: Fase 6c.5 — Texturas completas de Kino der Toten

```
Estamos en la Fase 6c.5 de BLOPS pocket. Lee continuar.md y reglas.md.
Objetivo: Cargar las texturas diffuse y specular de paredes, suelos, puertas y modelos estáticos de Kino der Toten desde los .iwd/.ff.
1. Extrae y mapea las texturas reales para reemplazar el render unlit/básico en escala de grises.
2. Aplica las texturas a la geometría BSP y a los 3.070 props estáticos del mapa.
3. Optimiza la memoria de Metal para que no sature la VRAM en el iPhone.
4. Verifica con git diff --check y las pruebas unitarias.
```

---

## Prompt 10: Fase 6d.1 — Arma inicial (M1911), disparo y HUD

```
Estamos en la Fase 6d.1 de BLOPS pocket. Lee continuar.md y reglas.md.
Objetivo: Implementar el arma inicial (Colt M1911) en primera persona, disparo con retroceso y HUD.
1. Renderiza el modelo viewmodel de la M1911 en primer plano anclado a la cámara.
2. Añade botón táctil de disparo con animación de retroceso (kick) y raycasting hacia el centro.
3. Controla la munición exacta (8 balas en cargador + 32 en reserva) y botón de recarga.
4. Muestra el HUD de juego con el contador de balas y 500 puntos iniciales.
5. Verifica con git diff --check y las pruebas unitarias.
```

---

## Prompt 11: Fase 6d.2 — Primer zombi con daño y muerte

```
Estamos en la Fase 6d.2 de BLOPS pocket. Lee continuar.md y reglas.md.
Objetivo: Spawnear un zombi en una ventana del Lobby, detectar impactos de bala y su eliminación.
1. Carga el modelo 3D del zombi de BO1 en una de las ventanas del Lobby.
2. Implementa hitboxes (cuerpo y cabeza) que detecten los disparos de la M1911.
3. Aplica las fórmulas de salud de Ronda 1 (150 HP; 20 de daño por bala de M1911).
4. Añade el sistema de puntos (+10 por impacto, +60 muerte al cuerpo, +100 muerte a la cabeza).
5. Elimina al zombi al llegar a 0 HP y actualiza los puntos en el HUD.
```

---

## Prompt 12: Fase 6d.3 — IA de persecución, ataque y daño al jugador

```
Estamos en la Fase 6d.3 de BLOPS pocket. Lee continuar.md y reglas.md.
Objetivo: Hacer que el zombi persiga al jugador, lo ataque cuerpo a cuerpo y el jugador pueda morir.
1. Implementa navegación del zombi hacia la posición del jugador en el Lobby.
2. Añade ataque cuerpo a cuerpo cuando esté a distancia de golpe.
3. Sistema de salud del jugador: pantalla roja por daño, muere de 2 golpes y se regenera a los 5 segundos sin daño.
4. Pantalla de Game Over / Reinicio de partida si el jugador muere.
```

---

## Prompt 13: Fase 6e — Flujo completo de Kino der Toten

```
Estamos en la Fase 6e de BLOPS pocket. Lee continuar.md y reglas.md.
Objetivo: Bucle completo de Zombies con rondas progresivas, compra de puertas y armas de pared.
1. Bucle de rondas (Ronda 1 con 6 zombis, incremento de velocidad y salud por ronda con sonido de cambio).
2. Compra de puertas del Lobby (750 pts) usando las coordenadas de MapEnts.
3. Compra de armas de pared (Olympia y M14 por 500 pts).
4. Integración de la Caja Misteriosa y máquinas de ventajas (Quick Revive y Titán).
```

---

## Prompt 14: Pruebas en iPhone y documentación final

```
Escribe el README para el usuario (requisitos, cómo copiar la carpeta del juego con SideStore, limitaciones conocidas) y una lista de pruebas manuales en iPhone: arranque, validación de la carpeta, uso de memoria y cierre con el juego en curso. Ejecuta lo que se pueda automatizar y dime qué debo probar yo.
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
