# pruebas-iphone.md: comprobaciones manuales en el iPhone

> Fase 7 de `reglas.md`. Lo que se puede automatizar ya se ejecuta sin dispositivo: `node --test tools/zonescan.test.mjs` (6 pruebas, en el CI en cada push). Todo lo de la tabla de abajo necesita el iPhone.

**Cómo usarla:** instala la IPA con SideStore y ve marcando. Si algo falla, apunta el número, lo que esperabas y lo que ha pasado; una captura de pantalla vale más que la descripción. El estado de cada fila se actualiza aquí al terminar.

## Preparación

- [ ] IPA del artefacto `BLOPSPocket-unsigned` de un run en verde de GitHub Actions.
- [ ] iPhone con iOS 15 o posterior y ~3 GB libres.
- [ ] Carpeta del juego en el PC (`...\Call of Duty Black Ops`, debe contener `zone/`).

## Pruebas

| # | Qué probar | Cómo | Qué debe pasar | Estado |
|---|---|---|---|---|
| 1 | Instalación | Instalar la IPA con SideStore y abrirla | La app abre, muestra "BLOPS pocket" y no se cierra | Pendiente |
| 2 | Primera apertura sin juego | Abrir sin haber copiado nada | Explica dónde copiar el juego y ofrece el botón; no se queda en blanco ni se cierra | Pendiente |
| 3 | Carpeta visible en Archivos | Abrir Archivos → En mi iPhone | Aparece **BLOPS pocket** con una carpeta **Games** dentro | Pendiente |
| 4 | Copia de ~2,6 GiB | Copiar la carpeta del juego (con `zone/`) a `BLOPS pocket/Games` | La copia termina; apuntar cuánto tarda y si el iPhone avisa de falta de espacio | Pendiente |
| 5 | Detección automática | Abrir la app con la copia hecha | "N zonas encontradas · X GB", origen "Copia dentro de la app", y N coincide con los archivos copiados | Pendiente |
| 6 | Reparto por grupos | Mirar el resumen y la lista | Zombies con 5 zonas · 279,7 MiB (si copiaste `Common/`); los grupos cuadran con lo copiado | Pendiente |
| 7 | Carpeta equivocada | Elegir una carpeta sin `zone/` | Mensaje claro ("Falta la subcarpeta zone…"), sin error ni cierre | Pendiente |
| 8 | Carpeta externa | Elegir una carpeta de Archivos (p. ej. iCloud Drive) | La lista aparece; al cerrar y reabrir la app sigue recordando esa carpeta | Pendiente |
| 9 | Olvidar carpeta | Pulsar "Olvidar la carpeta guardada" y reabrir | Deja de leerla y ofrece elegir otra | Pendiente |
| 10 | Desinstalación | Desinstalar y volver a instalar la app | Se pierde la copia del juego dentro de `Games/` (comportamiento de iOS, ya documentado en el README) | Pendiente |
| 11 | Memoria en reposo | — | Solo se puede medir cuando el motor descomprima zonas (fase 6); las sondas de `tools/` miden que `common_zombie.ff` ocupa 76 MiB descomprimido | Bloqueada por la fase 6 |
| 12 | Cierre con el juego en curso | — | Necesita el motor (fase 6) | Bloqueada por la fase 6 |

## Qué mirar en cada caso

- **Pantalla en blanco o cierre inmediato:** apunta el modelo de iPhone y la versión de iOS.
- **Número de zonas distinto al esperado:** cuenta en el PC con `ls zone/Common/*.ff | wc -l`; si copiaste también `Spanish/`, súmalos.
- **"Versión inesperada":** indica qué archivo aparece en rojo; significa que no tiene la versión `0x1D9` y probablemente no es de esta edición.
- **La carpeta externa no se recuerda:** anota si estaba en iCloud Drive o en "En mi iPhone", y si los archivos estaban descargados.

## Lo que ya está verificado sin iPhone

- Formato del contenedor `.ff` (magic `IWffu100`, versión `0x1D9`, un zlib hasta EOF) medido sobre las 143 zonas de la copia de Adri: `node tools/zonescan.mjs <carpeta>`.
- La lógica del catálogo (grupos, versiones inesperadas, archivos truncados y la garantía de que **no se descomprime**): `node --test tools/zonescan.test.mjs`.
- El launcher **compila** en GitHub Actions: los runs de `2564356` (fase 5), `2f050ac` (fase 4), `0683fa6` (auditoría) y `1a65063` (fase 7) están en verde, y los dos últimos ya ejecutan `node --test` antes de compilar.
- La copia de Adri en el PC coincide con lo esperado: 143 zonas, todas `0x1D9`, Zombies 5 zonas · 279,7 MiB.
- Lo que **no** está verificado es nada en dispositivo: eso es lo que cubre esta tabla.
