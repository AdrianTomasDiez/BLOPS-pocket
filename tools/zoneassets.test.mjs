import { test } from "node:test";
import assert from "node:assert/strict";
import { parseAssetList } from "./zoneassets.mjs";

const FOLLOWING = 0xffffffff;

/**
 * Construye un stream inflado mínimo: 36 bytes de cabecera XFile (size, externalSize y
 * 7 bloques), XAssetList de 16 bytes, tabla de punteros de cadenas, cadenas inline y
 * tabla de assets de 8 bytes por entrada.
 */
function buildStream({ strings = [], assets = [], stringPointers, assetsPointer = FOLLOWING, sizeOverride }) {
    const pointers = stringPointers ?? strings.map(() => FOLLOWING);
    const head = Buffer.alloc(36 + 16);
    const body = [];
    const table = Buffer.alloc(4 * pointers.length);
    pointers.forEach((p, i) => table.writeUInt32LE(p, 4 * i));
    body.push(table);
    for (const s of strings) body.push(Buffer.from(`${s}\0`, "latin1"));
    const assetTable = Buffer.alloc(8 * assets.length);
    assets.forEach((a, i) => {
        assetTable.writeInt32LE(a.type, 8 * i);
        assetTable.writeUInt32LE(0, 8 * i + 4);
    });
    body.push(assetTable);
    const total = Buffer.concat(body);
    // size = bytes tras los 36 de cabecera: XAssetList (16) + resto del stream
    head.writeUInt32LE(sizeOverride ?? total.length + 16, 0);
    // XAssetList en el byte 36
    head.writeUInt32LE(pointers.length, 36);
    head.writeUInt32LE(pointers.length ? FOLLOWING : 0, 40);
    head.writeUInt32LE(assets.length, 44);
    head.writeUInt32LE(assets.length ? assetsPointer : 0, 48);
    return Buffer.concat([head, total]);
}

test("cuenta assets por tipo y lee las cadenas inline", () => {
    const stream = buildStream({
        strings: ["tag_knife", "tag_view"],
        assets: [{ type: 4 }, { type: 36 }, { type: 4 }],
    });
    const result = parseAssetList(stream);
    assert.equal(result.stringCount, 2);
    assert.equal(result.assetCount, 3);
    assert.deepEqual(result.strings, ["tag_knife", "tag_view"]);
    assert.deepEqual(result.types, [
        { id: 4, name: "XANIMPARTS", count: 2 },
        { id: 36, name: "RAWFILE", count: 1 },
    ]);
});

test("un stream sin assets devuelve lista vacía", () => {
    const result = parseAssetList(buildStream({}));
    assert.equal(result.assetCount, 0);
    assert.deepEqual(result.types, []);
});

test("rechaza un size de cabecera que no coincide con el stream", () => {
    const stream = buildStream({ strings: ["a"], assets: [{ type: 4 }], sizeOverride: 1 });
    assert.throws(() => parseAssetList(stream), /size de cabecera/);
});

test("rechaza un tipo de asset fuera del enum de T5", () => {
    const stream = buildStream({ strings: ["a"], assets: [{ type: 99 }] });
    assert.throws(() => parseAssetList(stream), /tipo de asset desconocido: 99/);
});

test("rechaza una tabla de assets que se sale del stream", () => {
    const stream = buildStream({ strings: ["a"], assets: [{ type: 4 }, { type: 4 }] });
    assert.throws(() => parseAssetList(stream.subarray(0, stream.length - 4)), /size de cabecera|tabla de assets/);
});

test("rechaza una cadena sin terminador", () => {
    const stream = buildStream({ strings: ["abc"], assets: [] });
    const truncated = stream.subarray(0, stream.length - 1);
    assert.throws(() => parseAssetList(truncated), /size de cabecera|cadena sin terminador/);
});
