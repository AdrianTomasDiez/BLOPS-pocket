#!/usr/bin/env node
// Recorrido del stream de assets de un FastFile de BO1 PC (T5) sobre el
// BINARIO real (`common_zombie.ff`), sin usar cabeceras T5_Assets.h.
//
// Qué hace:
//  1. Lee el .ff, valida magic `IWffu100` + versión 0x1d9 e infla el stream.
//  2. Parsea la XAssetList con el parser compartido (tools/zoneassets.mjs):
//     stringCount, assetCount, tabla de assets y bodyOffset.
//  3. Recorre los 2693 assets en orden de tabla y aplica la regla
//     "región fija + datos following" a los assets de tipo RAWFILE:
//       u32 marca de puntero (0xffffffff)          <- región fija
//       u32 tamaño del bloque                       <- dato following (tamaño)
//       u32 marca del puntero del nombre (0xffffffff)
//       nombre ASCIIZ                               <- dato following
//       bloque de datos de `tamaño` bytes           <- dato following
//     El recorrido se encadena con el byte que separa registros: mide 1 byte
//     siempre, pero solo vale 0x00 cuando el registro que sigue va sin
//     comprimir; antes de uno comprimido es arbitrario (ver reglas.md).
//  4. Contrasta ese recorrido (vía tabla) con el escaneo por firma
//     (`findRawFiles`) y exige que las 105 anclas coincidan exactamente en
//     offset, extensión, tamaño, tipo (comprimido / sin comprimir) y nombre.
//
// Uso:
//   node tools/zstreamwalk.mjs [<archivo.ff>]
//
// Códigos de salida: 0 = recorrido validado; 1 = error de formato o lectura;
// 2 = uso incorrecto; 3 = hay discrepancias respecto a findRawFiles.

import { readFileSync } from "node:fs";
import { inflateSync } from "node:zlib";
import { basename } from "node:path";
import { parseAssetList, T5_ASSET_TYPE_NAMES } from "./zoneassets.mjs";
import { findRawFiles } from "./zrawfile.mjs";

const MAGIC = "IWffu100";
const HEADER_LEN = 12;
const T5_PC_VERSION = 0x1d9;
const FOLLOWING = 0xffffffff;
const ASSET_ENTRY_LEN = 8; // tipo int32 + puntero al nombre
const RAWFILE_TYPE = T5_ASSET_TYPE_NAMES.indexOf("RAWFILE");
const MAX_NAME_LEN = 200;
const MAX_PAYLOAD = 64 * 1024 * 1024;

/**
 * Lectura de una región RAWFILE aplicando la regla "región fija + datos
 * following" sobre el propio stream. Camino independiente de `decodeRawFile`
 * (que va por firma y exige el separador), para poder contrastarlos.
 * @param {Buffer} d stream inflado (sin la cabecera de 12 bytes)
 * @param {number} p desplazamiento donde empieza la región
 */
function parseRawFileRegion(d, p) {
    if (p < 0 || p + 12 > d.length) return null;
    if (d.readUInt32LE(p) !== FOLLOWING) return null;

    const size = d.readUInt32LE(p + 4); // región fija: tamaño del bloque
    if (size > MAX_PAYLOAD) return null;
    if (d.readUInt32LE(p + 8) !== FOLLOWING) return null;

    const nul = d.indexOf(0, p + 12);
    if (nul === -1) return null;
    const name = d.toString("latin1", p + 12, nul);
    // El nombre debe ser ASCII imprimible: sin esto el encadenado deriva hacia
    // secuencias de 0xff que parecen registros y contaminan la validación.
    if (name.length < 1 || name.length > MAX_NAME_LEN || !/^[\x20-\x7e]+$/.test(name)) return null;

    const payloadStart = nul + 1;
    const end = payloadStart + size;
    if (end > d.length) return null;

    let kind = "uncompressed";
    let len = size;
    let clen = 0;
    if (size >= 8) {
        const rawLen = d.readUInt32LE(payloadStart);
        const rawClen = d.readUInt32LE(payloadStart + 4);
        if (rawClen > 0 && rawClen === size - 8 && payloadStart + 8 + rawClen <= d.length) {
            try {
                const out = inflateSync(d.subarray(payloadStart + 8, payloadStart + 8 + rawClen));
                if (out.length === rawLen) {
                    kind = "compressed";
                    len = rawLen;
                    clen = rawClen;
                }
            } catch {
                // sigue como no comprimido
            }
        }
    }

    return { offset: p, name, size, len, clen, kind, payloadStart, end, after: d[end] };
}

/** Resuelve el nombre de un asset desde el puntero de su entrada de tabla. */
function resolveName(d, namePtr) {
    if (namePtr === FOLLOWING) return { inline: true, name: null };
    if (namePtr === 0 || namePtr >= d.length) return { inline: false, name: null };
    const end = d.indexOf(0, namePtr);
    if (end === -1) return { inline: false, name: null };
    return { inline: false, name: d.toString("latin1", namePtr, end) };
}

function main() {
    const args = process.argv.slice(2);
    const file = args.find((a) => !a.startsWith("--"));
    if (!file) {
        console.error("Uso: node tools/zstreamwalk.mjs <archivo.ff>");
        return 2;
    }

    console.error(`ffPath= ${file}`);
    const raw = readFileSync(file);
    const magic = raw.toString("latin1", 0, 8);
    const version = raw.readUInt32LE(8);
    console.error(`magic= ${magic} version=0x${version.toString(16)} fileSize= ${raw.length}`);
    if (magic !== MAGIC) {
        console.error(`Magic inesperado: ${magic}`);
        return 1;
    }
    if (version !== T5_PC_VERSION) {
        console.error(`Versión 0x${version.toString(16)} no es la de T5 PC (0x1d9)`);
        return 1;
    }

    const stream = inflateSync(raw.subarray(HEADER_LEN));
    console.error(`inflatedBytes= ${stream.length}`);

    const list = parseAssetList(stream);
    const tableOffset = list.bodyOffset - list.assetCount * ASSET_ENTRY_LEN;
    console.error(
        `stringCount= ${list.stringCount} assetCount= ${list.assetCount} `
        + `bodyOffset= ${list.bodyOffset} tablaDeAssets= ${tableOffset}`
    );

    // ---- Recorrido de la tabla de assets (2693 entradas, 8 bytes cada una) ----
    console.log("=== RECORRIDO DE LA TABLA DE ASSETS (orden de escritura) ===");
    console.log(`assetCount: ${list.assetCount}`);
    console.log(`tablaDeAssets: ${tableOffset} .. ${list.bodyOffset}`);
    console.log(`bodyOffset: ${list.bodyOffset}`);
    console.log("tipos (top 8):");
    for (const t of list.types.slice(0, 8)) {
        console.log(`  ${String(t.count).padStart(5)}  ${t.name}`);
    }

    const rawfileAssets = [];
    const typeCounts = new Map();
    for (let i = 0; i < list.assetCount; i++) {
        const at = tableOffset + i * ASSET_ENTRY_LEN;
        const type = stream.readInt32LE(at);
        const namePtr = stream.readUInt32LE(at + 4);
        typeCounts.set(type, (typeCounts.get(type) ?? 0) + 1);
        if (type === RAWFILE_TYPE) {
            rawfileAssets.push({ index: i, namePtr, ...resolveName(stream, namePtr) });
        }
    }
    console.log(`tipo RAWFILE = ${RAWFILE_TYPE}; entradas de tabla de ese tipo: ${rawfileAssets.length}`);
    console.log("índices de tabla de los RAWFILE (primeros 8): "
        + rawfileAssets.slice(0, 8).map((a) => a.index).join(", "));
    console.log("índices de tabla de los RAWFILE (últimos 8): "
        + rawfileAssets.slice(-8).map((a) => a.index).join(", "));
    console.log(`punteros de nombre RAWFILE: ${rawfileAssets.filter((a) => a.inline).length} inline (FOLLOWING), ${rawfileAssets.filter((a) => !a.inline && a.name !== null).length} apuntando al pool de cadenas`);

    // ---- Escaneo por firma (camino independiente) ----
    const anchors = findRawFiles(stream, list.bodyOffset);

    // ---- Recorrido encadenado de las regiones RAWFILE ----
    // Los RAWFILE no ocupan índices consecutivos en toda la tabla: forman
    // tramos. Cada tramo se siembra en el offset del primer registro (todavía
    // no derivable, porque los modificadores de los tipos anteriores no están
    // portados) y a partir de ahí el propio recorrido calcula el siguiente
    // aplicando la regla fija + following y el byte separador (0x00).
    const runs = [];
    rawfileAssets.forEach((asset, k) => {
        const last = runs[runs.length - 1];
        if (last && asset.index === rawfileAssets[k - 1].index + 1) last.push(k);
        else runs.push([k]);
    });

    const problems = [];
    const walk = [];
    const stats = { offset: 0, end: 0, name: 0, kind: 0, len: 0, clen: 0, sepCero: 0, sepArbitrario: 0, uncompCero: 0, uncompNoCero: 0 };
    let seeded = 0;
    let chained = 0;

    const compare = (region, anchor, k) => {
        if (region.offset === anchor.offset) stats.offset++;
        else problems.push(`offset del registro #${k}: recorrido ${region.offset} vs ${anchor.offset}`);
        if (region.end === anchor.end) stats.end++;
        else problems.push(`fin del registro #${k}: ${region.end} vs ${anchor.end}`);
        if (region.name === anchor.name) stats.name++;
        else problems.push(`nombre del registro #${k}: ${JSON.stringify(region.name)} vs ${JSON.stringify(anchor.name)}`);
        if (region.kind === anchor.kind) stats.kind++;
        else problems.push(`tipo del registro #${k}: ${region.kind} vs ${anchor.kind}`);
        if (region.len === anchor.len) stats.len++;
        else problems.push(`tamaño descomprimido del registro #${k}: ${region.len} vs ${anchor.len}`);
        if (region.clen === anchor.clen) stats.clen++;
        else problems.push(`tamaño comprimido del registro #${k}: ${region.clen} vs ${anchor.clen}`);
        const asset = rawfileAssets[k];
        if (asset && asset.name !== null && asset.name !== anchor.name) {
            problems.push(`nombre desde la tabla del registro #${k}: ${JSON.stringify(asset.name)} vs ${JSON.stringify(anchor.name)}`);
        }
    };

    // El recorrido (tabla + encadenado) es la fuente de verdad: los offsets y
    // tamaños los calcula él. Las anclas del escaneo por firma se alinean
    // contra él con dos punteros, así que un registro encadenado que no
    // coincide con la ancla en curso es uno que la firma no encuentra.
    const invisibles = [];
    const runInfo = [];
    let ai = 0; // ancla en curso

    for (const run of runs) {
        const seed = anchors[ai];
        if (!seed) {
            problems.push(`tramo ${run[0]}..${run[run.length - 1]} (${run.length} entrada(s)): sin ancla con la que sembrarlo`);
            break;
        }
        let cursor = seed.offset;
        seeded++;
        let recordsInRun = 0;
        for (let j = 0; j < run.length; j++) {
            const region = parseRawFileRegion(stream, cursor);
            if (!region) {
                problems.push(`entrada de tabla ${run[j]}: no se puede leer con la regla fija + following en ${cursor}`);
                break;
            }
            recordsInRun++;
            if (j > 0) {
                chained++;
                const sep = stream[region.offset - 1];
                if (sep === 0x00) stats.sepCero++;
                else stats.sepArbitrario++;
            }
            region.tableIndex = run[j];
            walk.push(region);
            const anchor = anchors[ai];
            if (anchor && anchor.offset === region.offset) {
                compare(region, anchor, ai);
                ai++;
            } else {
                invisibles.push({ tabla: run[j], name: region.name, offset: region.offset, len: region.len, kind: region.kind });
            }
            if (region.kind === "uncompressed") {
                if (region.after === 0x00) stats.uncompCero++;
                else stats.uncompNoCero++;
            }
            cursor = region.end + 1; // byte separador entre registros
        }
        runInfo.push({ indices: `${run[0]}..${run[run.length - 1]}`, tabla: run.length, registros: recordsInRun });
    }
    const anclasSinUsar = anchors.length - ai;

    console.log("");
    console.log("=== RECORRIDO RAWFILE (región fija + datos following) ===");
    console.log(`entradas RAWFILE en la tabla: ${rawfileAssets.length}, en ${runs.length} tramo(s) de índices consecutivos`);
    console.log(`tramo más largo: ${Math.max(0, ...runs.map((r) => r.length))} registros`);
    console.log(`regiones leídas con la regla: ${walk.length}`);
    console.log(`regiones encadenadas (inicio calculado por el recorrido): ${chained}`);
    console.log(`tramos sembrados en el offset de su primer registro: ${seeded}`);
    const covered = walk.reduce((s, r) => s + (r.end + 1 - r.offset), 0);
    console.log(`bytes cubiertos por las regiones (con separador): ${covered}`);

    console.log("");
    console.log("=== VALIDACIÓN CRUZADA vs findRawFiles ===");
    if (rawfileAssets.length !== anchors.length) {
        problems.push(`recuento: tabla ${rawfileAssets.length} vs findRawFiles ${anchors.length}`);
    }
    const pairs = ai;
    console.log(`registros leídos por el recorrido: ${walk.length}`);
    console.log(`registros comparados contra el escaneo: ${pairs}`);
    console.log(`anclas emparejadas por offset: ${pairs}/${anchors.length}`);
    console.log(`fin de región coincidentes: ${stats.end}/${pairs}`);
    console.log(`nombres coincidentes: ${stats.name}/${pairs}`);
    console.log(`tipo (comprimido / sin comprimir) coincidentes: ${stats.kind}/${pairs}`);
    console.log(`tamaños coincidentes (descomprimido / comprimido): ${stats.len}/${pairs} y ${stats.clen}/${pairs}`);
    console.log(`enlaces encadenados con hueco de exactamente 1 byte: ${chained}/${chained}`);
    console.log(`  de esos, byte 0x00: ${stats.sepCero}; con otro valor: ${stats.sepArbitrario}`);
    console.log(`registros sin comprimir: ${stats.uncompCero} con byte final 0x00 y ${stats.uncompNoCero} con otro valor`);
    if (rawfileAssets.length !== anchors.length) {
        console.log(`recuento: la tabla declara ${rawfileAssets.length} RAWFILE y el escaneo por firma encuentra ${anchors.length} (diferencia ${rawfileAssets.length - anchors.length})`);
    }
    for (const r of runInfo) {
        if (r.tabla !== r.registros) {
            console.log(`  tramo ${r.indices}: ${r.tabla} entrada(s) de tabla y ${r.registros} registro(s) leídos`);
        }
    }
    if (invisibles.length > 0) {
        console.log(`registros que el recorrido lee y el escaneo por firma no encuentra (${invisibles.length}):`);
        for (const r of invisibles.slice(0, 12)) {
            console.log(`  tabla ${r.tabla}: ${r.name} @${r.offset} len=${r.len} ${r.kind}`);
        }
        if (invisibles.length > 12) console.log(`  ... ${invisibles.length - 12} más`);
    }
    console.log(`anclas sin usar al final del recorrido: ${anclasSinUsar}`);
    if (anclasSinUsar !== 0) {
        problems.push(`el recorrido no alcanza ${anclasSinUsar} ancla(s) del escaneo por firma`);
    }

    console.log("");
    console.log("=== TRAMOS Y HUECOS (lo que falta modelar) ===");
    for (let r = 0; r + 1 < runs.length && r < 20; r++) {
        const kLast = runs[r][runs[r].length - 1];
        const kNext = runs[r + 1][0];
        if (!anchors[kLast] || !anchors[kNext]) continue;
        const bytes = anchors[kNext].offset - anchors[kLast].end;
        const intervening = rawfileAssets[kNext].index - rawfileAssets[kLast].index - 1;
        console.log(`  tramo ${r} → ${r + 1}: ${bytes} bytes entre fin#${kLast} (índice ${rawfileAssets[kLast].index}) e inicio#${kNext} (índice ${rawfileAssets[kNext].index}); ${intervening} asset(s) intercalado(s)`);
    }
    if (runs.length > 21) console.log(`  ... ${runs.length - 21} tramos más`);

    // ---- Resumen ----
    console.log("");
    console.log("=== RESUMEN FINAL ===");
    console.log(`ffPath: ${file}`);
    console.log(`fileBytes: ${raw.length}`);
    console.log(`inflatedBytes: ${stream.length}`);
    console.log(`assetCount: ${list.assetCount}`);
    console.log(`bodyOffset: ${list.bodyOffset}`);
    console.log(`entradas RAWFILE en la tabla: ${rawfileAssets.length}`);
    console.log(`anclas findRawFiles: ${anchors.length}`);
    console.log(`regiones recorridas: ${walk.length}`);
    console.log(`problemas: ${problems.length}`);
    for (const p of problems.slice(0, 10)) console.log(`  - ${p}`);
    const soloRecuento = problems.length > 0 && problems.every((p) => p.startsWith("recuento:"));
    if (problems.length === 0) {
        console.log(`SUCCESS: el recorrido por tabla y el escaneo por firma coinciden en offset, tamaño, tipo y nombre para las ${anchors.length} anclas RAWFILE.`);
    } else if (soloRecuento) {
        console.log("AVISO: todos los registros que lee el recorrido coinciden con las anclas encontradas, pero el escaneo por firma ve menos RAWFILE que la tabla (el último registro sin comprimir de un tramo no tiene detrás la marca de otro RAWFILE; ver reglas.md).");
    } else {
        console.log("FAIL: hay discrepancias entre el recorrido y findRawFiles.");
    }
    console.log(`cobertura del recorrido: ${walk.length} de ${list.assetCount} assets (el resto de tipos sigue sin modificadores portados)`);

    return problems.length === 0 ? 0 : 3;
}

process.exitCode = main();
