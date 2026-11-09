// Checks that every AI feature goes through the one switch (E5 in docs/OPTIONAL_FEATURES.md).
// Run it from anywhere:  node scripts/check-ai-gate.mjs
// 1. Any Swift file that talks to a model or an AI provider must mention AIGate. The signs looked for
//    are listed below; add a new one here when a new provider is built.
// 2. Nothing may switch the setting on by default.
// 3. The gate itself must stay off to begin with and must stay off in the demo store.

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

if (problems.length) {
  console.error("The AI gate check failed:");
  for (const p of problems) console.error("  - " + p);
  process.exit(1);
}
console.log(`The AI gate check passed. ${files.length} Swift files read, ${providerFiles} reach a provider and all of them check the gate.`);
