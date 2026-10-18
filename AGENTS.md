# AGENTS.md: BLOPS pocket (se carga siempre; mantener corto)

Port nativo de Call of Duty: Black Ops 1 Zombies (Kino der Toten) para iOS (iOS 15+, 64 bits ARM64) basado directamente en el código fuente de `bo1-zombies-decompiled`, idéntico a la filosofía de IW4-Pocket. Queda terminantemente prohibido reimplementar o "inventar" motores caseros en Swift.

## Índice
- [continuar.md](continuar.md): estado, comandos y siguiente paso. **Léelo primero.**
- [reglas.md](reglas.md): directrices técnicas, arquitectura C++, port a iOS, estado por fases.
- `engine/`: código fuente de `bo1-zombies-decompiled` adaptado para iOS ARM64 (Metal/SDL2/CoreAudio).
- `launcher/`: inicialización de plataforma iOS, sandbox de archivos y puente con el motor nativo.
- Compilación automatizada en CI (GitHub Actions en macOS arm64).

## Invariantes
- **Arquitectura de motor real:** Se usa la base de `bo1-zombies-decompiled`, eliminando código no utilizado (campaña, multijugador, dependencias Win32/x86/DirectX9 exclusivas de PC).
- **No inventar motores:** No escribir renderizadores caseros o visores poligonales ficticios en Swift. El juego debe correr el pipeline real de Treyarch.
- **Recursos del usuario:** Ningún archivo comercial del juego (`*.ff`, `zone/`) en git ni en la IPA. La app los lee desde `Documents/Games`.
