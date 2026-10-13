#!/usr/bin/env node
// Pruebas de tools/zonescan.mjs (la lógica que replica el launcher) usando
// archivos .ff SINTÉTICOS: cabecera de 12 bytes + zlib de relleno. No se usa
// ningún dato del juego.
//
// Uso: node --test tools/zonescan.test.mjs

import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { test } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { deflateSync } from "node:zlib";

const ZONESCAN = join(dirname(fileURLToPath(import.meta.url)), "zonescan.mjs");
const MAGIC = "IWffu100";
const T5_PC_VERSION = 0x1d9;

/** Construye un .ff sintético: magic + versión + stream zlib (o bytes sueltos). */
function zoneFile({ version = T5_PC_VERSION, payload = Buffer.alloc(64, 7), rawTail = null } = {}) {
    const header = Buffer.alloc(12);
    header.write(MAGIC, 0, "latin1");
    header.writeUInt32LE(version, 8);
    return Buffer.concat([header, rawTail ?? deflateSync(payload)]);
}

/** Crea una carpeta de juego temporal con las zonas indicadas y ejecuta zonescan. */
function runScan(zones, { target = "root", extraArgs = [] } = {}) {
    const root = mkdtempSync(join(tmpdir(), "blopspocket-"));
    try {
        for (const [relativePath, contents] of Object.entries(zones)) {
            const full = join(root, "zone", relativePath);
            mkdirSync(dirname(full), { recursive: true });
            writeFileSync(full, contents);
        }
        const args = [ZONESCAN, target === "root" ? root : join(root, "zone"), "--json", ...extraArgs];
        const result = spawnSync(process.execPath, args, { encoding: "utf8" });
        return { ...result, catalog: result.stdout ? JSON.parse(result.stdout) : null, root };
    } finally {
        rmSync(root, { recursive: true, force: true });
    }
}

const sample = {
    "Common/common.ff": zoneFile({ payload: Buffer.alloc(200, 1) }),
    "Common/common_zombie.ff": zoneFile({ payload: Buffer.alloc(100, 1) }),
    "Common/zombie_theater.ff": zoneFile({ payload: Buffer.alloc(50, 1) }),
    "Common/zombie_theater_patch.ff": zoneFile({ payload: Buffer.alloc(10, 1) }),
    "Common/mp_array.ff": zoneFile({ payload: Buffer.alloc(30, 1) }),
    "Common/code_pre_gfx.ff": zoneFile({ payload: Buffer.alloc(5, 1) }),
    "Common/ui_viewer_mp.ff": zoneFile({ payload: Buffer.alloc(5, 1) }),
    "Common/frontend.ff": zoneFile({ payload: Buffer.alloc(5, 1) }),
    "Common/cuba.ff": zoneFile({ payload: Buffer.alloc(5, 1) }),
    "Spanish/sp_common.ff": zoneFile({ payload: Buffer.alloc(5, 1) }),
    "Common/not_a_zone.txt": Buffer.from("no cuenta"),
};

test("encuentra solo los .ff y clasifica por grupo", () => {
    const { status, catalog } = runScan(sample);
    assert.equal(status, 0);
    assert.equal(catalog.zones.length, 10, "10 archivos .ff, el .txt se ignora");

    const names = catalog.zones.map((zone) => zone.name);
    assert.ok(names.includes("Common/common_zombie.ff"));
    assert.ok(!names.includes("Common/not_a_zone.txt"));

    // Clasificación equivalente a ZoneGroup en la app.
    const byGroup = (predicate) => catalog.zones.filter((zone) => predicate(zone.name)).length;
    assert.equal(byGroup((n) => /zombie/i.test(n) && !/_patch\.ff$/i.test(n)), 2, "common_zombie y zombie_theater");
    assert.equal(byGroup((n) => /_patch\.ff$/i.test(n)), 1);
    assert.equal(byGroup((n) => /^Common\/mp_/.test(n)), 1);
    assert.equal(byGroup((n) => /^Spanish\//.test(n)), 1);
});

test("todas las zonas del catálogo declaran magic y versión de BO1 PC", () => {
    const { catalog } = runScan(sample);
    for (const zone of catalog.zones) {
        assert.equal(zone.magic, MAGIC);
        assert.equal(zone.version, T5_PC_VERSION);
        assert.equal(zone.versionOk, true);
    }
});

test("detecta una versión inesperada y sale con código 1", () => {
    const { status, catalog } = runScan({
        "Common/common_zombie.ff": zoneFile(),
        "Common/otro_juego.ff": zoneFile({ version: 0x114 }),
    });
    assert.equal(status, 1, "el código de salida avisa de archivos inesperados");
    const bad = catalog.zones.filter((zone) => !zone.versionOk);
    assert.equal(bad.length, 1);
    assert.equal(bad[0].name, "Common/otro_juego.ff");
    assert.equal(bad[0].version, 0x114);
});

test("una cabecera válida con zlib corrupto sigue contando (no se descomprime)", () => {
    // Si zonescan intentara descomprimir para catalogar, esto fallaría.
    const corrupt = Buffer.concat([zoneFile({ rawTail: Buffer.alloc(0) }), Buffer.from("no es zlib")]);
    const { status, catalog } = runScan({ "Common/common_zombie.ff": corrupt });
    assert.equal(status, 0);
    assert.equal(catalog.zones.length, 1);
    assert.equal(catalog.zones[0].versionOk, true);
});

test("un archivo truncado no rompe el catálogo", () => {
    const { status, catalog } = runScan({
        "Common/common_zombie.ff": zoneFile(),
        "Common/corto.ff": Buffer.from("IWff"),
    });
    assert.equal(status, 1, "sin cabecera completa el archivo es sospechoso");
    const truncated = catalog.zones.find((zone) => zone.name === "Common/corto.ff");
    assert.equal(truncated.magic, null, "sin 8 bytes no se declara magic");
    assert.equal(truncated.version, null);
    assert.equal(truncated.magicOk, false);
});

test("acepta la carpeta zone directamente, sin la carpeta del juego", () => {
    const { status, catalog } = runScan(sample, { target: "zone" });
    assert.equal(status, 0);
    assert.equal(catalog.zones.length, 10);
    assert.ok(catalog.zoneDir.endsWith("zone"));
});
