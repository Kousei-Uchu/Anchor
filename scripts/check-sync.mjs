// Checks the rules iCloud sync (Patch SY1b) must keep, which can be checked without Xcode:
//   1. Only the real store, in AnchorSchema.makeContainer, may ask for CloudKit. Every other ModelConfiguration says
//      cloudKitDatabase: .none, so a review run, a self-test or the safety copy never syncs.
//   2. Sync starts only through CloudSync.shouldSyncAtLaunch, which needs the switch, the data key and everything locked.
//   3. The Health reader does not bring nights in while sync is on (D39).
// Run it from anywhere:  node scripts/check-sync.mjs

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const app = join(root, "iOS/Anchor/Anchor");
const problems = [];

function* swiftFiles(dir) {
  for (const f of readdirSync(dir)) {
    const p = join(dir, f);
    if (statSync(p).isDirectory()) yield* swiftFiles(p);
    else if (f.endsWith(".swift")) yield p;
  }
}

let realStores = 0;
for (const file of swiftFiles(app)) {
  const text = readFileSync(file, "utf8");
  for (const m of text.matchAll(/ModelConfiguration\([^\n]*cloudKitDatabase:\s*([^)\n]*\)?)/g)) {
    const value = m[1];
    if (/^\.none\b/.test(value)) continue;
    if (file.endsWith("Models/AnchorModels.swift") && /wantsSync/.test(value)) { realStores++; continue; }
    problems.push(`${file.replace(root + "/", "")}: a ModelConfiguration asks for ${value.trim()} outside the real store.`);
  }
}
if (realStores !== 1) problems.push(`Expected one real store that can sync, found ${realStores}.`);

const models = readFileSync(join(app, "Models/AnchorModels.swift"), "utf8");
if (!/let wantsSync = syncWanted\(\)/.test(models)) problems.push("makeContainer does not decide through syncWanted.");
if (/CloudSync/.test(models.replace(/\/\/[^\n]*/g, ""))) problems.push("AnchorModels.swift is built into the widget and must not name CloudSync in code.");
const appSwift = readFileSync(join(root, "iOS/Anchor/Anchor/AnchorApp.swift"), "utf8");
if (!/CloudSync\.install\(\)/.test(appSwift)) problems.push("AnchorApp.init must call CloudSync.install() before any store is opened.");

const sync = readFileSync(join(app, "Support/CloudSync.swift"), "utf8");
for (const needle of ["DataKeyStore.lookup()", "LockMyData.isOn", "LockMyData.needsMore"]) {
  if (!sync.includes(needle)) problems.push(`CloudSync.shouldSyncAtLaunch no longer checks ${needle}.`);
}

const plan = readFileSync(join(app, "Views/Plan/PlanView.swift"), "utf8");
const guards = (plan.match(/!CloudSync\.isOn/g) || []).length;
if (guards < 2) problems.push("The Health reader must stop bringing nights in while sync is on, in both connect and sync.");

// SY2: files reach iCloud only as sealed files, and nothing in FileSync deletes a local file by itself.
const files = readFileSync(join(app, "Support/FileSync.swift"), "utf8").replace(/\/\/[^\n]*/g, "");
if (!/StoredFiles\.isSealed\(at:/.test(files)) problems.push("FileSync no longer checks that a file is sealed before sending it.");
if (!/LockMyFiles\.isOn/.test(files)) problems.push("FileSync no longer needs Lock my files to be complete.");
if (!/installSealed/.test(files)) problems.push("FileSync no longer brings files in through StoredFiles.installSealed.");
if (/removeItem|FileManager\.default\.removeItem/.test(files.replace(/zone/gi, ""))) problems.push("FileSync removes a file by itself; only StoredFiles.removeFromSync may, for a delete made on another device.");
if (!/FileSync\.noteDeleted/.test(readFileSync(join(app, "Views/Thread/ThreadMessagesView.swift"), "utf8"))) problems.push("Deleting a voice note must tell FileSync.");

if (problems.length) {
  console.log(`FAIL: ${problems.length} problem(s)`);
  for (const p of problems) console.log("  - " + p);
  process.exit(1);
}
console.log("The sync check passed. One real store can sync, it starts only when switched on with the key here and everything locked, and Health nights are not brought in while it is on.");
