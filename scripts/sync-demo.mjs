// Makes the website demo's made-up content from the app's own demo content, so the two cannot
// drift apart.
//
//   node scripts/sync-demo.mjs          writes website/src/content/demo.generated.json
//   node scripts/sync-demo.mjs --check  fails if that file is out of date
//
// It reads the Swift source (no Xcode needed):
//   AnchorApp.swift                    the demo store: grounding tools, de-escalation scripts,
//                                      affirmations, the first task, the newest journal entry
//   Views/Now/CheckInSliderView.swift  the check-in questions (the first three) and the five slider names
//   Support/MascotEngine.swift         the mascot's two opening lines
// The look of the screens is not made here. It stays hand-built in DemoApp.tsx.

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const app = join(root, "iOS/Anchor/Anchor");
const outPath = join(root, "website/src/content/demo.generated.json");

function fail(message) {
  console.error(message);
  process.exit(1);
}

function decode(raw) {
  if (raw.includes("\\(")) fail("A demo string uses interpolation, which this script does not read: " + raw.slice(0, 60));
  return raw.replace(/\\(u\{[0-9a-fA-F]+\}|.)/g, (_, c) => {
    if (c[0] === "u") return String.fromCodePoint(parseInt(c.slice(2, -1), 16));
    if (c === "n") return "\n";
    if (c === "t") return "\t";
    return c;
  });
}

const read = (rel) => readFileSync(join(app, rel), "utf8");
const S = String.raw`"((?:[^"\\\n]|\\.)*)"`;

// The demo store is the body of DemoMode.makeContainer, which ends where the next top-level type starts.
const appSource = read("AnchorApp.swift");
const start = appSource.indexOf("static func makeContainer() -> ModelContainer?");
if (start < 0) fail("Could not find DemoMode.makeContainer in AnchorApp.swift.");
const demo = appSource.slice(start);

function all(text, pattern, label, min) {
  const found = [...text.matchAll(new RegExp(pattern, "g"))].map((m) => m.slice(1).map(decode));
  if (found.length < min) fail(`Found ${found.length} ${label}, expected at least ${min}. Has the demo store changed shape?`);
  return found;
}

const tools = all(demo, String.raw`GroundingTool\(title: ${S},\s*kind: [.\w]+,\s*steps: ${S}`, "grounding tools", 1)
  .map(([title, steps]) => ({ title, steps: steps.split("\n") }));
const scripts = all(demo, String.raw`DeEscalationScript\(text: ${S}`, "de-escalation scripts", 1).map((m) => m[0]);
const affirmations = all(demo, String.raw`Affirmation\(text: ${S}`, "affirmations", 1).map((m) => m[0]);

const firstTask = all(demo, String.raw`TaskItem\(title: ${S}`, "tasks", 1)[0][0];
const journal = all(demo, String.raw`JournalEntry\(createdAt: ago\(0, hour: 3\), text: ${S}`, "newest journal entries", 1)[0][0];

const slider = read("Views/Now/CheckInSliderView.swift");
const questions = all(slider, String.raw`CheckInPrompt\(\s*text: ${S}`, "check-in questions", 3).slice(0, 3).map((m) => m[0]);
const sliders = all(slider, String.raw`sliderCard\(${S}`, "slider names", 5).slice(0, 5).map((m) => m[0]);

const mascot = read("Support/MascotEngine.swift");
const open = (mood) => all(mascot, String.raw`\(\.appOpen, \.${mood}, ${S}\)`, `${mood} opening lines`, 1)[0][0];

const content = {
  tools,
  scripts,
  affirmations,
  checkInQuestions: questions,
  sliders,
  mascot: { hello: open("neutral"), quiet: open("quietDay") },
  firstTask,
  firstJournalEntry: journal,
};
const text = JSON.stringify(content, null, 2) + "\n";

if (process.argv.includes("--check")) {
  if (!existsSync(outPath) || readFileSync(outPath, "utf8") !== text) {
    fail("website/src/content/demo.generated.json is out of date. Run: node scripts/sync-demo.mjs");
  }
  console.log(`The website demo content matches the app (${tools.length} tools, ${scripts.length} scripts, ${affirmations.length} affirmations).`);
} else {
  writeFileSync(outPath, text);
  console.log(`Wrote website/src/content/demo.generated.json (${tools.length} tools, ${scripts.length} scripts, ${affirmations.length} affirmations).`);
}
