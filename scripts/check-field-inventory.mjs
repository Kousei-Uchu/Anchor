// Checks docs/FIELD_INVENTORY.md against the code (Patch 35f, D44, D64).
// The inventory lists every stored field of every SwiftData model and every typed or stored setting, each with
// a verdict (locked or plain), what is true today (sealed, plain, or still to lock in a named 35g patch) and a
// reason. This check keeps the list and the code in step:
// 1. Every @Model class has a section, and every section is a @Model class.
// 2. Every stored field of a model has exactly one row, and every row is a stored field, with the type that the
//    code has. A field written as `xPlain` with an `xSealed` twin is listed as `x`.
// 3. Every row has a verdict of locked or plain, a Today of sealed, plain or "to lock 35gN", and a reason.
// 4. Today says sealed exactly when the code has the sealed twin. A plain verdict is never "to lock". A locked verdict
//    that is not sealed yet names a 35g patch, and it matches the model's "Lock in" line.
// 5. Every settings key the code stores has a row, and every row is a key the code still has.
// 6. Nothing writes `isUserAuthored: true`, because mascot lines are listed as shipped, plain content.
// Run it from anywhere:  node scripts/check-field-inventory.mjs
// To see where a field that is still to be locked is sorted or filtered today (35g has to change each place):
//   node scripts/check-field-inventory.mjs --uses
// When a field or a key is missing from the list, the failure prints a row to start from.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const swiftRoot = join(root, "iOS");
const modelFiles = ["Models/AnchorModels.swift", "Models/RecoveryModels.swift"].map((f) => join(swiftRoot, "Anchor/Anchor", f));
const inventoryPath = join(root, "docs/FIELD_INVENTORY.md");
const showUses = process.argv.includes("--uses");
const problems = [];

function swiftFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name.startsWith(".")) continue;
    const path = join(dir, name);
    if (statSync(path).isDirectory()) out.push(...swiftFiles(path));
    else if (name.endsWith(".swift")) out.push(path);
  }
  return out;
}

// ---- The code: every stored field of every model ----
const storedLine = /^    (?:@Attribute\([^)]*\) )?var (\w+): ([^={]+?)(?: = .*?)?\s*(?:\/\/.*)?$/;
const codeModels = new Map(); // class -> Map(field -> { type, sealed })
for (const file of modelFiles) {
  const lines = readFileSync(file, "utf8").split("\n");
  let cls = null;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const c = line.match(/^final class (\w+)/);
    if (c && /@Model/.test(lines[i - 1] || "")) {
      cls = c[1];
      codeModels.set(cls, new Map());
      continue;
    }
    if (!cls) continue;
    if (line === "}") { cls = null; continue; }
    const m = line.match(storedLine);
    if (!m) continue;
    const fields = codeModels.get(cls);
    const [, name, rawType] = m;
    const type = rawType.trim();
    if (name.endsWith("Sealed")) {
      const base = name.slice(0, -"Sealed".length);
      fields.set(base, { ...(fields.get(base) || { type: "?" }), sealed: true });
    } else if (name.endsWith("Plain") && (/originalName/.test(line) || /\/\/ a new locked field/.test(line))) {
      const base = name.slice(0, -"Plain".length);
      fields.set(base, { ...(fields.get(base) || {}), type, sealed: fields.get(base)?.sealed || false });
    } else {
      fields.set(name, { type, sealed: false });
    }
  }
}

// ---- The inventory: the sections and the rows ----
const text = readFileSync(inventoryPath, "utf8");
const docModels = new Map(); // class -> { lockIn, rows: Map(field -> { type, verdict, today, reason }) }
const docKeys = new Map(); // key -> { verdict, today, reason }
let section = null;
let inSettings = false;
for (const line of text.split("\n")) {
  const h = line.match(/^## (.+?)\s*$/);
  if (h) {
    inSettings = /^Settings and other stored values/.test(h[1]);
    section = inSettings ? null : h[1];
    if (section && /^[A-Z]\w+$/.test(section)) docModels.set(section, { lockIn: null, rows: new Map() });
    else section = null;
    continue;
  }
  const lock = line.match(/^Lock in: (.+?)\s*$/);
  if (lock && section) { docModels.get(section).lockIn = lock[1]; continue; }
  if (!line.startsWith("|")) continue;
  const cells = line.split("|").slice(1, -1).map((c) => c.trim().replace(/^`|`$/g, ""));
  if (/^-+$/.test(cells[0]) || cells[0] === "Field" || cells[0] === "Key") continue;
  if (section && cells.length === 5) {
    const [field, type, verdict, today, reason] = cells;
    if (docModels.get(section).rows.has(field)) problems.push(`${section}.${field} has two rows.`);
    docModels.get(section).rows.set(field, { type, verdict, today, reason });
  } else if (inSettings && cells.length === 5) {
    const [key, , verdict, today, reason] = cells;
    if (docKeys.has(key)) problems.push(`The settings key ${key} has two rows.`);
    docKeys.set(key, { verdict, today, reason });
  }
}

const verdicts = new Set(["locked", "plain"]);
const todayOk = (t) => t === "sealed" || t === "plain" || /^to lock 35g[1-9]$/.test(t);
const norm = (t) => t.replace(/\s+/g, "");

// 1 and 2: models and fields
for (const cls of codeModels.keys()) if (!docModels.has(cls)) problems.push(`${cls} is a model but has no section in docs/FIELD_INVENTORY.md.`);
for (const cls of docModels.keys()) if (!codeModels.has(cls)) problems.push(`${cls} has a section in docs/FIELD_INVENTORY.md but is not a model.`);
for (const [cls, fields] of codeModels) {
  const doc = docModels.get(cls);
  if (!doc) continue;
  for (const [name, f] of fields) {
    if (!doc.rows.has(name)) {
      const guess = `| ${name} | ${f.type} | ? | ${f.sealed ? "sealed" : "?"} | ? |`;
      problems.push(`${cls}.${name} has no row. Start from: ${guess}`);
    }
  }
  for (const [name, r] of doc.rows) {
    const f = fields.get(name);
    if (!f) { problems.push(`${cls}.${name} has a row but is not a stored field.`); continue; }
    if (norm(r.type) !== norm(f.type)) problems.push(`${cls}.${name}: the row says the type is ${r.type} but the code has ${f.type}.`);
    // 3 and 4
    if (!verdicts.has(r.verdict)) problems.push(`${cls}.${name}: the verdict must be locked or plain, not "${r.verdict}".`);
    if (!todayOk(r.today)) problems.push(`${cls}.${name}: Today must be sealed, plain or "to lock 35g1" to "to lock 35g9", not "${r.today}".`);
    if (!r.reason || r.reason === "?") problems.push(`${cls}.${name} has no reason.`);
    if ((r.today === "sealed") !== f.sealed) problems.push(`${cls}.${name}: Today says ${r.today} but the code ${f.sealed ? "has" : "has no"} sealed twin.`);
    if (r.verdict === "plain" && r.today !== "plain") problems.push(`${cls}.${name}: a plain field must say plain under Today.`);
    if (r.verdict === "locked" && r.today === "plain") problems.push(`${cls}.${name}: a locked field cannot say plain under Today; say "to lock 35gN".`);
    if (/^to lock/.test(r.today) && doc.lockIn && doc.lockIn !== r.today.replace("to lock ", "")) {
      problems.push(`${cls}.${name}: ${r.today}, but the section says Lock in: ${doc.lockIn}.`);
    }
  }
  const pending = [...doc.rows.values()].some((r) => /^to lock/.test(r.today));
  if (pending && !/^35g[1-9]$/.test(doc.lockIn || "")) problems.push(`${cls}: has fields still to lock but its Lock in line is "${doc.lockIn}".`);
  if (!pending && doc.lockIn !== "none") problems.push(`${cls}: nothing is left to lock, so its Lock in line must say none, not "${doc.lockIn}".`);
}

// 5: settings keys
const files = swiftFiles(swiftRoot).filter((f) => !/ReviewWalkthrough\.swift$/.test(f));
const constants = new Map(); // const name -> Set(literal)
const used = new Set(); // literals that code reads or writes as settings
const notSettings = new Set([
  // userInfo keys of a scheduled notification, an identifier of a signing key, and the like: not stored settings.
  "helloContactID", "helloKind", "helloEventDay", "helloDayBefore", "helloMessageID", "helloWindowID", "06b8de366163df2a",
]);
const allText = new Map();
for (const f of files) allText.set(f, readFileSync(f, "utf8"));
for (const [, t] of allText) {
  for (const m of t.matchAll(/static (?:let|var) (\w+)(?:\s*:\s*String)?\s*=\s*"([^"\n]+)"/g)) {
    if (!constants.has(m[1])) constants.set(m[1], new Set());
    constants.get(m[1]).add(m[2]);
  }
}
const keyLine = /AppStorage\(|forKey:|LockedSetting\./;
for (const [, t] of allText) {
  for (const line of t.split("\n")) {
    if (!keyLine.test(line)) continue;
    for (const m of line.matchAll(/(?:AppStorage\(|forKey:\s*)"([^"\n]+)"/g)) used.add(m[1]);
    for (const m of line.matchAll(/\b(?:\w+\.)?(\w+Key|\w+Enabled|\w+Hour|\w+Minute|\w+Longest|key|storageKey|storeKey)\b/g)) {
      for (const lit of constants.get(m[1]) || []) used.add(lit);
    }
    for (const m of line.matchAll(/\.(?:fullKey|hiddenKey|orderKey)\b/g)) {
      for (const lit of ["widgetFull.<tab>", "widgetHidden.<tab>", "widgetOrder.<tab>"]) used.add(lit);
    }
  }
}
// Keys built from a name, as in "widgetOrder.\(rawValue)", and the one seeded flag per widget.
for (const [, t] of allText) {
  for (const m of t.matchAll(/"((?:widgetOrder|widgetHidden|widgetFull|widgetSeeded)\.[^"]*)"/g)) used.add(m[1].replace(/\\\([^)]*\)/g, "<>").replace(/\.<>\.<>$/, ".<tab>.<widget>").replace(/\.<>$/, ".<tab>"));
}
for (const lit of [...used]) if (notSettings.has(lit)) used.delete(lit);
const normKey = (k) => k.replace(/<[^>]*>/g, "<>");
const usedNorm = new Map([...used].map((k) => [normKey(k), k]));
const docNorm = new Map([...docKeys.keys()].map((k) => [normKey(k), k]));
for (const [n, k] of usedNorm) if (!docNorm.has(n)) problems.push(`The settings key ${k} is stored by the code but has no row. Start from: | ${k} | ? | ? | ? | ? |`);
for (const [n, k] of docNorm) if (!usedNorm.has(n)) problems.push(`The settings key ${k} has a row but the code no longer stores it.`);
for (const [k, r] of docKeys) {
  if (!verdicts.has(r.verdict)) problems.push(`Setting ${k}: the verdict must be locked or plain.`);
  if (!todayOk(r.today)) problems.push(`Setting ${k}: Today must be sealed, plain or "to lock 35gN".`);
  if (r.verdict === "plain" && r.today !== "plain") problems.push(`Setting ${k}: a plain value must say plain under Today.`);
  if (r.verdict === "locked" && r.today === "plain") problems.push(`Setting ${k}: a locked value cannot say plain under Today; say "to lock 35gN".`);
  if (!r.reason || r.reason === "?") problems.push(`Setting ${k} has no reason.`);
}

// 6: no user-authored mascot lines
for (const [f, t] of allText) {
  if (/isUserAuthored:\s*true/.test(t)) problems.push(`${relative(root, f)} writes isUserAuthored: true; MascotLine.text is listed as shipped content, so it would have to be locked first.`);
}

// ---- Optional: where each field that is still to be locked is sorted or filtered today ----
if (showUses) {
  const pendingFields = new Set();
  for (const [, d] of docModels) for (const [n, r] of d.rows) if (/^to lock/.test(r.today)) pendingFields.add(n);
  const database = [];
  let inMemory = 0;
  for (const [f, t] of allText) {
    const rel = relative(root, f);
    t.split("\n").forEach((line, i) => {
      if (!/SortDescriptor|@Query\(|sortBy|\.sorted\(|\.sort\(|#Predicate|\.filter\s*\{|\.first\(where|\.max\(by|\.min\(by/.test(line)) return;
      const fieldsHere = [...pendingFields].filter((n) => new RegExp(`(?:\\\\\\w*\\.|\\$0\\.|\\.)${n}\\b`).test(line));
      if (!fieldsHere.length) return;
      // The database does the sorting or filtering here, so a sealed value cannot be used: 35g has to change it.
      if (/SortDescriptor|@Query\(|sortBy|#Predicate/.test(line)) database.push(`${rel}:${i + 1}  ${fieldsHere.join(", ")}  ${line.trim().slice(0, 100)}`);
      else inMemory += 1;
    });
  }
  console.log(`Sorted or filtered by the database on a field still to lock (35g must change each one): ${database.length}`);
  for (const h of database) console.log("  " + h);
  console.log(`Sorted or filtered in memory on such a field (works after locking, only slower): ${inMemory}`);
}

const rows = [...docModels.values()].reduce((n, d) => n + d.rows.size, 0);
if (problems.length) {
  console.log(`FAIL: ${problems.length} problem(s) in the field inventory`);
  for (const p of problems) console.log("  - " + p);
  process.exit(1);
}
const pendingCount = [...docModels.values()].reduce((n, d) => n + [...d.rows.values()].filter((r) => /^to lock/.test(r.today)).length, 0);
console.log(`OK: ${codeModels.size} models, ${rows} fields and ${docKeys.size} settings are in the inventory; ${pendingCount} fields are still to lock.`);
