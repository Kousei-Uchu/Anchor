// Checks the parts of the database that iCloud sync through CloudKit needs, which can be checked without Xcode
// (Patch SY1a, E1). Run it from anywhere:  node scripts/check-cloudkit-ready.mjs
//   1. Every stored property of every model is optional or has a default value. CloudKit cannot make a row that
//      is missing a value, so a property with neither would stop sync from starting.
//   2. Every relationship is optional and has an inverse, which CloudKit also asks. Both were gaps until Patch
//      SY1b-pre, and now fail this check if they come back.
// It reads only the stored properties between a model's first line and its init, and skips computed ones.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const models = join(root, "iOS/Anchor/Anchor/Models");
const problems = [];
let classes = 0, stored = 0;

for (const file of ["AnchorModels.swift", "RecoveryModels.swift"]) {
  const text = readFileSync(join(models, file), "utf8");
  for (const m of text.matchAll(/^@Model\s*\nfinal class (\w+)[^{]*\{\n([\s\S]*?)\n    init\(/gm)) {
    classes++;
    const [, cls, body] = m;
    const lines = body.split("\n");
    lines.forEach((line, i) => {
      const t = line.trim();
      if (t.startsWith("//") || t.includes("{")) return;
      const decl = t.match(/^(?:@Attribute\([^)]*\)\s+)?(?:@Relationship\([^\n]*?\)\s+)?var (\w+)\s*:\s*([^=\/]+?)\s*(=.*)?(?:\/\/.*)?$/);
      if (!decl) {
        if (/^@Relationship/.test(t)) {
          const next = (lines[i + 1] || "").trim();
          const rel = next.match(/var (\w+)\s*:\s*([^=]+?)\s*(=|$)/);
          if (rel) {
            const bad = [!/inverse:/.test(t) && "has no inverse", !rel[2].trim().endsWith("?") && "is not optional"].filter(Boolean);
            if (bad.length) problems.push(`${cls}.${rel[1]}: a relationship that ${bad.join(" and ")}.`);
          }
        }
        return;
      }
      stored++;
      const [, name, type, dflt] = decl;
      if (!type.trim().endsWith("?") && !dflt) problems.push(`${cls}.${name}: ${type.trim()} has no default value and is not optional.`);
    });
  }
}
if (classes !== 34) problems.push(`Expected 34 models, found ${classes}.`);

if (problems.length) {
  console.log(`FAIL: ${problems.length} problem(s)`);
  for (const p of problems.slice(0, 40)) console.log("  - " + p);
  process.exit(1);
}
console.log(`The CloudKit readiness check passed. ${stored} stored properties on ${classes} models all have a default or are optional, and every relationship is optional with an inverse.`);
