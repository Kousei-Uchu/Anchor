// Checks that every kind of stored content has made-up content in the demo store, which showcase
// mode, the screenshot tests and the review run all share.
// Run it from anywhere:  node scripts/check-demo-coverage.mjs
// It reads the list of models in AnchorSchema.models and looks for each one being created inside
// DemoMode.makeContainer (or the helpers under it in AnchorApp.swift). A model that is missing and
// not in the short list below fails the check, so a new feature cannot reach showcase mode empty.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const modelsPath = join(root, "iOS/Anchor/Anchor/Models/AnchorModels.swift");
const appPath = join(root, "iOS/Anchor/Anchor/AnchorApp.swift");

// Models that are left out of the demo on purpose, and why.
const exempt = {
  SafetyPlan: "the older four-text form, copied into sections once and no longer read",
  NextHourItem: "the older Next hour list, moved into tasks once and no longer shown",
  MascotLine: "seeded on the first appearance of Now by MascotEngine.seedIfNeeded",
};

// Models the demo makes through a helper instead of calling the initialiser directly.
const viaHelper = {
  SafetyPlanSection: "SafetyPlanSections.makeSections(",
  BoundarySection: "BoundarySection.startingSections(",
};

const models = readFileSync(modelsPath, "utf8");
const app = readFileSync(appPath, "utf8");

const listStart = models.indexOf("static var models: [any PersistentModel.Type]");
if (listStart === -1) {
  console.error("Could not find AnchorSchema.models in AnchorModels.swift.");
  process.exit(2);
}
const listEnd = models.indexOf("]\n    }", listStart);
const names = [...models.slice(listStart, listEnd).matchAll(/(\w+)\.self/g)].map((m) => m[1]);
if (names.length === 0) {
  console.error("AnchorSchema.models looks empty; the check could not read it.");
  process.exit(2);
}

const demoStart = app.indexOf("enum DemoMode {");
const demoEnd = app.indexOf("// MARK: - Showcase mode: what is cleared outside the store", demoStart);
if (demoStart === -1 || demoEnd === -1) {
  console.error("Could not find DemoMode in AnchorApp.swift.");
  process.exit(2);
}
const demo = app.slice(demoStart, demoEnd);

let failed = false;
for (const name of Object.keys(exempt)) {
  if (!names.includes(name)) {
    console.error(`Stale exemption: ${name} is no longer in AnchorSchema.models. Remove it from this script.`);
    failed = true;
  }
}

const missing = [];
let covered = 0;
for (const name of names) {
  if (exempt[name]) continue;
  const found = viaHelper[name] ? demo.includes(viaHelper[name]) : new RegExp(`\\b${name}\\(`).test(demo);
  if (found) covered += 1;
  else missing.push(name);
}

console.log(`${names.length} models in the schema: ${covered} have made-up content, ${Object.keys(exempt).length} are left out on purpose.`);
for (const [name, why] of Object.entries(exempt)) console.log(`  left out: ${name} (${why})`);

if (missing.length > 0) {
  failed = true;
  console.error("\nNo made-up content for:");
  for (const name of missing) console.error(`  ${name}`);
  console.error("\nAdd some to DemoMode.makeContainer in AnchorApp.swift, or list it as left out above with a reason.");
}

process.exit(failed ? 1 : 0);
