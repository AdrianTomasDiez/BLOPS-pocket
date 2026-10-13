#!/usr/bin/env node
// Sonda de SOLO LECTURA para FastFiles (.ff) de Call of Duty: Black Ops 1 (T5, PC).
//
// Qué hace: lee la cabecera del contenedor, infla el stream zlib en streaming
// (sin cargarlo todo en memoria) y muestra los primeros bytes de la zona
// descomprimida. NO extrae ni escribe ningún dato del juego.
//
// Requisitos: Node 18+ (solo librería estándar).
// Uso: node tools/ffprobe.mjs <archivo.ff> [...]
//
// Reglas del proyecto (reglas.md): no usar rutas del usuario en logs, no
// incluir datos del juego en el repositorio. La ruta se pasa como argumento y
// solo se imprime el nombre del archivo.

import { createReadStream } from "node:fs";
import { open, stat } from "node:fs/promises";
import { basename } from "node:path";
import { createInflate } from "node:zlib";

const MAGIC = "IWffu100"; // 8 bytes ASCII al principio de cada .ff de BO1 (PC)
const HEADER_LEN = 12; // 8 de magic + 4 de versión (uint32 LE)
const PREVIEW = 256; // bytes de la zona descomprimida que mostramos

function hexdump(buffer) {
    const lines = [];
    for (let offset = 0; offset < buffer.length; offset += 16) {
        const slice = buffer.subarray(offset, offset + 16);
        const hex = [...slice].map((b) => b.toString(16).padStart(2, "0")).join(" ");
        const ascii = [...slice].map((b) => (b >= 0x20 && b < 0x7f ? String.fromCharCode(b) : ".")).join("");
        lines.push(`${String(offset).padStart(6, "0")}  ${hex.padEnd(47)}  ${ascii}`);
    }
    return lines.join("\n");
}

async function readHeader(file) {
    const handle = await open(file, "r");
    try {
        // Leemos 16 bytes para ver también la cabecera zlib que empieza en el byte 12.
        const header = Buffer.alloc(HEADER_LEN + 4);
        await handle.read(header, 0, header.length, 0);
        return header;
    } finally {
        await handle.close();
    }
}

/** Infla el stream zlib a partir del byte 12 contando bytes y guardando los primeros. */
function inflate(file) {
    return new Promise((resolve, reject) => {
        let size = 0;
        let preview = Buffer.alloc(0);
        const source = createReadStream(file, { start: HEADER_LEN });
        const inflate = createInflate();
        source.on("error", reject);
        inflate.on("error", reject);
        inflate.on("data", (chunk) => {
            size += chunk.length;
            if (preview.length < PREVIEW) {
                preview = Buffer.concat([preview, chunk]).subarray(0, PREVIEW);
            }
        });
        inflate.on("end", () => {
            // bytesRead del origen = bytes del stream zlib; el resto serían datos colgantes.
            source.close();
            resolve({ size, preview, consumed: source.bytesRead });
        });
        source.pipe(inflate);
    });
}

async function probe(file) {
    const info = await stat(file);
    const header = await readHeader(file);
    const magic = header.subarray(0, 8).toString("latin1");
    const version = header.readUInt32LE(8);
    // El stream zlib empieza en el byte 12: CMF (0x78 = deflate, 32K) + FLG.
    const cmf = header[HEADER_LEN];
    const flg = header[HEADER_LEN + 1];
    const zlibHeader = `${cmf.toString(16).padStart(2, "0")} ${flg.toString(16).padStart(2, "0")}`;
    const zlibValid = (cmf & 0x0f) === 8 && (cmf >> 4) <= 7 && ((cmf << 8) + flg) % 31 === 0;

    console.log(`\n=== ${basename(file)}`);
    console.log(`  tamaño en disco : ${info.size} bytes`);
    console.log(`  magic           : "${magic}" ${magic === MAGIC ? "OK" : "INESPERADO"}`);
    console.log(`  versión de zona : 0x${version.toString(16)} (${version})`);
    console.log(`  zlib (CMF|FLG)  : ${zlibHeader} ${zlibValid ? "(deflate válido)" : "(NO válido)"}`);

    const { size, preview, consumed } = await inflate(file);
    const trailing = info.size - HEADER_LEN - consumed;
    console.log(`  descomprimido   : ${size} bytes`);
    console.log(`  ratio           : ${(size / info.size).toFixed(2)}x`);
    console.log(`  cola tras zlib  : ${trailing} bytes ${trailing === 0 ? "(el stream llega a EOF)" : "(datos no consumidos)"}`);
    console.log("  primeros bytes de la zona descomprimida:");
    for (const line of hexdump(preview).split("\n")) console.log(`    ${line}`);
}

const files = process.argv.slice(2);
if (files.length === 0) {
    console.error("Uso: node tools/ffprobe.mjs <archivo.ff> [...]");
    process.exit(1);
}

for (const file of files) {
    try {
        await probe(file);
    } catch (error) {
        console.error(`\n=== ${basename(file)}\n  ERROR: ${error.message}`);
        process.exitCode = 1;
    }
}
