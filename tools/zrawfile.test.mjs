import { test } from "node:test";
import assert from "node:assert/strict";
import { deflateSync } from "node:zlib";
import { decodeRawFile, findRawFiles, readRawFileContent } from "./zrawfile.mjs";

const FOLLOWING = 0xffffffff;

/** Separador (0x00) + marca del siguiente registro, para que el bloque se cierre. */
const tail = () => Buffer.concat([Buffer.from([0x00]), Buffer.alloc(4, 0xff), Buffer.alloc(8)]);

/** Registro comprimido: marca, tamaño (8 + clen), marca, nombre, `len`, `clen`, zlib. */
function buildCompressed(name, text, { lenOverride } = {}) {
    const content = Buffer.from(text, "latin1");
    const compressed = deflateSync(content);
    const head = Buffer.alloc(12);
    head.writeUInt32LE(FOLLOWING, 0);
    head.writeUInt32LE(8 + compressed.length, 4);
    head.writeUInt32LE(FOLLOWING, 8);
    const tailLen = Buffer.alloc(8);
    tailLen.writeUInt32LE(lenOverride ?? content.length, 0);
    tailLen.writeUInt32LE(compressed.length, 4);
    return Buffer.concat([head, Buffer.from(`${name}\0`, "latin1"), tailLen, compressed]);
}

/** Registro sin comprimir: marca, tamaño (= len), marca, nombre, datos, separador. */
function buildUncompressed(name, text) {
    const content = Buffer.from(text, "latin1");
    const head = Buffer.alloc(12);
    head.writeUInt32LE(FOLLOWING, 0);
    head.writeUInt32LE(content.length, 4);
    head.writeUInt32LE(FOLLOWING, 8);
    return Buffer.concat([head, Buffer.from(`${name}\0`, "latin1"), content, tail()]);
}

test("descodifica un RAWFILE comprimido y valida el tamaño descomprimido", () => {
    const body = "void main() { self iprint(\"hola\"); }";
    const stream = Buffer.concat([Buffer.alloc(37), buildCompressed("animscripts/test.gsc", body)]);
    const record = decodeRawFile(stream, 37);
    assert.equal(record.kind, "compressed");
    assert.equal(record.name, "animscripts/test.gsc");
    assert.equal(record.len, Buffer.byteLength(body, "latin1"));
    assert.ok(record.clen > 0);
    assert.equal(readRawFileContent(stream, record).toString("latin1"), body);
});

test("descodifica un RAWFILE sin comprimir", () => {
    const body = "// reset the coop challenges\r\nstatset 2910 0\r\n";
    const stream = Buffer.concat([Buffer.alloc(11), buildUncompressed("mp/zm_challenges_reset.cfg", body)]);
    const record = decodeRawFile(stream, 11);
    assert.equal(record.kind, "uncompressed");
    assert.equal(record.name, "mp/zm_challenges_reset.cfg");
    assert.equal(record.len, Buffer.byteLength(body, "latin1"));
    assert.equal(readRawFileContent(stream, record).toString("latin1"), body);
});

test("encuentra registros de ambos tipos, en orden", () => {
    const a = buildCompressed("a.gsc", "uno");
    const b = buildUncompressed("b.cfg", "dos");
    const stream = Buffer.concat([Buffer.alloc(4), a, b, Buffer.alloc(4)]);
    const found = findRawFiles(stream);
    assert.deepEqual(found.map((r) => [r.name, r.kind]), [
        ["a.gsc", "compressed"],
        ["b.cfg", "uncompressed"],
    ]);
    assert.equal(found[0].offset, 4);
    assert.equal(found[1].offset, 4 + a.length);
});

test("rechaza un registro comprimido cuyo tamaño no coincide", () => {
    const stream = buildCompressed("a.gsc", "contenido real", { lenOverride: 999 });
    assert.equal(decodeRawFile(stream, 0), null);
    assert.deepEqual(findRawFiles(stream), []);
});

test("rechaza datos que no son un RAWFILE", () => {
    const noise = Buffer.alloc(64);
    for (let i = 0; i < noise.length; i++) noise[i] = i;
    assert.equal(decodeRawFile(noise, 0), null);
    assert.deepEqual(findRawFiles(noise), []);
});

test("rechaza un bloque sin el separador esperado", () => {
    const stream = buildUncompressed("a.cfg", "datos").subarray(0, 12 + 6 + 5);
    assert.equal(decodeRawFile(stream, 0), null);
});
