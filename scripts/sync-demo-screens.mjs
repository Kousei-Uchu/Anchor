// Turns what the capture recorded into the website's tappable demo (Patch 55b).
//
//   node scripts/sync-demo-screens.mjs          reads build/demo-capture/*.json and writes
//                                               website/src/content/demo.screens.generated.json
//   node scripts/sync-demo-screens.mjs --check  checks the table, the labels and the generated file
//                                               (needs no capture, so it can run anywhere)
//
// The screens the demo has are the table in iOS/Anchor/AnchorUITests/DemoCaptureTests.swift.
// The pictures are website/public/demo/<name>.jpg, which scripts/make-demo-capture.sh makes from the capture.
//
// How the screens are joined (nothing here is typed by hand):
//   - a tab button on any screen goes to that tab's first screen
//   - a button whose label is the last step of another screen's path goes to that screen, from the screen
//     one step up the path (or from that screen scrolled once, twice or more, if the button was below the fold)
//   - "Back", "Close", "Cancel" and "Done" go back to the screen before
//   - a screen whose path ends in "@scroll" is the scrolled version of its parent: wheel or swipe moves between them

import { readFileSync, writeFileSync, existsSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const testFile = join(root, "iOS/Anchor/AnchorUITests/DemoCaptureTests.swift");
const appDir = join(root, "iOS/Anchor/Anchor");
const captureDir = join(root, "build/demo-capture");
const imageDir = join(root, "website/public/demo");
const outPath = join(root, "website/src/content/demo.screens.generated.json");

const TABS = ["Now", "Plan", "Journal", "Bridge", "Thread"];
const BACKS = new Set(["Back", "Close", "Cancel", "Done"]);
const problems = [];
const warnings = [];
const fail = (m) => problems.push(m);

// ---- the table ----
function readTable() {
  const text = readFileSync(testFile, "utf8");
  const a = text.indexOf("// BEGIN SCREENS");
  const b = text.indexOf("// END SCREENS");
  if (a < 0 || b < a) {
    console.error("Could not find the BEGIN SCREENS and END SCREENS lines in DemoCaptureTests.swift.");
    process.exit(1);
  }
  const rows = [];
  for (const m of text.slice(a, b).matchAll(/\("([a-z0-9-]+)",\s*\[([^\]]*)\]\)/g)) {
    const path = [...m[2].matchAll(/"((?:[^"\\]|\\.)*)"/g)].map((s) => s[1]);
    rows.push({ name: m[1], path });
  }
  if (rows.length === 0) {
    console.error("The screens table in DemoCaptureTests.swift is empty or could not be read.");
    process.exit(1);
  }
  return rows;
}

const table = readTable();
const names = new Set();
for (const { name, path } of table) {
  if (names.has(name)) fail(`The screen name "${name}" is in the table twice.`);
  names.add(name);
}
if (!table.some((r) => r.path.length === 0)) fail("The table needs a first screen with an empty path (the Now tab).");
for (const tab of TABS.slice(1)) {
  if (!table.some((r) => r.path.length === 1 && r.path[0] === tab)) fail(`The table has no screen for the ${tab} tab (a path of just "${tab}").`);
}

// Every label in a path must be a string the app really has, or the capture would tap nothing.
const swift = readdirSync(appDir, { recursive: true })
  .filter((f) => String(f).endsWith(".swift"))
  .map((f) => readFileSync(join(appDir, String(f)), "utf8"))
  .join("\n");
for (const { name, path } of table) {
  for (const step of path) {
    if (step === "@scroll" || TABS.includes(step)) continue;
    if (!swift.includes(`"${step}"`)) fail(`Screen "${name}" taps "${step}", but no string "${step}" is in the app's source. Did the label change?`);
  }
}

// ---- the generated file ----
function checkGenerated() {
  if (!existsSync(outPath)) return fail("website/src/content/demo.screens.generated.json is missing. Run: node scripts/sync-demo-screens.mjs");
  const data = JSON.parse(readFileSync(outPath, "utf8"));
  if (!Array.isArray(data.screens)) return fail("demo.screens.generated.json has no screens list.");
  if (data.screens.length === 0) return; // not captured yet: the website keeps its hand-built demo
  const ids = new Set(data.screens.map((s) => s.id));
  if (!ids.has(data.start)) fail(`The start screen "${data.start}" is not among the screens.`);
  for (const s of data.screens) {
    if (!existsSync(join(imageDir, `${s.id}.jpg`))) fail(`No picture for screen "${s.id}": website/public/demo/${s.id}.jpg`);
    if (s.image !== `/demo/${s.id}.jpg`) fail(`Screen "${s.id}" points at ${s.image}.`);
    for (const h of s.hot) {
      if (h.to && !ids.has(h.to)) fail(`A tappable area on "${s.id}" goes to "${h.to}", which is not a screen.`);
    }
    for (const k of ["more", "less"]) if (s[k] && !ids.has(s[k])) fail(`"${s.id}" has ${k} "${s[k]}", which is not a screen.`);
    if (!names.has(s.id)) warnings.push(`The generated file has "${s.id}", which is no longer in the table. Run the capture again.`);
  }
}

if (process.argv.includes("--check")) {
  checkGenerated();
  report();
  const n = JSON.parse(readFileSync(outPath, "utf8")).screens.length;
  console.log(n === 0
    ? `The demo screens table is fine (${table.length} screens). Nothing is captured yet, so the website keeps its hand-built demo.`
    : `The demo screens table and the generated file are fine (${n} captured of ${table.length} in the table).`);
  process.exit(0);
}

// ---- build from the capture ----
if (problems.length) report();
if (!existsSync(captureDir)) {
  console.error("No capture found at build/demo-capture. Run scripts/make-demo-capture.sh first.");
  process.exit(1);
}

const same = (a, b) => a.length === b.length && a.every((x, i) => x === b[i]);
const captured = [];
for (const row of table) {
  const file = join(captureDir, `${row.name}.json`);
  if (!existsSync(file)) {
    warnings.push(`"${row.name}" was not captured.`);
    continue;
  }
  const info = JSON.parse(readFileSync(file, "utf8"));
  if (!existsSync(join(imageDir, `${row.name}.jpg`))) {
    warnings.push(`"${row.name}" has no picture in website/public/demo, so it is left out.`);
    continue;
  }
  captured.push({ ...row, info });
}
const byPath = (p) => captured.find((c) => same(c.path, p));
const pct = (v, total) => Math.round((v / total) * 10000) / 100;
const lastOf = (c) => c.path[c.path.length - 1];
const isScroll = (c) => lastOf(c) === "@scroll";
const matches = (label, step) => label === step || label.startsWith(step + ",");

const screens = captured.map((c) => {
  const { width, height } = c.info;
  const hot = [];
  const taken = new Set();
  for (const e of c.info.elements) {
    const box = { x: pct(e.x, width), y: pct(e.y, height), w: pct(e.w, width), h: pct(e.h, height), label: e.label };
    const key = e.label;
    if (taken.has(key)) continue;
    let to;
    const tab = TABS.find((t) => e.label === t);
    if (tab) {
      const target = tab === "Now" ? byPath([]) : byPath([tab]);
      if (target && target.name !== c.name) to = target.name;
      else { taken.add(key); continue; }
    } else if (BACKS.has(e.label)) {
      hot.push({ ...box, back: true });
      taken.add(key);
      continue;
    } else {
      for (const other of captured) {
        if (isScroll(other) || other.path.length === 0 || TABS.includes(lastOf(other)) && other.path.length === 1) continue;
        const parent = other.path.slice(0, -1);
        // the screen itself, or that screen scrolled once, twice, and so on
        const base = [...c.path];
        while (base.length > 0 && base[base.length - 1] === "@scroll") base.pop();
        const sameScreen = same(parent, base);
        if (sameScreen && matches(e.label, lastOf(other))) { to = other.name; break; }
      }
    }
    if (to) {
      hot.push({ ...box, to });
      taken.add(key);
    }
  }
  const s = { id: c.name, image: `/demo/${c.name}.jpg`, hot };
  return s;
});

// the scrolled versions
for (const c of captured.filter(isScroll)) {
  const parent = byPath(c.path.slice(0, -1));
  if (!parent) {
    warnings.push(`"${c.name}" is a scrolled screen but its parent was not captured.`);
    continue;
  }
  screens.find((s) => s.id === parent.name).more = c.name;
  screens.find((s) => s.id === c.name).less = parent.name;
}

// every screen should be reachable from the start
const start = "now";
const seen = new Set([start]);
const queue = [start];
while (queue.length) {
  const id = queue.shift();
  const s = screens.find((x) => x.id === id);
  if (!s) continue;
  for (const next of [...s.hot.map((h) => h.to), s.more, s.less]) {
    if (next && !seen.has(next)) { seen.add(next); queue.push(next); }
  }
}
for (const s of screens) if (!seen.has(s.id)) warnings.push(`"${s.id}" cannot be reached by tapping from the start, so it is left out.`);
const reachable = screens.filter((s) => seen.has(s.id));

if (!reachable.some((s) => s.id === start)) {
  console.error('The first screen ("now") was not captured, so there is no demo to make.');
  process.exit(1);
}
writeFileSync(outPath, JSON.stringify({ start, screens: reachable }, null, 2) + "\n");
report();
console.log(`Wrote website/src/content/demo.screens.generated.json (${reachable.length} screens, ${reachable.reduce((n, s) => n + s.hot.length, 0)} tappable areas).`);

function report() {
  for (const w of warnings) console.warn("Note: " + w);
  if (problems.length) {
    for (const p of problems) console.error("Problem: " + p);
    process.exit(1);
  }
}
