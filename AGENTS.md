# AGENTS.md: BLOPS pocket (se carga siempre; mantener corto)

Launcher iOS (SwiftUI, iOS 15+) para BO1 Zombies con los archivos del usuario. El motor no existe todavía. Las fuentes de verdad son los documentos de abajo: no copies aquí su contenido.

## Índice
- [continuar.md](continuar.md): estado, comandos y siguiente paso. **Léelo primero.**
- [reglas.md](reglas.md): legal (§2), reglas de trabajo (§5), decisiones (§6), estado por fases (§7). §3, §10 y §11 son historial y formato: búscalos por encabezado solo cuando los necesites.
- [pruebas-iphone.md](pruebas-iphone.md): pruebas manuales en el dispositivo. [prompts.md](prompts.md): una fase por prompt.
- `launcher/`: `project.yml` (XcodeGen) y `BLOPSPocket/*.swift` (carpeta, bookmark, cabecera `.ff` y catálogo).
- `tools/*.mjs`: sondas del formato FastFile en Node, sin dependencias. Pruebas: `node --test tools/*.test.mjs`, que deben coincidir con la lista de `.github/workflows/ios-ipa.yml`.
- Swift solo compila en el CI (macOS). Aquí no hay Xcode ni Mac.

## Invariantes (reglas.md §2 y §5)
- Ningún archivo del juego (`*.ff`, `zone/`) en git, la IPA ni los logs. No uses código de bo1-zombies-decompiled. KisakBlack solo como referencia (Apache 2.0).
- No inventes formatos: verifícalos contra bytes reales y anótalos en reglas.md.
- No implementes partes del motor sin el visto bueno de Adri.

## Eficiencia
- Busca (`Select-String`, encabezados) antes de abrir un archivo. No releas documentos que no hayan cambiado.
- No abras `*.ff`, `build/` ni binarios. No uses skills ni MCP de cloud o datos en este proyecto.
- Al cerrar una tarea, actualiza continuar.md y reglas.md §7 con cambios mínimos.
