// Reads the app's demo data (DemoMode.makeContainer and addRecoveryContent in AnchorApp.swift) and writes it as JSON,
// so the website demo always shows what the app's demo shows.
//   website/src/content/demo.seed.generated.json
// It understands the part of Swift those functions use: model initialisers with labelled arguments, string, number and
// boolean literals, .enumCases, arrays, `let` bindings, `context.insert(...)`, simple property assignments and calls such as `task.setDue(.today)`.
// Anything it cannot read as data (date arithmetic, Calendar lookups) is kept as {"$expr": "<the Swift text>"} for the website to interpret.
// Run with no arguments to write the file, or with --check to fail when it is out of date.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const SWIFT = join(root, "iOS/Anchor/Anchor/AnchorApp.swift");
const OUT = join(root, "website/src/content/demo.seed.generated.json");
const FUNCS = [/static func makeContainer\(\)[^{]*\{/, /private static func addRecoveryContent\([^{]*\{/];

const full = readFileSync(SWIFT, "utf8");

function matchBrace(text, open) {
  let depth = 0, i = open, inStr = false;
  for (; i < text.length; i++) {
    const c = text[i];
    if (inStr) { if (c === "\\") i++; else if (c === '"') inStr = false; continue; }
    if (c === '"') inStr = true;
    else if (c === "/" && text[i + 1] === "/") { while (i < text.length && text[i] !== "\n") i++; }
    else if (c === "{") depth++;
    else if (c === "}" && --depth === 0) return i;
  }
  throw new Error("Unbalanced braces in AnchorApp.swift");
}

function tokenize(src) {
  const toks = []; let i = 0;
  const two = ["??", "->", "==", "!=", "<=", ">=", "&&", "||", "...", "..<"];
  while (i < src.length) {
    const c = src[i];
    if (/\s/.test(c)) { i++; continue; }
    if (c === "/" && src[i + 1] === "/") { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (c === "/" && src[i + 1] === "*") { i = src.indexOf("*/", i) + 2; continue; }
    const s = i;
    if (c === '"') {
      let out = "", interpolated = false; i++;
      while (src[i] !== '"') {
        if (src[i] === "\\") {
          const n = src[i + 1];
          if (n === "n") { out += "\n"; i += 2; }
          else if (n === "t") { out += "\t"; i += 2; }
          else if (n === "u") { const e = src.indexOf("}", i); out += String.fromCodePoint(parseInt(src.slice(i + 3, e), 16)); i = e + 1; }
          else if (n === "(") { interpolated = true; let d = 0; i++; do { if (src[i] === "(") d++; else if (src[i] === ")") d--; i++; } while (d > 0); out += "\u0000"; }
          else { out += n; i += 2; }
        } else out += src[i++];
      }
      i++; toks.push({ t: "str", v: out, interpolated, s, e: i }); continue;
    }
    if (/[0-9]/.test(c)) { let m = /^[0-9][0-9_]*(\.[0-9]+)?/.exec(src.slice(i))[0]; i += m.length; toks.push({ t: "num", v: parseFloat(m.replace(/_/g, "")), s, e: i }); continue; }
    if (/[$A-Za-z_]/.test(c)) { let m = /^[$A-Za-z_][$\w]*/.exec(src.slice(i))[0]; i += m.length; toks.push({ t: "id", v: m, s, e: i }); continue; }
    const op = two.find((o) => src.startsWith(o, i));
    if (op) { i += op.length; toks.push({ t: "p", v: op, s, e: i }); continue; }
    i++; toks.push({ t: "p", v: c, s, e: i });
  }
  return toks;
}

// Models that the demo builds through a helper such as SafetyPlanSections.makeSections(warningSigns: "...").
// The helper's definition is read from the Swift source and its parameters are filled in from the call.
const FACTORY_SOURCES = ["Models/AnchorModels.swift"].map((f) => readFileSync(join(root, "iOS/Anchor/Anchor", f), "utf8"));
function expandFactory(call) {
  const fn = call.$static.split(".")[1];
  for (const text of FACTORY_SOURCES) {
    const m = new RegExp(`static func ${fn}\\(([^)]*)\\)[^{]*\\{`).exec(text);
    if (!m) continue;
    const open = m.index + m[0].length - 1;
    const body = text.slice(open + 1, matchBrace(text, open));
    const arr = parseBody(body, "expr");
    if (!Array.isArray(arr)) continue;
    const sub = (n) => {
      if (Array.isArray(n)) return n.map(sub);
      if (n && typeof n === "object") {
        if (n.$ref !== undefined && Object.prototype.hasOwnProperty.call(call.args, n.$ref)) return call.args[n.$ref];
        return Object.fromEntries(Object.entries(n).map(([k, v]) => [k, sub(v)]));
      }
      return n;
    };
    return arr.map(sub).filter((x) => x && x._type);
  }
  throw new Error(`Could not find the Swift definition of ${call.$static}`);
}

function parseBody(src, mode) {
  const toks = tokenize(src); let p = 0;
  const T = (o = 0) => toks[p + o] || { t: "eof", v: "", s: src.length, e: src.length };
  const isP = (v, o = 0) => T(o).t === "p" && T(o).v === v;
  const isId = (v, o = 0) => T(o).t === "id" && (v === undefined || T(o).v === v);
  const expect = (v) => { if (!isP(v)) throw new Error(`Expected "${v}" near: ${src.slice(T().s, T().s + 60)}`); p++; };
  const raw = (s) => ({ $expr: src.slice(s, toks[p - 1].e).replace(/\s+/g, " ") });
  const BIN = new Set(["+", "-", "*", "/", "%", "??", "==", "!=", "<", ">", "<=", ">=", "&&", "||", "...", "..<"]);

  let noTrailing = false;
  function skipBalanced(open, close) { let d = 0; do { if (isP(open)) d++; else if (isP(close)) d--; p++; } while (d > 0 && T().t !== "eof"); }

  function parseArgs() {
    expect("("); const args = [];
    while (!isP(")")) {
      let label = null;
      if (T().t === "id" && isP(":", 1)) { label = T().v; p += 2; }
      args.push({ label, value: parseExpr() });
      if (isP(",")) p++;
    }
    expect(")"); return args;
  }

  function parseExpr() {
    const s = T().s; let n = parseTerm();
    while (T().t === "p" && BIN.has(T().v)) { p++; parseTerm(); n = raw(s); }
    return n;
  }

  function parseTerm() {
    const t = T(); const s = t.s;
    if (isP("-")) { p++; const n = parseTerm(); return typeof n === "number" ? -n : raw(s); }
    if (isP("!")) { p++; parseTerm(); return raw(s); }
    if (t.t === "str") { p++; return t.interpolated ? { $expr: src.slice(t.s, t.e).replace(/\s+/g, " ") } : t.v; }
    if (t.t === "num") { p++; return t.v; }
    if (isP(".") && T(1).t === "id") { p++; const name = T().v; p++; const o = { $enum: name }; if (isP("(")) o.args = parseArgs().map((a) => a.value); return o; }
    if (isP("[")) {
      p++; if (isP(":")) { p += 2; return {}; }
      const items = []; let dict = null;
      while (!isP("]")) { const k = parseExpr(); if (isP(":")) { p++; dict ??= {}; dict[typeof k === "string" ? k : JSON.stringify(k)] = parseExpr(); } else items.push(k); if (isP(",")) p++; }
      expect("]"); return dict ?? items;
    }
    if (isP("(")) { p++; const n = parseExpr(); if (isP(",")) { while (!isP(")")) p++; p++; return raw(s); } expect(")"); return n; }
    if (isP("{")) { skipBalanced("{", "}"); return { $expr: "closure" }; }
    if (t.t === "id") {
      p++;
      if (t.v === "true") return true; if (t.v === "false") return false; if (t.v === "nil") return null;
      let name = t.v, call = null;
      for (;;) {
        if (!call && isP(".") && T(1).t === "id") { p++; name += "." + T().v; p++; }
        else if (isP("(") && !call) { call = parseArgs(); }
        else if (isP("[") && !call) { skipBalanced("[", "]"); return raw(s); }
        else break;
      }
      if (isP("{") && call && !noTrailing) skipBalanced("{", "}");
      if (!call) return { $ref: name };
      if (isP(".") || isP("[")) { while (isP(".") || isP("[") || isP("(")) { if (isP(".")) p += 2; else if (isP("(")) skipBalanced("(", ")"); else skipBalanced("[", "]"); } return raw(s); }
      if (/^[A-Z]\w*$/.test(name)) {
        const o = { _type: name };
        for (const a of call) { if (a.label) o[a.label] = a.value; else (o._args ??= []).push(a.value); }
        return o;
      }
      if (/^[a-z]\w*$/.test(name)) return { $call: name, args: call.map((a) => (a.label ? { [a.label]: a.value } : a.value)) };
      if (/^[A-Z]\w*\.[a-z]\w*$/.test(name) && call.every((a) => a.label && (typeof a.value !== "object" || a.value === null))) {
        return { $static: name, args: Object.fromEntries(call.map((a) => [a.label, a.value])) };
      }
      if (/^[A-Z]\w*\.[a-z]\w*$/.test(name) && call.length === 0) return { $static: name, args: {} };
      return raw(s);
    }
    p++; return raw(s);
  }

  if (mode === "expr") return parseExpr();

  const env = {}, inserted = [];
  const insert = (n) => { if (n && n._type && !inserted.includes(n)) inserted.push(n); };
  const bound = (name) => Object.prototype.hasOwnProperty.call(env, name);

  while (T().t !== "eof") {
    if (isId("let") && T(1).t === "id" && isP("=", 2)) { const name = T(1).v; p += 3; const v = parseExpr(); if (v && v._type) v._id = name; env[name] = v; continue; }
    if (isId("context") && isP(".", 1) && isId("insert", 2) && isP("(", 3)) {
      p += 4; const v = parseExpr(); expect(")");
      if (v && v.$ref && bound(v.$ref)) insert(env[v.$ref]); else insert(v);
      continue;
    }
    if (isId("for") && T(1).t === "id" && isId("in", 2)) {
      const loopVar = T(1).v; p += 3; noTrailing = true; const list = parseExpr(); noTrailing = false;
      if (isP("{")) { const s = p; skipBalanced("{", "}"); const body = toks.slice(s, p).map((x) => x.v).join(" ");
        if (new RegExp(`context \\. insert \\( ${loopVar.replace("$", "\\$")} \\)`).test(body)) {
          if (Array.isArray(list)) { for (const r of list) if (r?.$ref && bound(r.$ref)) insert(env[r.$ref]); }
          else if (list?.$static) for (const item of expandFactory(list)) insert(item);
          else if (list?.$ref && bound(list.$ref) && env[list.$ref]?.$static) for (const item of expandFactory(env[list.$ref])) insert(item);
        } }
      continue;
    }
    if (T().t === "id" && bound(T().v) && isP(".", 1) && T(2).t === "id") {
      const obj = env[T().v], prop = T(2).v;
      if (isP("=", 3) && !isP("=", 4)) { p += 4; const v = parseExpr(); if (obj && typeof obj === "object") obj[prop] = v; continue; }
      if (isP("(", 3)) { p += 3; const args = parseArgs().map((a) => a.value); if (obj && typeof obj === "object") (obj._calls ??= []).push({ name: prop, args }); continue; }
    }
    p++;
  }
  return { env, inserted };
}

function build() {
  const all = { env: {}, inserted: [] };
  for (const re of FUNCS) {
    const m = re.exec(full); if (!m) throw new Error(`Could not find ${re} in AnchorApp.swift`);
    const open = m.index + m[0].length - 1;
    const r = parseBody(full.slice(open + 1, matchBrace(full, open)));
    Object.assign(all.env, r.env); all.inserted.push(...r.inserted);
  }
  const insertedIds = new Set(all.inserted.map((n) => n._id).filter(Boolean));
  const clone = (x) => JSON.parse(JSON.stringify(x));
  const resolve = (n, top = false) => {
    if (Array.isArray(n)) return n.map((x) => resolve(x));
    if (n && typeof n === "object") {
      if (n.$ref !== undefined) {
        const base = n.$ref.replace(/\.id$/, "");
        if (all.env[base] && all.env[base]._type) return insertedIds.has(base) || n.$ref.endsWith(".id") ? { $id: base } : resolve(clone(all.env[base]));
        return n;
      }
      const o = {}; for (const [k, v] of Object.entries(n)) o[k] = resolve(v); return o;
    }
    return n;
  };
  const models = {};
  for (const n of all.inserted) (models[n._type] ??= []).push(resolve(n));
  // Plain values such as `let tuesday = Calendar.current.nextDate(...)`, which other objects refer to by name.
  const bindings = {};
  for (const [k, v] of Object.entries(all.env)) if ((v && typeof v === "object" && !v._type && (v.$expr || v.$call)) || typeof v === "string") bindings[k] = v;
  return { source: "DemoMode.makeContainer and addRecoveryContent in iOS/Anchor/Anchor/AnchorApp.swift", bindings, models };
}

const json = JSON.stringify(build(), null, 1) + "\n";
if (process.argv.includes("--check")) {
  if (!existsSync(OUT) || readFileSync(OUT, "utf8") !== json) { console.error("demo.seed.generated.json is out of date. Run: node scripts/sync-seed.mjs"); process.exit(1); }
  console.log("The website demo data matches the app's demo data.");
} else {
  writeFileSync(OUT, json);
  const m = JSON.parse(json).models;
  console.log("Wrote " + Object.entries(m).map(([k, v]) => `${v.length} ${k}`).join(", "));
}
