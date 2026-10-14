import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { createMeasurer } from "./zsizeof.mjs";

// Cabecera mínima que usa las mismas construcciones que las cabeceras reales:
// tipos de varias palabras, punteros, arrays, bitfields, uniones, structs
// anónimos, enums con tipo base, typedefs y macros de alineación.
const HEADER = `
enum SmallEnum : unsigned char { A = 1, B = 2 };

typedef unsigned int uint32;

union vec3_t {
    struct { float x; float y; float z; };
    float v[3];
};

struct type_align(8) Aligned8 { int a; };

union gcc_align32(8) Packed8 {
    uint64_t packed;
    struct { unsigned int lo; unsigned int hi; } parts;
};

struct Bits {
    unsigned int a : 1;
    unsigned int b : 31;
    unsigned int c : 1;
    unsigned char d;
};

struct Mixed {
    const char* name;
    unsigned char pad;
    unsigned short count;
    uint32 values[3];
    SmallEnum kind;
    Aligned8 aligned;
    struct { unsigned int inner; } ext;
};

static_assert(sizeof(Aligned8) == 8);
static_assert(sizeof(Bits) == 12);
static_assert(sizeof(vec3_t) == 12);
`;

function measure(source, pointerSize = 4) {
    const measurer = createMeasurer(pointerSize);
    const asserts = measurer.parse(source);
    return { measurer, asserts };
}

test("mide tipos básicos, arrays y punteros", () => {
    const { measurer } = measure(HEADER);
    assert.equal(measurer.sizeOf("uint32"), 4);
    assert.equal(measurer.sizeOf("vec3_t"), 12);
    assert.equal(measurer.sizeOf("SmallEnum"), 1);
});

test("respeta las macros de alineación", () => {
    const { measurer } = measure(HEADER);
    assert.equal(measurer.sizeOf("Aligned8"), 8);
    assert.equal(measurer.alignOf("Aligned8"), 8);
    assert.equal(measurer.sizeOf("Packed8"), 8);
    assert.equal(measurer.alignOf("Packed8"), 8);
});

test("empaqueta bitfields consecutivos en unidades del tipo base", () => {
    const { measurer } = measure(HEADER);
    // 1 + 31 bits llenan una unidad de 4; el bit 33 abre otra; el char va detrás.
    assert.equal(measurer.sizeOf("Bits"), 12);
});

test("el tamaño del puntero cambia la región fija", () => {
    const with4 = measure(HEADER, 4).measurer;
    const with8 = measure(HEADER, 8).measurer;
    // con puntero de 4: 4+1+2+12+1 (+3 relleno) +8 +4, redondeado a align 8
    assert.equal(with4.sizeOf("Mixed"), 40);
    // con puntero de 8: 8+1+2+12+1 (+7 relleno) +8 +4
    assert.equal(with8.sizeOf("Mixed"), 48);
    assert.equal(with4.alignOf("Mixed"), 8);
    assert.equal(with8.alignOf("Mixed"), 8);
});

test("cuenta los miembros anónimos como miembros normales", () => {
    const { measurer } = measure(HEADER);
    // Mixed = 4+1+2+12+1 (+3 de relleno) +8 (Miembro alineado) +4, cerrado a 8.
    assert.equal(measurer.sizeOf("Mixed"), 40);
});

test("recoge los static_assert de la cabecera", () => {
    const { asserts } = measure(HEADER);
    assert.deepEqual(asserts, [
        { type: "Aligned8", size: 8 },
        { type: "Bits", size: 12 },
        { type: "vec3_t", size: 12 },
    ]);
});

test("sitúa cada miembro en su offset, con el relleno incluido", () => {
    const { measurer } = measure(HEADER);
    const mixed = measurer.membersOf("Mixed").map((m) => [m.name, m.offset, m.size]);
    assert.deepEqual(mixed, [
        ["name", 0, 4],
        ["pad", 4, 1],
        ["count", 6, 2],
        ["values", 8, 12],
        ["kind", 20, 1],
        ["aligned", 24, 8],
        ["ext", 32, 4],
    ]);
    const bits = measurer.membersOf("Bits").map((m) => [m.name, m.offset, m.bitfield]);
    assert.deepEqual(bits, [
        ["a", 0, 1],
        ["b", 0, 31],
        ["c", 4, 1],
        ["d", 8, undefined],
    ]);
    // Los miembros de una union comparten el offset 0.
    assert.deepEqual(measurer.membersOf("Packed8").map((m) => m.offset), [0, 0]);
    assert.equal(measurer.membersOf("NoExiste"), null);
});

test("--fields imprime tamaño, alineación y offsets", () => {
    const dir = mkdtempSync(join(tmpdir(), "zsizeof-"));
    try {
        const file = join(dir, "campos.h");
        writeFileSync(file, HEADER);
        const out = execFileSync(process.execPath, [fileURLToPath(new URL("./zsizeof.mjs", import.meta.url)), file, "--fields", "Bits"], {
            encoding: "utf8",
        });
        assert.match(out, /Bits: size 12, align 4/);
        assert.match(out, /\+\s*0\s+0 B\s+a : 1/);
        assert.match(out, /\+\s*4\s+0 B\s+c : 1/);
        assert.match(out, /\+\s*8\s+1 B\s+d/);
    } finally {
        rmSync(dir, { recursive: true, force: true });
    }
});

test("--fields falla con un tipo desconocido", () => {
    const dir = mkdtempSync(join(tmpdir(), "zsizeof-"));
    try {
        const file = join(dir, "campos.h");
        writeFileSync(file, HEADER);
        assert.throws(
            () => execFileSync(process.execPath, [fileURLToPath(new URL("./zsizeof.mjs", import.meta.url)), file, "--fields", "NoExiste"], {
                encoding: "utf8",
                stdio: "pipe",
            }),
            /Command failed/,
        );
    } finally {
        rmSync(dir, { recursive: true, force: true });
    }
});

test("avisa de los tipos que no logra resolver", () => {
    const { measurer } = measure("struct S { UnknownType t; int tail; };");
    assert.deepEqual(measurer.unknowns(), ["UnknownType"]);
});

test("--check devuelve 0 si los static_assert cuadran", () => {
    const dir = mkdtempSync(join(tmpdir(), "zsizeof-"));
    try {
        const file = join(dir, "ok.h");
        writeFileSync(file, HEADER);
        const out = execFileSync(process.execPath, [fileURLToPath(new URL("./zsizeof.mjs", import.meta.url)), file, "--check"], {
            encoding: "utf8",
        });
        assert.match(out, /3 static_assert, 0 fallo/);
    } finally {
        rmSync(dir, { recursive: true, force: true });
    }
});

test("--check falla si un static_assert no cuadra", () => {
    const dir = mkdtempSync(join(tmpdir(), "zsizeof-"));
    try {
        const file = join(dir, "mal.h");
        writeFileSync(file, "struct S { int a; };\nstatic_assert(sizeof(S) == 99);\n");
        assert.throws(
            () => execFileSync(process.execPath, [fileURLToPath(new URL("./zsizeof.mjs", import.meta.url)), file, "--check"], {
                encoding: "utf8",
                stdio: "pipe",
            }),
            /Command failed/,
        );
    } finally {
        rmSync(dir, { recursive: true, force: true });
    }
});
