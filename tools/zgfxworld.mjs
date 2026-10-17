#!/usr/bin/env node
// Sonda de SOLO LECTURA y extractor de geometría espacial, materiales y texturas
// de mundo (GFXWORLD) para FastFiles (.ff) de BO1 PC (T5).
//
// Estructura verificada byte a byte en zombie_theater.ff (GFXWORLD @ offset 49006423):
//   - GfxWorld (1084 bytes fijos):
//       surfaceCount:        9141
//       cellCount:           33 (GfxCell @ 49357924)
//       materialMemoryCount: 812 (MaterialMemory @ 86663605)
//       staticSurfaceCount:  8289 (dpvs::sortedSurfIndex @ 87427878)
//       smodelCount:         3326 (dpvs::smodelInsts @ 87444456)
//       dpvs::surfaces:      9141 × 80 B (@ 87577496)
//   - GfxWorldDraw (@ base + 344):
//       reflectionProbes:    2 (@ 49482209, *reflection_probe1 DXT1 256×256×6 @ 49482567)
//       lightmaps:           2 (@ 49744791, *lightmap0/1 primary/secondary/secondaryb)
//       vertexCount:         471280 (draw::vd::vertices @ 57609643, 44 B/vértice)
//       vertexLayerDataSize: 479708 (draw::vld::data @ 78345963)
//       indexCount:          1015134 (draw::indices @ 78825671, uint16_t local a firstVertex)
//
// Uso:
//   node tools/zgfxworld.mjs <archivo.ff> [--json] [--room <0..7>] [--cell <0..32>] [--obj [room]]

import { readFile } from "node:fs/promises";
import { inflateSync } from "node:zlib";
import { basename, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { unpackUnitVec } from "./zxmodel.mjs";

const MAGIC = "IWffu100";
const HEADER_LEN = 12;
const T5_PC_VERSION = 0x1d9;
const FOLLOWING = 0xffffffff;
const LOADDEF_FOLLOWING = 0xfffffffe;
const GFXWORLD_FIXED_SIZE = 1084;
const DRAW_OFFSET_IN_WORLD = 344;
const LIGHTGRID_OFFSET_IN_WORLD = 536;
const DPVS_OFFSET_IN_WORLD = 836;
const GFXWORLD_VERTEX_SIZE = 44;
const GFXSURFACE_SIZE = 80;

export const D3DFMT_R5G6B5 = 23;
export const D3DFMT_G16R16 = 34;
export const D3DFMT_L8 = 50;
export const D3DFMT_DXT1 = 0x31545844;

/**
 * Agrupación arquitectónica de las 33 celdas PVS (GfxCell) y BrushModels de Kino der Toten.
 */
export const KINO_ROOMS = [
    {
        id: 0,
        key: "lobby",
        name: "Sala Inicial y Balcones (Lobby)",
        cells: [15, 16, 17, 18, 19],
        includeBrushModels: false,
    },
    {
        id: 1,
        key: "foyer",
        name: "Vestíbulo Central y Comedor (Foyer)",
        cells: [6],
        includeBrushModels: false,
    },
    {
        id: 2,
        key: "theater",
        name: "Auditorio Principal y Escenario",
        cells: [1, 2, 7],
        includeBrushModels: false,
    },
    {
        id: 3,
        key: "east_wing",
        name: "Ala Este: Camerinos y Sala Superior",
        cells: [3, 4, 8, 9, 10, 11, 12, 13, 14],
        includeBrushModels: false,
    },
    {
        id: 4,
        key: "alley",
        name: "Callejón Trasero Este (Double Tap)",
        cells: [5, 26, 27],
        includeBrushModels: false,
    },
    {
        id: 5,
        key: "west_wing",
        name: "Ala Oeste: Crematorio y Trampa de Fuego",
        cells: [20, 21, 22, 23],
        includeBrushModels: false,
    },
    {
        id: 6,
        key: "courtyard",
        name: "Patio Exterior y Calles",
        cells: [0, 24, 25, 28, 29, 30, 31, 32],
        includeBrushModels: false,
        maxCoordBounds: 3200,
    },
    {
        id: 7,
        key: "doors_brushes",
        name: "Puertas, Barricadas y Modelos BSP",
        cells: [],
        includeBrushModels: true,
    },
];

const isFol = (v) => v === FOLLOWING || v === LOADDEF_FOLLOWING;

/**
 * Clasifica el nombre real de un Material de BO1 en una categoría semántica y color base RGB.
 */
export function classifyMaterialColor(materialName = "") {
    const n = materialName.toLowerCase();
    if (n.includes("sky")) {
        return { category: "sky", skip: true, rgb: [0.35, 0.48, 0.68] };
    }
    if (n.includes("caulk") || n.includes("portal") || n.includes("shadow") || n.includes("clip")) {
        return { category: "caulk", skip: true, rgb: [0.5, 0.5, 0.5] };
    }
    if (n.includes("curtain") || n.includes("velvet") || n.includes("carpet") || n.includes("drape") || n.includes("seat")) {
        return { category: "velvet_red", skip: false, rgb: [0.68, 0.20, 0.18] };
    }
    if (n.includes("wood") || n.includes("parquet") || n.includes("plank") || n.includes("door") || n.includes("chair") || n.includes("bench")) {
        return { category: "wood", skip: false, rgb: [0.62, 0.43, 0.26] };
    }
    if (n.includes("brick") || n.includes("cobble") || n.includes("tile") || n.includes("roof") || n.includes("marble")) {
        return { category: "brick_stone", skip: false, rgb: [0.64, 0.49, 0.40] };
    }
    if (n.includes("metal") || n.includes("iron") || n.includes("steel") || n.includes("pipe") || n.includes("duct") || n.includes("cage") || n.includes("grate")) {
        return { category: "metal", skip: false, rgb: [0.46, 0.50, 0.55] };
    }
    if (n.includes("glass") || n.includes("window") || n.includes("mirror") || n.includes("ice")) {
        return { category: "glass", skip: false, rgb: [0.55, 0.72, 0.82] };
    }
    if (n.includes("foliage") || n.includes("tree") || n.includes("ivy") || n.includes("bush") || n.includes("grass")) {
        return { category: "foliage", skip: false, rgb: [0.36, 0.52, 0.32] };
    }
    if (n.includes("ter_") || n.includes("dirt") || n.includes("mud") || n.includes("rubble") || n.includes("trash") || n.includes("ash")) {
        return { category: "terrain_rubble", skip: false, rgb: [0.48, 0.44, 0.38] };
    }
    if (n.includes("plaster") || n.includes("wallpaper") || n.includes("stucco") || n.includes("trim") || n.includes("ceiling")) {
        return { category: "plaster_wall", skip: false, rgb: [0.78, 0.73, 0.64] };
    }
    if (n.includes("concrete") || n.includes("cement") || n.includes("asphalt") || n.includes("sidewalk") || n.includes("floor") || n.includes("wall")) {
        return { category: "concrete", skip: false, rgb: [0.66, 0.65, 0.62] };
    }
    return { category: "default_surface", skip: false, rgb: [0.72, 0.70, 0.66] };
}

/**
 * Localiza el asset GFXWORLD en el stream inflado y extrae sus metadatos de cabecera.
 */
export function locateGfxWorld(d) {
    const limit = d.length - GFXWORLD_FIXED_SIZE;
    for (let pos = 0; pos < limit; pos++) {
        const drawBase = pos + DRAW_OFFSET_IN_WORLD;
        if (d.readUInt32LE(drawBase + 160) === FOLLOWING && d.readUInt32LE(drawBase + 188) === FOLLOWING) {
            const vertexCount = d.readUInt32LE(drawBase + 156);
            const indexCount = d.readInt32LE(drawBase + 184);

            if (vertexCount > 0 && vertexCount < 2000000 && indexCount > 0 && indexCount < 5000000) {
                const minX = d.readFloatLE(pos + 600);
                const maxX = d.readFloatLE(pos + 612);

                if (Number.isFinite(minX) && Number.isFinite(maxX) && maxX > minX) {
                    const planeCount = d.readInt32LE(pos + 8);
                    const nodeCount = d.readInt32LE(pos + 12);
                    const surfaceCount = d.readInt32LE(pos + 16);
                    const cellCount = d.readInt32LE(pos + 320);
                    const materialMemoryCount = d.readInt32LE(pos + 628);
                    const dpvsBase = pos + DPVS_OFFSET_IN_WORLD;
                    const smodelCount = d.readUInt32LE(dpvsBase + 0);
                    const staticSurfaceCount = d.readUInt32LE(dpvsBase + 8);

                    const mins = [
                        d.readFloatLE(pos + 600),
                        d.readFloatLE(pos + 604),
                        d.readFloatLE(pos + 608),
                    ];
                    const maxs = [
                        d.readFloatLE(pos + 612),
                        d.readFloatLE(pos + 616),
                        d.readFloatLE(pos + 620),
                    ];

                    return {
                        baseOffset: pos,
                        planeCount,
                        nodeCount,
                        surfaceCount,
                        cellCount,
                        vertexCount,
                        indexCount,
                        materialMemoryCount,
                        staticSurfaceCount,
                        smodelCount,
                        mins,
                        maxs,
                    };
                }
            }
        }
    }
    return null;
}

/**
 * Recorre de forma determinista la estructura serializada de GfxWorld en el stream
 * para obtener los desplazamientos exactos de celdas, lightmaps, vértices, índices,
 * materiales y superficies (dpvs::surfaces).
 */
export function parseGfxWorldLayout(d, info) {
    const base = info.baseOffset;
    const drawBase = base + DRAW_OFFSET_IN_WORLD;
    const lightGridBase = base + LIGHTGRID_OFFSET_IN_WORLD;
    const dpvsBase = base + DPVS_OFFSET_IN_WORLD;

    const surfaceCount = d.readInt32LE(base + 16);
    const cellCount = d.readInt32LE(base + 320);
    const reflectionProbeCount = d.readUInt32LE(drawBase + 0);
    const lightmapCount = d.readInt32LE(drawBase + 12);
    const vertexCount = d.readUInt32LE(drawBase + 156);
    const vertexLayerDataSize = d.readUInt32LE(drawBase + 168);
    const indexCount = d.readInt32LE(drawBase + 184);
    const modelCount = d.readInt32LE(base + 592);
    const materialMemoryCount = d.readInt32LE(base + 628);
    const smodelCount = d.readUInt32LE(dpvsBase + 0);
    const staticSurfaceCount = d.readUInt32LE(dpvsBase + 8);

    const skipCString = (pos) => {
        const end = d.indexOf(0, pos);
        return end === -1 ? pos + 1 : end + 1;
    };

    const readGfxImage = (pos) => {
        const texPtr = d.readUInt32LE(pos);
        const mapType = d[pos + 4];
        const semantic = d[pos + 5];
        const category = d[pos + 6];
        const width = d.readUInt16LE(pos + 20);
        const height = d.readUInt16LE(pos + 22);
        const depth = d.readUInt16LE(pos + 24);
        const streaming = d[pos + 27];
        const namePtr = d.readUInt32LE(pos + 44);
        let c = pos + 52;
        let name = "";
        if (namePtr === FOLLOWING) {
            const end = d.indexOf(0, c);
            name = end !== -1 ? d.toString("latin1", c, end) : "";
            c = end !== -1 ? end + 1 : c + 1;
        }
        let loadDefStart = -1;
        let dataStart = -1;
        let resourceSize = 0;
        let format = 0;
        let levelCount = 0;
        let flags = 0;
        if (isFol(texPtr)) {
            loadDefStart = c;
            levelCount = d[c];
            flags = d[c + 1];
            format = d.readInt32LE(c + 4);
            resourceSize = d.readInt32LE(c + 8);
            dataStart = c + 12;
            c += 12 + resourceSize;
        }
        return {
            offset: pos,
            next: c,
            name,
            mapType,
            semantic,
            category,
            width,
            height,
            depth,
            streaming,
            loadDefStart,
            dataStart,
            resourceSize,
            format,
            levelCount,
            flags,
        };
    };

    let c = base + GFXWORLD_FIXED_SIZE;
    let worldName = "";
    let baseName = "";
    if (d.readUInt32LE(base + 0) === FOLLOWING) {
        worldName = d.toString("latin1", c, d.indexOf(0, c));
        c = skipCString(c);
    }
    if (d.readUInt32LE(base + 4) === FOLLOWING) {
        baseName = d.toString("latin1", c, d.indexOf(0, c));
        c = skipCString(c);
    }
    if (d.readUInt32LE(base + 24) === FOLLOWING) c += d.readInt32LE(base + 20) * 32;
    if (d.readUInt32LE(base + 32) === FOLLOWING) c += d.readInt32LE(base + 28) * 4;
    const skyStartSurfsOffset = d.readUInt32LE(base + 40) === FOLLOWING ? c : -1;
    if (d.readUInt32LE(base + 40) === FOLLOWING) c += d.readInt32LE(base + 36) * 4;
    let skyImage = null;
    if (isFol(d.readUInt32LE(base + 44))) {
        skyImage = readGfxImage(c);
        c = skyImage.next;
    }
    if (d.readUInt32LE(base + 52) === FOLLOWING) c = skipCString(c);
    if (d.readUInt32LE(base + 236) === FOLLOWING) {
        const defPtr = d.readUInt32LE(c + 352);
        c += 368;
        if (defPtr === FOLLOWING) {
            const ldName = d.readUInt32LE(c);
            const ldImg = d.readUInt32LE(c + 4);
            c += 16;
            if (ldName === FOLLOWING) c = skipCString(c);
            if (isFol(ldImg)) c = readGfxImage(c).next;
        }
    }
    if (d.readUInt32LE(base + 268) === FOLLOWING) c += d.readUInt32LE(base + 264) * 32;
    if (d.readUInt32LE(base + 276) === FOLLOWING) c += d.readUInt32LE(base + 272) * 16;
    if (d.readUInt32LE(base + 284) === FOLLOWING) c += d.readUInt32LE(base + 280) * 16;
    if (d.readUInt32LE(base + 292) === FOLLOWING) c += d.readUInt32LE(base + 288) * 24;
    if (d.readUInt32LE(base + 300) === FOLLOWING) c += d.readUInt32LE(base + 296) * 16;
    if (d.readUInt32LE(base + 324) === FOLLOWING) c += d.readInt32LE(base + 8) * 20;
    if (d.readUInt32LE(base + 328) === FOLLOWING) c += d.readInt32LE(base + 12) * 2;

    // Celdas espaciales PVS (GfxCell)
    let cellsStart = -1;
    const cells = [];
    if (d.readUInt32LE(base + 340) === FOLLOWING && cellCount > 0) {
        cellsStart = c;
        c += cellCount * 56;
        for (let i = 0; i < cellCount; i++) {
            const ce = cellsStart + i * 56;
            const mins = [d.readFloatLE(ce), d.readFloatLE(ce + 4), d.readFloatLE(ce + 8)];
            const maxs = [d.readFloatLE(ce + 12), d.readFloatLE(ce + 16), d.readFloatLE(ce + 20)];
            const aabbTreeCount = d.readInt32LE(ce + 24);
            const aabbTreePtr = d.readUInt32LE(ce + 28);
            const portalCount = d.readInt32LE(ce + 32);
            const portalsPtr = d.readUInt32LE(ce + 36);
            const cullGroupCount = d.readInt32LE(ce + 40);
            const cullGroupsPtr = d.readUInt32LE(ce + 44);
            const refProbeCount = d[ce + 48];
            const refProbesPtr = d.readUInt32LE(ce + 52);

            let rootSurfCount = 0;
            let rootStartSurfIndex = 0;
            if (aabbTreePtr === FOLLOWING) {
                const treeStart = c;
                rootSurfCount = d.readUInt16LE(treeStart + 26);
                rootStartSurfIndex = d.readUInt16LE(treeStart + 28);
                c += aabbTreeCount * 40;
                for (let t = 0; t < aabbTreeCount; t++) {
                    const te = treeStart + t * 40;
                    const smodelIndexCount = d.readUInt16LE(te + 30);
                    const smodelIndexesPtr = d.readUInt32LE(te + 32);
                    if (smodelIndexesPtr === FOLLOWING) c += smodelIndexCount * 2;
                }
            }
            if (portalsPtr === FOLLOWING) {
                const portStart = c;
                c += portalCount * 68;
                for (let p = 0; p < portalCount; p++) {
                    const pe = portStart + p * 68;
                    const vPtr = d.readUInt32LE(pe + 36);
                    const vCount = d[pe + 40];
                    if (vPtr === FOLLOWING) c += vCount * 12;
                }
            }
            if (cullGroupsPtr === FOLLOWING) c += cullGroupCount * 4;
            if (refProbesPtr === FOLLOWING) c += refProbeCount * 1;
            cells.push({
                index: i,
                mins,
                maxs,
                surfaceCount: rootSurfCount,
                startSurfIndex: rootStartSurfIndex,
            });
        }
    }

    // GfxWorldDraw::reflectionProbes
    const reflectionProbes = [];
    if (d.readUInt32LE(drawBase + 4) === FOLLOWING && reflectionProbeCount > 0) {
        const rpStart = c;
        c += reflectionProbeCount * 24;
        for (let i = 0; i < reflectionProbeCount; i++) {
            const rpe = rpStart + i * 24;
            const imgPtr = d.readUInt32LE(rpe + 12);
            const volPtr = d.readUInt32LE(rpe + 16);
            const volCount = d.readUInt32LE(rpe + 20);
            if (isFol(imgPtr)) {
                const img = readGfxImage(c);
                reflectionProbes.push(img);
                c = img.next;
            }
            if (volPtr === FOLLOWING) {
                const vs = c;
                c += volCount * 68;
                for (let v = 0; v < volCount; v++) {
                    const ve = vs + v * 68;
                    if (d.readUInt32LE(ve + 64) === FOLLOWING) c += d.readUInt16LE(ve + 60) * 2;
                }
            }
        }
    }

    // GfxWorldDraw::lightmaps
    const lightmaps = [];
    if (d.readUInt32LE(drawBase + 16) === FOLLOWING && lightmapCount > 0) {
        const lmStart = c;
        c += lightmapCount * 12;
        for (let i = 0; i < lightmapCount; i++) {
            const lme = lmStart + i * 12;
            const p0 = d.readUInt32LE(lme + 0);
            const p1 = d.readUInt32LE(lme + 4);
            const p2 = d.readUInt32LE(lme + 8);
            const entry = { index: i, primary: null, secondary: null, secondaryB: null };
            if (isFol(p0)) { entry.primary = readGfxImage(c); c = entry.primary.next; }
            if (isFol(p1)) { entry.secondary = readGfxImage(c); c = entry.secondary.next; }
            if (isFol(p2)) { entry.secondaryB = readGfxImage(c); c = entry.secondaryB.next; }
            lightmaps.push(entry);
        }
    }

    for (let i = 0; i < 31; i++) {
        const p = d.readUInt32LE(drawBase + 32 + i * 4);
        if (isFol(p)) c = readGfxImage(c).next;
    }

    // Buffers principales de vértices e índices de GfxWorldDraw
    const vStart = c;
    const vBytes = vertexCount * GFXWORLD_VERTEX_SIZE;
    c += vBytes;
    const vldStart = c;
    if (d.readUInt32LE(drawBase + 172) === FOLLOWING) c += vertexLayerDataSize;
    const iStart = c;
    const iBytes = indexCount * 2;
    c += iBytes;

    // Si estamos ante un buffer sintético corto (sin el resto de bloques), devolvemos lo ya localizado
    if (c >= d.length) {
        return {
            worldName,
            baseName,
            vStart,
            vBytes,
            vldStart,
            iStart,
            iBytes,
            cellsStart,
            cells,
            reflectionProbes,
            lightmaps,
            outdoorImage: null,
            matMemStart: -1,
            materials: [],
            sortedSurfIndexStart: -1,
            smodelInstsStart: -1,
            surfacesStart: -1,
            smodelDrawInstsStart: -1,
            skyStartSurfsOffset,
            smodelCount: 0,
        };
    }

    // GfxLightGrid
    if (d.readUInt32LE(lightGridBase + 28) === FOLLOWING) {
        const rowAxis = d.readUInt32LE(lightGridBase + 20);
        const minRow = d.readUInt16LE(lightGridBase + 8 + rowAxis * 2);
        const maxRow = d.readUInt16LE(lightGridBase + 14 + rowAxis * 2);
        c += (maxRow - minRow + 1) * 2;
    }
    if (d.readUInt32LE(lightGridBase + 36) === FOLLOWING) c += d.readUInt32LE(lightGridBase + 32);
    if (d.readUInt32LE(lightGridBase + 44) === FOLLOWING) c += d.readUInt32LE(lightGridBase + 40) * 4;
    if (d.readUInt32LE(lightGridBase + 52) === FOLLOWING) c += d.readUInt32LE(lightGridBase + 48) * 168;

    // GfxBrushModel
    const modelsStart = d.readUInt32LE(base + 596) === FOLLOWING ? c : -1;
    if (d.readUInt32LE(base + 596) === FOLLOWING) c += modelCount * 60;

    // MaterialMemory (812 materiales en zombie_theater.ff)
    let matMemStart = -1;
    const materials = [];
    if (d.readUInt32LE(base + 632) === FOLLOWING && materialMemoryCount > 0) {
        matMemStart = c;
        c += materialMemoryCount * 8;
        for (let i = 0; i < materialMemoryCount; i++) {
            const mp = d.readUInt32LE(matMemStart + i * 8);
            const memory = d.readInt32LE(matMemStart + i * 8 + 4);
            if (isFol(mp)) {
                const mBase = c;
                c += 192;
                let name = "";
                if (d.readUInt32LE(mBase) === FOLLOWING) {
                    name = d.toString("latin1", c, d.indexOf(0, c));
                    c = skipCString(c);
                }
                const texCount = d[mBase + 170];
                const constCount = d[mBase + 171];
                const sbCount = d[mBase + 172];
                const ttPtr = d.readUInt32LE(mBase + 180);
                const ctPtr = d.readUInt32LE(mBase + 184);
                const sbPtr = d.readUInt32LE(mBase + 188);
                const textures = [];
                if (isFol(ttPtr)) {
                    const ttStart = c;
                    c += texCount * 16;
                    for (let j = 0; j < texCount; j++) {
                        const sem = d[ttStart + j * 16 + 7];
                        const uPtr = d.readUInt32LE(ttStart + j * 16 + 12);
                        if (sem !== 11 && isFol(uPtr)) {
                            const img = readGfxImage(c);
                            c = img.next;
                            textures.push({
                                semantic: sem,
                                name: img.name,
                                category: img.category,
                                width: img.width,
                                height: img.height,
                                resourceSize: img.resourceSize,
                            });
                        } else {
                            textures.push({
                                semantic: sem,
                                name: null,
                                ptr: uPtr,
                                resourceSize: 0,
                            });
                        }
                    }
                }
                if (isFol(ctPtr)) c += constCount * 32;
                if (isFol(sbPtr)) c += sbCount * 8;
                materials.push({
                    index: i,
                    name,
                    memory,
                    textureCount: texCount,
                    textures,
                });
            }
        }
    }

    // sunflare_t materials (spriteMaterial @ +640, flareMaterial @ +644)
    for (const sunMatOff of [base + 640, base + 644]) {
        const sp = d.readUInt32LE(sunMatOff);
        if (isFol(sp)) {
            const mBase = c;
            c += 192;
            if (d.readUInt32LE(mBase) === FOLLOWING) c = skipCString(c);
            const texCount = d[mBase + 170];
            const constCount = d[mBase + 171];
            const sbCount = d[mBase + 172];
            const ttPtr = d.readUInt32LE(mBase + 180);
            const ctPtr = d.readUInt32LE(mBase + 184);
            const sbPtr = d.readUInt32LE(mBase + 188);
            if (isFol(ttPtr)) {
                const ttStart = c;
                c += texCount * 16;
                for (let j = 0; j < texCount; j++) {
                    const uPtr = d.readUInt32LE(ttStart + j * 16 + 12);
                    if (d[ttStart + j * 16 + 7] !== 11 && isFol(uPtr)) c = readGfxImage(c).next;
                }
            }
            if (isFol(ctPtr)) c += constCount * 32;
            if (isFol(sbPtr)) c += sbCount * 8;
        }
    }

    // outdoorImage (@ base + 796)
    let outdoorImage = null;
    if (isFol(d.readUInt32LE(base + 796))) {
        outdoorImage = readGfxImage(c);
        c = outdoorImage.next;
    }

    // shadowGeom (@ base + 828) & lightRegion (@ base + 832)
    const primaryLightCount = d.readUInt32LE(base + 256);
    if (d.readUInt32LE(base + 828) === FOLLOWING) {
        const sgStart = c;
        c += primaryLightCount * 12;
        for (let i = 0; i < primaryLightCount; i++) {
            const sge = sgStart + i * 12;
            if (d.readUInt32LE(sge + 4) === FOLLOWING) c += d.readUInt16LE(sge + 0) * 2;
            if (d.readUInt32LE(sge + 8) === FOLLOWING) c += d.readUInt16LE(sge + 2) * 2;
        }
    }
    if (d.readUInt32LE(base + 832) === FOLLOWING) {
        const lrStart = c;
        c += primaryLightCount * 8;
        for (let i = 0; i < primaryLightCount; i++) {
            const lre = lrStart + i * 8;
            const hullCount = d.readUInt32LE(lre + 0);
            if (d.readUInt32LE(lre + 4) === FOLLOWING) {
                const hStart = c;
                c += hullCount * 80;
                for (let h = 0; h < hullCount; h++) {
                    const he = hStart + h * 80;
                    if (d.readUInt32LE(he + 76) === FOLLOWING) c += d.readUInt32LE(he + 72) * 20;
                }
            }
        }
    }

    // GfxWorldDpvsStatic: sortedSurfIndex@80, smodelInsts@84, surfaces@88, smodelDrawInsts@96
    const sortedSurfIndexStart = d.readUInt32LE(dpvsBase + 80) === FOLLOWING ? c : -1;
    if (sortedSurfIndexStart !== -1) c += staticSurfaceCount * 2;
    const smodelInstsStart = d.readUInt32LE(dpvsBase + 84) === FOLLOWING ? c : -1;
    if (smodelInstsStart !== -1) c += smodelCount * 40;
    const surfacesStart = d.readUInt32LE(dpvsBase + 88) === FOLLOWING ? c : -1;
    if (surfacesStart !== -1) c += surfaceCount * GFXSURFACE_SIZE;
    const smodelDrawInstsStart = d.readUInt32LE(dpvsBase + 96) === FOLLOWING ? c : -1;

    return {
        worldName,
        baseName,
        vStart,
        vBytes,
        vldStart,
        iStart,
        iBytes,
        cellsStart,
        cells,
        modelsStart,
        reflectionProbes,
        lightmaps,
        outdoorImage,
        matMemStart,
        materials,
        sortedSurfIndexStart,
        smodelInstsStart,
        surfacesStart,
        smodelDrawInstsStart,
        skyStartSurfsOffset,
        smodelCount,
    };
}

/**
 * Localiza los buffers de GfxWorldDraw (y opcionalmente el layout completo de GfxWorld).
 */
export function findGfxWorldBuffers(d, info) {
    const { baseOffset, vertexCount, indexCount } = info;
    const expectedVertexBytes = vertexCount * GFXWORLD_VERTEX_SIZE;
    const expectedIndexBytes = indexCount * 2;

    try {
        const layout = parseGfxWorldLayout(d, info);
        if (
            layout.vStart >= baseOffset + GFXWORLD_FIXED_SIZE &&
            layout.iStart >= layout.vStart + expectedVertexBytes &&
            layout.iStart + expectedIndexBytes <= d.length &&
            Math.abs(d.readFloatLE(layout.vStart + 12)) === 1.0
        ) {
            return layout;
        }
    } catch {
        // Fallback para buffers sintéticos mínimos
    }

    let c = baseOffset + GFXWORLD_FIXED_SIZE;
    let vStart = -1;
    let iStart = -1;

    while (c <= d.length - expectedVertexBytes) {
        const binormalSign = d.readFloatLE(c + 12);
        if (Math.abs(binormalSign) === 1.0) {
            let ok = true;
            for (let test = 1; test < Math.min(4, vertexCount); test++) {
                const off = c + test * GFXWORLD_VERTEX_SIZE;
                const bs = d.readFloatLE(off + 12);
                if (Math.abs(bs) !== 1.0) {
                    ok = false;
                    break;
                }
            }
            if (ok) {
                vStart = c;
                break;
            }
        }
        c++;
    }

    if (vStart !== -1) {
        let ic = vStart + expectedVertexBytes;
        while (ic <= d.length - expectedIndexBytes) {
            let ok = true;
            for (let test = 0; test < Math.min(20, indexCount); test++) {
                const idx = d.readUInt16LE(ic + test * 2);
                if (idx >= vertexCount) {
                    ok = false;
                    break;
                }
            }
            if (ok) {
                iStart = ic;
                break;
            }
            ic++;
        }
    }

    return {
        vStart,
        vBytes: expectedVertexBytes,
        iStart,
        iBytes: expectedIndexBytes,
        cellsStart: -1,
        cells: [],
        materials: [],
        sortedSurfIndexStart: -1,
        surfacesStart: -1,
    };
}

/**
 * Decodifica una textura inline GfxImageLoadDef (DXT1, R5G6B5, G16R16 o L8) a RGBA8.
 */
export function decodeGfxImageLoadDef(d, img, { maxDimension = 512 } = {}) {
    if (!img || img.dataStart < 0 || img.resourceSize <= 0) return null;
    const srcW = Math.max(1, img.width);
    const srcH = Math.max(1, img.height);
    const outW = Math.min(srcW, maxDimension);
    const outH = Math.min(srcH, maxDimension);
    const rgba = Buffer.alloc(outW * outH * 4);
    const data = d.subarray(img.dataStart, img.dataStart + img.resourceSize);

    if (img.format === D3DFMT_L8) {
        for (let y = 0; y < outH; y++) {
            const sy = Math.floor((y * srcH) / outH);
            for (let x = 0; x < outW; x++) {
                const sx = Math.floor((x * srcW) / outW);
                const lum = data[sy * srcW + sx] ?? 128;
                const dst = (y * outW + x) * 4;
                rgba[dst] = lum;
                rgba[dst + 1] = lum;
                rgba[dst + 2] = lum;
                rgba[dst + 3] = 255;
            }
        }
        return { name: img.name, width: outW, height: outH, format: "L8", rgba };
    }

    if (img.format === D3DFMT_R5G6B5) {
        for (let y = 0; y < outH; y++) {
            const sy = Math.floor((y * srcH) / outH);
            for (let x = 0; x < outW; x++) {
                const sx = Math.floor((x * srcW) / outW);
                const off = (sy * srcW + sx) * 2;
                const c16 = off + 2 <= data.length ? data.readUInt16LE(off) : 0;
                const r = Math.round(((c16 >> 11) & 0x1f) * (255 / 31));
                const g = Math.round(((c16 >> 5) & 0x3f) * (255 / 63));
                const b = Math.round((c16 & 0x1f) * (255 / 31));
                const dst = (y * outW + x) * 4;
                rgba[dst] = r;
                rgba[dst + 1] = g;
                rgba[dst + 2] = b;
                rgba[dst + 3] = 255;
            }
        }
        return { name: img.name, width: outW, height: outH, format: "R5G6B5", rgba };
    }

    if (img.format === D3DFMT_G16R16) {
        for (let y = 0; y < outH; y++) {
            const sy = Math.floor((y * srcH) / outH);
            for (let x = 0; x < outW; x++) {
                const sx = Math.floor((x * srcW) / outW);
                const off = (sy * srcW + sx) * 4;
                const r16 = off + 4 <= data.length ? data.readUInt16LE(off) : 512;
                const g16 = off + 4 <= data.length ? data.readUInt16LE(off + 2) : 512;
                const lum = Math.min(255, Math.max(64, Math.round(((r16 + g16) * 0.5) / 4)));
                const dst = (y * outW + x) * 4;
                rgba[dst] = lum;
                rgba[dst + 1] = lum;
                rgba[dst + 2] = lum;
                rgba[dst + 3] = 255;
            }
        }
        return { name: img.name, width: outW, height: outH, format: "G16R16", rgba };
    }

    if (img.format === D3DFMT_DXT1) {
        const blocksX = Math.max(1, Math.ceil(srcW / 4));
        const rgb565 = (c) => [
            Math.round(((c >> 11) & 0x1f) * (255 / 31)),
            Math.round(((c >> 5) & 0x3f) * (255 / 63)),
            Math.round((c & 0x1f) * (255 / 31)),
        ];
        for (let y = 0; y < outH; y++) {
            const sy = Math.floor((y * srcH) / outH);
            const by = sy >> 2;
            const py = sy & 3;
            for (let x = 0; x < outW; x++) {
                const sx = Math.floor((x * srcW) / outW);
                const bx = sx >> 2;
                const px = sx & 3;
                const bOff = (by * blocksX + bx) * 8;
                const dst = (y * outW + x) * 4;
                if (bOff + 8 > data.length) {
                    rgba[dst + 3] = 255;
                    continue;
                }
                const c0 = data.readUInt16LE(bOff);
                const c1 = data.readUInt16LE(bOff + 2);
                const lut = data.readUInt32LE(bOff + 4);
                const [r0, g0, b0] = rgb565(c0);
                const [r1, g1, b1] = rgb565(c1);
                const code = (lut >> ((py * 4 + px) * 2)) & 3;
                let r = r0, g = g0, b = b0;
                if (code === 1) { r = r1; g = g1; b = b1; }
                else if (code === 2) {
                    r = c0 > c1 ? Math.round((2 * r0 + r1) / 3) : Math.round((r0 + r1) / 2);
                    g = c0 > c1 ? Math.round((2 * g0 + g1) / 3) : Math.round((g0 + g1) / 2);
                    b = c0 > c1 ? Math.round((2 * b0 + b1) / 3) : Math.round((b0 + b1) / 2);
                } else if (code === 3) {
                    r = c0 > c1 ? Math.round((r0 + 2 * r1) / 3) : 0;
                    g = c0 > c1 ? Math.round((g0 + 2 * g1) / 3) : 0;
                    b = c0 > c1 ? Math.round((b0 + 2 * b1) / 3) : 0;
                }
                rgba[dst] = r;
                rgba[dst + 1] = g;
                rgba[dst + 2] = b;
                rgba[dst + 3] = 255;
            }
        }
        return { name: img.name, width: outW, height: outH, format: "DXT1", rgba };
    }

    return null;
}

/**
 * Extrae geometría espacialmente continua de GFXWORLD usando las superficies reales
 * (dpvs::surfaces con el desplazamiento srfTriangles_t::firstVertex) y las celdas PVS
 * (GfxCell -> dpvs::sortedSurfIndex), asignando materiales reales de materialMemory.
 */
export function extractGfxWorldSurfaces(
    d,
    info,
    layout,
    {
        roomIndices = null,
        cellIndices = null,
        includeBrushModels = false,
        skipInvisible = true,
        maxTriangles = 65000,
    } = {}
) {
    const { vStart, iStart, surfacesStart, sortedSurfIndexStart, cells, materials } = layout;
    const { surfaceCount, staticSurfaceCount, vertexCount, indexCount } = info;

    if (surfacesStart < 0 || surfacesStart + surfaceCount * GFXSURFACE_SIZE > d.length) {
        throw new Error("El layout de GFXWORLD no contiene dpvs::surfaces válido.");
    }

    // 1. Calcular el puntero virtual mínimo de material en dpvs::surfaces
    //    Cada superficie apunta a materialMemory[(ptr - minMatPtr) / 8].
    let minMatPtr = Infinity;
    for (let s = 0; s < surfaceCount; s++) {
        const ptr = d.readUInt32LE(surfacesStart + s * GFXSURFACE_SIZE + 48);
        if (ptr > 0 && ptr < minMatPtr) minMatPtr = ptr;
    }

    // 2. Determinar qué superficies seleccionar según las salas/celdas pedidas
    const selectedSurfaceIds = [];
    const seenSurfaces = new Set();
    let maxCoordBounds = Infinity;

    const addSurface = (s) => {
        if (s >= 0 && s < surfaceCount && !seenSurfaces.has(s)) {
            seenSurfaces.add(s);
            selectedSurfaceIds.push(s);
        }
    };

    const addCell = (cellIdx) => {
        const cell = cells[cellIdx];
        if (!cell || sortedSurfIndexStart < 0) return;
        for (let k = 0; k < cell.surfaceCount; k++) {
            const pos = sortedSurfIndexStart + (cell.startSurfIndex + k) * 2;
            if (pos + 2 <= d.length) {
                addSurface(d.readUInt16LE(pos));
            }
        }
    };

    if (Array.isArray(roomIndices) && roomIndices.length > 0) {
        for (const rIdx of roomIndices) {
            const room = KINO_ROOMS[rIdx];
            if (!room) continue;
            for (const cIdx of room.cells) addCell(cIdx);
            if (room.includeBrushModels) {
                for (let s = staticSurfaceCount; s < surfaceCount; s++) addSurface(s);
            }
            if (room.maxCoordBounds && roomIndices.length === 1) {
                maxCoordBounds = room.maxCoordBounds;
            }
        }
    } else if (Array.isArray(cellIndices) && cellIndices.length > 0) {
        for (const cIdx of cellIndices) addCell(cIdx);
        if (includeBrushModels) {
            for (let s = staticSurfaceCount; s < surfaceCount; s++) addSurface(s);
        }
    } else {
        for (let s = 0; s < surfaceCount; s++) addSurface(s);
    }

    // 3. Extraer triángulos aplicando globalVertex = firstVertex + localIndex
    const usedVerts = new Map();
    const indices = [];
    const materialUsage = new Map();
    let keptSurfaces = 0;
    let skippedSurfaces = 0;
    let totalSurfaceTriangles = 0;
    let minP = [Infinity, Infinity, Infinity];
    let maxP = [-Infinity, -Infinity, -Infinity];

    for (const s of selectedSurfaceIds) {
        const se = surfacesStart + s * GFXSURFACE_SIZE;
        const surfMinX = d.readFloatLE(se + 0);
        const surfMinY = d.readFloatLE(se + 4);
        const surfMaxX = d.readFloatLE(se + 16);
        const surfMaxY = d.readFloatLE(se + 20);
        if (
            maxCoordBounds < Infinity &&
            (Math.abs(surfMinX) > maxCoordBounds ||
                Math.abs(surfMinY) > maxCoordBounds ||
                Math.abs(surfMaxX) > maxCoordBounds ||
                Math.abs(surfMaxY) > maxCoordBounds)
        ) {
            skippedSurfaces++;
            continue;
        }

        const firstVertex = d.readInt32LE(se + 28);
        const surfVertCount = d.readUInt16LE(se + 32);
        const triCount = d.readUInt16LE(se + 34);
        const baseIndex = d.readInt32LE(se + 36);
        const matPtr = d.readUInt32LE(se + 48);
        const lightmapIndex = d[se + 52];

        const matIndex = minMatPtr < Infinity ? Math.round((matPtr - minMatPtr) / 8) : -1;
        const matInfo = materials[matIndex] ?? null;
        const matName = matInfo?.name ?? `mat_${matIndex}`;
        const matStyle = classifyMaterialColor(matName);

        if (skipInvisible && matStyle.skip) {
            skippedSurfaces++;
            continue;
        }
        if (
            firstVertex < 0 ||
            firstVertex + surfVertCount > vertexCount ||
            baseIndex < 0 ||
            baseIndex + triCount * 3 > indexCount
        ) {
            skippedSurfaces++;
            continue;
        }

        keptSurfaces++;
        totalSurfaceTriangles += triCount;
        materialUsage.set(matName, (materialUsage.get(matName) || 0) + triCount);

        if (indices.length / 3 + triCount > maxTriangles) {
            continue;
        }

        const [mr, mg, mb] = matStyle.rgb;

        for (let t = 0; t < triCount; t++) {
            const idxOff = iStart + (baseIndex + t * 3) * 2;
            const l0 = d.readUInt16LE(idxOff + 0);
            const l1 = d.readUInt16LE(idxOff + 2);
            const l2 = d.readUInt16LE(idxOff + 4);
            if (l0 === l1 || l1 === l2 || l2 === l0) continue;
            if (l0 >= surfVertCount || l1 >= surfVertCount || l2 >= surfVertCount) continue;

            const g0 = firstVertex + l0;
            const g1 = firstVertex + l1;
            const g2 = firstVertex + l2;

            for (const gIdx of [g0, g1, g2]) {
                // Combinar índice global de vértice e índice de material para preservar colores por superficie
                const vertKey = gIdx * 1024 + Math.max(0, matIndex);
                let mapped = usedVerts.get(vertKey);
                if (!mapped) {
                    const vp = vStart + gIdx * GFXWORLD_VERTEX_SIZE;
                    const px = d.readFloatLE(vp + 0);
                    const py = d.readFloatLE(vp + 4);
                    const pz = d.readFloatLE(vp + 8);

                    const vr = d[vp + 16] / 255.0;
                    const vg = d[vp + 17] / 255.0;
                    const vb = d[vp + 18] / 255.0;
                    const va = d[vp + 19] / 255.0;

                    // Mezclar color semántico del material con el GfxColor de iluminación por vértice
                    const r = mr * (0.55 + 0.45 * vr);
                    const g = mg * (0.55 + 0.45 * vg);
                    const b = mb * (0.55 + 0.45 * vb);

                    const texU = d.readFloatLE(vp + 20);
                    const texV = d.readFloatLE(vp + 24);
                    const lmapU = d.readFloatLE(vp + 28);
                    const lmapV = d.readFloatLE(vp + 32);
                    const hasLmap = (lightmapIndex === 0 || lightmapIndex === 1) && lmapU >= 0 && lmapU <= 1 && lmapV >= 0 && lmapV <= 1;
                    const u = hasLmap ? lmapU : (texU - Math.floor(texU));
                    const v = hasLmap ? lmapV : (texV - Math.floor(texV));

                    const normal = unpackUnitVec(d[vp + 36], d[vp + 37], d[vp + 38], d[vp + 39]);

                    if (px < minP[0]) minP[0] = px;
                    if (py < minP[1]) minP[1] = py;
                    if (pz < minP[2]) minP[2] = pz;
                    if (px > maxP[0]) maxP[0] = px;
                    if (py > maxP[1]) maxP[1] = py;
                    if (pz > maxP[2]) maxP[2] = pz;

                    mapped = {
                        index: usedVerts.size,
                        globalVertexIndex: gIdx,
                        materialIndex: matIndex,
                        position: [px, py, pz],
                        normal,
                        color: [r, g, b, va],
                        uv: [u, v],
                        texCoord: [texU, texV],
                        lmapCoord: [lmapU, lmapV],
                    };
                    usedVerts.set(vertKey, mapped);
                }
                indices.push(mapped.index);
            }
        }
    }

    const vertices = Array.from(usedVerts.values()).sort((a, b) => a.index - b.index);
    const radius = vertices.length > 0
        ? Math.hypot(
            (maxP[0] - minP[0]) * 0.5,
            (maxP[1] - minP[1]) * 0.5,
            (maxP[2] - minP[2]) * 0.5
        )
        : 1.0;

    const topMaterials = [...materialUsage.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 12)
        .map(([name, triangles]) => ({ name, triangles }));

    return {
        keptSurfaces,
        skippedSurfaces,
        totalSurfaceTriangles,
        vertexCount: vertices.length,
        triangleCount: indices.length / 3,
        bounds: { minP, maxP, radius },
        topMaterials,
        vertices,
        indices,
    };
}

/**
 * Extrae un sector de geometría de GfxWorldDraw.
 * Si se pasa `layout` con `surfacesStart` válido, extrae la sala arquitectónica `chunkIndex`
 * usando `dpvs::surfaces` (`firstVertex + localIndex`). En buffers sintéticos sin `surfaces`,
 * aplica el recorrido directo sobre `vStart` / `iStart`.
 */
export function extractGfxWorldSector(
    d,
    vStart,
    iStart,
    vertexCount,
    indexCount,
    { chunkIndex = 0, trisPerChunk = 6000, info = null, layout = null } = {}
) {
    if (info && layout && layout.surfacesStart > 0 && layout.cells.length > 0) {
        const roomIdx = Math.max(0, Math.min(KINO_ROOMS.length - 1, chunkIndex));
        const res = extractGfxWorldSurfaces(d, info, layout, {
            roomIndices: [roomIdx],
            maxTriangles: Math.max(trisPerChunk, 65000),
        });
        return {
            chunkIndex: roomIdx,
            roomName: KINO_ROOMS[roomIdx].name,
            totalValidTrianglesInMap: res.totalSurfaceTriangles,
            vertexCount: res.vertexCount,
            triangleCount: res.triangleCount,
            keptSurfaces: res.keptSurfaces,
            topMaterials: res.topMaterials,
            bounds: res.bounds,
            vertices: res.vertices,
            indices: res.indices,
        };
    }

    const totalTris = Math.floor(indexCount / 3);
    const targetStart = chunkIndex * trisPerChunk;
    const targetEnd = targetStart + trisPerChunk;

    const usedVerts = new Map();
    const indices = [];
    let validTrisEncountered = 0;
    let minP = [Infinity, Infinity, Infinity];
    let maxP = [-Infinity, -Infinity, -Infinity];

    for (let t = 0; t < totalTris; t++) {
        const i0 = d.readUInt16LE(iStart + (t * 3 + 0) * 2);
        const i1 = d.readUInt16LE(iStart + (t * 3 + 1) * 2);
        const i2 = d.readUInt16LE(iStart + (t * 3 + 2) * 2);

        if (i0 === i1 || i1 === i2 || i2 === i0) continue;
        if (i0 >= vertexCount || i1 >= vertexCount || i2 >= vertexCount) continue;

        if (validTrisEncountered >= targetStart && validTrisEncountered < targetEnd) {
            const mappedTri = [];

            for (const vIdx of [i0, i1, i2]) {
                if (!usedVerts.has(vIdx)) {
                    const vp = vStart + vIdx * GFXWORLD_VERTEX_SIZE;
                    const px = d.readFloatLE(vp + 0);
                    const py = d.readFloatLE(vp + 4);
                    const pz = d.readFloatLE(vp + 8);
                    const r = d[vp + 16] / 255.0;
                    const g = d[vp + 17] / 255.0;
                    const b = d[vp + 18] / 255.0;
                    const a = d[vp + 19] / 255.0;
                    const u = d.readFloatLE(vp + 20);
                    const v = d.readFloatLE(vp + 24);
                    const normal = unpackUnitVec(d[vp + 36], d[vp + 37], d[vp + 38], d[vp + 39]);

                    minP[0] = Math.min(minP[0], px);
                    minP[1] = Math.min(minP[1], py);
                    minP[2] = Math.min(minP[2], pz);
                    maxP[0] = Math.max(maxP[0], px);
                    maxP[1] = Math.max(maxP[1], py);
                    maxP[2] = Math.max(maxP[2], pz);

                    const newIdx = usedVerts.size;
                    usedVerts.set(vIdx, {
                        index: newIdx,
                        position: [px, py, pz],
                        normal,
                        color: [r, g, b, a],
                        uv: [u, v],
                    });
                }
                mappedTri.push(usedVerts.get(vIdx).index);
            }
            indices.push(mappedTri[0], mappedTri[1], mappedTri[2]);
        }

        validTrisEncountered++;
        if (validTrisEncountered >= targetEnd) break;
    }

    const vertices = Array.from(usedVerts.values()).sort((a, b) => a.index - b.index);
    const radius = Math.hypot(
        (maxP[0] - minP[0]) * 0.5,
        (maxP[1] - minP[1]) * 0.5,
        (maxP[2] - minP[2]) * 0.5
    );

    return {
        chunkIndex,
        totalValidTrianglesInMap: validTrisEncountered,
        vertexCount: vertices.length,
        triangleCount: indices.length / 3,
        bounds: { minP, maxP, radius },
        vertices,
        indices,
    };
}

/**
 * Exporta un sector a formato Wavefront OBJ en memoria.
 */
export function sectorToObj(sector, name = "kino_sector") {
    const lines = [
        `# GFXWORLD Sector ${sector.chunkIndex ?? 0}: ${name}`,
        `# Vértices: ${sector.vertexCount}, Triángulos: ${sector.triangleCount}`,
        `o ${name}`,
    ];
    for (const v of sector.vertices) {
        lines.push(`v ${v.position[0].toFixed(4)} ${v.position[1].toFixed(4)} ${v.position[2].toFixed(4)}`);
    }
    for (const v of sector.vertices) {
        lines.push(`vn ${v.normal[0].toFixed(4)} ${v.normal[1].toFixed(4)} ${v.normal[2].toFixed(4)}`);
    }
    for (const v of sector.vertices) {
        lines.push(`vt ${v.uv[0].toFixed(4)} ${v.uv[1].toFixed(4)}`);
    }
    for (let t = 0; t < sector.indices.length; t += 3) {
        const i0 = sector.indices[t + 0] + 1;
        const i1 = sector.indices[t + 1] + 1;
        const i2 = sector.indices[t + 2] + 1;
        lines.push(`f ${i0}/${i0}/${i0} ${i1}/${i1}/${i1} ${i2}/${i2}/${i2}`);
    }
    return lines.join("\n") + "\n";
}

/**
 * Transforma un vértice 3D de un XModel a coordenadas de mundo según su colocación (placement).
 * P_world = origin + scale * (axis[0] * P_x + axis[1] * P_y + axis[2] * P_z)
 */
export function transformModelVertex(vertex, placement) {
    const { origin, axis, scale = 1.0 } = placement;
    const px = vertex[0], py = vertex[1], pz = vertex[2];
    const x = origin[0] + scale * (px * axis[0][0] + py * axis[1][0] + pz * axis[2][0]);
    const y = origin[1] + scale * (px * axis[0][1] + py * axis[1][1] + pz * axis[2][1]);
    const z = origin[2] + scale * (px * axis[0][2] + py * axis[1][2] + pz * axis[2][2]);
    return [x, y, z];
}

/**
 * Transforma una normal 3D según los vectores base (axis) ortogonales de la instancia.
 */
export function transformModelNormal(normal, placement) {
    const { axis } = placement;
    const nx = normal[0], ny = normal[1], nz = normal[2];
    const x = nx * axis[0][0] + ny * axis[1][0] + nz * axis[2][0];
    const y = nx * axis[0][1] + ny * axis[1][1] + nz * axis[2][1];
    const z = nx * axis[0][2] + ny * axis[1][2] + nz * axis[2][2];
    const len = Math.hypot(x, y, z) || 1.0;
    return [x / len, y / len, z / len];
}

/**
 * Extrae instancias de modelos estáticos (dpvs::smodelDrawInsts y dpvs::smodelInsts).
 * Resuelve el modelo referenciado mediante la fórmula verificada:
 *   assetIndex = ((modelPtr & 0x1FFFFFFF) - 17137) / 8
 */
export function extractStaticModelInstances(
    d,
    info,
    layout,
    {
        roomIndex = null,
        cellIndices = null,
        bounds = null,
        maxCount = Infinity,
    } = {}
) {
    const smodelDrawInstsStart = layout.smodelDrawInstsStart;
    if (!smodelDrawInstsStart || smodelDrawInstsStart <= 0 || smodelDrawInstsStart >= d.length) {
        return [];
    }

    const smodelCount = layout.smodelCount || (info.smodelCount ?? 0);
    if (smodelCount <= 0) return [];

    const smodelInstsStart = layout.smodelInstsStart;

    // Calcular límites de filtrado espacial si se solicita roomIndex o cellIndices
    let filterBounds = bounds;
    if (!filterBounds && Number.isInteger(roomIndex) && KINO_ROOMS[roomIndex]) {
        const roomCells = KINO_ROOMS[roomIndex].cells;
        let rMins = [Infinity, Infinity, Infinity];
        let rMaxs = [-Infinity, -Infinity, -Infinity];
        let hasCells = false;
        if (layout.cells && layout.cells.length > 0) {
            for (const cIdx of roomCells) {
                const c = layout.cells[cIdx];
                if (!c) continue;
                hasCells = true;
                for (let j = 0; j < 3; j++) {
                    rMins[j] = Math.min(rMins[j], c.mins[j]);
                    rMaxs[j] = Math.max(rMaxs[j], c.maxs[j]);
                }
            }
        }
        if (hasCells) {
            const pad = 60.0;
            filterBounds = {
                mins: [rMins[0] - pad, rMins[1] - pad, rMins[2] - pad],
                maxs: [rMaxs[0] + pad, rMaxs[1] + pad, rMaxs[2] + pad],
            };
        }
    }

    const instances = [];
    for (let i = 0; i < smodelCount; i++) {
        if (instances.length >= maxCount) break;
        const off = smodelDrawInstsStart + i * 76;
        if (off + 76 > d.length) break;

        const cullDist = d.readFloatLE(off + 0);
        const origin = [
            d.readFloatLE(off + 4),
            d.readFloatLE(off + 8),
            d.readFloatLE(off + 12),
        ];

        if (filterBounds) {
            if (origin[0] < filterBounds.mins[0] || origin[0] > filterBounds.maxs[0] ||
                origin[1] < filterBounds.mins[1] || origin[1] > filterBounds.maxs[1] ||
                origin[2] < filterBounds.mins[2] || origin[2] > filterBounds.maxs[2]) {
                continue;
            }
        }

        const axis = [
            [d.readFloatLE(off + 16), d.readFloatLE(off + 20), d.readFloatLE(off + 24)],
            [d.readFloatLE(off + 28), d.readFloatLE(off + 32), d.readFloatLE(off + 36)],
            [d.readFloatLE(off + 40), d.readFloatLE(off + 44), d.readFloatLE(off + 48)],
        ];
        const scale = d.readFloatLE(off + 52);
        const modelPtr = d.readUInt32LE(off + 56);
        const flags = d.readInt32LE(off + 60);

        let mins = null, maxs = null;
        if (smodelInstsStart && smodelInstsStart > 0) {
            const instOff = smodelInstsStart + i * 40;
            if (instOff + 24 <= d.length) {
                mins = [d.readFloatLE(instOff + 0), d.readFloatLE(instOff + 4), d.readFloatLE(instOff + 8)];
                maxs = [d.readFloatLE(instOff + 12), d.readFloatLE(instOff + 16), d.readFloatLE(instOff + 20)];
            }
        }

        let assetIndex = -1;
        let isXModel = false;
        if (modelPtr !== 0xffffffff && modelPtr !== 0) {
            const vAddr = modelPtr & 0x1fffffff;
            const aIdx = (vAddr - 17137) / 8;
            if (Number.isInteger(aIdx) && aIdx >= 0) {
                assetIndex = aIdx;
                const entryOff = 17135 + assetIndex * 8;
                if (entryOff + 4 <= d.length) {
                    const type = d.readInt32LE(entryOff);
                    if (type === 5) isXModel = true;
                }
            }
        }

        instances.push({
            index: i,
            cullDist,
            origin,
            axis,
            scale,
            modelPtr,
            assetIndex,
            isXModel,
            flags,
            mins,
            maxs,
        });
    }

    return instances;
}

async function main(argv) {
    const args = argv.slice(2);
    let json = false;
    let roomIndex = 0;
    let cellIndex = null;
    let objMode = false;
    let fileArg = null;

    for (let i = 0; i < args.length; i++) {
        const a = args[i];
        if (a === "--json") json = true;
        else if (a === "--chunk" || a === "--room") roomIndex = parseInt(args[++i], 10) || 0;
        else if (a === "--cell") cellIndex = parseInt(args[++i], 10);
        else if (a === "--obj") {
            objMode = true;
            if (args[i + 1] && !args[i + 1].startsWith("-")) roomIndex = parseInt(args[++i], 10) || 0;
        } else if (!a.startsWith("-") && !fileArg) fileArg = a;
    }

    if (!fileArg) {
        console.error("Uso: node tools/zgfxworld.mjs <archivo.ff> [--json] [--room <0..7>] [--cell <0..32>] [--obj [room]]");
        return 2;
    }

    const raw = await readFile(resolve(fileArg));
    if (raw.length < HEADER_LEN) throw new Error("Archivo demasiado corto");
    const magic = raw.toString("ascii", 0, 8);
    const version = raw.readUInt32LE(8);
    if (magic !== MAGIC || version !== T5_PC_VERSION) {
        throw new Error("Cabecera no soportada");
    }

    const inflated = inflateSync(raw.subarray(HEADER_LEN));
    const info = locateGfxWorld(inflated);
    if (!info) {
        console.error("No se encontró ningún asset GFXWORLD en esta zona.");
        return 1;
    }

    const layout = findGfxWorldBuffers(inflated, info);
    if (layout.vStart === -1 || layout.iStart === -1) {
        console.error("No se pudieron localizar los buffers de dibujo de GfxWorldDraw.");
        return 1;
    }

    const sector = Number.isInteger(cellIndex)
        ? extractGfxWorldSurfaces(inflated, info, layout, { cellIndices: [cellIndex] })
        : extractGfxWorldSector(inflated, layout.vStart, layout.iStart, info.vertexCount, info.indexCount, {
            chunkIndex: roomIndex,
            info,
            layout,
        });

    if (objMode) {
        const label = Number.isInteger(cellIndex) ? `kino_cell_${cellIndex}` : `kino_${KINO_ROOMS[roomIndex]?.key ?? roomIndex}`;
        process.stdout.write(sectorToObj(sector, label));
        return 0;
    }

    if (json) {
        console.log(JSON.stringify({
            file: basename(fileArg),
            info,
            offsets: {
                cellsStart: layout.cellsStart,
                vStart: layout.vStart,
                vldStart: layout.vldStart,
                iStart: layout.iStart,
                matMemStart: layout.matMemStart,
                sortedSurfIndexStart: layout.sortedSurfIndexStart,
                surfacesStart: layout.surfacesStart,
            },
            inlineTextures: {
                reflectionProbes: layout.reflectionProbes?.map(p => ({ name: p.name, width: p.width, height: p.height, format: p.format, resourceSize: p.resourceSize })),
                lightmaps: layout.lightmaps?.map(l => ({
                    primary: l.primary ? { name: l.primary.name, width: l.primary.width, height: l.primary.height, format: l.primary.format, resourceSize: l.primary.resourceSize } : null,
                    secondary: l.secondary ? { name: l.secondary.name, width: l.secondary.width, height: l.secondary.height, format: l.secondary.format, resourceSize: l.secondary.resourceSize } : null,
                    secondaryB: l.secondaryB ? { name: l.secondaryB.name, width: l.secondaryB.width, height: l.secondaryB.height, format: l.secondaryB.format, resourceSize: l.secondaryB.resourceSize } : null,
                })),
                outdoorImage: layout.outdoorImage ? { name: layout.outdoorImage.name, width: layout.outdoorImage.width, height: layout.outdoorImage.height, format: layout.outdoorImage.format, resourceSize: layout.outdoorImage.resourceSize } : null,
            },
            sectorSummary: {
                roomIndex,
                roomName: sector.roomName ?? `Cell ${cellIndex}`,
                keptSurfaces: sector.keptSurfaces,
                vertexCount: sector.vertexCount,
                triangleCount: sector.triangleCount,
                bounds: sector.bounds,
                topMaterials: sector.topMaterials,
            },
        }, null, 2));
        return 0;
    }

    console.log(`Zona: ${basename(fileArg)} (${layout.worldName || "GFXWORLD"})`);
    console.log(`GFXWORLD en offset ${info.baseOffset} · Celdas PVS: ${info.cellCount} · Materiales: ${info.materialMemoryCount} · Superficies: ${info.surfaceCount}`);
    console.log(`World BBox: mins=[${info.mins.map(v => v.toFixed(0)).join(", ")}] maxs=[${info.maxs.map(v => v.toFixed(0)).join(", ")}]`);
    console.log(`GfxWorldDraw: ${info.vertexCount} vértices (@ ${layout.vStart}), ${info.indexCount} índices (@ ${layout.iStart}), dpvs::surfaces (@ ${layout.surfacesStart})`);
    console.log(`Región [${sector.roomName ?? `Cell ${cellIndex}`}]: ${sector.keptSurfaces ?? 0} sup · ${sector.vertexCount} vértices · ${sector.triangleCount} triángulos`);
    console.log(`Bounds región: mins=[${sector.bounds.minP.map(v => v.toFixed(1)).join(", ")}] maxs=[${sector.bounds.maxP.map(v => v.toFixed(1)).join(", ")}] (radio: ${sector.bounds.radius.toFixed(1)})`);
    if (sector.topMaterials?.length) {
        console.log(`Materiales principales: ${sector.topMaterials.slice(0, 5).map(m => `${m.name} (${m.triangles} tris)`).join(", ")}`);
    }
    return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    main(process.argv).then((code) => process.exit(code));
}
