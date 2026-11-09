// Checks that every AI feature goes through the one switch (E5 in docs/OPTIONAL_FEATURES.md).
// Run it from anywhere:  node scripts/check-ai-gate.mjs
// 1. Any Swift file that talks to a model or an AI provider must mention AIGate. The signs looked for
//    are listed below; add a new one here when a new provider is built.
// 2. Nothing may switch the setting on by default.
// 3. The gate itself must stay off to begin with and must stay off in the demo store.
// 4. Nothing but AIAsk may call a provider's generate(instruction:text:). AIAsk checks the gate, then asks the
//    person (unless they said not to be asked), and only then sends.
// 5. The consent sheet shows the whole text: its file must not cut text with a line limit, a prefix or a
//    truncation mode.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const swiftRoot = join(root, "iOS");

// Signs that a file reaches a model or a provider.
const providerSigns = [
  /import\s+FoundationModels/,
  /\bLanguageModelSession\b/,
  /\bSystemLanguageModel\b/,
  /\bOllama\w*/,
  /\bAIProvider\w*/,
  /\bAIProviding\b/,
  /api\.anthropic\.com/,
  /api\.openai\.com/,
  /:11434\b/,
];

function swiftFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name.startsWith(".") || name === "build" || name === "DerivedData") continue;
    const path = join(dir, name);
    const info = statSync(path);
    if (info.isDirectory()) out.push(...swiftFiles(path));
    else if (name.endsWith(".swift")) out.push(path);
  }
  return out;
}

const problems = [];
let providerFiles = 0;
const generateCall = /\.generate\(\s*instruction:/;
const files = swiftFiles(swiftRoot);

for (const file of files) {
  const rel = relative(root, file);
  if (rel.endsWith("Support/AIGate.swift")) continue;
  const text = readFileSync(file, "utf8");

  if (providerSigns.some((sign) => sign.test(text))) {
    providerFiles += 1;
    if (!/AIGate\.(isEnabled|require)/.test(text)) {
      problems.push(`${rel}: talks to a model or provider but never checks AIGate.isEnabled`);
    }
  }

  // Only AIAsk may send text to a provider.
  if (generateCall.test(text) && !rel.endsWith("Support/AIAsk.swift")) {
    problems.push(`${rel}: calls a provider's generate directly; go through AIAsk.run so the person is asked first`);
  }

  // Nothing may default the switch to on.
  if (/@AppStorage\(\s*AIGate\.storageKey\s*\)[^\n]*=\s*true/.test(text)) {
    problems.push(`${rel}: sets the AI switch to on by default`);
  }
  if (/register\(defaults:[^)]*aiToolsEnabled[^)]*true/.test(text)) {
    problems.push(`${rel}: registers the AI switch as on by default`);
  }
}

const gatePath = join(swiftRoot, "Anchor/Anchor/Support/AIGate.swift");
let gate = "";
try {
  gate = readFileSync(gatePath, "utf8");
} catch {
  problems.push("Support/AIGate.swift is missing");
}
if (gate) {
  if (!/DemoMode\.isOn/.test(gate)) problems.push("AIGate.isEnabled no longer stays off in the demo store and showcase mode");
  if (!/UserDefaults\.standard\.bool\(forKey: storageKey\)/.test(gate)) problems.push("AIGate.isChosen no longer reads an off-by-default boolean");
}

// AIAsk must check the gate, then ask, and only then send.
let ask = "";
try {
  ask = readFileSync(join(swiftRoot, "Anchor/Anchor/Support/AIAsk.swift"), "utf8");
} catch {
  problems.push("Support/AIAsk.swift is missing");
}
if (ask) {
  const send = ask.search(generateCall);
  const gateAt = ask.indexOf("guard gate()");
  const skipAt = ask.indexOf("consent.skipsAsking(");
  const askAt = ask.indexOf("await askPerson(request)");
  if (send < 0) problems.push("AIAsk.swift no longer sends to a provider through generate(instruction:text:)");
  else if (gateAt < 0 || gateAt > send) problems.push("AIAsk.swift sends before it checks the gate");
  else if (skipAt < 0 || askAt < 0 || skipAt > askAt || askAt > send) problems.push("AIAsk.swift sends before it has asked the person, or no longer checks Don't ask again before asking");
  if (!/AIGate\.isEnabled/.test(ask)) problems.push("AIAsk.swift no longer defaults to AIGate.isEnabled");
}

// The consent sheet shows everything it is sending.
let sheet = "";
try {
  sheet = readFileSync(join(swiftRoot, "Anchor/Anchor/Views/Settings/AIConsentSheet.swift"), "utf8");
} catch {
  problems.push("Views/Settings/AIConsentSheet.swift is missing");
}
if (sheet) {
  const code = sheet.split("\n").filter((line) => !line.trim().startsWith("//")).join("\n");
  if (/\.lineLimit\(|\.truncationMode\(|\.prefix\(|\.minimumScaleFactor\(/.test(code)) problems.push("AIConsentSheet.swift cuts or shrinks text; the sheet must show everything that is sent");
  if (!/request\.text/.test(code)) problems.push("AIConsentSheet.swift no longer shows request.text");
}

if (problems.length) {
  console.error("The AI gate check failed:");
  for (const p of problems) console.error("  - " + p);
  process.exit(1);
}
console.log(`The AI gate check passed. ${files.length} Swift files read, ${providerFiles} reach a provider and all of them check the gate.`);
