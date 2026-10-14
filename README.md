# BLOPS pocket

Lanzador para iPhone que ejecuta **Call of Duty: Black Ops 1** leyendo los archivos del juego que tú mismo aportas. Ni este repositorio ni la app incluyen ninguna copia del juego: la app solo lee la carpeta que tú elijas.

> **Estado: el juego todavía no se ejecuta.** El launcher ya valida la carpeta del juego y lista sus zonas (con tamaños y grupos), pero el motor está pendiente (fase 6 de `reglas.md`). Hoy la app sirve para comprobar que tu copia está completa y en el sitio correcto, no para jugar.
>
> **No ha sido probada todavía en un iPhone.** Se compila en GitHub Actions; la primera prueba real en dispositivo está en [pruebas-iphone.md](pruebas-iphone.md).

## Requisitos

- Un iPhone con **iOS 15 o posterior**.
- Una copia **legítima** de Call of Duty: Black Ops 1 (la de Steam, PC). La app no descarga ni incluye archivos del juego, y no admite la versión de consola.
- Unos **3 GB libres** en el iPhone para la carpeta del juego (la carpeta `zone` son ~2,6 GiB).
- Un ordenador para instalar la IPA, con **SideStore** o cualquier método para instalar aplicaciones sin firmar.

## Cómo conseguir e instalar la IPA

1. En GitHub, abre la pestaña **Actions** del repositorio y entra en un run en verde de *iOS IPA (sin firmar)*.
2. Descarga el artefacto **`BLOPSPocket-unsigned`** y descomprímelo: contiene `BLOPSPocket.ipa`.
3. Instala esa IPA con **SideStore** (la firma con tu Apple ID la hace SideStore, no el CI).

El identificador de la app es `com.adriantomasdiez.blopspocket`.

### Si SideStore da error al instalar

Con una cuenta Apple **gratuita** solo puedes tener **3 apps instaladas a la vez en el iPhone**, y la propia herramienta (SideStore o AltStore) ocupa uno de esos tres huecos. El error lo dice con estas palabras:

> This device has reached the maximum number of installed apps using a free developer profile

El mensaje suele listar las apps que ocupan los huecos. Para liberar uno:

1. Desinstala en el iPhone una de esas apps (en AltStore, **Deactivate** libera el hueco guardando antes los datos).
2. Vuelve a intentar la instalación.

El límite es **por dispositivo**, así que usar otra cuenta de Apple no lo evita, y esperar a que caduque la firma de 7 días no libera el hueco por sí solo. Si necesitas convivir con más apps, las salidas son un Apple Developer Program de pago (99 $/año) o la instalación en otro dispositivo. Ojo también con el otro límite de la cuenta gratuita: 10 identificadores distintos por semana.

## Cómo copiar el juego al iPhone

1. En el PC, localiza la carpeta del juego:
   `...\steamapps\common\Call of Duty Black Ops`. Debe contener una subcarpeta **`zone`**.
   No hace falta copiar toda la instalación: con `zone/` basta (unos 2,6 GiB de archivos; el iPhone lo mostrará como ~2,8 GB).
2. Abre la app **una vez** en el iPhone. Eso crea su carpeta visible en Archivos.
3. Copia la carpeta del juego desde el PC al iPhone, dentro de:
   **Archivos → En mi iPhone → BLOPS pocket → Games**
   (en el PC, la app aparece en el explorador al conectar el iPhone por cable).
4. Vuelve a abrir la app. Debe mostrar "N zonas encontradas · X GB" y de qué carpeta las está leyendo.

### Alternativa: leer una carpeta externa

Si prefieres no duplicar los archivos, el botón **Elegir otra carpeta del juego** deja seleccionar una carpeta de Archivos y la app recuerda el permiso entre aperturas. Con una carpeta en **iCloud Drive** esto es menos fiable: iOS puede liberar espacio y dejar los archivos sin descargar, y el permiso se pierde al reinstalar la app. Para jugar, la copia dentro de la app es la vía recomendada.

### Avisos importantes

- **Desinstalar la app borra la copia del juego.** iOS elimina el contenedor de la app, incluidos los archivos de `Games/`. Si la borras, tendrás que volver a copiarla.
- **Nunca subas archivos del juego al repositorio.** El `.gitignore` ya bloquea `zone/`, `Games/` y los `.ff`.
- La app no registra rutas de tu dispositivo en ningún sitio; el permiso de la carpeta se guarda solo en el teléfono.

## Qué hace hoy y qué no

| Hace | No hace (todavía) |
|---|---|
| Validar que la carpeta contiene `zone/` | Ejecutar el juego |
| Listar las zonas `.ff` con su tamaño, agrupadas (Zombies, Multijugador, Campaña…) | Leer el contenido de esas zonas |
| Avisar si una zona no es de la versión esperada (`0x1D9`) | Renderizar, reproducir audio o aceptar entrada |
| Recordar la carpeta entre aperturas | Multijugador ni campaña (el objetivo es Zombies) |

Solo se leen **12 bytes de cabecera** por archivo: abrir la app no descomprime nada ni consume memoria del juego.

## Limitaciones conocidas

- Sin probar en un iPhone; la compilación se ha verificado solo en el CI.
- Solo se han medido archivos de la versión de **PC (Steam)**.
- Las zonas traducidas (`Spanish/sp_*.ff`) se listan, pero aún no se sabe cómo elige el juego entre ellas.
- El consumo de memoria real (lo que más ha hecho fallar a proyectos parecidos en iOS) solo se podrá medir cuando exista el motor.

## Pruebas

La lista de comprobaciones manuales en dispositivo, con lo que se espera de cada una, está en [pruebas-iphone.md](pruebas-iphone.md).

## Legal

- Este proyecto **no distribuye** archivos, recursos ni datos de Call of Duty: Black Ops 1, y no incluye logotipos ni marcas de Activision o Treyarch. Necesitas una copia legítima de la que seas titular.
- Código propio bajo **GNU GPL v3.0** (ver [LICENSE](LICENSE)); atribuciones y referencias consultadas en [NOTICE](NOTICE). De ninguna referencia se ha copiado código.
- Antes de publicar la app en cualquier tienda o hacer distribución pública hace falta una revisión legal (regla 2.5 de `reglas.md`).

## Documentación del proyecto

- [reglas.md](reglas.md) — objetivo, restricciones legales, decisiones y estado por fases.
- [prompts.md](prompts.md) — el plan de trabajo, una fase por prompt.
- [pruebas-iphone.md](pruebas-iphone.md) — comprobaciones manuales en el iPhone.
- [tools/](tools) — sondas de verificación del formato de las zonas (`node --test tools/zonescan.test.mjs`).
