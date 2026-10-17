#!/usr/bin/env node
// Medidor de `sizeof` y alineación para las cabeceras de assets de T5.
//
// El recorrido del stream necesita saber cuántos bytes ocupa la región fija de
// cada struct (los punteros van inline). En vez de transcribir a mano decenas
// de tamaños, este medidor lee la cabecera y calcula el layout con las reglas
// de C para el tamaño de puntero indicado (4 en la zona de BO1 PC).
//
// No copia código de la referencia: solo lee la cabecera como texto, para
// calcular tamaños. Es la misma información que usa el generador de cargadores.
//
// Uso:
//   node tools/zsizeof.mjs <cabecera.h> [--ptr 4] [--type Nombre] [--fields Tipo] [--check]
//     --ptr <n>     tamaño de puntero en bytes (por defecto 4)
//     --type <n>    imprime solo el tamaño del tipo indicado
//     --fields <t>  imprime tamaño, alineación y offset de cada miembro del tipo
//     --check       comprueba los static_assert(sizeof(X) == N) de la cabecera
//
// Códigos de salida: 0 = correcto; 1 = error de lectura o comprobación fallida; 2 = uso incorrecto.

import { readFile } from "node:fs/promises";
import { basename, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const PRIMITIVE = {
    void: { size: 1, align: 1 },
    bool: { size: 1, align: 1 },
    char: { size: 1, align: 1 },
    int8_t: { size: 1, align: 1 },
    uint8_t: { size: 1, align: 1 },
    short: { size: 2, align: 2 },
    int16_t: { size: 2, align: 2 },
    uint16_t: { size: 2, align: 2 },
    int: { size: 4, align: 4 },
    unsigned: { size: 4, align: 4 },
    long: { size: 4, align: 4 },
    int32_t: { size: 4, align: 4 },
    uint32_t: { size: 4, align: 4 },
    float: { size: 4, align: 4 },
    int64_t: { size: 8, align: 8 },
    uint64_t: { size: 8, align: 8 },
    "unsigned short": { size: 2, align: 2 },
    "long long": { size: 8, align: 8 },
    "unsigned long long": { size: 8, align: 8 },
    double: { size: 8, align: 8 },
};

// Tipos que el medidor no llega a resolver: se avisa en vez de callar.

const TYPE_QUALIFIERS = new Set(["const", "volatile", "struct", "union", "enum", "signed", "unsigned"]);

/** Quita comentarios de línea y de bloque. */
function stripComments(src) {
    return src
        .replace(/\/\*[\s\S]*?\*\//g, " ")
        .replace(/\/\/[^\n]*/g, "");
}

/** Extrae los static_assert(sizeof(X) == N) para poder comprobarlos. */
function extractStaticAsserts(src) {
    const asserts = [];
    const re = /static_assert\(\s*sizeof\(\s*([A-Za-z_][A-Za-z_0-9]*)\s*\)\s*==\s*(\d+)/g;
    let match;
    while ((match = re.exec(src)) !== null) {
        asserts.push({ type: match[1], size: Number(match[2]) });
    }
    return asserts;
}

/** Convierte el texto en una lista de tokens. */
function tokenize(src) {
    const tokens = [];
    const re = /0x[0-9a-fA-F]+|[A-Za-z_][A-Za-z_0-9]*|\d+|[{}()[\];,:*]|\.\.\.|\S/g;
    let match;
    while ((match = re.exec(src)) !== null) tokens.push(match[0]);
    return tokens;
}

/** Lee un número entre paréntesis, si lo hay: `name(8)` → 8. */
function readAlignArg(tokens, i) {
    if (tokens[i + 1] !== "(") return null;
    const value = Number(tokens[i + 2]);
    return Number.isFinite(value) ? { align: value, next: i + 4 } : null;
}

/** Medidor: construye la tabla de tipos y calcula layout. */
export function createMeasurer(pointerSize = 4) {
    const types = new Map(); // nombre → { size, align, kind, members? }
    const enums = new Set();
    const constants = new Map(); // identificador de enum → valor numérico
    const unknown = new Set();

    function primitive(name) {
        if (PRIMITIVE[name]) return { ...PRIMITIVE[name] };
        if (types.has(name)) return types.get(name);
        return null;
    }

    function pointer() {
        return { size: pointerSize, align: pointerSize };
    }

    /** Reproduce las reglas de alineación del bloque de miembros. */
    function layout(members, explicitAlign) {
        let offset = 0;
        let maxAlign = 1;
        let inBitfieldUnit = false;
        let bitfieldFree = 0;
        const placed = [];
        for (const member of members) {
            if (member.bitfield !== undefined) {
                const base = member.base;
                const bits = member.bitfield;
                // Los bitfields consecutivos del mismo tipo comparten unidad de
                // `sizeof(base)`; al desbordarla, empieza otra.
                if (!inBitfieldUnit || bits > bitfieldFree) {
                    offset = Math.ceil(offset / base.size) * base.size + base.size;
                    bitfieldFree = base.size * 8;
                    inBitfieldUnit = true;
                }
                bitfieldFree -= bits;
                maxAlign = Math.max(maxAlign, base.align);
                placed.push({ name: member.name, offset: offset - base.size, size: 0, align: base.align, bitfield: bits });
                continue;
            }
            inBitfieldUnit = false;
            offset = Math.ceil(offset / member.align) * member.align;
            placed.push({ name: member.name, offset, size: member.size, align: member.align });
            offset += member.size;
            maxAlign = Math.max(maxAlign, member.align);
        }
        const align = Math.max(maxAlign, explicitAlign ?? 1);
        return { size: Math.ceil(offset / align) * align, align, members: placed };
    }

    /** Parsea el contenido completo: va acumulando tipos. */
    function parse(src) {
        const clean = stripComments(src);
        const asserts = extractStaticAsserts(clean);
        // Se descartan las directivas de preprocesador y los static_assert;
        // el resto (incluido lo que va en bloques #ifndef) se conserva.
        const body = clean
            .split("\n")
            .filter((line) => !/^\s*#/.test(line))
            .join("\n")
            .replace(/static_assert\([^)]*\)\s*;/g, "")
            .replace(/\bnamespace\s+[A-Za-z_][A-Za-z_0-9]*/g, "");
        const tokens = tokenize(body);
        parseDeclarations(tokens, 0);
        return asserts;
    }

    /** Recorre las declaraciones de primer nivel. */
    function parseDeclarations(tokens, start) {
        let i = start;
        while (i < tokens.length) {
            const token = tokens[i];
            if (token === "typedef") {
                i = parseTypedef(tokens, i + 1);
            } else if (token === "struct" || token === "union") {
                i = parseStructOrUnion(tokens, i);
            } else if (token === "enum") {
                i = parseEnum(tokens, i);
            } else if (token === "}") {
                i++;
            } else {
                i++;
            }
        }
        return i;
    }

    function skipAlignModifiers(tokens, i) {
        let align = 0;
        while (/^(type_align|gcc_align|tdef_align)(32|64)?$/.test(tokens[i] ?? "")) {
            const name = tokens[i];
            const applies = name.endsWith("64") ? pointerSize === 8 : name.endsWith("32") ? pointerSize === 4 : true;
            const arg = readAlignArg(tokens, i);
            if (!arg) break;
            if (applies) align = Math.max(align, arg.align);
            i = arg.next;
        }
        return { align, next: i };
    }

    function parseTypedef(tokens, i) {
        const mod = skipAlignModifiers(tokens, i);
        i = mod.next;
        // Tipo base (puede ser struct/union/enum).
        const { base, next } = readTypeName(tokens, i);
        i = next;
        let ptr = 0;
        while (tokens[i] === "*") { ptr++; i++; }
        const name = tokens[i];
        let size, align;
        if (ptr > 0) {
            ({ size, align } = pointer());
            if (mod.align) align = Math.max(align, mod.align);
        } else {
            const resolved = resolveType(base);
            size = resolved.size;
            align = Math.max(resolved.align, mod.align);
        }
        i++;
        // Arrays en el typedef: `typedef char ByteVec[3];`
        let esArray = false;
        while (tokens[i] === "[") {
            const count = Number(tokens[i + 1]);
            size *= count;
            i += 3;
            esArray = true;
        }
        if (tokens[i] === ";") i++;
        if (name && /^[A-Za-z_]/.test(name)) types.set(name, { size, align, kind: "typedef", target: ptr === 0 && !esArray ? base : null });
        return i;
    }

    const BASIC_WORDS = new Set(["void", "bool", "char", "short", "int", "long", "float", "double", "signed", "unsigned"]);

    /** Normaliza un tipo básico escrito con varias palabras a una clave conocida. */
    function canonical(words) {
        if (words.length === 0) return "int";
        const unsigned = words.includes("unsigned");
        if (words.includes("char")) return "char";
        if (words.includes("bool")) return "bool";
        if (words.includes("float")) return "float";
        if (words.includes("double")) return "double";
        if (words.includes("short")) return unsigned ? "unsigned short" : "short";
        if (words.filter((w) => w === "long").length >= 2) return unsigned ? "unsigned long long" : "long long";
        if (words.includes("long")) return unsigned ? "long" : "long";
        return unsigned ? "unsigned" : "int";
    }

    function readTypeName(tokens, i) {
        let j = i;
        while (tokens[j] === "const" || tokens[j] === "volatile") j++;
        if (tokens[j] === "struct" || tokens[j] === "union" || tokens[j] === "enum") j++;
        const words = [];
        while (BASIC_WORDS.has(tokens[j])) { words.push(tokens[j]); j++; }
        if (words.length === 0 && /^[A-Za-z_]/.test(tokens[j] ?? "")) {
            return { base: tokens[j], next: j + 1 };
        }
        return { base: canonical(words), next: j };
    }

    function resolveType(name) {
        const prim = primitive(name);
        if (prim) return prim;
        unknown.add(name);
        return { size: 4, align: 4 }; // desconocido: se asume int, pero se reporta
    }

    /** Parsea `struct`/`union` [nombre] [{ ... }] sin consumir el `;`. */
    function parseStructSpecifier(tokens, i) {
        const kind = tokens[i];
        let j = i + 1;
        const mod = skipAlignModifiers(tokens, j);
        j = mod.next;
        let name = null;
        if (/^[A-Za-z_]/.test(tokens[j] ?? "") && tokens[j + 1] === "{") {
            name = tokens[j];
            j++;
        }
        if (tokens[j] !== "{") {
            // Referencia a un tipo ya visto (o declaración adelantada).
            if (/^[A-Za-z_]/.test(tokens[j] ?? "")) { name = tokens[j]; j++; }
            return { name, layout: (name && types.get(name)) || null, next: j, definition: false };
        }
        const members = [];
        j++;
        while (j < tokens.length && tokens[j] !== "}") {
            if (tokens[j] === ";") { j++; continue; }
            const parsed = parseMember(tokens, j, kind);
            if (parsed.member) members.push(parsed.member);
            j = parsed.next;
        }
        j++; // '}'
        const computed = kind === "union" ? unionLayout(members, mod.align) : layout(members, mod.align);
        if (name) types.set(name, { ...computed, kind });
        return { name, layout: computed, next: j, definition: true };
    }

    function parseStructOrUnion(tokens, i) {
        const spec = parseStructSpecifier(tokens, i);
        let j = spec.next;
        while (j < tokens.length && tokens[j] !== ";") j++;
        return j + 1;
    }

    function unionLayout(members, explicitAlign) {
        let size = 0;
        let align = explicitAlign ?? 1;
        const placed = [];
        for (const member of members) {
            size = Math.max(size, member.size);
            align = Math.max(align, member.align);
            placed.push({ name: member.name, offset: 0, size: member.size, align: member.align });
        }
        return { size: Math.ceil(size / align) * align, align, members: placed };
    }

    function parseMember(tokens, i, containerKind) {
        const mod = skipAlignModifiers(tokens, i);
        let j = mod.next;
        if (tokens[j] === "struct" || tokens[j] === "union") {
            const spec = parseStructSpecifier(tokens, j);
            j = spec.next;
            const baseFor = () => spec.layout
                ? { size: spec.layout.size, align: Math.max(spec.layout.align, mod.align) }
                : null;
            let ptr = 0;
            while (tokens[j] === "*") { ptr++; j++; }
            let declName = null;
            if (/^[A-Za-z_]/.test(tokens[j] ?? "")) { declName = tokens[j]; j++; }
            if (spec.definition && spec.name === null && declName === null) {
                // Miembro anónimo (C11): ocupa espacio sin nombre.
                const base = baseFor();
                const { size, align, end } = applyArray(base, tokens, j);
                return { member: { size, align, name: null }, next: end };
            }
            if (declName === null) {
                // Definición de un tipo anidado, no es miembro.
                if (tokens[j] === ";") j++;
                return { member: null, next: j };
            }
            const base = ptr > 0 ? pointer() : baseFor();
            if (!base) {
                while (j < tokens.length && tokens[j] !== ";") j++;
                return { member: null, next: j + 1 };
            }
            const { size, align, end } = applyArray(base, tokens, j);
            return { member: { size, align, name: declName }, next: end };
        }
        const { base, next } = readTypeName(tokens, j);
        j = next;
        if (tokens[j] === "(" && tokens[j + 1] === "*") {
            const name = tokens[j + 2];
            j += 3;
            if (tokens[j] === ")") j++;
            while (j < tokens.length && tokens[j] !== ";") j++;
            if (tokens[j] === ";") j++;
            return { member: { size: pointerSize, align: pointerSize, name }, next: j };
        }
        let ptr = 0;
        while (tokens[j] === "*") { ptr++; j++; }
        if (ptr > 0) {
            const name = tokens[j];
            j++;
            const { size, align, end } = applyArray(pointer(), tokens, j);
            return { member: { size, align, name }, next: end };
        }
        const resolved = resolveType(base);
        const baseType = { size: resolved.size, align: Math.max(resolved.align, mod.align) };
        const name = tokens[j];
        if (tokens[j + 1] === ":") {
            const bits = Number(tokens[j + 2]);
            return { member: { bitfield: bits, base: baseType, name }, next: j + 4 };
        }
        j++;
        const { size, align, end } = applyArray(baseType, tokens, j);
        return { member: { size, align, name }, next: end };
    }

    function applyArray(baseType, tokens, i) {
        let size = baseType.size;
        let align = baseType.align;
        while (tokens[i] === "[") {
            const rawToken = tokens[i + 1];
            let count = Number(rawToken);
            if (!Number.isFinite(count) && constants.has(rawToken)) {
                count = constants.get(rawToken);
            }
            size *= Number.isFinite(count) ? count : 1;
            i += 3;
        }
        if (tokens[i] === ";") i++;
        return { size, align, end: i };
    }

    function parseEnum(tokens, i) {
        i++; // 'enum'
        let name = null;
        if (/^[A-Za-z_]/.test(tokens[i] ?? "")) { name = tokens[i]; i++; }
        let size = 4;
        let align = 4;
        if (tokens[i] === ":") {
            const named = readTypeName(tokens, i + 1);
            size = resolveType(named.base).size;
            align = resolveType(named.base).align;
            i = named.next;
        }
        if (tokens[i] === "{") {
            i++; // '{'
            let currentVal = 0;
            while (i < tokens.length && tokens[i] !== "}") {
                if (/^[A-Za-z_]/.test(tokens[i])) {
                    const constName = tokens[i];
                    i++;
                    if (tokens[i] === "=") {
                        i++; // '='
                        const valStr = tokens[i];
                        i++;
                        let val;
                        if (valStr.startsWith("0x") || valStr.startsWith("0X")) val = parseInt(valStr, 16);
                        else if (/^\d+$/.test(valStr)) val = parseInt(valStr, 10);
                        else if (constants.has(valStr)) val = constants.get(valStr);
                        else val = Number(valStr);
                        if (Number.isFinite(val)) {
                            constants.set(constName, val);
                            currentVal = val + 1;
                        }
                    } else {
                        constants.set(constName, currentVal);
                        currentVal++;
                    }
                } else if (tokens[i] === ",") {
                    i++;
                } else {
                    i++;
                }
            }
            if (tokens[i] === "}") i++;
        }
        if (tokens[i] !== ";") { /* enum con instancia: se salta */ }
        if (tokens[i] === ";") i++;
        if (name) { types.set(name, { size, align, kind: "enum" }); enums.add(name); }
        return i;
    }

    return {
        parse,
        sizeOf(name) {
            const type = types.get(name);
            return type ? type.size : null;
        },
        alignOf(name) {
            const type = types.get(name);
            return type ? type.align : null;
        },
        membersOf(name) {
            const type = types.get(name);
            return type && type.members ? type.members : null;
        },
        names() {
            return [...types.keys()].sort();
        },
        unknowns() {
            return [...unknown].sort();
        },
        constantOf(name) {
            return constants.has(name) ? constants.get(name) : null;
        },
        all() {
            return types;
        },
    };
}

async function main(argv) {
    const args = argv.slice(2);
    const ptrIndex = args.indexOf("--ptr");
    const pointerSize = ptrIndex === -1 ? 4 : Number(args[ptrIndex + 1]);
    const typeIndex = args.indexOf("--type");
    const typeName = typeIndex === -1 ? null : args[typeIndex + 1];
    const fieldsIndex = args.indexOf("--fields");
    const fieldsName = fieldsIndex === -1 ? null : args[fieldsIndex + 1];
    const check = args.includes("--check");
    const isOptionValue = (i) => [ptrIndex, typeIndex, fieldsIndex].some((index) => index >= 0 && i === index + 1);
    const file = args.find((arg, i) => !arg.startsWith("--") && !isOptionValue(i));

    if (!file || !Number.isFinite(pointerSize)) {
        console.error("Uso: node tools/zsizeof.mjs <cabecera.h> [--ptr 4] [--type Nombre] [--check]");
        return 2;
    }

    const source = await readFile(file, "utf8");
    const measurer = createMeasurer(pointerSize);
    const asserts = measurer.parse(source);

    const unknown = measurer.unknowns();
    if (unknown.length > 0) {
        console.error(`aviso: ${unknown.length} tipo(s) sin resolver (se asume int): ${unknown.slice(0, 12).join(", ")}${unknown.length > 12 ? "…" : ""}`);
    }

    if (check) {
        let failures = 0;
        for (const { type, size } of asserts) {
            const actual = measurer.sizeOf(type);
            if (actual !== size) {
                console.error(`FALLO ${type}: static_assert dice ${size}, calculado ${actual}`);
                failures++;
            }
        }
        console.log(`${basename(file)}: ${asserts.length} static_assert, ${failures} fallo(s)`);
        return failures === 0 ? 0 : 1;
    }

    if (fieldsName) {
        const members = measurer.membersOf(fieldsName);
        const size = measurer.sizeOf(fieldsName);
        if (!members) {
            console.error(`Tipo desconocido o sin miembros: ${fieldsName}`);
            return 1;
        }
        console.log(`${fieldsName}: size ${size}, align ${measurer.alignOf(fieldsName)}`);
        for (const member of members) {
            const label = member.bitfield !== undefined ? `${member.name} : ${member.bitfield}` : member.name;
            console.log(`  +${String(member.offset).padStart(4)}  ${String(member.size).padStart(4)} B  ${label ?? "(anonimo)"}`);
        }
        return 0;
    }

    if (typeName) {
        const size = measurer.sizeOf(typeName);
        if (size === null) {
            console.error(`Tipo desconocido: ${typeName}`);
            return 1;
        }
        console.log(`${typeName}: size ${size}, align ${measurer.alignOf(typeName)}`);
        return 0;
    }

    console.log(`${basename(file)}: ${measurer.names().length} tipos (puntero ${pointerSize} B)`);
    return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    main(process.argv)
        .then((code) => { process.exitCode = code; })
        .catch((error) => {
            console.error(`Error: ${error.message}`);
            process.exitCode = 1;
        });
}
