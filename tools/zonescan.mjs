#!/usr/bin/env node
// Catálogo de zonas: recorre la carpeta `zone/` del usuario y describe cada
// FastFile (.ff) leyendo SOLO su cabecera de 12 bytes. No extrae ni escribe
// datos del juego. Es el equivalente en Node del lector que irá en el launcher.
//
// Uso:
//   node tools/zonescan.mjs <ruta> [--inflate] [--json]
//     <ruta>      carpeta del juego (con subcarpeta zone) o la propia carpeta zone
//     --inflate   además infla el stream zlib para medir el tamaño descomprimido
//                 (más lento y usa algo de CPU; no guarda nada)
//     --json      imprime el catálogo como JSON
//
// Códigos de salida: 0 = todos los archivos tienen cabecera esperada; 1 = alguno no.

import { createReadStream } from "node:fs";
import { open, readdir, stat } from "node:fs/promises";
import { join, relative, sep } from "node:path";
import { createInflate } from "node:zlib";

const MAGIC = "IWffu100";
const HEADER_LEN = 12;
const T5_PC_VERSION = 0x1d9; // 473, identificador de zona de BO1 en PC

/** Recorre `dir` buscando archivos .ff (sin seguir enlaces simbólicos). */
async function findZoneFiles(dir) {
    const found = [];
    for (const entry of await readdir(dir, { withFileTypes: true })) {
        if (entry.isSymbolicLink()) continue;
        const path = join(dir, entry.name);
        if (entry.isDirectory()) {
            found.push(...(await findZoneFiles(path)));
        } else if (entry.isFile() && entry.name.toLowerCase().endsWith(".ff")) {
            found.push(path);
        }
    }
    return found;
}

/** Lee la cabecera de 12 bytes: magic ASCII + versión uint32 little-endian. */
async function readHeader(file) {
    const handle = await open(file, "r");
    try {
        const header = Buffer.alloc(HEADER_LEN);
        const { bytesRead } = await handle.read(header, 0, HEADER_LEN, 0);
        return { header, bytesRead };
    } finally {
        await handle.close();
    }
}

/** Infla el stream zlib (desde el byte 12) y devuelve solo el tamaño. */
function inflatedSize(file) {
    return new Promise((resolve, reject) => {
        let size = 0;
        const source = createReadStream(file, { start: HEADER_LEN });
        const inflate = createInflate();
        source.on("error", reject);
        inflate.on("error", reject);
        inflate.on("data", (chunk) => { size += chunk.length; });
        inflate.on("end", () => resolve(size));
        source.pipe(inflate);
    });
}

/** Clasifica una zona por subcarpeta (idioma) y prefijo, para resumir el catálogo.
 *  Mantener en paralelo con ZoneGroup en launcher/BLOPSPocket/ZoneCatalog.swift. */
function zoneGroup(relativePath) {
    const slash = relativePath.lastIndexOf("/");
    if (slash >= 0) {
        if (relativePath.slice(0, slash).toLowerCase() !== "common") return "traducciones";
        relativePath = relativePath.slice(slash + 1);
    }
    if (/_patch\.ff$/i.test(relativePath)) return "parches";
    if (/zombie/i.test(relativePath)) return "Zombies";
    if (/^code_/.test(relativePath)) return "código";
    if (/^ui_/.test(relativePath)) return "interfaz";
    if (/^common/.test(relativePath)) return "comunes";
    if (/^mp_/.test(relativePath)) return "multijugador";
    if (/^(frontend|so_narrative)/.test(relativePath)) return "interfaz";
    return "campaña";
}

function formatBytes(bytes) {
    return `${(bytes / 1024 / 1024).toFixed(1)} MiB`;
}

async function main() {
    const args = process.argv.slice(2);
    const inflate = args.includes("--inflate");
    const asJson = args.includes("--json");
    const target = args.find((a) => !a.startsWith("--"));
    if (!target) {
        console.error("Uso: node tools/zonescan.mjs <ruta> [--inflate] [--json]");
        process.exit(1);
    }

    // Aceptamos tanto la carpeta del juego como la carpeta zone directamente.
    const info = await stat(target);
    if (!info.isDirectory()) throw new Error(`${target} no es una carpeta`);
    let zoneDir = target;
    try {
        const inside = await stat(join(target, "zone"));
        if (inside.isDirectory()) zoneDir = join(target, "zone");
    } catch { /* target ya es la carpeta zone */ }

    const files = (await findZoneFiles(zoneDir)).sort();
    const zones = [];
    for (const file of files) {
        const { header, bytesRead } = await readHeader(file);
        const fileInfo = await stat(file);
        const zone = {
            name: relative(zoneDir, file).split(sep).join("/"),
            bytes: fileInfo.size,
            magic: bytesRead >= 8 ? header.subarray(0, 8).toString("latin1") : null,
            version: bytesRead >= HEADER_LEN ? header.readUInt32LE(8) : null,
        };
        zone.magicOk = zone.magic === MAGIC;
        zone.versionOk = zone.version === T5_PC_VERSION;
        if (inflate) zone.inflatedBytes = await inflatedSize(file);
        zones.push(zone);
    }

    const problems = zones.filter((z) => !z.magicOk || !zoneVersionOkSafe(z));
    if (asJson) {
        console.log(JSON.stringify({ zoneDir, zones }, null, 2));
    } else {
        const groups = new Map();
        for (const zone of zones) {
            const key = zoneGroup(zone.name);
            const group = groups.get(key) ?? { count: 0, bytes: 0, inflatedBytes: 0 };
            group.count += 1;
            group.bytes += zone.bytes;
            group.inflatedBytes += zone.inflatedBytes ?? 0;
            groups.set(key, group);
        }
        console.log(`Carpeta de zonas: ${zoneDir}`);
        console.log(`Archivos .ff    : ${zones.length}`);
        console.log(`Total en disco  : ${formatBytes(zones.reduce((n, z) => n + z.bytes, 0))}`);
        if (inflate) {
            console.log(`Total inflado   : ${formatBytes(zones.reduce((n, z) => n + (z.inflatedBytes ?? 0), 0))}`);
        }
        console.log("\nPor grupo:");
        for (const [name, group] of [...groups].sort((a, b) => b[1].bytes - a[1].bytes)) {
            const extra = inflate ? `, ${formatBytes(group.inflatedBytes)} inflados` : "";
            console.log(`  ${name.padEnd(24)} ${String(group.count).padStart(3)} archivos, ${formatBytes(group.bytes)}${extra}`);
        }
        console.log("\nVersiones de zona encontradas:");
        const versions = new Map();
        for (const zone of zones) {
            const key = zone.version === null ? "sin cabecera" : `0x${zone.version.toString(16)} (${zone.version})`;
            versions.set(key, (versions.get(key) ?? 0) + 1);
        }
        for (const [key, count] of versions) console.log(`  ${key.padEnd(24)} ${count}`);
        if (problems.length > 0) {
            console.log("\nArchivos con cabecera inesperada:");
            for (const zone of problems) console.log(`  ${zone.name}: magic=${zone.magic} version=${zone.version}`);
        } else {
            console.log("\nTodos los archivos tienen magic IWffu100 y versión 0x1d9.");
        }
    }

    process.exit(problems.length > 0 ? 1 : 0);
}

function zoneVersionOkSafe(zone) {
    return zone.version === T5_PC_VERSION;
}

await main();
