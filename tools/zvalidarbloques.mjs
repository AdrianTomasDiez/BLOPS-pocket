#!/usr/bin/env node
// Valida el recorrido de los assets de un FastFile por bloques de 100, contra
// los RAWFILE encontrados por firma (findRawFiles). Cada RAWFILE del recorrido
// debe caer en el offset de una ancla y medir exactamente lo que mide la ancla.
//
// El progreso se guarda bloque a bloque en un JSON (escritura atómica). Si el
// proceso se interrumpe, al volver a lanzarlo salta los bloques ya validados.
//
// Uso:
//   node tools/zvalidarbloques.mjs <src> <archivo.ff> [progreso.json]
//
// Por defecto el progreso va a <home>/zvalidar-progreso.json.
// Códigos de salida: 0 = todo validado; 1 = hay discrepancias o un bloque
// bloqueado; 2 = uso incorrecto.

import { readFileSync, writeFileSync, renameSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { T5_ASSET_TYPE_NAMES } from "./zoneassets.mjs";
import { findRawFiles } from "./zrawfile.mjs";
import { Modelo, Medidor, cargarStream, caminar } from "./zassetsize.mjs";

const BLOQUE = 100;
const SEP = 0; // separación fijada por el criterio de cierre de 6b.1
// Byte separador que el recorrido mide tras cada RAWFILE (ver zstreamwalk.mjs);
// la ancla no lo incluye en su tamaño.
const SEP_RAWFILE = 1;
const RAWFILE = T5_ASSET_TYPE_NAMES.indexOf("RAWFILE");

function leerProgreso(ruta, cabecera) {
    if (!existsSync(ruta)) return { ...cabecera, bloques: {} };
    const previo = JSON.parse(readFileSync(ruta, "utf8"));
    // Solo se reutiliza si es del mismo fichero y configuración.
    if (previo.archivo !== cabecera.archivo || previo.sep !== cabecera.sep || previo.total !== cabecera.total) {
        return { ...cabecera, bloques: {} };
    }
    return previo;
}

function guardarProgreso(ruta, progreso) {
    const tmp = `${ruta}.tmp`;
    writeFileSync(tmp, JSON.stringify(progreso, null, 1));
    renameSync(tmp, ruta);
}

function validarBloque(a, b, recorrido, anclas, total) {
    const ultimoOk = recorrido.ok ? total - 1 : recorrido.hasta - 1;
    const limite = Math.min(b, ultimoOk);
    const siguiente = recorrido.offsets[limite + 1] ?? (recorrido.ok ? recorrido.fin : null);
    const inicio = recorrido.offsets[a];

    const porOffset = new Map(anclas.map((x) => [x.offset, x]));
    const emparejadas = new Set();
    const discrepancias = [];
    let medidos = 0;
    let raw = 0;

    for (let i = a; i <= limite; i++) {
        medidos++;
        if (recorrido.datosTipos[i] !== RAWFILE) continue;
        raw++;
        const offset = recorrido.offsets[i];
        const ancla = porOffset.get(offset);
        const total_ = recorrido.resultados[i].total;
        if (!ancla) {
            discrepancias.push({ indice: i, offset, motivo: "RAWFILE sin ancla en ese offset" });
        } else if (total_ !== ancla.end - ancla.offset + SEP_RAWFILE) {
            discrepancias.push({ indice: i, offset, motivo: `mide ${total_}, ancla ${ancla.end - ancla.offset + SEP_RAWFILE} (${ancla.name})` });
        } else {
            emparejadas.add(offset);
        }
    }

    // Anclas dentro del rango recorrido por este bloque sin RAWFILE que las cubra.
    const sinAsset = [];
    if (inicio !== undefined && siguiente !== null) {
        for (const x of anclas) {
            if (x.offset >= inicio && x.offset < siguiente && !emparejadas.has(x.offset)) {
                sinAsset.push({ offset: x.offset, name: x.name });
            }
        }
    }

    const res = {
        a,
        b,
        medidos,
        raw,
        emparejadas: emparejadas.size,
        anclasEnRango: emparejadas.size + sinAsset.length,
        discrepancias,
        anclasSinAsset: sinAsset,
    };
    if (!recorrido.ok && recorrido.hasta <= b) {
        res.bloqueadoEn = {
            indice: recorrido.hasta,
            tipo: T5_ASSET_TYPE_NAMES[recorrido.tipos?.[recorrido.hasta] ?? -1] ?? "?",
            motivo: recorrido.motivo,
        };
    }
    return res;
}

function main(argv) {
    const [src, archivo, rutaProgreso] = argv.slice(2);
    if (!src || !archivo) {
        console.error("Uso: node tools/zvalidarbloques.mjs <src> <archivo.ff> [progreso.json]");
        return 2;
    }
    const ruta = rutaProgreso ?? join(homedir(), "zvalidar-progreso.json");

    const datos = cargarStream(archivo);
    const total = datos.tipos.length;
    const modelo = new Modelo(src);
    const medidor = new Medidor(datos.stream, SEP);
    const anclas = findRawFiles(datos.stream, datos.bodyOffset);
    console.log(`assets=${total} anclas RAWFILE=${anclas.length} progreso=${ruta}`);

    const progreso = leerProgreso(ruta, { archivo, sep: SEP, total, anclas: anclas.length, bloques: {} });
    const recorrido = caminar(modelo, medidor, datos, 0, total - 1);
    recorrido.datosTipos = datos.tipos;
    recorrido.tipos = datos.tipos;

    let hayFallos = false;
    for (let a = 0; a < total; a += BLOQUE) {
        const b = Math.min(a + BLOQUE, total) - 1;
        const clave = `${a}-${b}`;
        let res = progreso.bloques[clave];
        if (res) {
            console.log(`bloque ${clave}: (ya validado)`);
        } else {
            res = validarBloque(a, b, recorrido, anclas, total);
            progreso.bloques[clave] = res;
            guardarProgreso(ruta, progreso);
            const estado = res.discrepancias.length || res.anclasSinAsset.length || res.bloqueadoEn ? "FALLO" : "OK";
            console.log(
                `bloque ${clave}: ${estado} medidos=${res.medidos} raw=${res.raw} ancla-emparejadas=${res.emparejadas} sin-asset=${res.anclasSinAsset.length} discrepancias=${res.discrepancias.length}` +
                (res.bloqueadoEn ? ` bloqueado en ${res.bloqueadoEn.indice} (${res.bloqueadoEn.tipo}): ${res.bloqueadoEn.motivo}` : ""),
            );
        }
        if (res.discrepancias.length || res.anclasSinAsset.length || res.bloqueadoEn) hayFallos = true;
        if (res.bloqueadoEn) break; // sin recorrido no hay posiciones que comparar más allá
    }

    const emparejadasTotal = Object.values(progreso.bloques).reduce((s, r) => s + r.emparejadas, 0);
    const ultimo = Object.values(progreso.bloques).at(-1);
    const hasta = ultimo ? ultimo.b : -1;
    console.log(`resumen: anclas emparejadas ${emparejadasTotal}/${anclas.length}; assets validados hasta el índice ${hasta} de ${total - 1}`);
    if (!recorrido.ok) console.log(`recorrido parado en ${recorrido.hasta} (${T5_ASSET_TYPE_NAMES[datos.tipos[recorrido.hasta]]}): ${recorrido.motivo}`);
    return hayFallos || emparejadasTotal !== anclas.length ? 1 : 0;
}

if (process.argv[1] && process.argv[1].endsWith("zvalidarbloques.mjs")) {
    process.exitCode = main(process.argv);
}
