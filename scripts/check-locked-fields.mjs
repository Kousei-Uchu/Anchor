// Checks the locked fields (Patch 35b2, docs/ENCRYPTION.md). A locked field is a stored plain property
// (`textPlain`, with the old name as originalName so the stored values carry over), a sealed twin
// (`textSealed`) and a computed property under the old name that goes through FieldLock.
// 1. Every Plain property has a Sealed twin, an originalName that matches, and an accessor under the old name.
// 2. Nothing outside the model files, the key code and the self-test reads or writes a Plain or Sealed property:
//    everything else uses the old name, so a locked value always reads as its text.
// 3. No init sets the old name before the object is whole, and every init ends with lockNewValues().
// 4. Nothing queries or sorts on a locked field, because a stored value that is sealed cannot be compared.
// 5. (Patch 35b3) Every model with locked fields can be locked in place: it conforms to LockableModel, has
//    lockExistingValues, lockedSnapshot and lockedFieldsAreSealed, and is in the list in LockMyData.kinds, so Lock my
//    data cannot leave one behind. Every field is in its snapshot and its sealed check.
// Run it from anywhere:  node scripts/check-locked-fields.mjs

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const swiftRoot = join(root, "iOS");
const modelFiles = ["Models/AnchorModels.swift", "Models/RecoveryModels.swift"].map((f) => join(swiftRoot, "Anchor/Anchor", f));
// Files allowed to touch the twins: the models, and the code that is about the locking itself.
const allowed = (rel) => /Models\/(Anchor|Recovery)Models\.swift$/.test(rel) || /Support\/(AppLock|LockedFields|LockMyData)\.swift$/.test(rel);

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

const problems = [];
const locked = []; // { cls, name }

for (const file of modelFiles) {
  const lines = readFileSync(file, "utf8").split("\n");
  let cls = null;
  let inInit = false;
  const classFields = new Map();
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const c = line.match(/^final class (\w+)/);
    if (c && /@Model/.test(lines[i - 1] || "")) { cls = c[1]; inInit = false; classFields.clear(); }
    if (cls) {
      const p = line.match(/^    @Attribute\(originalName: "(\w+)"\) var (\w+)Plain: /);
      if (p) {
        if (p[1] !== p[2]) problems.push(`${cls}: ${p[2]}Plain has originalName "${p[1]}".`);
        classFields.set(p[2], true);
        locked.push({ cls, name: p[2] });
        if (!lines.some((l) => l.startsWith(`    var ${p[2]}Sealed: String? = nil`))) problems.push(`${cls}.${p[2]} has no Sealed twin.`);
        const accessor = new RegExp(`^    var ${p[2]}: `);
        if (!lines.some((l, j) => accessor.test(l) && /^extension /.test(lines.slice(0, j).reverse().find((x) => /^(extension|final class|@Model)/.test(x)) || ""))) {
          problems.push(`${cls}.${p[2]} has no accessor under the old name.`);
        }
      }
      if (/^    init\(/.test(line)) inInit = true;
      if (inInit) {
        for (const name of classFields.keys()) {
          if (new RegExp(`^\\s+self\\.${name} = `).test(line)) problems.push(`${cls}: an init sets self.${name} before the object is whole (use ${name}Plain).`);
        }
      }
      if (inInit && line === "    }") {
        inInit = false;
        if (lines[i - 1].trim() !== "lockNewValues()" && classFields.size) problems.push(`${cls}: an init does not end with lockNewValues().`);
      }
      if (line === "}") cls = null;
    }
  }
}

const twins = new Set(locked.flatMap((f) => [`${f.name}Plain`, `${f.name}Sealed`]));
for (const file of swiftFiles(swiftRoot)) {
  const rel = relative(root, file);
  const text = readFileSync(file, "utf8");
  if (!allowed(rel)) {
    for (const t of twins) {
      if (new RegExp(`\\b${t}\\b`).test(text)) problems.push(`${rel} uses ${t}; use the old name so a locked value reads as its text.`);
    }
  }
  // 4. Sorting or filtering on a locked field: a key path such as \\Class.field, an unqualified \\.field in a
  // sort, or $0.field inside a predicate. An unqualified key path or $0 is about the model the line names, in
  // FetchDescriptor<Model> or in the type of the property (: [Model]); when the line names none, it counts against
  // every model, as it always did (Patch 35g1a).
  const modelOfLine = (line) => (line.match(/(?:FetchDescriptor|#Predicate)<(\w+)>/) || line.match(/:\s*\[(\w+)\]/) || [])[1] || null;
  for (const line of text.split("\n")) {
    const lineModel = modelOfLine(line);
    if (/SortDescriptor|@Query\(|sortBy/.test(line)) {
      for (const m of line.matchAll(/\\(\w*)\.(\w+)/g)) {
        const owner = m[1] || lineModel;
        const hit = locked.some((f) => f.name === m[2] && (owner === null || owner === f.cls));
        if (hit) problems.push(`${rel}: sorts on the locked field ${owner ? owner + "." : ""}${m[2]}.`);
      }
    }
    if (/#Predicate/.test(line)) {
      for (const m of line.matchAll(/\$0\.(\w+)/g)) {
        if (locked.some((f) => f.name === m[1] && (lineModel === null || lineModel === f.cls))) {
          problems.push(`${rel}: a predicate reads ${m[1]}, which is a locked field${lineModel ? " of " + lineModel : ""}.`);
        }
      }
    }
  }
}

// 5. Lock my data covers every model with locked fields.
const lockMyData = readFileSync(join(swiftRoot, "Anchor/Anchor/Support/LockMyData.swift"), "utf8");
const modelText = modelFiles.map((f) => readFileSync(f, "utf8")).join("\n");
const lockedClasses = new Set(locked.map((f) => f.cls));
for (const cls of lockedClasses) {
  if (!new RegExp(`^extension ${cls}: LockableModel \\{\\}`, "m").test(modelText)) problems.push(`${cls} does not conform to LockableModel.`);
  if (!lockMyData.includes(`kind(${cls}.self)`)) problems.push(`${cls} is not in LockMyData.kinds, so Lock my data would leave it unlocked.`);
}
for (const m of lockMyData.matchAll(/kind\((\w+)\.self\)/g)) {
  if (!lockedClasses.has(m[1])) problems.push(`LockMyData.kinds lists ${m[1]}, which has no locked fields.`);
}
for (const cls of lockedClasses) {
  const start = modelText.indexOf(`extension ${cls} {`);
  const end = modelText.indexOf("\n}\n", start);
  const body = start >= 0 ? modelText.slice(start, end) : "";
  for (const fn of ["func lockExistingValues()", "func lockedSnapshot()", "func lockedFieldsAreSealed()"]) {
    if (!body.includes(fn)) problems.push(`${cls} has no ${fn.replace("func ", "")}.`);
  }
  for (const f of locked.filter((x) => x.cls === cls)) {
    if (!new RegExp(`FieldLock\\.describe\\(${f.name}\\)`).test(body)) problems.push(`${cls}.${f.name} is not in lockedSnapshot().`);
    if (!new RegExp(`\\b${f.name}(Sealed|Plain)\\b`).test(body.slice(body.indexOf("func lockedFieldsAreSealed")))) problems.push(`${cls}.${f.name} is not in lockedFieldsAreSealed().`);
  }
}

if (problems.length) {
  console.log([...new Set(problems)].join("\n"));
  process.exit(1);
}
console.log(`The locked fields check passed. ${locked.length} fields on ${new Set(locked.map((f) => f.cls)).size} models.`);
