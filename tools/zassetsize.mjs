#!/usr/bin/env node
// Tamaño real de los assets de un FastFile (.ff) de BO1 PC (T5) aplicando el
// modelo de escritura (tools/ztypemods.mjs) y las expresiones de las
// directivas (`count`, `arraysize`, `string`) contra el stream.
//
// Es el paso que convierte el modelo en tamaños: la región fija sale del
// struct, y los datos following se miden resolviendo, con los valores que el
// propio asset lleva dentro, las expresiones de sus directivas.
//
// Uso:
//   node tools/zassetsize.mjs <src de la referencia> <archivo.ff> --plan TIPO
//   node tools/zassetsize.mjs <src> <archivo.ff> --type TIPO
//   node tools/zassetsize.mjs <src> <archivo.ff> --walk INICIO FIN [--expect N] [--sep N]
//     --plan T   imprime el plan de tamaño del tipo (pasos y expresiones)
//     --type T   mide el primer asset de ese tipo y lo compara con el hueco real
//     --walk A B mide los assets A..B (desde el índice 0, para arrastrar el cursor)
//     --expect N comprueba que la región A..B mide N bytes
//     --sep N    bytes de separación entre assets (por defecto 1)
//
// Códigos de salida: 0 = correcto; 1 = no se pudo medir o la comprobación falla;
// 2 = uso incorrecto.

import { readFileSync } from "node:fs";
import { basename } from "node:path";
import { inflateSync } from "node:zlib";
import { loadModel } from "./ztypemods.mjs";
import { parseAssetList, T5_ASSET_TYPE_NAMES } from "./zoneassets.mjs";

const HEADER_LEN = 12; // cabecera del .ff (magic + versión)
const FOLLOWING = 0xffffffff;
const LOADDEF_FOLLOWING = 0xfffffffe;

function combinarDirectivas(sub, def) {
    if (!sub && !def) return null;
    if (!sub) return def;
    if (!def) return sub;
    return {
        struct: sub.struct, file: sub.file || def.file,
        strings: [...new Set([...sub.strings, ...def.strings])],
        counts: [...sub.counts, ...def.counts.filter((c) => !sub.counts.some((sc) => sc.member === c.member))],
        arraysizes: [...sub.arraysizes, ...def.arraysizes.filter((c) => !sub.arraysizes.some((sc) => sc.member === c.member))],
        reusables: [...new Set([...sub.reusables, ...def.reusables])],
        conditions: [...sub.conditions, ...def.conditions.filter((c) => !sub.conditions.some((sc) => sc.member === c.member))],
        scriptstrings: [...new Set([...sub.scriptstrings, ...def.scriptstrings])],
        assetrefs: [...new Set([...sub.assetrefs, ...def.assetrefs])],
        blocks: [...new Set([...sub.blocks, ...def.blocks])],
        runtimeBlocks: [...new Set([...(sub.runtimeBlocks ?? []), ...(def.runtimeBlocks ?? [])])],
        allocaligns: [...new Set([...sub.allocaligns, ...def.allocaligns])],
        actions: [...new Set([...sub.actions, ...def.actions])],
        reorder: sub.reorder && sub.reorder.length ? sub.reorder : def.reorder,
        scoped: [...(sub.scoped ?? []), ...(def.scoped ?? [])],
    };
}

/**
 * Cabecera fija de un `GfxImageLoadDef`: hasta el miembro flexible `data[1]`
 * (sin el byte de relleno del struct). Los datos reales no entran aquí.
 */
function cabeceraLoadDef(modelo) {
    const data = (modelo.miembros("GfxImageLoadDef") ?? []).find((x) => x.name === "data");
    if (!data) throw new SinResolver("GfxImageLoadDef sin data");
    return data.offset;
}

// ---------------------------------------------------------------------------
// Miembros de los structs: qué tipo declara cada uno (zsizeof da tamaños y
// offsets, pero no el tipo, y para `count` hacen falta los del tipo apuntado).
// ---------------------------------------------------------------------------
function parseMemberDecls(source) {
    const clean = source
        .replace(/\/\*[\s\S]*?\*\//g, " ")
        .replace(/\/\/[^\n]*/g, "");
    const decls = new Map(); // struct → [{ type, ptr, dims, name }]

    for (const m of clean.matchAll(/(?:^|\n)\s*(?:struct|union)\s+(?:(?:type_align|gcc_align|tdef_align)(?:32|64)?\s*\(\s*\d+\s*\)\s*)*([A-Za-z_][\w]*)\s*\{/g)) {
        const nombre = m[1];
        const abre = m.index + m[0].length - 1;
        let nivel = 0;
        let fin = -1;
        for (let i = abre; i < clean.length; i++) {
            if (clean[i] === "{") nivel++;
            else if (clean[i] === "}") { nivel--; if (nivel === 0) { fin = i; break; } }
        }
        if (fin === -1) continue;

        const cuerpo = clean.slice(abre + 1, fin);
        const miembros = [];
        let buffer = "";
        nivel = 0;
        for (const ch of cuerpo) {
            if (ch === "{" || ch === "(") nivel++;
            else if (ch === "}" || ch === ")") nivel--;
            if (ch === ";" && nivel === 0) {
                const declaracion = buffer.trim();
                buffer = "";
                const miembro = parseOneDecl(declaracion);
                if (miembro) miembros.push(...miembro);
                continue;
            }
            buffer += ch;
        }
        if (!decls.has(nombre)) decls.set(nombre, miembros);
    }
    return decls;
}

/** Una declaración (`const char* name;`) → uno o más miembros. */
function parseOneDecl(declaracion) {
    if (declaracion === "") return null;
    // Agrupadas: `float x, y, z;`
    const partes = declaracion.split(",").map((p) => p.trim());
    const resultado = [];
    for (let i = 0; i < partes.length; i++) {
        const parte = i === 0 ? partes[i] : partes[i];
        // Puntero a array: `const float (*name)[4]` → el puntero apunta a `float[4]`.
        const aArr = /^([\s\S]*?)\(\s*\*\s*([A-Za-z_][\w]*)\s*\)\s*((?:\[\s*\d*\s*\]\s*)*)$/.exec(parte);
        if (aArr) {
            const base = aArr[1].replace(/^(const|volatile|struct|union|enum|signed)\s+/g, "")
                .replace(/\s+(const|volatile)$/g, "").trim();
            if (base !== "" && !base.includes("(")) {
                const pointeeDims = [...aArr[3].matchAll(/\[\s*(\d*)\s*\]/g)].map((m) => (m[1] === "" ? null : Number(m[1])));
                resultado.push({ type: base, ptr: 1, dims: [], name: aArr[2], pointeeDims, anon: false, bruto: declaracion });
                continue;
            }
        }
        const dims = [];
        let resto = parte;
        while (/\[\s*(\w*)\s*\]\s*$/.test(resto)) {
            const m = /\[\s*(\w*)\s*\]\s*$/.exec(resto);
            const val = m[1] === "" ? null : (Number.isFinite(Number(m[1])) ? Number(m[1]) : m[1]);
            dims.unshift(val);
            resto = resto.slice(0, m.index).trim();
        }
        const nameMatch = /([A-Za-z_][\w]*)\s*$/.exec(resto);
        if (!nameMatch) continue;
        const name = nameMatch[1];
        let tipo = resto.slice(0, nameMatch.index).trim();
        let ptr = 0;
        // Solo los punteros de primer nivel: `int* x` y también `int *x`.
        tipo = tipo.replace(/\*\s*$/, (s) => { ptr++; return ""; }).trim();
        while (/\*\s*$/.test(tipo)) { tipo = tipo.replace(/\*\s*$/, "").trim(); ptr++; }
        tipo = tipo
            .replace(/^(const|volatile|struct|union|enum|signed)\s+/g, "")
            .replace(/\s+(const|volatile)$/g, "")
            .trim();
        if (tipo === "" || tipo.includes("(")) continue; // puntero a función o anónimo
        resultado.push({ type: tipo, ptr, dims, name, anon: false, bruto: declaracion });
    }
    return resultado.length ? resultado : null;
}

// ---------------------------------------------------------------------------
// Expresiones de las directivas: `len + 1`, `numBones - numRootBones`,
// `columnCount * rowCount`, `boneCount[9]`, `header::count`, `32`.
// Se evalúan leyendo los valores del propio asset (su región fija).
// ---------------------------------------------------------------------------
class SinResolver extends Error {}

function tokenize(expr) {
    const tokens = [];
    const re = /<=|>=|==|!=|&&|\|\||0[xX][0-9a-zA-Z_]*|[A-Za-z_][\w]*|\d+|::|[\s()+\-*/%\[\]<>!]/g;
    let m;
    while ((m = re.exec(expr)) !== null) {
        const t = m[0];
        if (!/\s/.test(t)) tokens.push(t);
    }
    return tokens;
}

/**
 * @param {string} expr expresión de la directiva
 * @param {(path: string[], index: number|null) => number} leer lee un miembro del asset
 */
export function evalExpr(expr, leer) {
    const tokens = tokenize(expr);
    let i = 0;
    const ve = () => tokens[i];
    const come = (t) => { if (tokens[i] === t) { i++; return true; } return false; };

    function primario() {
        if (come("-")) return -primario();
        if (come("(")) {
            const v = oLogica();
            if (!come(")")) throw new SinResolver(`paréntesis sin cerrar en "${expr}"`);
            return v;
        }
        const t = ve();
        if (t === undefined) throw new SinResolver(`expresión incompleta "${expr}"`);
        if (/^0[xX][0-9a-fA-F]+$/.test(t)) {
            i++;
            return parseInt(t, 16);
        }
        if (/^\d+$/.test(t)) {
            i++;
            return Number(t);
        }
        if (/^[A-Za-z_]/.test(t)) {
            const path = [t];
            i++;
            while (come("::")) {
                const s = ve();
                if (!s || !/^[A-Za-z_]/.test(s)) throw new SinResolver(`ruta rota en "${expr}"`);
                path.push(s);
                i++;
            }
            let index = null;
            if (come("[")) {
                index = suma();
                if (!come("]")) throw new SinResolver(`corchete sin cerrar en "${expr}"`);
            }
            return leer(path, index);
        }
        throw new SinResolver(`token inesperado "${t}" en "${expr}"`);
    }
    function producto() {
        let v = primario();
        for (;;) {
            if (come("*")) v *= primario();
            else if (come("/")) { const d = primario(); if (d === 0) throw new SinResolver(`división por cero en "${expr}"`); v = Math.trunc(v / d); }
            else if (come("%")) { const d = primario(); if (d === 0) throw new SinResolver(`resto por cero en "${expr}"`); v %= d; }
            else return v;
        }
    }
    function suma() {
        let v = producto();
        for (;;) {
            if (come("+")) v += producto();
            else if (come("-")) v -= producto();
            else return v;
        }
    }
    /** Comparaciones: `==`, `!=`, `<`, `<=`, `>`, `>=` (devuelven 1 o 0). */
    function comparacion() {
        const a = suma();
        if (come("==")) return a === suma() ? 1 : 0;
        if (come("!=")) return a !== suma() ? 1 : 0;
        if (come("<=")) return a <= suma() ? 1 : 0;
        if (come(">=")) return a >= suma() ? 1 : 0;
        if (come("<")) return a < suma() ? 1 : 0;
        if (come(">")) return a > suma() ? 1 : 0;
        return a;
    }
    /** Y lógico (`&&`). */
    function yLogica() {
        let v = comparacion();
        while (come("&&")) { const r = comparacion(); v = v !== 0 && r !== 0 ? 1 : 0; }
        return v;
    }
    /** O lógico (`||`). */
    function oLogica() {
        let v = yLogica();
        while (come("||")) { const r = yLogica(); v = v !== 0 || r !== 0 ? 1 : 0; }
        return v;
    }
    const valor = oLogica();
    if (i !== tokens.length) throw new SinResolver(`sobra "${tokens.slice(i).join(" ")}" en "${expr}"`);
    return valor;
}

// ---------------------------------------------------------------------------
// Plan de tamaño de un tipo: región fija + pasos following en orden.
// ---------------------------------------------------------------------------
const ENTEROS_CON_SIGNO = new Set(["int", "int8_t", "int16_t", "int32_t", "short", "char", "long"]);

// Tipos básicos: zsizeof solo mide lo que declara la cabecera, así que los
// primitivos se resuelven aquí (mismo tamaño que el compilador de 32 bits).
const PRIMITIVOS = new Map([
    ["void", 1], ["bool", 1], ["char", 1], ["int8_t", 1], ["uint8_t", 1],
    ["short", 2], ["int16_t", 2], ["uint16_t", 2],
    ["unsigned char", 1], ["unsigned short", 2], ["unsigned int", 4],
    ["long long", 8], ["unsigned long", 4], ["unsigned long long", 8],
    ["int", 4], ["unsigned", 4], ["long", 4], ["int32_t", 4], ["uint32_t", 4], ["float", 4],
    ["int64_t", 8], ["uint64_t", 8], ["double", 8],
]);

export class Modelo {
    constructor(src) {
        this.modelo = loadModel(src);
        this.decls = parseMemberDecls(readFileSync(this.modelo.assetsHeader, "utf8"));
        this.assetStructs = new Set(this.modelo.mapping.values());
        this.planes = new Map();
        this.planesStruct = new Map();
    }

    medidor() { return this.modelo.medidor; }

    /** Miembros del struct con offset y tamaño (de zsizeof) fusionados con el tipo declarado. */
    /** Valor numérico de un enum de T5_Assets.h, o null si no existe. */
    enumValor(nombre) {
        return this.modelo.enumValor(nombre);
    }

    /** Directivas de un struct por su nombre (las regiones anidadas las necesitan). */
    directivesOfStruct(struct) {
        if (this.modelo.byStruct.has(struct)) return this.modelo.byStruct.get(struct);
        const t = this.medidor().all().get(struct)?.target;
        return t ? (this.modelo.byStruct.get(t) ?? null) : null;
    }

    miembros(struct) {
        let real = struct;
        let offsets = this.medidor().membersOf(real);
        if (!offsets) {
            const t = this.medidor().all().get(real)?.target;
            if (t) { real = t; offsets = this.medidor().membersOf(real); }
        }
        if (!offsets) return null;
        const declarados = this.decls.get(real) ?? [];
        const porNombre = new Map(declarados.map((d) => [d.name, d]));
        return offsets.map((m) => ({ ...m, ...(porNombre.get(m.name) ?? { type: null, ptr: 0, dims: [] }) }));
    }

    sizeOf(type) {
        const del = this.medidor().sizeOf(type);
        if (del !== null) return del;
        return PRIMITIVOS.has(type) ? PRIMITIVOS.get(type) : null;
    }

    /** Tamaño del elemento de un `count`: el tipo apuntado por el miembro. */
    elemSize(struct, member) {
        const lista = this.miembros(struct);
        const m = lista ? lista.find((x) => x.name === member) : null;
        if (!m) throw new SinResolver(`no está el miembro ${struct}::${member}`);
        if (m.ptr >= 2) return 4;
        if (m.ptr === 0) {
            // `count` sobre un array inline: el elemento es el tipo base.
            const base = this.sizeOf(m.type);
            if (base === null) throw new SinResolver(`tipo ${m.type} sin tamaño (${struct}::${member})`);
            return base;
        }
        const base = this.sizeOf(m.type);
        if (base === null) throw new SinResolver(`tipo ${m.type} sin tamaño (${struct}::${member})`);
        return base;
    }

    /**
     * Plan de un tipo de asset: pasos following en el orden en que el escritor
     * los emite (orden de declaración de los miembros, con `reorder` delante).
     */
    plan(tipo) {
        if (this.planes.has(tipo)) return this.planes.get(tipo);
        const struct = this.modelo.structOf(tipo);
        if (!struct) throw new SinResolver(`no hay struct para el tipo ${tipo}`);
        const dir = this.modelo.directivesOf(tipo);
        const pasos = [];
        const faltas = [];
        this.recogerPasos(struct, dir, pasos, faltas, "");
        const fijo = this.sizeOf(struct);
        const declarados = this.decls.get(struct) ?? [];
        const plan = { tipo, struct, fijo, pasos, faltas, directivas: dir, avisos: avisosDeDirectiva(declarados, dir) };
        this.planes.set(tipo, plan);
        return plan;
    }

    /**
     * Plan de following de un struct cualquiera. Es lo que permite medir las
     * regiones anidadas (un `MaterialTechnique` dentro de un `TECHNIQUE_SET`,
     * una `MaterialPass` dentro de una técnica, …).
     */
    planStruct(struct, dir) {
        const clave = `struct:${struct}`;
        const guardado = this.planesStruct.get(clave);
        if (guardado) return guardado;
        const pasos = [];
        const faltas = [];
        this.recogerPasos(struct, dir, pasos, faltas, "");
        const dinamico = pasos.some((p) => p.clase === "arraysize");
        const fijo = dinamico
            ? Math.min(...pasos.filter((p) => p.clase === "arraysize" || p.clase === "hojaUnion").map((p) => p.offset))
            : this.sizeOf(struct);
        const plan = { struct, fijo, dinamico, pasos, faltas };
        this.planesStruct.set(clave, plan);
        return plan;
    }

    /** Recorre los miembros y añade los pasos; baja a sub-structs por valor. */
    recogerPasos(struct, dir, pasos, faltas, prefijo, raiz = true, desp = 0, cadenaPadre = null, condPadre = null) {
        // Ámbito de resolución de las expresiones: el struct actual y sus padres
        // (una directiva `streamInfo::x n` puede citar un miembro del padre).
        const cadena = [{ struct, desp }, ...(cadenaPadre ?? [])];
        const miembros = this.miembros(struct);
        if (!miembros) {
            faltas.push(`${struct}: sin layout (zsizeof no lo resuelve)`);
            return;
        }
        let orden = [...miembros];
        if (dir && dir.reorder.length) {
            const porNombre = new Map(miembros.map((m) => [m.name, m]));
            if (!dir.reorder.includes("...")) {
                const primeros = dir.reorder.map((n) => porNombre.get(n)).filter(Boolean);
                const resto = orden.filter((m) => !dir.reorder.includes(m.name));
                orden = [...primeros, ...resto];
            } else {
                const bloques = [];
                let actual = null;
                for (const item of dir.reorder) {
                    if (item === "...") {
                        actual = { elipsis: true, items: [] };
                        bloques.push(actual);
                    } else {
                        if (!actual) {
                            actual = { elipsis: false, items: [] };
                            bloques.push(actual);
                        }
                        actual.items.push(item);
                    }
                }
                for (const b of bloques) {
                    if (!b.items.length) continue;
                    const objs = b.items.map((n) => porNombre.get(n)).filter(Boolean);
                    if (!b.elipsis) {
                        const resto = orden.filter((m) => !b.items.includes(m.name));
                        orden = [...objs, ...resto];
                    } else {
                        const primero = b.items[0];
                        const movidos = new Set(b.items.slice(1));
                        const sinMovidos = orden.filter((m) => !movidos.has(m.name));
                        const idx = sinMovidos.findIndex((m) => m.name === primero);
                        if (idx !== -1) {
                            sinMovidos.splice(idx + 1, 0, ...objs.slice(1));
                            orden = sinMovidos;
                        }
                    }
                }
            }
        }

        const condsExplicitPorOffset = new Map();
        for (const m of orden) {
            const ruta = `${prefijo}${m.name}`;
            const condPropio = dir ? dir.conditions.find((c) => c.member === m.name || c.member === ruta) : null;
            if (condPropio && condPropio.expr.trim() !== "never") {
                const prev = condsExplicitPorOffset.get(m.offset) ?? [];
                prev.push(condPropio.expr);
                condsExplicitPorOffset.set(m.offset, prev);
            }
        }

        const condPorOffset = new Map();
        for (const m of orden) {
            const ruta = `${prefijo}${m.name}`;
            const condPropio = dir ? dir.conditions.find((c) => c.member === m.name || c.member === ruta) : null;
            if (condPropio && condPropio.expr.trim() === "never") continue;
            let condLocal = condPropio ? condPropio.expr : null;
            if (condLocal) {
                const prev = condPorOffset.get(m.offset);
                if (prev) {
                    const negPrev = `(${prev}) == 0`;
                    condPorOffset.set(m.offset, `(${prev}) || (${condLocal})`);
                    condLocal = `(${negPrev}) && (${condLocal})`;
                } else {
                    condPorOffset.set(m.offset, condLocal);
                }
            } else if (condPorOffset.has(m.offset)) {
                condLocal = `(${condPorOffset.get(m.offset)}) == 0`;
            } else if (condsExplicitPorOffset.has(m.offset)) {
                const exprs = condsExplicitPorOffset.get(m.offset);
                condLocal = exprs.map((c) => `(${c}) == 0`).join(" && ");
            }
            const condEfectiva = condPadre && condLocal ? `(${condPadre}) && (${condLocal})` : (condLocal ?? condPadre);

            const esTexto = dir ? dir.strings.includes(m.name) || dir.strings.includes(ruta) : false;
            const cuenta = dir ? dir.counts.find((c) => c.member === m.name || c.member === ruta) : null;
            const asize = dir ? dir.arraysizes.find((c) => c.member === m.name || c.member === ruta) : null;
            const reutilizable = dir ? dir.reusables.includes(m.name) || dir.reusables.includes(ruta) : false;

            if (asize) {
                pasos.push({ clase: "arraysize", struct, member: ruta, offset: desp + m.offset, expr: asize.expr, ambito: cadena, elemSize: this.elemSize(struct, m.name), elemType: m.type, dims: m.dims, cond: condEfectiva });
                continue;
            }

            const subDir = dir ? this.subDirectivas(dir, m.name) : null;
            const dirTipo = this.directivesOfStruct(m.type);
            const subEfectivo = combinarDirectivas(subDir, dirTipo);
            if (m.ptr === 0 && (subEfectivo || (this.miembros(m.type) && !PRIMITIVOS.has(m.type)))) {
                const lenAntes = pasos.length;
                this.recogerPasos(m.type, subEfectivo, pasos, faltas, `${ruta}::`, false, desp + m.offset, cadena, condEfectiva);
                if (pasos.length === lenAntes && condLocal !== null && this.medidor().all().get(struct)?.kind === "union" && pasos.some((p) => p.clase === "arraysize" && p.offset >= desp + m.offset)) {
                    pasos.push({ clase: "hojaUnion", struct, member: ruta, offset: desp + m.offset, size: m.size, ambito: cadena, cond: condEfectiva });
                }
                continue;
            }
            if (cuenta) {
                const esRuntime = dir ? dir.runtimeBlocks && (dir.runtimeBlocks.includes(m.name) || dir.runtimeBlocks.includes(ruta)) : false;
                if (esRuntime) continue;
                try {
                    pasos.push({
                        clase: "count", struct, member: ruta, offset: desp + m.offset,
                        expr: cuenta.expr, elemSize: this.elemSize(struct, m.name),
                        // Puntero: sus datos solo van following si el marcador es 0xffffffff.
                        puntero: m.ptr > 0, ptrDepth: m.ptr, elemString: esTexto,
                        ambito: cadena,
                        elemType: m.type, dims: m.dims,
                        imagenes: raiz && m.ptr > 0 ? this.imagenesDe(m.type) : null,
                        cond: condEfectiva,
                    });
                } catch (error) {
                    faltas.push(`${ruta}: ${error.message}`);
                }
                continue;
            }
            if (m.dims && m.dims.length === 1 && m.ptr === 1 && dir) {
                const tieneIndexados = dir.counts.some((c) => c.member.startsWith(`${m.name}[`) || c.member.startsWith(`${ruta}[`));
                if (tieneIndexados) {
                    const dim = m.dims[0];
                    for (let idx = 0; idx < dim; idx++) {
                        const idxNombre = `${m.name}[${idx}]`;
                        const idxRuta = `${ruta}[${idx}]`;
                        const cIdx = dir.counts.find((c) => c.member === idxNombre || c.member === idxRuta);
                        const idxRuntime = dir.runtimeBlocks && (dir.runtimeBlocks.includes(idxNombre) || dir.runtimeBlocks.includes(idxRuta) || dir.runtimeBlocks.includes(m.name) || dir.runtimeBlocks.includes(ruta));
                        if (idxRuntime) continue;
                        if (!cIdx) continue;
                        try {
                            pasos.push({
                                clase: "count", struct, member: idxRuta, offset: desp + m.offset + idx * 4,
                                expr: cIdx.expr, elemSize: this.elemSize(struct, m.name),
                                puntero: true, ptrDepth: 1, elemString: esTexto,
                                ambito: cadena,
                                elemType: m.type, dims: [],
                                imagenes: raiz ? this.imagenesDe(m.type) : null,
                                cond: condEfectiva,
                            });
                        } catch (error) {
                            faltas.push(`${idxRuta}: ${error.message}`);
                        }
                    }
                    continue;
                }
            }
            if (esTexto) {
                pasos.push({ clase: "string", struct, member: ruta, offset: desp + m.offset, puntero: m.ptr > 0, ambito: cadena, cond: condEfectiva });
                continue;
            }
            if (reutilizable || (m.ptr === 1 && (this.assetStructs.has(m.type) || dirTipo !== null))) {
                // Reutilizable: su tabla solo va inline cuando el marcador del puntero
                // es 0xffffffff. Si es un puntero de zona real, el escritor la deduplica
                // y no ocupa stream.
                const pointeeDims = m.pointeeDims ?? [];
                const baseTipo = m.type === null ? null : this.sizeOf(m.type);
                const hojaBytes = baseTipo === null
                    ? null
                    : baseTipo * pointeeDims.reduce((a, b) => a * (b || 1), 1);
                pasos.push({
                    clase: "reusable", struct, member: ruta, offset: desp + m.offset,
                    tipo: m.type, ptr: m.ptr > 0, dims: m.dims, ambito: cadena, hojaBytes, cond: condEfectiva,
                });
                continue;
            }
            if (m.ptr === 0 && condLocal !== null && this.medidor().all().get(struct)?.kind === "union" && pasos.some((p) => p.clase === "arraysize" && p.offset >= desp + m.offset)) {
                pasos.push({ clase: "hojaUnion", struct, member: ruta, offset: desp + m.offset, size: m.size, ambito: cadena, cond: condEfectiva });
            }
        }
    }

    /**
     * Elementos con una unión `u` cuya alternativa `image` (GfxImage) lleva datos
     * following. La condición de la directiva (`u::water`) decide cuál es agua.
     */
    imagenesDe(tipoElem) {
        // Solo la unión del agua: `set condition u::water …`. Otras uniones con
        // `u::` (literalConst, loadSnd, frames…) llevan datos following normales
        // y las trata el recorrido genérico, no esta medición especial de imagen.
        const dirElem = this.modelo.byStruct.get(tipoElem);
        const cond = dirElem
            ? (dirElem.scoped ?? []).find((s) => s.palabra === "condition" && s.path[0] === "u" && s.path.includes("water"))
            : null;
        if (!cond) return null;
        return { struct: tipoElem, expr: cond.expr };
    }

    /** Directivas de un miembro concreto, vistas desde el struct que las contiene. */
    subDirectivas(dir, miembro) {
        const scoped = dir.scoped ?? [];
        const suyos = scoped.filter((s) => s.path[0] === miembro);
        if (!suyos.length) return null;
        const sub = {
            struct: `sub:${miembro}`, file: dir.file,
            strings: [], counts: [], arraysizes: [], reusables: [], conditions: [],
            scriptstrings: [], assetrefs: [], blocks: [], runtimeBlocks: [], allocaligns: [], actions: [], reorder: [], scoped: [],
        };
        for (const s of suyos) {
            const resto = s.path.slice(1);
            if (resto.length === 0) continue;
            const nombre = resto.join("::");
            switch (s.palabra) {
                case "string": sub.strings.push(nombre); break;
                case "scriptstring": sub.scriptstrings.push(nombre); break;
                case "count": sub.counts.push({ member: nombre, expr: s.expr }); break;
                case "arraysize": sub.arraysizes.push({ member: nombre, expr: s.expr }); break;
                case "reusable": sub.reusables.push(nombre); break;
                case "condition": sub.conditions.push({ member: nombre, expr: s.expr }); break;
                case "block": {
                    sub.blocks.push(s.expr ? `${nombre} ${s.expr}` : nombre);
                    if (s.expr === "XFILE_BLOCK_RUNTIME") sub.runtimeBlocks.push(nombre);
                    break;
                }
                default: break;
            }
            if (resto.length > 1) sub.scoped.push({ ...s, path: resto });
        }
        return sub;
    }
}

/**
 * Directivas que nombran un miembro que el struct no tiene: no se pueden
 * aplicar y, si aportan datos following, el tamaño saldría corto.
 */
function avisosDeDirectiva(declarados, dir) {
    if (!dir) return [];
    const nombres = new Set(declarados.map((d) => d.name));
    const citados = [
        ...dir.strings, ...dir.scriptstrings, ...dir.assetrefs, ...dir.reusables,
        ...dir.counts.map((c) => c.member), ...dir.arraysizes.map((c) => c.member),
    ];
    return [...new Set(citados.filter((n) => {
        if (n.includes("::")) return false;
        const baseNombre = n.replace(/\[\d+\]/g, "");
        return !nombres.has(n) && !nombres.has(baseNombre);
    }))].map((n) => `${dir.struct}: directiva sobre un miembro que no existe (${n})`);
}

// ---------------------------------------------------------------------------
// Medir un asset del stream.
// ---------------------------------------------------------------------------
export class Medidor {
    constructor(stream, sep) {
        this.d = stream;
        this.sep = sep;
    }

    /**
     * Valor de un miembro resolviendo la ruta en el ámbito más cercano que la contenga
     * (el struct actual y luego sus padres, cada uno con su desplazamiento en el asset).
     */
    leerEnAmbito(modelo, ambito, base, ruta, index, ctxPadre = []) {
        if (ruta.length > 1) {
            const espLocal = ambito.find((a) => a.struct === ruta[0]);
            if (espLocal) return this.leerValor(modelo, espLocal.struct, base + espLocal.desp, ruta.slice(1), index);
            const espPadre = ctxPadre.find((a) => a.struct === ruta[0]);
            if (espPadre) return this.leerValor(modelo, espPadre.struct, espPadre.base, ruta.slice(1), index);
        }
        for (const { struct, desp } of ambito) {
            const lista = modelo.miembros(struct) ?? [];
            if (lista.some((x) => x.name === ruta[0] && (ruta.length > 1 || index !== null || x.size <= 4))) {
                return this.leerValor(modelo, struct, base + desp, ruta, index);
            }
        }
        if (ruta.length === 1) {
            const v = modelo.enumValor(ruta[0]);
            if (v !== null) return v;
        }
        throw new SinResolver(`no está ${ruta.join("::")} en el ámbito ${ambito.map((a) => a.struct).join(" < ")}`);
    }

    /** Valor de un miembro del asset (por ruta), leído de su región fija. */
    leerValor(modelo, struct, base, ruta, index) {
        let actualStruct = struct;
        let offset = 0;
        for (let i = 0; i < ruta.length; i++) {
            const lista = modelo.miembros(actualStruct);
            if (!lista) throw new SinResolver(`${actualStruct} sin layout`);
            const m = lista.find((x) => x.name === ruta[i]);
            if (!m) throw new SinResolver(`no está ${actualStruct}::${ruta[i]}`);
            let salto = m.offset;
            let tam = m.size;
            if (i === ruta.length - 1 && index !== null && m.dims && m.dims.length) {
                const elemTam = modelo.sizeOf(m.type);
                salto += index * elemTam;
                tam = elemTam;
            }
            offset += salto;
            if (i < ruta.length - 1) actualStruct = m.type;
            else return this.leerEntero(base + offset, tam, m.type);
        }
        throw new SinResolver(`ruta vacía`);
    }

    /** Entero sin signo de 4 bytes en una posición del stream (los marcadores). */
    valorEn(pos) {
        if (pos + 4 > this.d.length) throw new SinResolver("marcador fuera del stream");
        return this.d.readUInt32LE(pos);
    }

    /** Marcador de un puntero: true si sus datos van following en el stream. */
    marcadorFollowing(pos) {
        return this.valorEn(pos) === FOLLOWING;
    }

    /**
     * Recorre los elementos de una tabla; las imágenes (no agua) con datos following
     * se miden detrás de la tabla: GfxImage fijo + nombre + GfxImageLoadDef opcional.
     * @returns posición tras las imágenes
     */
    medirImagenes(modelo, imag, elemSize, ini, n, cursor, detalle, miembro) {
        const uM = (modelo.miembros(imag.struct) ?? []).find((x) => x.name === "u");
        if (!uM) throw new SinResolver(`${imag.struct} sin unión u`);
        const texM = (modelo.miembros("GfxImage") ?? []).find((x) => x.name === "texture");
        if (!texM) throw new SinResolver("GfxImage sin texture");
        const nameM = (modelo.miembros("GfxImage") ?? []).find((x) => x.name === "name");
        if (!nameM) throw new SinResolver("GfxImage sin name");
        const miembrosElem = modelo.miembros(imag.struct) ?? [];
        for (let i = 0; i < n; i++) {
            const e = ini + i * elemSize;
            const agua = evalExpr(imag.expr, (ruta, index) => {
                if (ruta.length === 1 && !miembrosElem.some((x) => x.name === ruta[0])) {
                    const v = modelo.enumValor(ruta[0]);
                    if (v === null) throw new SinResolver(`enum desconocido ${ruta[0]}`);
                    return v;
                }
                return this.leerValor(modelo, imag.struct, e, ruta, index);
            });
            if (process.env.ZDBG) console.error("ELEM", miembro, i, e, agua, this.marcadorFollowing(e + uM.offset), uM.offset, elemSize, n);
            if (agua) continue;
            if (!this.marcadorFollowing(e + uM.offset)) continue;
            // El nombre va following solo si su puntero tiene marcador 0xffffffff;
            // si no, el nombre vive en la tabla de cadenas y no ocupa stream.
            let fin2 = cursor + modelo.sizeOf("GfxImage");
            if (this.marcadorFollowing(cursor + nameM.offset)) {
                const fin = this.d.indexOf(0, fin2);
                if (fin === -1) throw new SinResolver(`nombre de imagen sin terminador en ${miembro}[${i}]`);
                fin2 = fin + 1;
            }
            // `GfxTexture` es una unión: 0xfffffffe marca un `loadDef` con datos following (medido en common_zombie).
            // Su región son la cabecera (hasta `data`) más `resourceSize` bytes de datos.
            if (this.valorEn(cursor + texM.offset) === LOADDEF_FOLLOWING) {
                const resM = (modelo.miembros("GfxImageLoadDef") ?? []).find((x) => x.name === "resourceSize");
                if (!resM) throw new SinResolver("GfxImageLoadDef sin resourceSize");
                const resourceSize = this.leerEntero(fin2 + resM.offset, resM.size, resM.type);
                fin2 += cabeceraLoadDef(modelo) + resourceSize;
            }
            detalle.push({ clase: "imagen", member: `${miembro}[${i}]::u::image`, bytes: fin2 - cursor });
            if (process.env.ZDBG) console.error("DBG", miembro, i, cursor, fin2 - cursor, this.valorEn(cursor + texM.offset).toString(16), nameM.offset);
            cursor = fin2;
        }
        return cursor;
    }

    leerEntero(pos, size, tipo) {
        if (pos + size > this.d.length) throw new SinResolver("lectura fuera del stream");
        switch (size) {
            case 1: return ENTEROS_CON_SIGNO.has(tipo) ? this.d.readInt8(pos) : this.d.readUInt8(pos);
            case 2: return ENTEROS_CON_SIGNO.has(tipo) && !["unsigned short", "uint16_t"].includes(tipo) ? this.d.readInt16LE(pos) : this.d.readUInt16LE(pos);
            case 4: return ENTEROS_CON_SIGNO.has(tipo) ? this.d.readInt32LE(pos) : this.d.readUInt32LE(pos);
            default: throw new SinResolver(`no sé leer enteros de ${size} bytes (${tipo})`);
        }
    }

    /**
     * Mide la región de un asset: región fija + pasos following del plan.
     * @returns {{ok: boolean, total: number, fijo: number, detalle: object[], motivo?: string}}
     */
    medir(modelo, tipo, base) {
        const plan = modelo.plan(tipo);
        const detalle = [];
        let cursor;
        try {
            cursor = this.medirRegion(modelo, plan.struct, plan.directivas, base, base, detalle, "", 0);
        } catch (error) {
            return { ok: false, fijo: plan.fijo, detalle, motivo: error.message };
        }

        cursor += this.sep;
        if (cursor > this.d.length) return { ok: false, fijo: plan.fijo, detalle, motivo: "el asset se sale del stream" };
        return { ok: true, fijo: plan.fijo, total: cursor - base, detalle };
    }

    /**
     * Mide la región fija del struct en `base` y, detrás, sus datos following.
     * Es recursiva: un miembro `reusable` con marcador `0xffffffff` anida el plan
     * entero del tipo apuntado, y cada elemento de una tabla `count` anida el suyo.
     * @returns {number} posición tras los datos following
     */
    medirRegion(modelo, struct, dir, base, cursor, detalle, etiqueta, nivel, ctxPadre = []) {
        const plan = modelo.planStruct(struct, dir);
        if (plan.fijo === null || plan.fijo === undefined) throw new SinResolver(`${struct} sin tamaño (zsizeof no lo resuelve)`);
        if (nivel > 24) throw new SinResolver(`anidamiento demasiado profundo en ${struct}`);
        let c = Math.max(cursor, base + plan.fijo);
        const ctx = [{ struct, base }, ...ctxPadre];

        for (const paso of plan.pasos) {
            if (paso.cond) {
                const activa = evalExpr(paso.cond, (ruta, index) => this.leerEnAmbito(modelo, paso.ambito, base, ruta, index, ctx));
                if (!activa) continue;
            }
            const etq = etiqueta ? `${etiqueta}::${paso.member}` : paso.member;
            if (paso.clase === "string") {
                // Cadena following: solo si el puntero lleva marcador (si no, es nulo o deducido).
                if (paso.puntero && this.valorEn(base + paso.offset) !== FOLLOWING) {
                    detalle.push({ clase: "string", struct, member: etq, offset: paso.offset, bytes: 0 });
                    continue;
                }
                const fin = this.d.indexOf(0, c);
                if (fin === -1) throw new SinResolver(`cadena sin terminador en ${etq}`);
                detalle.push({ clase: "string", struct, member: etq, offset: paso.offset, bytes: fin + 1 - c });
                c = fin + 1;
                continue;
            }
            if (paso.clase === "hojaUnion") {
                const finHoja = base + paso.offset + paso.size;
                detalle.push({ ...paso, member: etq, bytes: finHoja - c });
                c = finHoja;
                continue;
            }
            if (paso.clase === "count") {
                if (paso.puntero && !this.marcadorFollowing(base + paso.offset)) {
                    // Puntero nulo o deducido: la tabla no va en el stream.
                    detalle.push({ ...paso, member: etq, valor: 0, bytes: 0 });
                    continue;
                }
                const valor = evalExpr(paso.expr, (ruta, index) => this.leerEnAmbito(modelo, paso.ambito, base, ruta, index, ctx));
                const dirElem = (!paso.imagenes && !paso.elemString && (!paso.ptrDepth || paso.ptrDepth < 2) && paso.elemType)
                    ? modelo.directivesOfStruct(paso.elemType)
                    : null;
                const planElem = (dirElem && modelo.miembros(paso.elemType) && !PRIMITIVOS.has(paso.elemType))
                    ? modelo.planStruct(paso.elemType, dirElem)
                    : null;
                if (planElem && planElem.dinamico) {
                    const ini = c;
                    for (let i = 0; i < valor; i++) {
                        c = this.medirRegion(modelo, paso.elemType, dirElem, c, c, detalle, `${etq}[${i}]`, nivel + 1, ctx);
                    }
                    detalle.push({ ...paso, member: etq, valor, bytes: c - ini });
                    continue;
                }
                const bytes = valor * paso.elemSize;
                detalle.push({ ...paso, member: etq, valor, bytes });
                const ini = c;
                c += bytes;
                if (valor <= 0) continue;
                if (paso.imagenes) {
                    c = this.medirImagenes(modelo, paso.imagenes, paso.elemSize, ini, valor, c, detalle, etq);
                } else if (paso.elemString) {
                    for (let i = 0; i < valor; i++) {
                        if (this.valorEn(ini + i * 4) !== FOLLOWING) continue;
                        const fin = this.d.indexOf(0, c);
                        if (fin === -1) throw new SinResolver(`cadena sin terminador en ${etq}[${i}]`);
                        detalle.push({ clase: "string", struct, member: `${etq}[${i}]`, offset: i * 4, bytes: fin + 1 - c });
                        c = fin + 1;
                    }
                } else if (paso.ptrDepth && paso.ptrDepth >= 2 && paso.elemType) {
                    const dirElemPtr = modelo.directivesOfStruct(paso.elemType);
                    const tamElem = modelo.sizeOf(paso.elemType);
                    for (let i = 0; i < valor; i++) {
                        if (this.valorEn(ini + i * 4) !== FOLLOWING) continue;
                        if (dirElemPtr) {
                            c = this.medirRegion(modelo, paso.elemType, dirElemPtr, c, c, detalle, `${etq}[${i}]`, nivel + 1, ctx);
                        } else if (tamElem !== null) {
                            detalle.push({ clase: "hoja", struct, member: `${etq}[${i}]`, bytes: tamElem });
                            c += tamElem;
                        }
                    }
                } else if (paso.elemType) {
                    const tienePasos = dirElem || (modelo.miembros(paso.elemType) && !PRIMITIVOS.has(paso.elemType) && modelo.planStruct(paso.elemType, null).pasos.length > 0);
                    if (tienePasos) {
                        for (let i = 0; i < valor; i++) {
                            c = this.medirRegion(modelo, paso.elemType, dirElem, ini + i * paso.elemSize, c, detalle, `${etq}[${i}]`, nivel + 1, ctx);
                        }
                    }
                }
                continue;
            }
            if (paso.clase === "arraysize") {
                const valor = evalExpr(paso.expr, (ruta, index) => this.leerEnAmbito(modelo, paso.ambito, base, ruta, index, ctx));
                const elem = paso.elemSize ?? 1;
                const finArray = base + paso.offset + valor * elem;
                detalle.push({ ...paso, member: etq, valor, bytes: finArray - c });
                c = finArray;
                if (valor > 0 && paso.elemType) {
                    const dirElem = modelo.directivesOfStruct(paso.elemType);
                    const tienePasos = dirElem || (modelo.miembros(paso.elemType) && !PRIMITIVOS.has(paso.elemType) && modelo.planStruct(paso.elemType, null).pasos.length > 0);
                    if (tienePasos) {
                        for (let i = 0; i < valor; i++) {
                            c = this.medirRegion(modelo, paso.elemType, dirElem, base + paso.offset + i * elem, c, detalle, `${etq}[${i}]`, nivel + 1, ctx);
                        }
                    }
                }
                continue;
            }
            if (paso.clase === "reusable") {
                const dim = paso.dims && paso.dims.length ? paso.dims[0] : 1;
                let anidados = 0;
                const dirTipo = paso.tipo ? modelo.directivesOfStruct(paso.tipo) : null;
                const tienePasos = dirTipo || (paso.tipo && modelo.miembros(paso.tipo) && !PRIMITIVOS.has(paso.tipo) && modelo.planStruct(paso.tipo, null).pasos.length > 0);
                const tamTipo = paso.hojaBytes ?? (paso.tipo ? modelo.sizeOf(paso.tipo) : null);
                for (let i = 0; i < dim; i++) {
                    const marcador = this.valorEn(base + paso.offset + i * 4);
                    if (marcador !== FOLLOWING && marcador !== LOADDEF_FOLLOWING) continue;
                    if (paso.tipo === "GfxImageLoadDef") {
                        const resM = (modelo.miembros("GfxImageLoadDef") ?? []).find((x) => x.name === "resourceSize");
                        if (!resM) throw new SinResolver("GfxImageLoadDef sin resourceSize");
                        const resourceSize = this.leerEntero(c + resM.offset, resM.size, resM.type);
                        const tam = cabeceraLoadDef(modelo) + resourceSize;
                        detalle.push({ clase: "reusable", struct: paso.tipo, member: dim > 1 ? `${etq}[${i}]` : etq, bytes: tam });
                        c += tam;
                    } else if (tienePasos) {
                        c = this.medirRegion(modelo, paso.tipo, dirTipo, c, c, detalle, dim > 1 ? `${etq}[${i}]` : etq, nivel + 1, ctx);
                    } else if (tamTipo !== null) {
                        // Tipo hoja sin directivas: se escribe su región fija tal cual.
                        detalle.push({ clase: "hoja", struct, member: dim > 1 ? `${etq}[${i}]` : etq, bytes: tamTipo });
                        c += tamTipo;
                    } else {
                        throw new SinResolver(`${etq}: ${paso.tipo} anidado sin tamaño ni directivas`);
                    }
                    anidados++;
                }
                detalle.push({ ...paso, member: etq, bytes: 0, anidados });
                continue;
            }
        }
        return c;
    }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
export function cargarStream(archivo) {
    const raw = readFileSync(archivo);
    const stream = inflateSync(raw.subarray(HEADER_LEN));
    const lista = parseAssetList(stream); // valida cabecera, tamaños y cadenas
    const tablaEn = lista.bodyOffset - lista.assetCount * 8;
    const tipos = [];
    for (let i = 0; i < lista.assetCount; i++) tipos.push(stream.readInt32LE(tablaEn + i * 8));
    return { stream, tipos, bodyOffset: lista.bodyOffset };
}

function main(argv) {
    const args = argv.slice(2);
    // Opciones y cuántos valores consume cada una.
    const OPCIONES = new Map([["--plan", 1], ["--type", 1], ["--walk", 2], ["--expect", 1], ["--sep", 1]]);
    const valores = new Map();
    const posicionales = [];
    for (let i = 0; i < args.length; i++) {
        const a = args[i];
        if (OPCIONES.has(a)) {
            const n = OPCIONES.get(a);
            valores.set(a, args.slice(i + 1, i + 1 + n));
            i += n;
        } else if (a.startsWith("--")) {
            console.error(`Opción desconocida: ${a}`);
            return 2;
        } else {
            posicionales.push(a);
        }
    }
    const planTipo = valores.get("--plan")?.[0] ?? null;
    const tipo = valores.get("--type")?.[0] ?? null;
    const walk = valores.get("--walk") ?? null;
    const expectArg = valores.get("--expect")?.[0] ?? null;
    const expect = expectArg === null ? null : Number(expectArg);
    const sep = valores.get("--sep")?.[0] === undefined ? 1 : Number(valores.get("--sep")[0]);

    if (posicionales.length < 2 || (!planTipo && !tipo && !walk)) {
        console.error("Uso: node tools/zassetsize.mjs <src> <archivo.ff> --plan TIPO | --type TIPO | --walk INICIO FIN [--expect N] [--sep N]");
        return 2;
    }
    const [src, archivo] = posicionales;
    if (!Number.isInteger(sep) || sep < 0) {
        console.error(`Separación no válida: ${valores.get("--sep")[0]}`);
        return 2;
    }

    let modelo;
    try {
        modelo = new Modelo(src);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        return 1;
    }

    if (planTipo) {
        let plan;
        try {
            plan = modelo.plan(planTipo);
        } catch (error) {
            console.error(`Error: ${error.message}`);
            return 1;
        }
        console.log(`${plan.tipo} (struct ${plan.struct}): región fija ${plan.fijo} bytes`);
        for (const paso of plan.pasos) {
            if (paso.clase === "string") console.log(`  string    ${paso.member} (+0x${paso.offset.toString(16)}) → cadena con NUL`);
            else if (paso.clase === "count") console.log(`  count     ${paso.member} [0x${paso.offset.toString(16)}] = ${paso.expr} × ${paso.elemSize} bytes`);
            else if (paso.clase === "arraysize") console.log(`  arraysize ${paso.member} [0x${paso.offset.toString(16)}] = ${paso.expr} bytes`);
            else if (paso.clase === "reusable") console.log(`  reusable  ${paso.member} [0x${paso.offset.toString(16)}] → 0 bytes (tabla fuera del asset)`);
        }
        for (const aviso of plan.avisos) console.log(`  aviso: ${aviso}`);
        if (plan.faltas.length) {
            console.log(`  sin resolver: ${plan.faltas.join("; ")}`);
            return 1;
        }
        return 0;
    }

    let datos;
    try {
        datos = cargarStream(archivo);
    } catch (error) {
        console.error(`Error leyendo ${basename(archivo)}: ${error.message}`);
        return 1;
    }
    const medidor = new Medidor(datos.stream, sep);

    if (tipo) {
        const i = datos.tipos.findIndex((id) => T5_ASSET_TYPE_NAMES[id] === tipo);
        if (i === -1) {
            console.error(`No hay ningún asset de tipo ${tipo} en ${basename(archivo)}`);
            return 1;
        }
        // Para medir un asset suelto hace falta caminar desde el principio.
        const recorrido = caminar(modelo, medidor, datos, 0, i);
        if (!recorrido.ok) {
            console.error(`No se pudo llegar al asset ${i} (${tipo}): ${recorrido.motivo}`);
            console.error(`  se llegó hasta el índice ${recorrido.hasta} (${T5_ASSET_TYPE_NAMES[datos.tipos[recorrido.hasta]]})`);
            return 1;
        }
        const r = recorrido.resultados[i];
        console.log(`asset ${i} = ${tipo} en +0x${recorrido.offsets[i].toString(16)} (cuerpo +0x${datos.bodyOffset.toString(16)})`);
        console.log(`  región fija ${r.fijo}, total ${r.total}`);
        for (const p of r.detalle) {
            const valor = p.valor === undefined ? "" : ` valor ${p.valor}`;
            console.log(`    ${p.clase.padEnd(9)} ${p.member}${valor} → ${p.bytes} bytes`);
        }
        if (r.motivo) { console.log(`  motivo: ${r.motivo}`); return 1; }
        return 0;
    }

    // --walk
    const [a, b] = walk.map(Number);
    if (!Number.isInteger(a) || !Number.isInteger(b) || a < 0 || b < a) {
        console.error(`Recorrido no válido: ${walk.join(" ")}`);
        return 2;
    }
    const recorrido = caminar(modelo, medidor, datos, 0, b);
    if (!recorrido.ok) {
        console.error(`El recorrido se paró en el índice ${recorrido.hasta} (${T5_ASSET_TYPE_NAMES[datos.tipos[recorrido.hasta]]}): ${recorrido.motivo}`);
        return 1;
    }
    let total = 0;
    for (let i = a; i <= b; i++) {
        const r = recorrido.resultados[i];
        if (!r || !r.ok) {
            console.error(`El asset ${i} (${T5_ASSET_TYPE_NAMES[datos.tipos[i]]}) no se pudo medir: ${r ? r.motivo : "sin medir"}`);
            return 1;
        }
        total += r.total;
        console.log(`${String(i).padStart(5)}  ${T5_ASSET_TYPE_NAMES[datos.tipos[i]].padEnd(18)} fijo ${String(r.fijo).padStart(6)}  total ${String(r.total).padStart(6)}`);
    }
    console.log(`región ${a}..${b}: ${total} bytes (separación ${sep} B por asset)`);
    if (expect !== null) {
        const ok = total === expect;
        console.log(`esperado ${expect} → ${ok ? "OK" : `FALLA (diferencia ${total - expect})`}`);
        return ok ? 0 : 1;
    }
    return 0;
}

/** Camina los assets 0..hasta acumulando tamaños; para al primer fallo. */
export function caminar(modelo, medidor, datos, desde, hasta) {
    const resultados = [];
    const offsets = [];
    let cursor = datos.bodyOffset;
    for (let i = desde; i <= hasta; i++) {
        const tipoNombre = T5_ASSET_TYPE_NAMES[datos.tipos[i]];
        offsets.push(cursor);
        let r;
        try {
            r = medidor.medir(modelo, tipoNombre, cursor);
        } catch (error) {
            r = { ok: false, motivo: `${tipoNombre}: ${error.message}` };
        }
        resultados.push(r);
        if (!r.ok) return { ok: false, hasta: i, motivo: r.motivo, resultados, offsets };
        cursor += r.total;
    }
    return { ok: true, resultados, offsets, fin: cursor };
}

if (process.argv[1] && process.argv[1].endsWith("zassetsize.mjs")) {
    process.exitCode = main(process.argv);
}
