#!/usr/bin/env node
// Pruebas del evaluador de expresiones de las directivas de tipo
// (tools/zassetsize.mjs) con datos sintéticos: no necesitan el juego ni la
// copia de referencia, solo el álgebra y los nombres de miembro.
//
// Uso: node --test tools/zassetsize.test.mjs

import test from "node:test";
import assert from "node:assert/strict";

import { evalExpr, Medidor, Modelo } from "./zassetsize.mjs";

// Miembros de prueba: nombre → valor, y una tabla con dimensión conocida.
const MEMBRES = {
    len: 2092,
    numBones: 40,
    numRootBones: 3,
    elemDefCountLooping: 2,
    elemDefCountOneShot: 1,
    elemDefCountEmission: 4,
    columnCount: 3,
    rowCount: 5,
    resourceSize: 1024,
    boneCount: [12, 8, 33, 7, 5, 9, 4, 6, 2, 1],
    N: 4,
    M: 3,
    cellCount: 3,
    negativo: -7,
};

const leer = (ruta, index) => {
    const nombre = ruta.join("::");
    if (!(nombre in MEMBRES)) throw new Error(`miembro desconocido: ${nombre}`);
    const valor = MEMBRES[nombre];
    if (index !== null) {
        if (!Array.isArray(valor)) throw new Error(`${nombre} no es un array`);
        return valor[index];
    }
    return valor;
};

test("suma y producto con la precedencia de C", () => {
    assert.equal(evalExpr("len + 1", leer), 2093);
    assert.equal(evalExpr("N * M", leer), 12);
    assert.equal(evalExpr("N * M + 1", leer), 13);
    assert.equal(evalExpr("1 + N * M", leer), 13);
});

test("resta y paréntesis", () => {
    assert.equal(evalExpr("numBones - numRootBones", leer), 37);
    assert.equal(evalExpr("(numBones - numRootBones) * 4", leer), 148);
    assert.equal(evalExpr("numBones - (numRootBones + 1)", leer), 36);
    assert.equal(evalExpr("-numBones + 2", leer), -38);
});

test("suma de varios miembros, como en FxEffectDef", () => {
    assert.equal(evalExpr("elemDefCountLooping + elemDefCountOneShot + elemDefCountEmission", leer), 7);
});

test("índices de array, como boneCount[9]", () => {
    assert.equal(evalExpr("boneCount[9]", leer), 1);
    assert.equal(evalExpr("boneCount[N - 1]", leer), 7);
    assert.equal(evalExpr("boneCount[2] * 2", leer), 66);
});

test("valores negativos del propio asset", () => {
    assert.equal(evalExpr("negativo + 10", leer), 3);
});

test("comparación de igualdad y expresiones booleanas entre paréntesis", () => {
    assert.equal(evalExpr("N == 4", leer), 1);
    assert.equal(evalExpr("N == 3", leer), 0);
    assert.equal(evalExpr("N + 1 == M + 2", leer), 1);
    assert.equal(evalExpr("(numBones < 256) == 0", leer), 0);
    assert.equal(evalExpr("((N > 1) == 0) || (M == 3)", leer), 1);
});

test("literales hexadecimales (0x... y 0X...) y precedencia con decimales", () => {
    assert.equal(evalExpr("0x200", leer), 512);
    assert.equal(evalExpr("0X200", leer), 512);
    assert.equal(evalExpr("cellCount * 0x200", leer), 1536);
    assert.equal(evalExpr("0x10 + 0x20 * 2", leer), 80);
    assert.equal(evalExpr("(0x10 + 0x20) * 2", leer), 96);
    assert.equal(evalExpr("1 + N * 0x10", leer), 65);
    assert.equal(evalExpr("-0x200", leer), -512);
});

test("un miembro que no existe se propaga como error, no como cero", () => {
    assert.throws(() => evalExpr("inexistente + 1", leer), /miembro desconocido/);
});

test("las expresiones mal formadas se rechazan", () => {
    assert.throws(() => evalExpr("len +", leer), /expresión incompleta/);
    assert.throws(() => evalExpr("(len + 1", leer), /paréntesis sin cerrar/);
    assert.throws(() => evalExpr("len + 1)", leer), /sobra/);
    assert.throws(() => evalExpr("len + + 1", leer), /token inesperado/);
    assert.throws(() => evalExpr("len / 0", leer), /división por cero/);
    assert.throws(() => evalExpr("0xG", leer), /token inesperado/);
    assert.throws(() => evalExpr("0x", leer), /token inesperado/);
});

test("Medidor mide tablas count de ScriptString (uint16_t) sin confundirlas con cadenas C", () => {
    // Simula el caso real de XModel::boneNames (numBones = 2, bytes 01 00 02 00) seguido de surfs (8 B).
    // Si la directiva `scriptstrings` hiciera que boneNames se clasificara como cadena C en recogerPasos(),
    // el cursor se pararía en el byte 0x00 (+13) midiendo 2 bytes en vez de 4, lo que desfasaría surfs a +14
    // (encontrando 0x0000ffff en lugar de 0xffffffff).
    const dir = {
        reorder: [],
        conditions: [],
        strings: [],
        scriptstrings: ["boneNames"],
        counts: [
            { member: "boneNames", expr: "numBones" },
            { member: "surfs", expr: "1" },
        ],
        arraysizes: [],
        reusables: [],
    };

    const modelo = Object.create(Modelo.prototype);
    modelo.planes = new Map();
    modelo.planesStruct = new Map();
    modelo.assetStructs = new Set();
    modelo.sizeOf = (t) => (t === "ScriptString" ? 2 : (t === "FakeSurf" ? 8 : 12));
    modelo.miembros = (s) => (s === "FakeXModel" ? [
        { name: "numBones", offset: 0, size: 1, type: "unsigned char", ptr: 0, dims: [] },
        { name: "boneNames", offset: 4, size: 4, type: "ScriptString", ptr: 1, dims: [] },
        { name: "surfs", offset: 8, size: 4, type: "FakeSurf", ptr: 1, dims: [] },
    ] : null);
    modelo.subDirectivas = () => null;
    modelo.directivesOfStruct = () => null;
    modelo.imagenesDe = () => null;
    modelo.medidor = () => ({ all: () => new Map() });
    modelo.plan = () => ({ struct: "FakeXModel", fijo: 12, directivas: dir });

    const buf = Buffer.alloc(24);
    buf.writeUInt8(2, 0);              // numBones = 2 (+0)
    buf.writeUInt32LE(0xffffffff, 4);  // boneNames = FOLLOWING (+4)
    buf.writeUInt32LE(0xffffffff, 8);  // surfs = FOLLOWING (+8)
    buf.writeUInt16LE(1, 12);          // boneNames[0] = 0x0001 (contiene byte 0x00 en +13)
    buf.writeUInt16LE(2, 14);          // boneNames[1] = 0x0002
    buf.writeUInt32LE(0xffffffff, 16); // surfs[0].triIndices = FOLLOWING (+16)
    buf.writeUInt32LE(0, 20);

    const plan = modelo.planStruct("FakeXModel", dir);
    assert.equal(plan.pasos[0].clase, "count");
    assert.equal(plan.pasos[0].elemString, false);
    assert.equal(plan.pasos[0].elemSize, 2);

    const medidor = new Medidor(buf, 0);
    const res = medidor.medir(modelo, "XMODEL", 0);
    assert.equal(res.ok, true);
    assert.equal(res.total, 24);
    assert.equal(res.detalle[0].member, "boneNames");
    assert.equal(res.detalle[0].bytes, 4); // 2 enteros uint16_t de 2 bytes (offset 12..16)
    assert.equal(res.detalle[1].member, "surfs");
    assert.equal(res.detalle[1].bytes, 8); // surfs empieza exactamente en offset 16 (16..24)
});

test("omite miembros declarados XFILE_BLOCK_RUNTIME aunque lleven marcador 0xffffffff", () => {
    const dir = {
        struct: "FakePathData",
        file: "FakePathData.txt",
        strings: [],
        counts: [
            { member: "nodes", expr: "nodeCount" },
            { member: "basenodes", expr: "nodeCount" },
        ],
        arraysizes: [],
        reusables: [],
        conditions: [],
        scriptstrings: [],
        assetrefs: [],
        blocks: ["set block basenodes XFILE_BLOCK_RUNTIME;"],
        runtimeBlocks: ["basenodes"],
        allocaligns: [],
        actions: [],
        reorder: [],
        scoped: [],
    };

    const modelo = Object.create(Modelo.prototype);
    modelo.planes = new Map();
    modelo.planesStruct = new Map();
    modelo.assetStructs = new Set();
    modelo.sizeOf = (t) => (t === "FakeNode" ? 8 : (t === "FakeBaseNode" ? 16 : 12));
    modelo.miembros = (s) => (s === "FakePathData" ? [
        { name: "nodeCount", offset: 0, size: 4, type: "unsigned int", ptr: 0, dims: [] },
        { name: "nodes", offset: 4, size: 4, type: "FakeNode", ptr: 1, dims: [] },
        { name: "basenodes", offset: 8, size: 4, type: "FakeBaseNode", ptr: 1, dims: [] },
    ] : null);
    modelo.subDirectivas = () => null;
    modelo.directivesOfStruct = () => null;
    modelo.imagenesDe = () => null;
    modelo.medidor = () => ({ all: () => new Map() });
    modelo.plan = () => ({ struct: "FakePathData", fijo: 12, directivas: dir });

    const plan = modelo.planStruct("FakePathData", dir);
    // Solo debe generar paso following para nodes, no para basenodes (runtime)
    assert.equal(plan.pasos.length, 1);
    assert.equal(plan.pasos[0].member, "nodes");

    const buf = Buffer.alloc(28);
    buf.writeUInt32LE(2, 0);              // nodeCount = 2 (+0)
    buf.writeUInt32LE(0xffffffff, 4);     // nodes = FOLLOWING (+4)
    buf.writeUInt32LE(0xffffffff, 8);     // basenodes = 0xffffffff en struct (+8, pero es runtime!)
    // nodes following data: 2 nodos * 8 bytes = 16 bytes (offset 12..28)
    buf.writeUInt32LE(111, 12);
    buf.writeUInt32LE(222, 20);

    const medidor = new Medidor(buf, 0);
    const res = medidor.medir(modelo, "FAKE_PATH", 0);
    assert.equal(res.ok, true);
    assert.equal(res.total, 28); // 12 fijo + 16 nodes (0 basenodes)
    assert.equal(res.detalle.length, 1);
    assert.equal(res.detalle[0].member, "nodes");
    assert.equal(res.detalle[0].bytes, 16);
});

test("genera pasos indexados para arrays de punteros y respeta runtime en índices", () => {
    const dir = {
        struct: "FakeClipMap",
        file: "FakeClipMap.txt",
        strings: [],
        counts: [
            { member: "dynEntDefList[0]", expr: "count0" },
            { member: "dynEntDefList[1]", expr: "count1" },
            { member: "dynEntPoseList[0]", expr: "count0" },
        ],
        arraysizes: [],
        reusables: [],
        conditions: [],
        scriptstrings: [],
        assetrefs: [],
        blocks: ["set block dynEntPoseList XFILE_BLOCK_RUNTIME;"],
        runtimeBlocks: ["dynEntPoseList"],
        allocaligns: [],
        actions: [],
        reorder: [],
        scoped: [],
    };

    const modelo = Object.create(Modelo.prototype);
    modelo.planes = new Map();
    modelo.planesStruct = new Map();
    modelo.assetStructs = new Set();
    modelo.sizeOf = (t) => (t === "DynEntityDef" ? 10 : 24);
    modelo.miembros = (s) => (s === "FakeClipMap" ? [
        { name: "count0", offset: 0, size: 4, type: "unsigned int", ptr: 0, dims: [] },
        { name: "count1", offset: 4, size: 4, type: "unsigned int", ptr: 0, dims: [] },
        { name: "dynEntDefList", offset: 8, size: 8, type: "DynEntityDef", ptr: 1, dims: [2] },
        { name: "dynEntPoseList", offset: 16, size: 8, type: "DynEntityPose", ptr: 1, dims: [2] },
    ] : []);
    modelo.subDirectivas = () => null;
    modelo.directivesOfStruct = () => null;
    modelo.imagenesDe = () => null;
    modelo.medidor = () => ({ all: () => new Map() });
    const plan = Modelo.prototype.planStruct.call(modelo, "FakeClipMap", dir);
    modelo.plan = () => ({ struct: "FakeClipMap", fijo: 24, directivas: dir });
    modelo.planStruct = (s) => (s === "DynEntityDef" ? { struct: "DynEntityDef", fijo: 10, pasos: [] } : plan);

    // dynEntDefList[0] y [1] deben generar 2 pasos. dynEntPoseList es runtime y no genera pasos.
    assert.equal(plan.pasos.length, 2);
    assert.equal(plan.pasos[0].member, "dynEntDefList[0]");
    assert.equal(plan.pasos[0].offset, 8);
    assert.equal(plan.pasos[1].member, "dynEntDefList[1]");
    assert.equal(plan.pasos[1].offset, 12);

    const buf = Buffer.alloc(54);
    buf.writeUInt32LE(2, 0);              // count0 = 2 (+0)
    buf.writeUInt32LE(1, 4);              // count1 = 1 (+4)
    buf.writeUInt32LE(0xffffffff, 8);     // dynEntDefList[0] = FOLLOWING (+8)
    buf.writeUInt32LE(0xffffffff, 12);    // dynEntDefList[1] = FOLLOWING (+12)
    buf.writeUInt32LE(0xffffffff, 16);    // dynEntPoseList[0] = FOLLOWING (+16, runtime!)
    buf.writeUInt32LE(0, 20);             // dynEntPoseList[1] = NULL (+20, runtime!)
    // Following data:
    // dynEntDefList[0]: 2 * 10 = 20 bytes (offset 24..44)
    // dynEntDefList[1]: 1 * 10 = 10 bytes (offset 44..54)

    const medidor = new Medidor(buf, 0);
    const res = medidor.medir(modelo, "FAKE_CLIP", 0);
    assert.equal(res.ok, true);
    assert.equal(res.total, 54);
    assert.equal(res.detalle[0].member, "dynEntDefList[0]");
    assert.equal(res.detalle[0].bytes, 20);
    assert.equal(res.detalle[1].member, "dynEntDefList[1]");
    assert.equal(res.detalle[1].bytes, 10);
});

test("miembros de unión en el mismo offset reciben la condición complementaria", () => {
    const dir = {
        struct: "FakeTreeInfo",
        file: "FakeTreeInfo.txt",
        strings: [],
        counts: [],
        arraysizes: [],
        reusables: ["child"],
        conditions: [{ member: "s", expr: "axis < 0" }],
        scriptstrings: [],
        assetrefs: [],
        blocks: [],
        runtimeBlocks: [],
        allocaligns: [],
        actions: [],
        reorder: [],
        scoped: [{ palabra: "count", path: ["s", "nodes"], expr: "nodeCount", file: "test" }],
    };

    const modelo = Object.create(Modelo.prototype);
    modelo.planes = new Map();
    modelo.planesStruct = new Map();
    modelo.assetStructs = new Set();
    modelo.sizeOf = (t) => (t === "FakeTreeInfo" ? 8 : (t === "FakeTreeNodes" ? 8 : 4));
    modelo.miembros = (s) => {
        if (s === "FakeTreeInfo") {
            return [
                { name: "child", offset: 0, size: 8, type: "FakeTreeInfo", ptr: 1, dims: [2] },
                { name: "s", offset: 0, size: 8, type: "FakeTreeNodes", ptr: 0, dims: [] },
            ];
        }
        if (s === "FakeTreeNodes") {
            return [
                { name: "nodeCount", offset: 0, size: 4, type: "int", ptr: 0, dims: [] },
                { name: "nodes", offset: 4, size: 4, type: "unsigned short", ptr: 1, dims: [] },
            ];
        }
        return [];
    };
    modelo.subDirectivas = Modelo.prototype.subDirectivas;
    modelo.directivesOfStruct = () => null;
    modelo.imagenesDe = () => null;
    modelo.medidor = () => ({ all: () => new Map() });

    const plan = Modelo.prototype.planStruct.call(modelo, "FakeTreeInfo", dir);
    assert.equal(plan.pasos.length, 2);
    // child viene antes en offset 0 y debe recibir la condición complementaria de s
    assert.equal(plan.pasos[0].member, "child");
    assert.equal(plan.pasos[0].cond, "(axis < 0) == 0");
    // s viene después con su condición explícita
    assert.equal(plan.pasos[1].member, "s::nodes");
    assert.equal(plan.pasos[1].cond, "axis < 0");
});
