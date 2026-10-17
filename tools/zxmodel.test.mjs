import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
    unpackUnitVec,
    unpackHalfFloat,
    findXModelOffset,
    decodeXModel,
    buildLodMesh,
    toWavefrontObj,
} from "./zxmodel.mjs";

const FOLLOWING = 0xffffffff;
const STREAM_VERT_SENTINEL = 0x0000ffff;

/**
 * Construye un XModel sintético con 1 superficie (triángulo simple de 3 vértices)
 * siguiendo exactamente el layout de T5 PC (252B XModel + bloques following + 68B XSurface).
 */
function buildSyntheticXModelBuffer(name = "test_pyramid", { useStreamSentinel = false } = {}) {
    const nameBytes = Buffer.from(name + "\0", "latin1");
    const numBones = 2;
    const numRootBones = 1;
    const childBones = numBones - numRootBones;
    const numsurfs = 1;
    const vertCount = 3;
    const triCount = 1;

    // Cabecera XModel (252 bytes)
    const header = Buffer.alloc(252, 0);
    header.writeUInt32LE(FOLLOWING, 0); // name
    header[4] = numBones;
    header[5] = numRootBones;
    header[6] = numsurfs;
    header[7] = 0; // lodRampType
    header.writeUInt32LE(FOLLOWING, 8);  // boneNames
    header.writeUInt32LE(FOLLOWING, 12); // parentList
    header.writeUInt32LE(FOLLOWING, 16); // quats
    header.writeUInt32LE(FOLLOWING, 20); // trans
    header.writeUInt32LE(FOLLOWING, 24); // partClassification
    header.writeUInt32LE(FOLLOWING, 28); // baseMat
    header.writeUInt32LE(FOLLOWING, 32); // surfs
    header.writeUInt32LE(FOLLOWING, 36); // materialHandles

    // lodInfo[0] en +40
    header.writeFloatLE(1000.0, 40);
    header.writeUInt16LE(1, 44); // numsurfs
    header.writeUInt16LE(0, 46); // surfIndex

    // bounds
    header.writeFloatLE(15.0, 188); // radius
    header.writeFloatLE(-10.0, 192);
    header.writeFloatLE(-5.0, 196);
    header.writeFloatLE(0.0, 200);
    header.writeFloatLE(10.0, 204);
    header.writeFloatLE(5.0, 208);
    header.writeFloatLE(12.0, 212);
    header.writeInt16LE(1, 216); // numLods

    // Bloques de huesos
    const boneBlocks = Buffer.alloc(
        numBones * 2 +
        childBones * 1 +
        childBones * 8 +
        childBones * 16 +
        numBones * 1 +
        numBones * 32,
        0
    );

    // XSurface (68 bytes)
    const xsurf = Buffer.alloc(68, 0);
    xsurf[1] = 1; // vertListCount = 1
    xsurf.writeUInt16LE(vertCount, 4);
    xsurf.writeUInt16LE(triCount, 6);
    const ptrMarker = useStreamSentinel ? STREAM_VERT_SENTINEL : FOLLOWING;
    xsurf.writeUInt32LE(ptrMarker, 12); // triIndices
    xsurf.writeInt16LE(1, 16); // vertInfo.vertCount[0] = 1
    xsurf.writeUInt32LE(FOLLOWING, 24); // vertsBlend
    xsurf.writeUInt32LE(0, 28); // tensionData = NULL
    xsurf.writeUInt32LE(ptrMarker, 32); // verts0
    xsurf.writeUInt32LE(FOLLOWING, 40); // vertList

    // 1. vertInfo.vertsBlend: 1 * 2 bytes
    const vertsBlend = Buffer.alloc(2, 0);

    // 2. verts0: 3 * 32 bytes (GfxPackedVertex)
    const verts0 = Buffer.alloc(vertCount * 32, 0);
    const coords = [
        [-10.0, -5.0, 0.0],
        [10.0, -5.0, 0.0],
        [0.0, 5.0, 12.0],
    ];
    for (let i = 0; i < vertCount; i++) {
        const vp = i * 32;
        verts0.writeFloatLE(coords[i][0], vp + 0);
        verts0.writeFloatLE(coords[i][1], vp + 4);
        verts0.writeFloatLE(coords[i][2], vp + 8);
        verts0.writeFloatLE(1.0, vp + 12);
        // RGBA
        verts0[vp + 16] = 255;
        verts0[vp + 17] = 128;
        verts0[vp + 18] = 64;
        verts0[vp + 19] = 255;
        // texCoord: u = 0.5 (0x3800), v = 1.0 (0x3c00)
        verts0.writeUInt32LE((0x3800 << 16) | 0x3c00, vp + 20);
        // normal: (0, 0, +1) -> b0=127, b1=127, b2=254, b3=63 ((63+192)/32385 * 127 = 1.0)
        verts0[vp + 24] = 127;
        verts0[vp + 25] = 127;
        verts0[vp + 26] = 254;
        verts0[vp + 27] = 63;
    }

    // 3. vertList (12 bytes) + XSurfaceCollisionTree (40 bytes + 1 node * 16B + 2 leafs * 2B)
    const vertList = Buffer.alloc(12, 0);
    vertList.writeUInt32LE(FOLLOWING, 8); // collisionTree
    const ctree = Buffer.alloc(40, 0);
    ctree.writeUInt32LE(1, 24); // nodeCount = 1
    ctree.writeUInt32LE(FOLLOWING, 28); // nodes
    ctree.writeUInt32LE(2, 32); // leafCount = 2
    ctree.writeUInt32LE(FOLLOWING, 36); // leafs
    const ctreeData = Buffer.alloc(1 * 16 + 2 * 2, 0);

    // 4. triIndices: 1 * 6 bytes
    const tris = Buffer.alloc(6, 0);
    tris.writeUInt16LE(0, 0);
    tris.writeUInt16LE(1, 2);
    tris.writeUInt16LE(2, 4);

    const prefix = Buffer.alloc(64, 0xaa);
    return {
        buffer: Buffer.concat([
            prefix,
            header,
            nameBytes,
            boneBlocks,
            xsurf,
            vertsBlend,
            verts0,
            vertList,
            ctree,
            ctreeData,
            tris,
        ]),
        expectedOffset: prefix.length,
    };
}

describe("zxmodel", () => {
    it("desempaqueta PackedUnitVec con escala de T5", () => {
        // (127, 127, 254, 63) -> scale = 255 / 32385 = 1 / 127 -> (0, 0, 1)
        const [nx, ny, nz] = unpackUnitVec(127, 127, 254, 63);
        assert.equal(nx, 0);
        assert.equal(ny, 0);
        assert.ok(Math.abs(nz - 1.0) < 1e-6);
    });

    it("desempaqueta float16 (IEEE 754 binary16) a float32", () => {
        assert.equal(unpackHalfFloat(0x0000), 0);
        assert.equal(unpackHalfFloat(0x3c00), 1.0);
        assert.equal(unpackHalfFloat(0xbc00), -1.0);
        assert.equal(unpackHalfFloat(0x3800), 0.5);
    });

    it("localiza y decodifica un XModel con punteros 0xFFFFFFFF y 0x0000FFFF", () => {
        for (const useStreamSentinel of [false, true]) {
            const { buffer, expectedOffset } = buildSyntheticXModelBuffer("zombie_test_skull", {
                useStreamSentinel,
            });
            const found = findXModelOffset(buffer, "zombie_test_skull");
            assert.equal(found, expectedOffset);

            const model = decodeXModel(buffer, found);
            assert.equal(model.name, "zombie_test_skull");
            assert.equal(model.numBones, 2);
            assert.equal(model.numRootBones, 1);
            assert.equal(model.numsurfs, 1);
            assert.equal(model.numLods, 1);
            assert.deepEqual(model.bounds.mins, [-10, -5, 0]);
            assert.deepEqual(model.bounds.maxs, [10, 5, 12]);

            const surf = model.surfaces[0];
            assert.equal(surf.vertCount, 3);
            assert.equal(surf.triCount, 1);
            assert.equal(surf.allIndicesValid, true);
            assert.deepEqual(surf.indices, [0, 1, 2]);
            assert.deepEqual(surf.vertices[2].position, [0, 5, 12]);
            assert.deepEqual(surf.vertices[0].uv, [0.5, 1.0]);
            assert.ok(Math.abs(surf.vertices[0].normal[2] - 1.0) < 1e-6);

            const mesh = buildLodMesh(model, 0);
            assert.equal(mesh.vertexCount, 3);
            assert.equal(mesh.triangleCount, 1);

            const obj = toWavefrontObj(model, 0);
            assert.match(obj, /o zombie_test_skull/);
            assert.match(obj, /v -10\.000000 -5\.000000 0\.000000/);
            assert.match(obj, /f 1\/1\/1 2\/2\/2 3\/3\/3/);
        }
    });
});
