#!/usr/bin/env node
// Sonda de SOLO LECTURA para los RAWFILE de un FastFile (.ff) de BO1 PC (T5).
// Lee el stream inflado, localiza los registros de RAWFILE y valida cada uno:
// los comprimidos descomprimiendo su buffer con zlib, y comprobando en ambos
// casos que el tamaño coincide. No extrae ni escribe datos del juego.
//
// Estructura de un RAWFILE (verificada sobre `common_zombie.ff`):
//
//   u32  marca de puntero (0xFFFFFFFF, el dato va a continuación)
//   u32  tamaño del bloque de datos
//   u32  marca de puntero del nombre (0xFFFFFFFF)
//   ...  nombre ASCII terminado en NUL
//   ...  bloque de datos, de `tamaño` bytes:
//          - comprimido:   u32 len (descomprimido) + u32 clen + clen bytes zlib
//                          (por eso el tamaño del bloque es 8 + clen)
//          - sin comprimir: los propios bytes del buffer (tamaño = len)
//   ...  1 byte de separación antes del siguiente registro (0x00 en los no
//        comprimidos; su significado no está confirmado, ver reglas.md)
//
// Uso:
//   node tools/zrawfile.mjs <archivo.ff> [--json] [--dump <nombre>]
//
// Códigos de salida: 0 = leído; 1 = error de formato o de lectura; 2 = uso incorrecto.

import { readFile } from "node:fs/promises";
import { inflateSync } from "node:zlib";
import { basename, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { parseAssetList } from "./zoneassets.mjs";

const MAGIC = "IWffu100";
const HEADER_LEN = 12;
const T5_PC_VERSION = 0x1d9; // 473, identificador de zona de BO1 en PC
const FOLLOWING = 0xffffffff; // marca de puntero "el dato va a continuación"
const BLOB_HEADER_LEN = 8; // marca de puntero + tamaño del bloque
const MAX_NAME_LEN = 200;
const MAX_PAYLOAD = 64 * 1024 * 1024;

/**
 * Descodifica el RAWFILE que empieza en `p`, si lo hay (comprimido o no).
 * Valida el registro por su firma; en los comprimidos, además, descomprime.
 * Devuelve metadatos o null si no es un registro.
 *
 * @param {Buffer} d stream inflado (sin la cabecera de 12 bytes)
 * @param {number} p desplazamiento de la marca de puntero del registro
 */
export function decodeRawFile(d, p) {
    if (p < 0 || p + BLOB_HEADER_LEN + 4 > d.length) return null;
    if (d.readUInt32LE(p) !== FOLLOWING) return null;

    const size = d.readUInt32LE(p + BLOB_HEADER_LEN - 4);
    if (size > MAX_PAYLOAD) return null;
    if (d.readUInt32LE(p + BLOB_HEADER_LEN) !== FOLLOWING) return null;

    const nameStart = p + BLOB_HEADER_LEN + 4;
    const nul = d.indexOf(0, nameStart);
    if (nul === -1) return null;
    const nameLen = nul - nameStart;
    if (nameLen < 1 || nameLen > MAX_NAME_LEN) return null;
    const name = d.toString("latin1", nameStart, nul);
    if (!/^[\x20-\x7e]+$/.test(name)) return null;

    const payloadStart = nul + 1;
    const payloadEnd = payloadStart + size;
    if (payloadEnd > d.length) return null;

    // Caso comprimido: el bloque empieza por `len` y `clen`, y sigue un zlib.
    if (size >= BLOB_HEADER_LEN) {
        const len = d.readUInt32LE(payloadStart);
        const clen = d.readUInt32LE(payloadStart + 4);
        if (clen > 0 && clen === size - BLOB_HEADER_LEN && payloadStart + BLOB_HEADER_LEN + clen <= d.length) {
            try {
                const content = inflateSync(d.subarray(payloadStart + BLOB_HEADER_LEN, payloadStart + BLOB_HEADER_LEN + clen));
                if (content.length === len) {
                    return { offset: p, name, kind: "compressed", len, clen, payloadStart, end: payloadEnd };
                }
            } catch {
                // no es un bloque comprimido válido; se prueba como no comprimido
            }
        }
    }

    // Caso sin comprimir: el bloque son los propios bytes. Se exige el separador
    // y, o bien la marca del registro siguiente, o bien el final del stream (el
    // último asset de la zona no tiene registro detrás).
    const closedByNext = payloadEnd + 1 < d.length && d.readUInt32LE(payloadEnd + 1) === FOLLOWING;
    const closedByEnd = payloadEnd + 1 === d.length;
    if (payloadEnd < d.length && d[payloadEnd] === 0x00 && (closedByNext || closedByEnd)) {
        return { offset: p, name, kind: "uncompressed", len: size, clen: 0, payloadStart, end: payloadEnd };
    }

    return null;
}

/** Devuelve el contenido del buffer de un registro ya descodificado. */
export function readRawFileContent(d, record) {
    if (record.kind === "compressed") {
        return inflateSync(d.subarray(record.payloadStart + BLOB_HEADER_LEN, record.end));
    }
    return d.subarray(record.payloadStart, record.end);
}

/**
 * Localiza todos los RAWFILE del stream inflado, comprimidos o no.
 * @param {Buffer} d stream inflado (sin la cabecera de 12 bytes)
 * @param {number} from desplazamiento desde el que empezar a buscar
 */
export function findRawFiles(d, from = 0) {
    const found = [];
    for (let p = Math.max(0, from); p <= d.length - BLOB_HEADER_LEN - 4; p++) {
        if (d.readUInt32LE(p) !== FOLLOWING) continue;
        const record = decodeRawFile(d, p);
        if (record) found.push(record);
    }
    return found;
}

/** Lee el archivo .ff, valida su cabecera e infla el stream. */
export async function readZoneStream(file) {
    const raw = await readFile(file);
    if (raw.length < HEADER_LEN) throw new Error("archivo demasiado corto");

    const magic = raw.toString("latin1", 0, 8);
    if (magic !== MAGIC) throw new Error(`cabecera ${JSON.stringify(magic)} no es ${MAGIC}`);

    const version = raw.readUInt32LE(8);
    if (version !== T5_PC_VERSION) {
        throw new Error(`versión 0x${version.toString(16)} no es la de T5 PC (0x${T5_PC_VERSION.toString(16)})`);
    }

    return inflateSync(raw.subarray(HEADER_LEN));
}

async function main(argv) {
    const args = argv.slice(2);
    const json = args.includes("--json");
    const dumpIndex = args.indexOf("--dump");
    const dumpName = dumpIndex === -1 ? undefined : args[dumpIndex + 1];
    const file = args.find((arg, i) => !arg.startsWith("--") && !(dumpIndex >= 0 && i === dumpIndex + 1));
    if (!file) {
        console.error("Uso: node tools/zrawfile.mjs <archivo.ff> [--json] [--dump <nombre>]");
        return 2;
    }

    const stream = await readZoneStream(file);
    // Los cuerpos empiezan tras la lista de assets; así se evita confundir con
    // ella algún bloque con la misma firma (ver reglas.md).
    const { bodyOffset } = parseAssetList(stream);
    const records = findRawFiles(stream, bodyOffset);

    if (dumpName) {
        const record = records.find((r) => r.name === dumpName);
        if (!record) {
            console.error(`No hay RAWFILE llamado ${JSON.stringify(dumpName)}`);
            return 1;
        }
        process.stdout.write(readRawFileContent(stream, record));
        return 0;
    }

    const compressed = records.filter((r) => r.kind === "compressed");
    const raw = records.filter((r) => r.kind === "uncompressed");
    const sum = (list) => list.reduce((total, r) => total + r.len, 0);

    if (json) {
        console.log(JSON.stringify({
            file: basename(file),
            count: records.length,
            compressed: { count: compressed.length, bytes: sum(compressed) },
            uncompressed: { count: raw.length, bytes: sum(raw) },
            records,
        }, null, 2));
        return 0;
    }

    console.log(`${basename(file)}: ${records.length} RAWFILE `
        + `(${compressed.length} comprimidos, ${sum(compressed)} bytes descomprimidos; `
        + `${raw.length} sin comprimir, ${sum(raw)} bytes)`);
    for (const r of records) {
        console.log(`  ${r.kind === "compressed" ? "z " : "  "}${String(r.len).padStart(9)}  ${r.name}`);
    }
    return 0;
}

// Solo se ejecuta como script, no al importar desde tests.
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    main(process.argv)
        .then((code) => { process.exitCode = code; })
        .catch((error) => {
            console.error(`Error: ${error.message}`);
            process.exitCode = 1;
        });
}
