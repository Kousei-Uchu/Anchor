// Checks that the About screen's words in the app and on the website match.
// Run it from anywhere:  node scripts/check-about-content.mjs
// It reads the double-quoted strings in AboutContent (Swift) and in about.ts,
// in order, and compares them. Strings that are code (such as the "Version"
// parts and the mail fields) sit outside the compared region on purpose.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const swiftPath = join(root, "iOS/Anchor/Anchor/Views/Settings/SettingsView.swift");
const tsPath = join(root, "website/src/content/about.ts");

function literals(text) {
  const found = [];
  const re = /"((?:[^"\\\n]|\\.)*)"/g;
  let m;
  while ((m = re.exec(text)) !== null) found.push(m[1]);
  return found;
}

const swift = readFileSync(swiftPath, "utf8");
const start = swift.indexOf("enum AboutContent {");
const end = swift.indexOf("/// For example \"Version", start);
if (start < 0 || end < 0) {
  console.error("Could not find the AboutContent block in SettingsView.swift.");
  process.exit(2);
}
const fromSwift = literals(swift.slice(start, end)).filter((s) => s.length > 0);

const ts = readFileSync(tsPath, "utf8")
  .split("\n")
  .filter((line) => !line.trim().startsWith("//"))
  .join("\n");
// The title and body keys are not strings, so every literal here is content.
const fromTs = literals(ts);

// Swift's AboutNote(title:, body:) holds the same words as the TypeScript objects.
const same =
  fromSwift.length === fromTs.length && fromSwift.every((s, i) => s === fromTs[i]);

if (!same) {
  console.error("The About copy in the app and in about.ts has drifted apart.");
  const n = Math.max(fromSwift.length, fromTs.length);
  for (let i = 0; i < n; i++) {
    if (fromSwift[i] !== fromTs[i]) {
      console.error(`First difference at string ${i + 1}:`);
      console.error(`  app:     ${JSON.stringify(fromSwift[i])}`);
      console.error(`  website: ${JSON.stringify(fromTs[i])}`);
      break;
    }
  }
  process.exit(1);
}
console.log(`About copy matches (${fromSwift.length} strings).`);
