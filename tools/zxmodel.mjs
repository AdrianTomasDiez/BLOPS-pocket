#!/usr/bin/env node
// Sonda de SOLO LECTURA y decodificador de geometría intermedia para los XMODEL
// de un FastFile (.ff) de BO1 PC (T5).
//
// Lee el stream inflado, localiza los registros XMODEL inline y decodifica su
// cabecera fija (252 bytes), los bloques following de huesos y el array de
// superficies XSurface (68 bytes por superficie) con sus buffers de vértices
// (GfxPackedVertex, 32 bytes) e índices de triángulos (u16[3], 6 bytes).
// No escribe archivos en disco; solo imprime por consola.
//
// Estructura binaria verificada sobre common_zombie.ff (184/184 XMODEL) y
// zombie_theater.ff (242/242 XMODEL inline):
//
//   XModel (252 bytes fijos):
//     +0    u32     name (0xFFFFFFFF -> cadena ASCII terminada en NUL tras +252)
//     +4    u8      numBones
//     +5    u8      numRootBones
//     +6    u8      numsurfs
//     +7    u8      lodRampType
//     +8    u32     boneNames (0xFFFFFFFF -> numBones * 2 bytes)
//     +12   u32     parentList (0xFFFFFFFF -> (numBones - numRootBones) * 1 byte)
//     +16   u32     quats (0xFFFFFFFF -> (numBones - numRootBones) * 8 bytes)
//     +20   u32     trans (0xFFFFFFFF -> (numBones - numRootBones) * 16 bytes)
//     +24   u32     partClassification (0xFFFFFFFF -> numBones * 1 byte)
//     +28   u32     baseMat (0xFFFFFFFF -> numBones * 32 bytes)
//     +32   u32     surfs (0xFFFFFFFF -> numsurfs * 68 bytes + bloques por XSurface)
//     +36   u32     materialHandles (0xFFFFFFFF -> numsurfs * 4 bytes)
//     +40   4x32B   lodInfo[4] (cada uno: +0 f32 dist, +4 u16 numsurfs, +6 u16 surfIndex)
//     +188  f32     radius
//     +192  f32[3]  mins
//     +204  f32[3]  maxs
//     +216  i16     numLods
//
//   XSurface (68 bytes fijos, orden de following fijado por directiva reorder):
//     +1    u8      vertListCount
//     +4    u16     vertCount
//     +6    u16     triCount
//     +12   u32     triIndices (0xFFFFFFFF / 0x0000FFFF -> triCount * 6 bytes)
//     +16   i16[4]  vertInfo.vertCount[0..3]
//     +24   u32     vertInfo.vertsBlend
//     +28   u32     vertInfo.tensionData
//     +32   u32     verts0 (0xFFFFFFFF / 0x0000FFFF -> vertCount * 32 bytes)
//     +40   u32     vertList (0xFFFFFFFF -> vertListCount * 12 bytes + XSurfaceCollisionTree)
//
//   GfxPackedVertex (32 bytes):
//     +0..12   f32[3]  xyz (posición)
//     +12..16  f32     binormalSign
//     +16..20  u8[4]   color (RGBA)
//     +20..24  u32     texCoord (u = f16(hi16), v = f16(lo16))
//     +24..28  u8[4]   normal (PackedUnitVec: scale = (b3 + 192) / 32385,
//                              n = (b0..b2 - 127) * scale)
//     +28..32  u8[4]   tangent (PackedUnitVec)
//
// Uso:
//   node tools/zxmodel.mjs <archivo.ff> [--json] [--model <nombre>] [--obj <nombre>]

import { readFile } from "node:fs/promises";
import { inflateSync } from "node:zlib";
import { basename, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { parseAssetList } from "./zoneassets.mjs";

const MAGIC = "IWffu100";
const HEADER_LEN = 12;
const T5_PC_VERSION = 0x1d9;
const FOLLOWING = 0xffffffff;
const STREAM_VERT_SENTINEL = 0x0000ffff;
const XMODEL_FIXED_SIZE = 252;
const XSURFACE_FIXED_SIZE = 68;
const PACKED_VERTEX_SIZE = 32;

function isFollowingPtr(val, allowStreamSentinel = false) {
    return val === FOLLOWING || (allowStreamSentinel && val === STREAM_VERT_SENTINEL);
}

/**
 * Desempaqueta un vector unitario de 4 bytes (PackedUnitVec de T5).
 * Fórmula de referencia: Vec3UnpackUnitVecScaleBased en ObjWriterT5.cpp (Kisak/OAT).
 */
export function unpackUnitVec(b0, b1, b2, b3) {
    const scale = (b3 + 192.0) / 32385.0;
    return [
        (b0 - 127.0) * scale,
        (b1 - 127.0) * scale,
        (b2 - 127.0) * scale,
    ];
}

/**
 * Convierte un entero de 16 bits (IEEE 754 binary16) a número en coma flotante.
 */
export function unpackHalfFloat(u16) {
    const s = (u16 & 0x8000) >> 15;
    const e = (u16 & 0x7c00) >> 10;
    const f = u16 & 0x03ff;
    if (e === 0) {
        return (s ? -1 : 1) * Math.pow(2, -14) * (f / 1024);
    }
    if (e === 0x1f) {
        return f ? NaN : (s ? -Infinity : Infinity);
    }
    return (s ? -1 : 1) * Math.pow(2, e - 15) * (1 + f / 1024);
}

function isValidZonePtr(val) {
    return val === 0 || val === FOLLOWING || val >= 0x80000000;
}

function isModelNameChar(ch) {
    return (
        (ch >= 0x30 && ch <= 0x39) || // 0-9
        (ch >= 0x41 && ch <= 0x5a) || // A-Z
        (ch >= 0x61 && ch <= 0x7a) || // a-z
        ch === 0x5f || // _
        ch === 0x2d || // -
        ch === 0x2e || // .
        ch === 0x2f    // /
    );
}

/**
 * Comprueba si `base` apunta a una cabecera XModel válida (y opcionalmente seguida de `expectedName`).
 */
export function isValidXModelHeaderAt(d, base, expectedName = null) {
    if (base < 0 || base + XMODEL_FIXED_SIZE + 2 > d.length) {
        return false;
    }
    if (d.readUInt32LE(base) !== FOLLOWING) return false;
    const numBones = d[base + 4];
    const numRootBones = d[base + 5];
    const numsurfs = d[base + 6];
    const lodRampType = d[base + 7];
    if (numRootBones > numBones) return false;
    if (numsurfs === 0 || numsurfs > 128) return false;
    if (lodRampType > 8) return false;

    if (!isValidZonePtr(d.readUInt32LE(base + 8))) return false;  // boneNames
    if (!isValidZonePtr(d.readUInt32LE(base + 12))) return false; // parentList
    if (!isValidZonePtr(d.readUInt32LE(base + 16))) return false; // quats
    if (!isValidZonePtr(d.readUInt32LE(base + 20))) return false; // trans
    if (!isValidZonePtr(d.readUInt32LE(base + 24))) return false; // partClassification
    if (!isValidZonePtr(d.readUInt32LE(base + 28))) return false; // baseMat
    if (d.readUInt32LE(base + 32) !== FOLLOWING) return false;    // surfs
    if (!isValidZonePtr(d.readUInt32LE(base + 36))) return false; // materialHandles

    const numLods = d.readInt16LE(base + 216);
    if (numLods < 1 || numLods > 4) return false;

    const radius = d.readFloatLE(base + 188);
    if (!Number.isFinite(radius) || radius < 0 || radius > 1e6) return false;

    const nameStart = base + XMODEL_FIXED_SIZE;
    const nul = d.indexOf(0, nameStart);
    if (nul === -1 || nul === nameStart || nul - nameStart > 128) return false;

    if (expectedName !== null) {
        if (nul !== nameStart + expectedName.length) return false;
        return d.toString("latin1", nameStart, nul) === expectedName;
    }

    for (let i = nameStart; i < nul; i++) {
        if (!isModelNameChar(d[i])) return false;
    }
    return true;
}

/**
 * Busca en el stream inflado `d` el desplazamiento base de un XModel por su nombre.
 * Devuelve el offset de inicio de la estructura XModel (252 bytes antes del nombre) o -1.
 */
export function findXModelOffset(d, name, minOffset = 0) {
    const needle = Buffer.from(name + "\0", "latin1");
    let pos = Math.max(XMODEL_FIXED_SIZE, minOffset + XMODEL_FIXED_SIZE);
    while (pos <= d.length - needle.length) {
        const idx = d.indexOf(needle, pos);
        if (idx === -1) return -1;
        const base = idx - XMODEL_FIXED_SIZE;
        if (base > 0 && d[idx - 1] >= 0x20 && d[idx - 1] <= 0x7e) {
            // Evitar coincidencias de sufijo cuando el byte anterior pertenece a una cadena.
            // Aun así comprobamos la cabecera XModel por si el último byte de XModel coincide con ASCII.
        }
        if (isValidXModelHeaderAt(d, base, name)) {
            return base;
        }
        pos = idx + 1;
    }
    return -1;
}

/**
 * Decodifica un XModel completo en `base` dentro del stream inflado `d`.
 * Si `includeGeometry` es true, extrae los arrays de vértices e índices de cada superficie.
 */
export function decodeXModel(d, base, { includeGeometry = true } = {}) {
    if (base < 0 || base + XMODEL_FIXED_SIZE > d.length) {
        throw new Error(`Offset de XModel fuera de rango: ${base}`);
    }

    const namePtr = d.readUInt32LE(base + 0);
    const numBones = d[base + 4];
    const numRootBones = d[base + 5];
    const numsurfs = d[base + 6];
    const lodRampType = d[base + 7];
    const boneNamesPtr = d.readUInt32LE(base + 8);
    const parentListPtr = d.readUInt32LE(base + 12);
    const quatsPtr = d.readUInt32LE(base + 16);
    const transPtr = d.readUInt32LE(base + 20);
    const partClassPtr = d.readUInt32LE(base + 24);
    const baseMatPtr = d.readUInt32LE(base + 28);
    const surfsPtr = d.readUInt32LE(base + 32);
    const matHandlesPtr = d.readUInt32LE(base + 36);

    const lods = [];
    const numLods = d.readInt16LE(base + 216);
    for (let i = 0; i < Math.min(4, Math.max(0, numLods)); i++) {
        const lb = base + 40 + i * 32;
        lods.push({
            lod: i,
            dist: d.readFloatLE(lb + 0),
            numsurfs: d.readUInt16LE(lb + 4),
            surfIndex: d.readUInt16LE(lb + 6),
        });
    }

    const radius = d.readFloatLE(base + 188);
    const mins = [
        d.readFloatLE(base + 192),
        d.readFloatLE(base + 196),
        d.readFloatLE(base + 200),
    ];
    const maxs = [
        d.readFloatLE(base + 204),
        d.readFloatLE(base + 208),
        d.readFloatLE(base + 212),
    ];

    let c = base + XMODEL_FIXED_SIZE;
    let name = "";
    if (namePtr === FOLLOWING) {
        const nul = d.indexOf(0, c);
        if (nul === -1) throw new Error("Nombre de XModel sin terminador NUL");
        name = d.toString("latin1", c, nul);
        c = nul + 1;
    }

    const childBones = Math.max(0, numBones - numRootBones);
    if (boneNamesPtr === FOLLOWING) c += numBones * 2;
    if (parentListPtr === FOLLOWING) c += childBones * 1;
    if (quatsPtr === FOLLOWING) c += childBones * 8;
    if (transPtr === FOLLOWING) c += childBones * 16;
    if (partClassPtr === FOLLOWING) c += numBones * 1;
    if (baseMatPtr === FOLLOWING) c += numBones * 32;

    const surfaces = [];
    if (surfsPtr === FOLLOWING) {
        const surfsTable = c;
        c += numsurfs * XSURFACE_FIXED_SIZE;
        if (c > d.length) throw new Error(`Tabla XSurface truncada en XModel "${name}"`);

        for (let i = 0; i < numsurfs; i++) {
            const sb = surfsTable + i * XSURFACE_FIXED_SIZE;
            const vertListCount = d[sb + 1];
            const vertCount = d.readUInt16LE(sb + 4);
            const triCount = d.readUInt16LE(sb + 6);
            const triIndicesPtr = d.readUInt32LE(sb + 12);
            const vc0 = d.readInt16LE(sb + 16);
            const vc1 = d.readInt16LE(sb + 18);
            const vc2 = d.readInt16LE(sb + 20);
            const vc3 = d.readInt16LE(sb + 22);
            const vertsBlendPtr = d.readUInt32LE(sb + 24);
            const tensionDataPtr = d.readUInt32LE(sb + 28);
            const verts0Ptr = d.readUInt32LE(sb + 32);
            const vertListPtr = d.readUInt32LE(sb + 40);

            // 1. vertInfo
            if (vertsBlendPtr === FOLLOWING) {
                const count = vc0 + 3 * vc1 + 5 * vc2 + 7 * vc3;
                c += count * 2;
            }
            if (tensionDataPtr === FOLLOWING) {
                const count = vc0 + vc1 + vc2 + vc3;
                c += count * 48;
            }

            // 2. verts0
            let vertsOffset = -1;
            if (isFollowingPtr(verts0Ptr, true)) {
                vertsOffset = c;
                c += vertCount * PACKED_VERTEX_SIZE;
            }

            // 3. vertList + XSurfaceCollisionTree
            if (vertListPtr === FOLLOWING) {
                const vlTable = c;
                c += vertListCount * 12;
                for (let j = 0; j < vertListCount; j++) {
                    const vlb = vlTable + j * 12;
                    const collisionTreePtr = d.readUInt32LE(vlb + 8);
                    if (collisionTreePtr === FOLLOWING) {
                        const ctb = c;
                        c += 40;
                        const nodeCount = d.readUInt32LE(ctb + 24);
                        const nodesPtr = d.readUInt32LE(ctb + 28);
                        const leafCount = d.readUInt32LE(ctb + 32);
                        const leafsPtr = d.readUInt32LE(ctb + 36);
                        if (nodesPtr === FOLLOWING) c += nodeCount * 16;
                        if (leafsPtr === FOLLOWING) c += leafCount * 2;
                    }
                }
            }

            // 4. triIndices
            let trisOffset = -1;
            if (isFollowingPtr(triIndicesPtr, true)) {
                trisOffset = c;
                c += triCount * 6;
            }

            if (c > d.length) {
                throw new Error(`Superficie ${i} truncada en XModel "${name}"`);
            }

            let vertices = [];
            let indices = [];
            let allIndicesValid = true;

            if (includeGeometry && vertsOffset >= 0) {
                vertices = new Array(vertCount);
                for (let v = 0; v < vertCount; v++) {
                    const vp = vertsOffset + v * PACKED_VERTEX_SIZE;
                    const x = d.readFloatLE(vp + 0);
                    const y = d.readFloatLE(vp + 4);
                    const z = d.readFloatLE(vp + 8);
                    const rgba = [d[vp + 16], d[vp + 17], d[vp + 18], d[vp + 19]];
                    const rawTc = d.readUInt32LE(vp + 20);
                    const uv = [
                        unpackHalfFloat((rawTc >>> 16) & 0xffff),
                        unpackHalfFloat(rawTc & 0xffff),
                    ];
                    const normal = unpackUnitVec(d[vp + 24], d[vp + 25], d[vp + 26], d[vp + 27]);
                    vertices[v] = { position: [x, y, z], normal, uv, color: rgba };
                }
            }

            if (trisOffset >= 0) {
                if (includeGeometry) {
                    indices = new Array(triCount * 3);
                }
                for (let t = 0; t < triCount; t++) {
                    const tp = trisOffset + t * 6;
                    const i0 = d.readUInt16LE(tp + 0);
                    const i1 = d.readUInt16LE(tp + 2);
                    const i2 = d.readUInt16LE(tp + 4);
                    if (i0 >= vertCount || i1 >= vertCount || i2 >= vertCount) {
                        allIndicesValid = false;
                    }
                    if (includeGeometry) {
                        indices[t * 3 + 0] = i0;
                        indices[t * 3 + 1] = i1;
                        indices[t * 3 + 2] = i2;
                    }
                }
            }

            surfaces.push({
                index: i,
                vertCount,
                triCount,
                vertsOffset,
                trisOffset,
                allIndicesValid,
                vertices,
                indices,
            });
        }
    }

    return {
        name,
        offset: base,
        surfsEndOffset: c,
        numBones,
        numRootBones,
        numsurfs,
        lodRampType,
        numLods,
        bounds: { radius, mins, maxs },
        lods,
        surfaces,
        hasMaterialHandles: matHandlesPtr === FOLLOWING,
    };
}

/**
 * Combina las superficies de un LOD (por defecto LOD 0) en una malla única
 * lista para exportar a Wavefront OBJ o pasar a un buffer de GPU.
 */
export function buildLodMesh(model, lodIndex = 0) {
    const lod = model.lods[lodIndex] ?? { surfIndex: 0, numsurfs: model.surfaces.length };
    const start = lod.surfIndex;
    const end = Math.min(model.surfaces.length, start + lod.numsurfs);

    const vertices = [];
    const indices = [];

    for (let s = start; s < end; s++) {
        const surf = model.surfaces[s];
        const baseVertex = vertices.length;
        for (const v of surf.vertices) {
            vertices.push(v);
        }
        for (const idx of surf.indices) {
            indices.push(baseVertex + idx);
        }
    }

    return {
        name: model.name,
        lod: lodIndex,
        surfaceCount: end - start,
        vertexCount: vertices.length,
        triangleCount: indices.length / 3,
        bounds: model.bounds,
        vertices,
        indices,
    };
}

/**
 * Convierte un XModel decodificado al formato de texto Wavefront OBJ (en memoria).
 */
export function toWavefrontObj(model, lodIndex = 0) {
    const lod = model.lods[lodIndex] ?? { surfIndex: 0, numsurfs: model.surfaces.length };
    const start = lod.surfIndex;
    const end = Math.min(model.surfaces.length, start + lod.numsurfs);

    const lines = [
        `# XModel: ${model.name} (LOD ${lodIndex})`,
        `# Superficies: ${end - start}`,
        `o ${model.name}`,
    ];

    let vertexBase = 1;
    for (let s = start; s < end; s++) {
        const surf = model.surfaces[s];
        lines.push(`g surf_${s}`);
        for (const v of surf.vertices) {
            lines.push(`v ${v.position[0].toFixed(6)} ${v.position[1].toFixed(6)} ${v.position[2].toFixed(6)}`);
        }
        for (const v of surf.vertices) {
            lines.push(`vt ${v.uv[0].toFixed(6)} ${v.uv[1].toFixed(6)}`);
        }
        for (const v of surf.vertices) {
            lines.push(`vn ${v.normal[0].toFixed(6)} ${v.normal[1].toFixed(6)} ${v.normal[2].toFixed(6)}`);
        }
        for (let t = 0; t < surf.indices.length; t += 3) {
            const a = vertexBase + surf.indices[t + 0];
            const b = vertexBase + surf.indices[t + 1];
            const c = vertexBase + surf.indices[t + 2];
            lines.push(`f ${a}/${a}/${a} ${b}/${b}/${b} ${c}/${c}/${c}`);
        }
        vertexBase += surf.vertices.length;
    }

    return lines.join("\n") + "\n";
}

/**
 * Escanea el stream inflado `d` a partir de `bodyOffset` en busca de todos los
 * XMODEL inline y valida sus superficies e índices.
 */
export function scanInlineXModels(d) {
    const parsed = parseAssetList(d);
    const declaredTotal = parsed.types.find((t) => t.name === "XMODEL")?.count ?? 0;
    const marker = Buffer.from([0xff, 0xff, 0xff, 0xff]);
    const results = [];
    let pos = parsed.bodyOffset;

    while (pos <= d.length - XMODEL_FIXED_SIZE) {
        const idx = d.indexOf(marker, pos);
        if (idx === -1 || idx > d.length - XMODEL_FIXED_SIZE) break;
        if (!isValidXModelHeaderAt(d, idx)) {
            pos = idx + 1;
            continue;
        }
        try {
            const model = decodeXModel(d, idx, { includeGeometry: false });
            if (model.surfaces.length > 0 && model.surfaces.every((s) => s.allIndicesValid && s.vertCount > 0 && s.triCount > 0)) {
                const totalVerts = model.surfaces.reduce((acc, s) => acc + s.vertCount, 0);
                const totalTris = model.surfaces.reduce((acc, s) => acc + s.triCount, 0);
                results.push({
                    name: model.name,
                    found: true,
                    offset: idx,
                    numBones: model.numBones,
                    numLods: model.numLods,
                    numsurfs: model.numsurfs,
                    lod0Surfs: model.lods[0]?.numsurfs ?? model.numsurfs,
                    totalVerts,
                    totalTris,
                    allIndicesValid: true,
                    bounds: model.bounds,
                });
                pos = model.surfsEndOffset;
                continue;
            }
        } catch {
            // Falso positivo de cabecera; continuar escaneando
        }
        pos = idx + 1;
    }

    return {
        declaredCount: declaredTotal,
        foundCount: results.length,
        allValidCount: results.filter((r) => r.allIndicesValid).length,
        models: results,
    };
}

export async function inspectXModelsFile(filePath, options = {}) {
    const raw = await readFile(filePath);
    if (raw.length < HEADER_LEN) {
        throw new Error(`Archivo demasiado corto (${raw.length} bytes)`);
    }
    const magic = raw.toString("ascii", 0, 8);
    const version = raw.readUInt32LE(8);
    if (magic !== MAGIC || version !== T5_PC_VERSION) {
        throw new Error(`Cabecera no soportada: magic=${JSON.stringify(magic)} version=0x${version.toString(16)}`);
    }
    const inflated = inflateSync(raw.subarray(HEADER_LEN));

    if (options.modelName) {
        const base = findXModelOffset(inflated, options.modelName);
        if (base === -1) {
            throw new Error(`No se encontró ningún XMODEL inline con nombre "${options.modelName}"`);
        }
        const model = decodeXModel(inflated, base, { includeGeometry: true });
        return { file: basename(filePath), mode: "single", model };
    }

    const report = scanInlineXModels(inflated);
    return {
        file: basename(filePath),
        mode: "scan",
        streamBytes: inflated.length,
        ...report,
    };
}

async function main(argv) {
    const args = argv.slice(2);
    let json = false;
    let modelName = null;
    let objName = null;
    let fileArg = null;

    for (let i = 0; i < args.length; i++) {
        const a = args[i];
        if (a === "--json") {
            json = true;
        } else if (a === "--model") {
            modelName = args[++i];
            if (!modelName) {
                console.error("Falta el nombre tras --model");
                return 2;
            }
        } else if (a === "--obj") {
            objName = args[++i];
            if (!objName) {
                console.error("Falta el nombre tras --obj");
                return 2;
            }
        } else if (!a.startsWith("-") && !fileArg) {
            fileArg = a;
        } else {
            console.error(`Argumento no reconocido: ${a}`);
            return 2;
        }
    }

    if (!fileArg) {
        console.error("Uso: node tools/zxmodel.mjs <archivo.ff> [--json] [--model <nombre>] [--obj <nombre>]");
        return 2;
    }

    try {
        const targetModel = objName ?? modelName;
        const res = await inspectXModelsFile(resolve(fileArg), { modelName: targetModel });

        if (objName) {
            process.stdout.write(toWavefrontObj(res.model, 0));
            return 0;
        }

        if (json) {
            if (res.mode === "single") {
                const mesh = buildLodMesh(res.model, 0);
                console.log(JSON.stringify({
                    file: res.file,
                    name: res.model.name,
                    offset: res.model.offset,
                    numBones: res.model.numBones,
                    numLods: res.model.numLods,
                    numsurfs: res.model.numsurfs,
                    bounds: res.model.bounds,
                    lods: res.model.lods,
                    lod0Summary: {
                        surfaceCount: mesh.surfaceCount,
                        vertexCount: mesh.vertexCount,
                        triangleCount: mesh.triangleCount,
                        sampleVertices: mesh.vertices.slice(0, 3),
                        sampleTriangle: mesh.indices.slice(0, 3),
                    },
                }, null, 2));
            } else {
                console.log(JSON.stringify(res, null, 2));
            }
            return 0;
        }

        if (res.mode === "single") {
            const m = res.model;
            const mesh = buildLodMesh(m, 0);
            console.log(`XMODEL: ${m.name} (${res.file} @ ${m.offset})`);
            console.log(`Huesos: ${m.numBones} (raíz: ${m.numRootBones}) · LODs: ${m.numLods} · Superficies totales: ${m.numsurfs}`);
            console.log(`Bounds: radio=${m.bounds.radius.toFixed(3)} mins=[${m.bounds.mins.map((v) => v.toFixed(2)).join(", ")}] maxs=[${m.bounds.maxs.map((v) => v.toFixed(2)).join(", ")}]`);
            console.log(`LOD 0: ${mesh.surfaceCount} sup · ${mesh.vertexCount} vértices · ${mesh.triangleCount} triángulos`);
            for (const s of m.surfaces) {
                console.log(`  surf[${s.index}]: verts=${s.vertCount} (@${s.vertsOffset}) tris=${s.triCount} (@${s.trisOffset}) indicesOK=${s.allIndicesValid}`);
            }
            return 0;
        }

        console.log(`Zona: ${res.file}`);
        console.log(`XMODEL declarados: ${res.declaredCount} · XMODEL inline decodificados: ${res.foundCount} (${res.allValidCount}/${res.foundCount} con geometría e índices válidos)`);
        return res.foundCount > 0 && res.allValidCount === res.foundCount ? 0 : 1;
    } catch (err) {
        console.error(`Error: ${err.message}`);
        return 1;
    }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    main(process.argv).then((code) => process.exit(code));
}
