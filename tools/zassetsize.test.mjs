#!/usr/bin/env node
// Pruebas del evaluador de expresiones de las directivas de tipo
// (tools/zassetsize.mjs) con datos sintéticos: no necesitan el juego ni la
// copia de referencia, solo el álgebra y los nombres de miembro.
//
// Uso: node --test tools/zassetsize.test.mjs

import test from "node:test";
import assert from "node:assert/strict";

import { evalExpr } from "./zassetsize.mjs";

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

test("comparación de igualdad, como semantic == TS_WATER_MAP", () => {
    assert.equal(evalExpr("N == 4", leer), 1);
    assert.equal(evalExpr("N == 3", leer), 0);
    assert.equal(evalExpr("N + 1 == M + 2", leer), 1);
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
});
