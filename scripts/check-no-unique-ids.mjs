// Checks that the database stays free of unique constraints, and that the backup import keeps ids from doubling up.
// Run it from anywhere:  node scripts/check-no-unique-ids.mjs
// Sync through CloudKit cannot carry a unique constraint (Patch SY0, E1), so no model may declare one, and
// everything that was once kept in line by the database is now kept in line by the app:
//   1. No Swift file may use `.unique` on a stored property.
//   2. Every loop in the backup import that skips an id it already has must record the id as it goes
//      (`existing...IDs.insert(dto.id).inserted`), so an id that appears twice in one file is added once.
//   3. All 34 models still have an `id: UUID`.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const swiftRoot = join(root, "iOS");
const problems = [];

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name === "build" || name === "DerivedData" || name.startsWith(".")) continue;
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else if (full.endsWith(".swift")) out.push(full);
  }
  return out;
}

const files = walk(swiftRoot);
let models = 0;
for (const f of files) {
  const text = readFileSync(f, "utf8");
  const rel = relative(root, f);
  text.split("\n").forEach((line, i) => {
    if (line.trim().startsWith("//")) return;
    if (/\.unique\b/.test(line)) problems.push(`${rel}:${i + 1}: uses .unique, which sync cannot carry.`);
  });
  if (/Models\/(AnchorModels|RecoveryModels)\.swift$/.test(f)) {
    models += (text.match(/^@Model\s*\nfinal class /gm) || []).length;
    const ids = (text.match(/^    var id: UUID(?: = UUID\(\))?$/gm) || []).length;
    if (ids < 1) problems.push(`${rel}: no model has an id.`);
  }
  if (/Views\/Plan\/DataControlView\.swift$/.test(f)) {
    for (const m of text.matchAll(/where\s+(?:!existing\w+IDs\.contains\(dto\.id\)|[^\n{]*existing\w+IDs\.contains\()/g)) {
      problems.push(`${rel}: an import loop checks an id but does not record it: ${m[0].trim()}`);
    }
    const tracked = (text.match(/existing\w+IDs\.insert\(dto\.id\)\.inserted/g) || []).length;
    const declared = (text.match(/var existing\w+IDs = Set\(/g) || []).length;
    if (tracked !== declared) problems.push(`${rel}: ${declared} id sets are declared but ${tracked} import loops record an id.`);
  }
}
if (models !== 34) problems.push(`Expected 34 models, found ${models}. If a model was added or removed, update this check and the plan.`);

if (problems.length) {
  console.log(`FAIL: ${problems.length} problem(s)`);
  for (const p of problems) console.log("  - " + p);
  process.exit(1);
}
console.log(`The unique ids check passed. ${models} models, none with a unique constraint, and every import loop records the ids it adds.`);
