#!/usr/bin/env node
// Lista de assets de un FastFile (.ff) de BO1 PC (T5): cuenta cuántos assets
// hay de cada tipo leyendo la XAssetList que está al principio del stream
// inflado. No extrae ni escribe datos del juego; solo imprime resúmenes.
//
// Uso:
//   node tools/zoneassets.mjs <archivo.ff> [--json]
//     --json   imprime el resultado como JSON
//
// Códigos de salida: 0 = lista leída; 1 = error de formato o de lectura; 2 = uso incorrecto.

import { readFile } from "node:fs/promises";
import { inflateSync } from "node:zlib";
import { basename, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const MAGIC = "IWffu100";
const HEADER_LEN = 12;
const T5_PC_VERSION = 0x1d9; // 473, identificador de zona de BO1 en PC
const XFILE_BLOCK_COUNT = 7; // bloques XFile de T5, según ZoneLoaderFactoryT5
const XFILE_SIZES_LEN = 8 + 4 * XFILE_BLOCK_COUNT; // size + externalSize + un uint32 por bloque
const XASSETLIST_LEN = 16; // stringList(count, strings) + assetCount + assets
const ASSET_ENTRY_LEN = 8; // tipo int32 + puntero
const FOLLOWING = 0xffffffff; // puntero que indica que el dato va inline en el stream

// Nombres de XAssetType de T5 (T5.h), en el orden del enum.
export const T5_ASSET_TYPE_NAMES = [
    "XMODELPIECES", "PHYSPRESET", "PHYSCONSTRAINTS", "DESTRUCTIBLEDEF", "XANIMPARTS",
    "XMODEL", "MATERIAL", "TECHNIQUE_SET", "IMAGE", "SOUND",
    "SOUND_PATCH", "CLIPMAP", "CLIPMAP_PVS", "COMWORLD", "GAMEWORLD_SP",
    "GAMEWORLD_MP", "MAP_ENTS", "GFXWORLD", "LIGHT_DEF", "UI_MAP",
    "FONT", "MENULIST", "MENU", "LOCALIZE_ENTRY", "WEAPON",
    "WEAPONDEF", "WEAPON_VARIANT", "SNDDRIVER_GLOBALS", "FX", "IMPACT_FX",
    "AITYPE", "MPTYPE", "MPBODY", "MPHEAD", "CHARACTER",
    "XMODELALIAS", "RAWFILE", "STRINGTABLE", "PACK_INDEX", "XGLOBALS",
    "DDL", "GLASSES", "EMBLEMSET",
];

/**
 * Lee la XAssetList del stream inflado de un FastFile T5.
 * Lanza Error si el formato no es el esperado.
 * @param {Buffer} d stream inflado (sin la cabecera de 12 bytes)
 */
export function parseAssetList(d) {
    if (d.length < XFILE_SIZES_LEN + XASSETLIST_LEN) {
        throw new Error("el stream inflado es demasiado corto");
    }

    const size = d.readUInt32LE(0);
    const expectedSize = d.length - XFILE_SIZES_LEN;
    if (size !== expectedSize) {
        throw new Error(`size de cabecera ${size} no coincide con ${expectedSize}`);
    }

    const base = XFILE_SIZES_LEN;
    const stringCount = d.readUInt32LE(base);
    const stringsPtr = d.readUInt32LE(base + 4);
    const assetCount = d.readUInt32LE(base + 8);
    const assetsPtr = d.readUInt32LE(base + 12);

    if (stringsPtr !== FOLLOWING && stringsPtr !== 0) {
        throw new Error("puntero de cadenas no soportado");
    }
    if (assetsPtr !== FOLLOWING && assetsPtr !== 0) {
        throw new Error("puntero de assets no soportado");
    }

    // Tras la XAssetList va la tabla de punteros de cadenas; luego, en orden,
    // las cadenas cuyo puntero es FOLLOWING; luego la tabla de assets.
    let pos = base + XASSETLIST_LEN;
    const tableEnd = pos + 4 * stringCount;
    if (tableEnd > d.length) throw new Error("tabla de cadenas fuera del stream");

    const pointers = [];
    for (let i = 0; i < stringCount; i++) {
        pointers.push(d.readUInt32LE(pos + 4 * i));
    }
    pos = tableEnd;

    const strings = [];
    for (const pointer of pointers) {
        if (pointer !== FOLLOWING) continue;
        const end = d.indexOf(0, pos);
        if (end === -1) throw new Error("cadena sin terminador");
        strings.push(d.toString("latin1", pos, end));
        pos = end + 1;
    }

    const typeCounts = new Array(T5_ASSET_TYPE_NAMES.length).fill(0);
    if (assetCount > 0) {
        if (assetsPtr !== FOLLOWING) throw new Error("la tabla de assets no va inline");
        if (pos + assetCount * ASSET_ENTRY_LEN > d.length) {
            throw new Error("tabla de assets fuera del stream");
        }
        for (let i = 0; i < assetCount; i++) {
            const type = d.readInt32LE(pos + i * ASSET_ENTRY_LEN);
            if (type < 0 || type >= T5_ASSET_TYPE_NAMES.length) {
                throw new Error(`tipo de asset desconocido: ${type}`);
            }
            typeCounts[type]++;
        }
    }

    const types = T5_ASSET_TYPE_NAMES.map((name, id) => ({ id, name, count: typeCounts[id] }))
        .filter((entry) => entry.count > 0)
        .sort((a, b) => b.count - a.count || a.id - b.id);

    return { stringCount: strings.length, assetCount, types, strings };
}

/** Lee el archivo .ff, valida su cabecera e infla el stream para parsearlo. */
export async function readZoneAssets(file) {
    const raw = await readFile(file);
    if (raw.length < HEADER_LEN) throw new Error("archivo demasiado corto");

    const magic = raw.toString("latin1", 0, 8);
    if (magic !== MAGIC) throw new Error(`cabecera ${JSON.stringify(magic)} no es ${MAGIC}`);

    const version = raw.readUInt32LE(8);
    if (version !== T5_PC_VERSION) {
        throw new Error(`versión 0x${version.toString(16)} no es la de T5 PC (0x${T5_PC_VERSION.toString(16)})`);
    }

    return parseAssetList(inflateSync(raw.subarray(HEADER_LEN)));
}

async function main(argv) {
    const args = argv.slice(2);
    const json = args.includes("--json");
    const file = args.find((arg) => !arg.startsWith("--"));
    if (!file) {
        console.error("Uso: node tools/zoneassets.mjs <archivo.ff> [--json]");
        return 2;
    }

    const { strings, ...result } = await readZoneAssets(file);
    if (json) {
        console.log(JSON.stringify({ file: basename(file), ...result }, null, 2));
        return 0;
    }

    console.log(`${basename(file)}: ${result.assetCount} assets, ${result.stringCount} cadenas`);
    for (const { name, count } of result.types) {
        console.log(`  ${String(count).padStart(6)}  ${name}`);
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
