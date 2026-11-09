// Checks the rules of the one-page layout (patch 30r, D30, D32). It is a content check, not a build.
//   1. Nothing is cut to make a page fit: no truncating, no ellipsis, no prefix on the person's words.
//   2. The printed words carry no score, reading or advice, and no em dash, en dash or emoji.
//   3. On the Session prep sheet only what the person wrote is on to begin with.
//   4. Both screens reach the one-page code, and the lines on the Session prep sheet are built by the same
//      code as the cards (no copy that could drift).
//   5. The guide and the review walkthrough mention it.
// Run it from anywhere:  node scripts/check-one-page.mjs
// Pass --root <folder> to check a copy of the repo (used to try that the check fails).

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const argRoot = process.argv.includes("--root") ? process.argv[process.argv.indexOf("--root") + 1] : null;
const root = argRoot || join(dirname(fileURLToPath(import.meta.url)), "..");
const app = join(root, "iOS/Anchor/Anchor");
const read = (rel) => readFileSync(join(app, rel), "utf8");

const onePage = read("Views/Bridge/OnePageSummary.swift");
const prep = read("Views/Bridge/AppointmentPrepView.swift");
const exportView = read("Views/Bridge/BridgeExportView.swift");
const help = read("Support/HelpContent.swift");
const review = read("Support/ReviewWalkthrough.swift");

const problems = [];

// 1. Nothing is cut. The one place a prefix is allowed is the cleaned file name.
const codeLines = onePage.split("\n").filter((line) => !line.trim().startsWith("//"));
for (const line of codeLines) {
  if (/byTruncating|truncat|ellipsis|…|"\.\.\."/i.test(line)) problems.push(`Cuts text: ${line.trim()}`);
  if (/\.prefix\(|\.dropLast\(|\.dropFirst\(|\.suffix\(/.test(line) && !line.trim().startsWith("let short = String(cleaned.prefix(40))")) {
    problems.push(`Shortens text (only the file name may): ${line.trim()}`);
  }
}

// 2. Words. Every string literal in the file, and any dash or emoji anywhere in it.
const literals = [];
for (const line of codeLines) for (const m of line.matchAll(/"((?:[^"\\]|\\.)*)"/g)) literals.push(m[1]);
const banned = /\b(scores?|averages?|mean|trends?|trending|improv\w*|worse|worsen\w*|better|declin\w*|risks?|concern\w*|mood|you seem|doing well|doing badly|streaks?|progress|should|recommend\w*|suggest\w*)\b/i;
for (const text of literals) {
  if (banned.test(text)) problems.push(`A printed or shown word that reads like a score or advice: "${text}"`);
}
if (/[\u2013\u2014]/.test(onePage)) problems.push("OnePageSummary.swift has an en dash or em dash.");
if (/\p{Extended_Pictographic}/u.test(onePage)) problems.push("OnePageSummary.swift has an emoji.");

// 3. Defaults on the Session prep sheet.
const defaults = onePage.match(/@State private var on: Set<Part> = \[([^\]]*)\]/);
if (!defaults) problems.push("Cannot find the Session prep sheet's default switches.");
else {
  const on = defaults[1].split(",").map((s) => s.trim()).filter(Boolean).sort().join(",");
  if (on !== ".bring,.notes,.raise") {
    problems.push(`Only .notes, .raise and .bring may be on to begin with; found ${on}.`);
  }
}

// 4. Wiring and shared code.
if (!/OnePagePDF\.makePDF\(onePage\)/.test(exportView)) problems.push("Export for someone does not make the one-page PDF.");
if (!/OnePageSummary\.from\(document: document\)/.test(exportView)) problems.push("Export for someone does not lay out the same document.");
if (!/SessionOnePageSheet\(/.test(prep)) problems.push("Session prep does not open the one-page sheet.");
for (const name of ["eligibleEntries", "checkInTally", "countsText", "nightsWritten", "describingLines", "waitingItems"]) {
  if (!new RegExp(`static func ${name}\\(`).test(prep)) problems.push(`AppointmentPrepView.swift lost the shared helper ${name}.`);
  if (!new RegExp(`\\.${name}\\(`).test(onePage)) problems.push(`The one-page sheet does not use the shared helper ${name}.`);
  if (!new RegExp(`Self\\.${name}\\(`).test(prep)) problems.push(`The card on Session prep does not use the shared helper ${name}.`);
}

// 5. Guide and review.
if (!/one-page sheet/i.test(help)) problems.push("The guide does not mention the one-page sheet.");
if (!/\("30r"/.test(review)) problems.push("The review walkthrough has no stop for 30r.");

if (problems.length) {
  console.log(problems.join("\n"));
  process.exit(1);
}
console.log(`The one-page check passed. ${literals.length} strings read, 6 shared helpers in use by both the cards and the sheet.`);
