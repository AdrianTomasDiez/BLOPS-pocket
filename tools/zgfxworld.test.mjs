import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
    locateGfxWorld,
    findGfxWorldBuffers,
    extractGfxWorldSector,
    extractGfxWorldSurfaces,
    extractStaticModelInstances,
    transformModelVertex,
    transformModelNormal,
    classifyMaterialColor,
    decodeGfxImageLoadDef,
    sectorToObj,
    D3DFMT_L8,
    D3DFMT_R5G6B5,
    D3DFMT_G16R16,
    D3DFMT_DXT1,
} from "./zgfxworld.mjs";

describe("zgfxworld", () => {
    it("localiza GFXWORLD y extrae sector geométrico en un buffer sintético", () => {
        const baseOffset = 200;
        const drawOffset = baseOffset + 344;
        const vertexCount = 4;
        const indexCount = 6;
        const totalSize = 3500;
        const buf = Buffer.alloc(totalSize, 0);

        // GfxWorld header: planeCount, nodeCount, surfaceCount
        buf.writeInt32LE(10, baseOffset + 8);
        buf.writeInt32LE(20, baseOffset + 12);
        buf.writeInt32LE(5, baseOffset + 16);

        // GfxWorld mins & maxs @ +600 y +612
        buf.writeFloatLE(-500.0, baseOffset + 600);
        buf.writeFloatLE(-500.0, baseOffset + 604);
        buf.writeFloatLE(0.0, baseOffset + 608);
        buf.writeFloatLE(500.0, baseOffset + 612);
        buf.writeFloatLE(500.0, baseOffset + 616);
        buf.writeFloatLE(200.0, baseOffset + 620);

        // GfxWorldDraw: vertexCount @ +156, vd.verticesPtr @ +160, indexCount @ +184, indicesPtr @ +188
        buf.writeUInt32LE(vertexCount, drawOffset + 156);
        buf.writeUInt32LE(0xffffffff, drawOffset + 160);
        buf.writeInt32LE(indexCount, drawOffset + 184);
        buf.writeUInt32LE(0xffffffff, drawOffset + 188);

        // Ubicación de vértices (GfxWorldVertex, 44 bytes cada uno)
        const vStart = baseOffset + 1084 + 100;
        const coords = [
            [-100, -100, 0],
            [100, -100, 0],
            [100, 100, 0],
            [-100, 100, 0],
        ];
        for (let i = 0; i < vertexCount; i++) {
            const vp = vStart + i * 44;
            buf.writeFloatLE(coords[i][0], vp + 0);
            buf.writeFloatLE(coords[i][1], vp + 4);
            buf.writeFloatLE(coords[i][2], vp + 8);
            buf.writeFloatLE(1.0, vp + 12); // binormalSign = 1.0
            buf[vp + 16] = 255; buf[vp + 17] = 255; buf[vp + 18] = 255; buf[vp + 19] = 255;
            buf.writeFloatLE(0.0, vp + 20); // u
            buf.writeFloatLE(1.0, vp + 24); // v
            buf[vp + 36] = 127; buf[vp + 37] = 127; buf[vp + 38] = 254; buf[vp + 39] = 63; // normal (0,0,1)
        }

        // Ubicación de índices (uint16_t, 2 triángulos = 6 índices)
        const iStart = vStart + vertexCount * 44;
        buf.writeUInt16LE(0, iStart + 0);
        buf.writeUInt16LE(1, iStart + 2);
        buf.writeUInt16LE(2, iStart + 4);
        buf.writeUInt16LE(0, iStart + 6);
        buf.writeUInt16LE(2, iStart + 8);
        buf.writeUInt16LE(3, iStart + 10);

        const info = locateGfxWorld(buf);
        assert.ok(info !== null);
        assert.equal(info.baseOffset, baseOffset);
        assert.equal(info.vertexCount, vertexCount);
        assert.equal(info.indexCount, indexCount);
        assert.deepEqual(info.mins, [-500, -500, 0]);
        assert.deepEqual(info.maxs, [500, 500, 200]);

        const buffers = findGfxWorldBuffers(buf, info);
        assert.equal(buffers.vStart, vStart);
        assert.equal(buffers.iStart, iStart);

        const sector = extractGfxWorldSector(buf, buffers.vStart, buffers.iStart, info.vertexCount, info.indexCount, { chunkIndex: 0, trisPerChunk: 10 });
        assert.equal(sector.vertexCount, 4);
        assert.equal(sector.triangleCount, 2);
        assert.deepEqual(sector.indices, [0, 1, 2, 0, 2, 3]);

        const obj = sectorToObj(sector, "test_quad");
        assert.match(obj, /o test_quad/);
        assert.match(obj, /v -100\.0000 -100\.0000 0\.0000/);
        assert.match(obj, /f 1\/1\/1 2\/2\/2 3\/3\/3/);
    });

    it("reconstruye superficies con firstVertex > 0, celdas PVS y filtrado de materiales caulk/sky", () => {
        // Dos superficies: sup 0 es caulk (debe filtrarse) y sup 1 usa firstVertex = 2
        const vertexCount = 6;
        const indexCount = 6;
        const surfaceCount = 2;
        const staticSurfaceCount = 2;

        const vStart = 0;
        const iStart = vStart + vertexCount * 44;
        const sortedSurfIndexStart = iStart + indexCount * 2;
        const surfacesStart = sortedSurfIndexStart + staticSurfaceCount * 2;
        const buf = Buffer.alloc(surfacesStart + surfaceCount * 80, 0);

        // Vértices 0..1 señuelo (fuera de lugar) y vértices 2..5 reales (firstVertex = 2)
        const vCoords = [
            [9999, 9999, 9999],
            [-9999, -9999, -9999],
            [-50, -50, 10],
            [50, -50, 10],
            [50, 50, 10],
            [-50, 50, 10],
        ];
        for (let i = 0; i < vertexCount; i++) {
            const vp = vStart + i * 44;
            buf.writeFloatLE(vCoords[i][0], vp + 0);
            buf.writeFloatLE(vCoords[i][1], vp + 4);
            buf.writeFloatLE(vCoords[i][2], vp + 8);
            buf.writeFloatLE(1.0, vp + 12);
            buf[vp + 16] = 255; buf[vp + 17] = 255; buf[vp + 18] = 255; buf[vp + 19] = 255;
            buf.writeFloatLE(0.25, vp + 28); // lmapU
            buf.writeFloatLE(0.75, vp + 32); // lmapV
            buf[vp + 36] = 127; buf[vp + 37] = 127; buf[vp + 38] = 254; buf[vp + 39] = 63;
        }

        // Índices locales 0,1,2 y 0,2,3 (que deben sumarse a firstVertex = 2 -> vértices 2,3,4,5)
        [0, 1, 2, 0, 2, 3].forEach((idx, k) => buf.writeUInt16LE(idx, iStart + k * 2));

        // sortedSurfIndex: celda 0 referencia superficies [0, 1]
        buf.writeUInt16LE(0, sortedSurfIndexStart + 0);
        buf.writeUInt16LE(1, sortedSurfIndexStart + 2);

        // Superficie 0: material 0 (wc/caulk), firstVertex = 0, triCount = 1
        const s0 = surfacesStart;
        buf.writeInt32LE(0, s0 + 28);  // firstVertex
        buf.writeUInt16LE(3, s0 + 32); // vertexCount
        buf.writeUInt16LE(1, s0 + 34); // triCount
        buf.writeInt32LE(0, s0 + 36);  // baseIndex
        buf.writeUInt32LE(0x84000000, s0 + 48); // material ptr -> idx 0

        // Superficie 1: material 1 (wc/eb_art_floor_wood), firstVertex = 2, vertexCount = 4, triCount = 2
        const s1 = surfacesStart + 80;
        buf.writeInt32LE(2, s1 + 28);  // firstVertex = 2
        buf.writeUInt16LE(4, s1 + 32); // vertexCount = 4
        buf.writeUInt16LE(2, s1 + 34); // triCount = 2
        buf.writeInt32LE(0, s1 + 36);  // baseIndex = 0
        buf.writeUInt32LE(0x84000008, s1 + 48); // material ptr -> idx 1 (+8 bytes)
        buf[s1 + 52] = 0; // lightmapIndex = 0

        const info = {
            surfaceCount,
            staticSurfaceCount,
            vertexCount,
            indexCount,
        };
        const layout = {
            vStart,
            iStart,
            sortedSurfIndexStart,
            surfacesStart,
            cells: [{ index: 0, startSurfIndex: 0, surfaceCount: 2 }],
            materials: [
                { index: 0, name: "wc/caulk" },
                { index: 1, name: "wc/eb_art_floor_wood" },
            ],
        };

        const res = extractGfxWorldSurfaces(buf, info, layout, { cellIndices: [0] });
        assert.equal(res.keptSurfaces, 1);
        assert.equal(res.skippedSurfaces, 1);
        assert.equal(res.vertexCount, 4);
        assert.equal(res.triangleCount, 2);
        assert.deepEqual(res.bounds.minP, [-50, -50, 10]);
        assert.deepEqual(res.bounds.maxP, [50, 50, 10]);
        assert.equal(res.topMaterials[0].name, "wc/eb_art_floor_wood");
        assert.deepEqual(res.vertices[0].uv, [0.25, 0.75]);
        assert.equal(classifyMaterialColor("wc/sky_day").skip, true);
        assert.equal(classifyMaterialColor("wc/eb_art_floor_wood").category, "wood");
    });

    it("decodifica texturas inline GfxImageLoadDef (L8, R5G6B5, G16R16 y DXT1) a RGBA8", () => {
        const buf = Buffer.alloc(64, 0);
        // L8 2x2
        buf[0] = 10; buf[1] = 20; buf[2] = 30; buf[3] = 240;
        const l8 = decodeGfxImageLoadDef(buf, {
            name: "$outdoor",
            width: 2,
            height: 2,
            format: D3DFMT_L8,
            dataStart: 0,
            resourceSize: 4,
        });
        assert.ok(l8 !== null);
        assert.equal(l8.rgba[0], 10);
        assert.equal(l8.rgba[12], 240);
        assert.equal(l8.rgba[15], 255);

        // R5G6B5 1x1: rojo puro (0xF800)
        buf.writeUInt16LE(0xf800, 8);
        const rgb565 = decodeGfxImageLoadDef(buf, {
            name: "*lightmap0_secondary",
            width: 1,
            height: 1,
            format: D3DFMT_R5G6B5,
            dataStart: 8,
            resourceSize: 2,
        });
        assert.deepEqual([...rgb565.rgba], [255, 0, 0, 255]);

        // G16R16 1x1
        buf.writeUInt16LE(600, 16);
        buf.writeUInt16LE(600, 18);
        const rg16 = decodeGfxImageLoadDef(buf, {
            name: "*lightmap0_secondaryb",
            width: 1,
            height: 1,
            format: D3DFMT_G16R16,
            dataStart: 16,
            resourceSize: 4,
        });
        assert.equal(rg16.rgba[0], 150);
        assert.equal(rg16.rgba[3], 255);

        // DXT1 4x4: c0 = 0xF800 (rojo), c1 = 0x001F (azul), lut = 0 (todos c0)
        buf.writeUInt16LE(0xf800, 24);
        buf.writeUInt16LE(0x001f, 26);
        buf.writeUInt32LE(0x00000000, 28);
        const dxt1 = decodeGfxImageLoadDef(buf, {
            name: "*reflection_probe1",
            width: 4,
            height: 4,
            format: D3DFMT_DXT1,
            dataStart: 24,
            resourceSize: 8,
        });
        assert.equal(dxt1.width, 4);
        assert.equal(dxt1.height, 4);
        assert.deepEqual([...dxt1.rgba.subarray(0, 4)], [255, 0, 0, 255]);
    });

    it("decodifica instancias de static models (smodelDrawInsts) y transforma vértices a coordenadas de mapa", () => {
        // 1. Prueba de transformaciones matemáticas
        const placement = {
            origin: [100, 200, 50],
            axis: [
                [0, 1, 0],   // rotación 90 deg alrededor de Z: eje X pasa a +Y
                [-1, 0, 0],  // eje Y pasa a -X
                [0, 0, 1],   // eje Z se mantiene +Z
            ],
            scale: 2.0,
        };

        const localV = [10, 0, 5];
        const worldV = transformModelVertex(localV, placement);
        // x = 100 + 2 * (10*0 + 0*(-1) + 5*0) = 100
        // y = 200 + 2 * (10*1 + 0*0 + 5*0) = 220
        // z = 50 + 2 * (10*0 + 0*0 + 5*1) = 60
        assert.deepEqual(worldV, [100, 220, 60]);

        const localN = [1, 0, 0];
        const worldN = transformModelNormal(localN, placement);
        assert.deepEqual(worldN, [0, 1, 0]);

        // 2. Buffer sintético con smodelDrawInsts y tabla de assets
        const totalSize = 25000;
        const buf = Buffer.alloc(totalSize, 0);

        // Asset table start en 17135 (Asset 3 es tipo 5: XMODEL)
        const assetIndex = 3;
        const assetEntryOff = 17135 + assetIndex * 8;
        buf.writeInt32LE(5, assetEntryOff); // ASSET_TYPE_XMODEL
        buf.writeUInt32LE(0xffffffff, assetEntryOff + 4);

        // modelPtr con block 4 bit (0x80000000) y offset virtual 17137 + assetIndex * 8
        const modelPtr = (0x80000000 | (17137 + assetIndex * 8)) >>> 0;

        const smodelDrawInstsStart = 18000;
        const smodelInstsStart = 19000;
        // Instancia 0: cullDist=5000, origin=[150, -250, 10], scale=1.0
        buf.writeFloatLE(5000.0, smodelDrawInstsStart + 0);
        buf.writeFloatLE(150.0, smodelDrawInstsStart + 4);
        buf.writeFloatLE(-250.0, smodelDrawInstsStart + 8);
        buf.writeFloatLE(10.0, smodelDrawInstsStart + 12);
        // axis identidad
        buf.writeFloatLE(1.0, smodelDrawInstsStart + 16);
        buf.writeFloatLE(1.0, smodelDrawInstsStart + 32);
        buf.writeFloatLE(1.0, smodelDrawInstsStart + 48);
        buf.writeFloatLE(1.0, smodelDrawInstsStart + 52); // scale
        buf.writeUInt32LE(modelPtr, smodelDrawInstsStart + 56);
        buf.writeInt32LE(0, smodelDrawInstsStart + 60);

        // Bounding box en smodelInsts: mins=[140, -260, 0], maxs=[160, -240, 20]
        buf.writeFloatLE(140.0, smodelInstsStart + 0);
        buf.writeFloatLE(-260.0, smodelInstsStart + 4);
        buf.writeFloatLE(0.0, smodelInstsStart + 8);
        buf.writeFloatLE(160.0, smodelInstsStart + 12);
        buf.writeFloatLE(-240.0, smodelInstsStart + 16);
        buf.writeFloatLE(20.0, smodelInstsStart + 20);

        const layout = {
            smodelCount: 1,
            smodelDrawInstsStart,
            smodelInstsStart,
            cells: [],
        };
        const info = { smodelCount: 1 };

        const insts = extractStaticModelInstances(buf, info, layout);
        assert.equal(insts.length, 1);
        const inst = insts[0];
        assert.equal(inst.index, 0);
        assert.equal(inst.cullDist, 5000.0);
        assert.deepEqual(inst.origin, [150.0, -250.0, 10.0]);
        assert.equal(inst.scale, 1.0);
        assert.equal(inst.assetIndex, 3);
        assert.equal(inst.isXModel, true);
        assert.deepEqual(inst.mins, [140.0, -260.0, 0.0]);
        assert.deepEqual(inst.maxs, [160.0, -240.0, 20.0]);

        // Filtrado espacial: dentro vs fuera de límites
        const inside = extractStaticModelInstances(buf, info, layout, {
            bounds: { mins: [100, -300, 0], maxs: [200, -200, 50] }
        });
        assert.equal(inside.length, 1);

        const outside = extractStaticModelInstances(buf, info, layout, {
            bounds: { mins: [300, 0, 0], maxs: [400, 100, 50] }
        });
        assert.equal(outside.length, 0);
    });
});
