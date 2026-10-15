#!/usr/bin/env node
// Modelo de escritura por tipo de asset de BO1 PC (T5), leído de la copia de
// referencia en TEXTO (no se copia código suyo: se leen sus datos).
//
// De dónde sale cada cosa:
//   - <src>/Common/Game/T5/T5.h .......... enum ASSET_TYPE_* en orden y el
//     mapeo tipo → struct (`using AssetX = Asset<ASSET_TYPE_Y, Struct>;`).
//   - <src>/Common/Game/T5/T5_Assets.h ... definiciones de struct (vía
//     tools/zsizeof.mjs, que da tamaño fijo y offset de cada miembro).
//   - <src>/ZoneCode/Game/T5/XAssets/*.txt ... directivas por struct: qué
//     miembros son `string`, qué arrays llevan `count` o `arraysize`, cuáles
//     son `reusable`, qué `condition` los excluye, el `block` y el `reorder`.
//
// El objetivo es el mismo que el del generador de la referencia: saber, para
// cada asset, cuánto ocupa su región fija y qué datos van detrás (following).
//
// Uso:
//   node tools/ztypemods.mjs <ruta de src de la referencia> [--type NOMBRE] [--json]
//     --type T   solo ese tipo de asset (por nombre del enum, sin ASSET_TYPE_)
//     --json     imprime el modelo como JSON
//
// Códigos de salida: 0 = modelo leído; 1 = falta algún fichero o no cuadra la
// validación; 2 = uso incorrecto.

import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { createMeasurer } from "./zsizeof.mjs";

const PALABRAS = new Set(["string", "count", "arraysize", "reusable", "condition", "scriptstring", "assetref", "allocalign", "action", "block"]);

// ---------------------------------------------------------------------------
// Directivas: `use X;` abre el struct sobre el que aplican los `set ...;`
// siguientes, salvo los que llevan `Tipo::miembro`, que apuntan a ese tipo.
// ---------------------------------------------------------------------------
export function parseDirectives(directory) {
    const byStruct = new Map();
    const desconocidas = [];
    const files = readdirSync(directory).filter((f) => f.endsWith(".txt")).sort();

    const entry = (name) => {
        if (!byStruct.has(name)) {
            byStruct.set(name, {
                struct: name, file: null,
                strings: [], counts: [], arraysizes: [], reusables: [],
                conditions: [], scriptstrings: [], assetrefs: [], blocks: [], allocaligns: [], actions: [],
                reorder: [], scoped: [],
            });
        }
        return byStruct.get(name);
    };

    for (const file of files) {
        const lines = readFileSync(join(directory, file), "utf8").split(/\r?\n/);
        let actual = null;
        let pendiente = null; // directiva partida en varias líneas (cierra con ';')
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].replace(/\/\/.*$/, "").trim();
            if (pendiente !== null) {
                line = `${pendiente} ${line}`;
                if (!line.endsWith(";")) continue;
                pendiente = null;
            } else if (line.startsWith("set ") && !line.endsWith(";")) {
                // Las condiciones largas vienen partidas por `||` en varias líneas.
                pendiente = line;
                continue;
            }
            if (line === "") continue;

            if (line.startsWith("use ")) {
                actual = entry(line.slice(4).replace(/;$/, "").trim());
                actual.file = file;
                continue;
            }
            if (line.startsWith("reorder:")) {
                const target = actual ?? entry("?");
                for (let j = i + 1; j < lines.length; j++) {
                    const item = lines[j].replace(/\/\/.*$/, "").trim();
                    if (item === "") continue;
                    if (/^(set|use|reorder)\b/.test(item)) break;
                    const nombre = item.replace(/;$/, "").trim();
                    if (!/^[A-Za-z_][A-Za-z0-9_:]*$/.test(nombre)) break;
                    target.reorder.push(nombre);
                    if (item.endsWith(";")) { i = j; break; }
                }
                continue;
            }
            if (!line.startsWith("set ")) continue;

            const m = /^set\s+([a-z]+)\s+(.*);$/.exec(line);
            if (!m) { desconocidas.push({ file, line }); continue; }
            const [, palabra, resto] = m;
            if (!PALABRAS.has(palabra)) { desconocidas.push({ file, line }); continue; }

            // `Tipo::miembro` apunta a ese tipo; el resto, al struct en curso.
            const first = resto.split(/\s+/)[0];
            const scoped = first.includes("::");
            const target = scoped ? entry(first.split("::")[0]) : (actual ?? entry("?"));
            if (scoped && target.file === null) target.file = file;

            const miembro = scoped ? first.split("::")[1] : first;
            // La expresión va siempre tras el miembro (o tras la ruta `Tipo::miembro`).
            const restoExpr = resto.split(/\s+/).slice(1).join(" ");
            // Las rutas con `::` también se guardan en el struct en curso: para
            // el generador, `info::name` es un miembro del struct actual cuando
            // `info` lo es, y `MaterialVertexShader::name` un tipo cuando no lo es.
            // Se guarda en el struct en curso (no en el del primer segmento),
            // que es quien puede resolver la ruta contra sus propios miembros.
            if (scoped) (actual ?? entry("?")).scoped.push({ palabra, path: first.split("::"), expr: restoExpr, file });

            switch (palabra) {
                case "string": target.strings.push(miembro); break;
                case "count": target.counts.push({ member: miembro, expr: restoExpr }); break;
                case "arraysize": target.arraysizes.push({ member: miembro, expr: restoExpr }); break;
                case "reusable": target.reusables.push(miembro); break;
                case "condition": target.conditions.push({ member: miembro, expr: restoExpr }); break;
                case "scriptstring": target.scriptstrings.push(miembro); break;
                case "assetref": target.assetrefs.push(miembro); break;
                case "block": target.blocks.push(resto); break;
                case "allocalign": target.allocaligns.push(resto); break;
                case "action": target.actions.push(resto); break;
                default: break;
            }
        }
    }
    return { byStruct, files, desconocidas };
}

// ---------------------------------------------------------------------------
// T5.h: enum ASSET_TYPE_* en orden y mapeo tipo → struct.
// ---------------------------------------------------------------------------
export function parseT5Header(source) {
    const enumNames = [];
    const enumBody = /enum\s+[\w:]*\s*\{([\s\S]*?)\}\s*;/.exec(source);
    if (enumBody) {
        for (const m of enumBody[1].matchAll(/ASSET_TYPE_[A-Z0-9_]+/g)) enumNames.push(m[0]);
    }
    const mapping = new Map();
    for (const m of source.matchAll(/using\s+\w+\s*=\s*Asset<\s*(ASSET_TYPE_[A-Z0-9_]+)\s*,\s*([A-Za-z_][\w]*)\s*>/g)) {
        mapping.set(m[1], m[2]);
    }
    return { enumNames, mapping };
}

/**
 * Carga el modelo completo (mapeo, directivas y medidas) para que otras
 * herramientas lo usen: mismas fuentes y mismas comprobaciones que el CLI.
 * @param {string} root ruta del `src` de la referencia
 */
export function loadModel(root) {
    const t5Header = join(root, "Common", "Game", "T5", "T5.h");
    const assetsHeader = join(root, "Common", "Game", "T5", "T5_Assets.h");
    const xassets = join(root, "ZoneCode", "Game", "T5", "XAssets");
    for (const p of [t5Header, assetsHeader, xassets]) {
        if (!existsSync(p)) throw new Error(`no encuentro ${p}`);
    }

    const { enumNames, mapping } = parseT5Header(readFileSync(t5Header, "utf8"));
    const { byStruct, desconocidas } = parseDirectives(xassets);
    const medidor = createMeasurer(4);
    const assetsText = readFileSync(assetsHeader, "utf8");
    medidor.parse(assetsText);
    /** Valor de un enum (`NOMBRE = 0xB,`) de T5_Assets.h; null si no existe. */
    const enumValor = (nombre) => {
        const m = new RegExp(`\\b${nombre}\\s*=\\s*(0x[0-9a-fA-F]+|\\d+)`).exec(assetsText);
        return m ? Number(m[1]) : null;
    };

    /** Struct del tipo de asset (por nombre del enum, sin ASSET_TYPE_). */
    const structOf = (tipo) => {
        const enumName = enumNames.find((e) => e === `ASSET_TYPE_${tipo}`);
        return enumName ? mapping.get(enumName) ?? null : null;
    };
    /** Directivas del struct del tipo de asset. */
    const directivesOf = (tipo) => {
        const struct = structOf(tipo);
        return struct ? byStruct.get(struct) ?? null : null;
    };

    return { enumNames, mapping, byStruct, medidor, unknownDirectives: desconocidas, assetsHeader, structOf, directivesOf, enumValor };
}

function main() {
    const args = process.argv.slice(2);
    const json = args.includes("--json");
    const typeIndex = args.indexOf("--type");
    const soloTipo = typeIndex === -1 ? null : args[typeIndex + 1];
    const root = args.find((a, i) => !a.startsWith("--") && !(typeIndex >= 0 && i === typeIndex + 1));

    if (!root) {
        console.error("Uso: node tools/ztypemods.mjs <ruta de src de la referencia> [--type NOMBRE] [--json]");
        return 2;
    }

    const t5Header = join(root, "Common", "Game", "T5", "T5.h");
    const assetsHeader = join(root, "Common", "Game", "T5", "T5_Assets.h");
    const xassets = join(root, "ZoneCode", "Game", "T5", "XAssets");
    for (const [etiqueta, p] of [["T5.h", t5Header], ["T5_Assets.h", assetsHeader], ["XAssets/", xassets]]) {
        if (!existsSync(p)) {
            console.error(`No encuentro ${etiqueta} en ${p}`);
            return 1;
        }
    }

    const { enumNames, mapping } = parseT5Header(readFileSync(t5Header, "utf8"));
    const { byStruct, files, desconocidas } = parseDirectives(xassets);

    const medidor = createMeasurer(4);
    medidor.parse(readFileSync(assetsHeader, "utf8"));
    const sinTipo = medidor.unknowns();

    const filas = [];
    for (const [indice, enumName] of enumNames.entries()) {
        const nombre = enumName.replace(/^ASSET_TYPE_/, "");
        const struct = mapping.get(enumName) ?? null;
        const dir = struct ? byStruct.get(struct) ?? null : null;
        filas.push({
            index: indice,
            type: nombre,
            struct,
            fijo: struct ? medidor.sizeOf(struct) : null,
            strings: dir ? dir.strings.length : null,
            counts: dir ? dir.counts.length : null,
            arraysizes: dir ? dir.arraysizes.length : null,
            reusables: dir ? dir.reusables.length : null,
            conditions: dir ? dir.conditions.length : null,
            scriptstrings: dir ? dir.scriptstrings.length : null,
            assetrefs: dir ? dir.assetrefs.length : null,
            reorder: dir ? dir.reorder : null,
            detalle: dir,
        });
    }

    const filtradas = soloTipo ? filas.filter((f) => f.type === soloTipo) : filas;
    if (soloTipo && filtradas.length === 0) {
        console.error(`No hay ningún tipo de asset llamado ${soloTipo}`);
        return 1;
    }

    // Validación contra dos hechos ya medidos en el binario (reglas.md):
    // el primer asset de common_zombie es un TECHNIQUE_SET de 528 bytes de
    // región fija, y MATERIAL mide 192.
    const esperado = { TECHNIQUE_SET: 528, MATERIAL: 192 };
    const fallos = [];
    for (const [tipo, size] of Object.entries(esperado)) {
        const fila = filas.find((f) => f.type === tipo);
        if (!fila || fila.fijo !== size) {
            fallos.push(`${tipo}: región fija ${fila ? fila.fijo : "?"} en vez de ${size}`);
        }
    }

    if (json) {
        console.log(JSON.stringify({
            enumCount: enumNames.length,
            directiveFiles: files.length,
            structsWithDirectives: byStruct.size,
            unresolvedStructs: sinTipo,
            unknownDirectives: desconocidas,
            assets: filtradas.map(({ detalle, ...resto }) => resto),
        }, null, 2));
    } else {
        console.log("=== MODELO POR TIPO DE ASSET (T5) ===");
        console.log(`enum ASSET_TYPE_*: ${enumNames.length} tipos; directivas en ${files.length} ficheros sobre ${byStruct.size} structs`);
        console.log("");
        console.log("TIPO                       STRUCT                    FIJO  str  cnt  asz  reu  cnd  script  ref  reorder");
        for (const f of filtradas) {
            const n = (v) => (v === null ? "  -" : String(v).padStart(4));
            console.log(
                f.type.padEnd(26) + " " +
                String(f.struct ?? "(sin struct)").padEnd(24) + " " +
                String(f.fijo ?? "?").padStart(5) + " " +
                n(f.strings) + " " + n(f.counts) + " " + n(f.arraysizes) + " " + n(f.reusables) + " " +
                n(f.conditions) + " " + n(f.scriptstrings) + " " + n(f.assetrefs) + "  " +
                (f.reorder && f.reorder.length ? f.reorder.join(",") : "-")
            );
        }
        console.log("");
        const conStruct = filtradas.filter((f) => f.struct).length;
        const conDirectiva = filtradas.filter((f) => f.detalle).length;
        const conTamano = filtradas.filter((f) => f.fijo !== null).length;
        console.log(`tipos con struct mapeado: ${conStruct}/${filtradas.length}`);
        console.log(`tipos con directiva: ${conDirectiva}/${filtradas.length}`);
        console.log(`tipos con región fija conocida: ${conTamano}/${filtradas.length}`);
        const faltan = filtradas.filter((f) => !f.detalle).map((f) => f.type);
        if (faltan.length) console.log(`sin directiva: ${faltan.join(", ")}`);

        // Detalle de los tipos con datos following: es lo que el recorrido
        // necesita para saber qué hay detrás de la región fija.
        const conFollowing = filtradas.filter((f) => f.detalle &&
            (f.strings + f.counts + f.arraysizes + f.reusables + f.scriptstrings + f.assetrefs) > 0);
        console.log("");
        console.log(`tipos con datos following: ${conFollowing.length}/${filtradas.length}`);
        for (const f of conFollowing.slice(0, 8)) {
            const d = f.detalle;
            const partes = [];
            if (d.strings.length) partes.push(`string: ${d.strings.join(", ")}`);
            if (d.counts.length) partes.push(`count: ${d.counts.map((c) => `${c.member}=${c.expr}`).join(", ")}`);
            if (d.arraysizes.length) partes.push(`arraysize: ${d.arraysizes.map((c) => `${c.member}=${c.expr}`).join(", ")}`);
            if (d.reusables.length) partes.push(`reusable: ${d.reusables.join(", ")}`);
            if (d.conditions.length) partes.push(`condition: ${d.conditions.map((c) => `${c.member} ${c.expr}`).join(", ")}`);
            console.log(`  ${f.type}: ${partes.join(" | ") || "(solo valores)"}`);
        }

        if (sinTipo.length) {
            console.error(`aviso: ${sinTipo.length} struct(s) sin resolver por zsizeof: ${sinTipo.slice(0, 10).join(", ")}${sinTipo.length > 10 ? "…" : ""}`);
        }
        if (desconocidas.length) {
            console.error(`aviso: ${desconocidas.length} directiva(s) no reconocida(s), p. ej. ${desconocidas[0].file}: ${desconocidas[0].line}`);
        }
        console.log("");
        console.log("=== VALIDACIÓN CONTRA MEDIDAS DEL BINARIO ===");
        for (const [tipo, size] of Object.entries(esperado)) {
            const fila = filas.find((f) => f.type === tipo);
            console.log(`  ${tipo}: región fija ${fila ? fila.fijo : "?"} (esperado ${size}) ${fila && fila.fijo === size ? "OK" : "FALLA"}`);
        }
        if (fallos.length === 0) console.log("validación OK");
        else console.log(`validación con ${fallos.length} fallo(s): ${fallos.join("; ")}`);
    }

    return fallos.length === 0 ? 0 : 1;
}

// Solo se ejecuta como script, no al importar desde otras herramientas.
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
    process.exitCode = main();
}
