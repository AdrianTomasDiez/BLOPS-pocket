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

// ---------------------------------------------------------------------------
// Miembros de los structs: qué tipo declara cada uno (zsizeof da tamaños y
// offsets, pero no el tipo, y para `count` hacen falta los del tipo apuntado).
// ---------------------------------------------------------------------------
function parseMemberDecls(source) {
    const clean = source
        .replace(/\/\*[\s\S]*?\*\//g, " ")
        .replace(/\/\/[^\n]*/g, "");
    const decls = new Map(); // struct → [{ type, ptr, dims, name }]

    for (const m of clean.matchAll(/(?:^|\n)\s*(?:struct|union)\s+([A-Za-z_][\w]*)\s*\{/g)) {
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
        const dims = [];
        let resto = parte;
        const dimMatch = /\[\s*(\d*)\s*\]\s*$/g;
        while (dimMatch.test(resto)) {
            const m = /\[\s*(\d*)\s*\]\s*$/.exec(resto);
            dims.unshift(m[1] === "" ? null : Number(m[1]));
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
    const re = /[A-Za-z_][\w]*|\d+|::|[\s()+\-*/%\[\]]/g;
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
            const v = suma();
            if (!come(")")) throw new SinResolver(`paréntesis sin cerrar en "${expr}"`);
            return v;
        }
        const t = ve();
        if (t === undefined) throw new SinResolver(`expresión incompleta "${expr}"`);
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
    const valor = suma();
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
    ["int", 4], ["unsigned", 4], ["long", 4], ["int32_t", 4], ["uint32_t", 4], ["float", 4],
    ["int64_t", 8], ["uint64_t", 8], ["double", 8],
]);

class Modelo {
    constructor(src) {
        this.modelo = loadModel(src);
        this.decls = parseMemberDecls(readFileSync(this.modelo.assetsHeader, "utf8"));
        this.planes = new Map();
    }

    medidor() { return this.modelo.medidor; }

    /** Miembros del struct con offset y tamaño (de zsizeof) fusionados con el tipo declarado. */
    miembros(struct) {
        const offsets = this.medidor().membersOf(struct);
        if (!offsets) return null;
        const declarados = this.decls.get(struct) ?? [];
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

    /** Recorre los miembros y añade los pasos; baja a sub-structs por valor. */
    recogerPasos(struct, dir, pasos, faltas, prefijo) {
        const miembros = this.miembros(struct);
        if (!miembros) {
            faltas.push(`${struct}: sin layout (zsizeof no lo resuelve)`);
            return;
        }
        let orden = miembros;
        if (dir && dir.reorder.length) {
            const porNombre = new Map(miembros.map((m) => [m.name, m]));
            const primeros = dir.reorder.map((n) => porNombre.get(n)).filter(Boolean);
            const resto = miembros.filter((m) => !dir.reorder.includes(m.name));
            orden = [...primeros, ...resto];
        }

        for (const m of orden) {
            const ruta = `${prefijo}${m.name}`;
            const cond = dir ? dir.conditions.find((c) => c.member === ruta) : null;
            if (cond && cond.expr.trim() === "never") continue;

            const esTexto = dir ? dir.strings.includes(ruta) || dir.scriptstrings.includes(ruta) : false;
            const cuenta = dir ? dir.counts.find((c) => c.member === ruta) : null;
            const asize = dir ? dir.arraysizes.find((c) => c.member === ruta) : null;
            const reutilizable = dir ? dir.reusables.includes(ruta) : false;

            // Sub-directivas con el nombre de este miembro por delante (`info::name`).
            const subDir = dir ? this.subDirectivas(dir, m.name) : null;
            if (subDir) {
                this.recogerPasos(m.type, subDir, pasos, faltas, "");
                continue;
            }
            if (esTexto) {
                pasos.push({ clase: "string", struct, member: ruta, offset: m.offset });
                continue;
            }
            if (cuenta) {
                try {
                    pasos.push({
                        clase: "count", struct, member: ruta, offset: m.offset,
                        expr: cuenta.expr, elemSize: this.elemSize(struct, m.name),
                    });
                } catch (error) {
                    faltas.push(`${ruta}: ${error.message}`);
                }
                continue;
            }
            if (asize) {
                pasos.push({ clase: "arraysize", struct, member: ruta, offset: m.offset, expr: asize.expr });
                continue;
            }
            if (reutilizable) {
                // Reutilizable sin `count`: su tabla no va inline (técnicas, etc.).
                pasos.push({ clase: "reusable", struct, member: ruta, offset: m.offset });
                continue;
            }
        }
    }

    /** Directivas de un miembro concreto, vistas desde el struct que las contiene. */
    subDirectivas(dir, miembro) {
        const scoped = dir.scoped ?? [];
        const suyos = scoped.filter((s) => s.path[0] === miembro);
        if (!suyos.length) return null;
        const sub = {
            struct: `sub:${miembro}`, file: dir.file,
            strings: [], counts: [], arraysizes: [], reusables: [], conditions: [],
            scriptstrings: [], assetrefs: [], blocks: [], allocaligns: [], actions: [], reorder: [], scoped: [],
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
    return [...new Set(citados.filter((n) => !n.includes("::") && !nombres.has(n)))]
        .map((n) => `${dir.struct}: directiva sobre un miembro que no existe (${n})`);
}

// ---------------------------------------------------------------------------
// Medir un asset del stream.
// ---------------------------------------------------------------------------
class Medidor {
    constructor(stream, sep) {
        this.d = stream;
        this.sep = sep;
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
            if (i === ruta.length - 1 && index !== null && m.dims && m.dims.length) {
                salto += index * modelo.sizeOf(m.type);
            }
            offset += salto;
            if (i < ruta.length - 1) actualStruct = m.type;
            else return this.leerEntero(base + offset, m.size, m.type);
        }
        throw new SinResolver(`ruta vacía`);
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
        let cursor = base + plan.fijo;

        for (const paso of plan.pasos) {
            if (paso.clase === "string") {
                const fin = this.d.indexOf(0, cursor);
                if (fin === -1) return { ok: false, fijo: plan.fijo, detalle, motivo: `cadena sin terminador en ${paso.member}` };
                detalle.push({ ...paso, bytes: fin + 1 - cursor });
                cursor = fin + 1;
                continue;
            }
            if (paso.clase === "count") {
                let valor;
                try {
                    valor = evalExpr(paso.expr, (ruta, index) => this.leerValor(modelo, paso.struct, base, ruta, index));
                } catch (error) {
                    return { ok: false, fijo: plan.fijo, detalle, motivo: `${paso.member}: ${error.message}` };
                }
                const bytes = valor * paso.elemSize;
                detalle.push({ ...paso, valor, bytes });
                cursor += bytes;
                continue;
            }
            if (paso.clase === "arraysize") {
                let valor;
                try {
                    valor = evalExpr(paso.expr, (ruta, index) => this.leerValor(modelo, paso.struct, base, ruta, index));
                } catch (error) {
                    return { ok: false, fijo: plan.fijo, detalle, motivo: `${paso.member}: ${error.message}` };
                }
                detalle.push({ ...paso, valor, bytes: valor });
                cursor += valor;
                continue;
            }
            if (paso.clase === "reusable") {
                detalle.push({ ...paso, bytes: 0 });
                continue;
            }
        }

        cursor += this.sep;
        if (cursor > this.d.length) return { ok: false, fijo: plan.fijo, detalle, motivo: "el asset se sale del stream" };
        return { ok: true, fijo: plan.fijo, total: cursor - base, detalle };
    }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------
function cargarStream(archivo) {
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
function caminar(modelo, medidor, datos, desde, hasta) {
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
