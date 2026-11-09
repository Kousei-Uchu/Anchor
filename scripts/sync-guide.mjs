// Makes the website's Features page content from the app's guide registry, so
// the two cannot drift apart.
//
//   node scripts/sync-guide.mjs          writes website/src/content/guide.generated.json
//   node scripts/sync-guide.mjs --check  fails if that file is out of date
//
// It reads iOS/Anchor/Anchor/Support/HelpContent.swift: the five tab overviews
// (HelpTopic) and every GuideEntry in Guide.screenEntries. Anything inside
// #if DEBUG is left out, because those screens are test builds only. It also
// fails if the text mentions AI tools, because the website says nothing about
// them beyond one plain line written by hand.

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const swiftPath = join(root, "iOS/Anchor/Anchor/Support/HelpContent.swift");
const outPath = join(root, "website/src/content/guide.generated.json");

function fail(message) {
  console.error(message);
  process.exit(1);
}

function decode(raw) {
  if (raw.includes("\\(")) fail("A guide string uses interpolation, which this script does not read: " + raw.slice(0, 60));
  return raw.replace(/\\(u\{[0-9a-fA-F]+\}|.)/g, (_, c) => {
    if (c[0] === "u") return String.fromCodePoint(parseInt(c.slice(2, -1), 16));
    if (c === "n") return "\n";
    if (c === "t") return "\t";
    return c;
  });
}

function withoutDebug(text) {
  return text.replace(/^[ \t]*#if DEBUG[\s\S]*?^[ \t]*#endif[^\n]*\n/gm, "");
}

const source = withoutDebug(readFileSync(swiftPath, "utf8"));

const STRING = /"((?:[^"\\\n]|\\.)*)"/y;

function readBalanced(text, openIndex) {
  let depth = 0;
  let i = openIndex;
  while (i < text.length) {
    const ch = text[i];
    if (ch === '"') {
      STRING.lastIndex = i;
      const m = STRING.exec(text);
      if (!m) fail("Unterminated string near: " + text.slice(i, i + 40));
      i += m[0].length;
      continue;
    }
    if (ch === "/" && text[i + 1] === "/") {
      while (i < text.length && text[i] !== "\n") i++;
      continue;
    }
    if (ch === "(" || ch === "[") depth++;
    if (ch === ")" || ch === "]") {
      depth--;
      if (depth === 0) return text.slice(openIndex + 1, i);
    }
    i++;
  }
  fail("Unbalanced brackets in HelpContent.swift");
}

function parseArgs(body) {
  const args = {};
  let i = 0;
  const skip = () => {
    while (i < body.length) {
      if (/\s|,/.test(body[i])) i++;
      else if (body[i] === "/" && body[i + 1] === "/") while (i < body.length && body[i] !== "\n") i++;
      else break;
    }
  };
  while (true) {
    skip();
    if (i >= body.length) break;
    const label = /^([A-Za-z]+)\s*:\s*/.exec(body.slice(i));
    if (!label) fail("Could not read a GuideEntry argument near: " + body.slice(i, i + 50));
    i += label[0].length;
    let value;
    if (body[i] === '"') {
      STRING.lastIndex = i;
      const m = STRING.exec(body);
      value = decode(m[1]);
      i += m[0].length;
    } else if (body[i] === "[") {
      const inner = readBalanced(body, i);
      value = [];
      const re = /"((?:[^"\\\n]|\\.)*)"/g;
      let m;
      while ((m = re.exec(inner)) !== null) value.push(decode(m[1]));
      i += inner.length + 2;
    } else {
      const m = /^(\.?[A-Za-z]+)/.exec(body.slice(i));
      if (!m) fail("Could not read a value for " + label[1]);
      value = m[1] === "nil" ? null : m[1] === "false" ? false : m[1] === "true" ? true : m[1].replace(/^\./, "");
      i += m[0].length;
    }
    args[label[1]] = value;
  }
  return args;
}

const markStart = source.indexOf("// MARK: - Guide entries: Plan");
if (markStart < 0) fail("Could not find the guide entries in HelpContent.swift.");

const arrays = {};
const arrayRe = /static let (\w+): \[GuideEntry\] = \[/g;
arrayRe.lastIndex = markStart;
let am;
while ((am = arrayRe.exec(source)) !== null) {
  const open = am.index + am[0].length - 1;
  const inner = readBalanced(source, open);
  const entries = [];
  const entryRe = /GuideEntry\(/g;
  let em;
  while ((em = entryRe.exec(inner)) !== null) {
    const body = readBalanced(inner, em.index + "GuideEntry".length);
    const a = parseArgs(body);
    for (const key of ["id", "title", "whatItIs", "howToUse", "tips"]) {
      if (a[key] === undefined) fail(`A guide entry is missing ${key}: ${JSON.stringify(a.id)}`);
    }
    entries.push({
      id: a.id,
      tab: a.tab ?? null,
      title: a.title,
      whatItIs: a.whatItIs,
      howToUse: a.howToUse.split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean),
      tips: a.tips,
      inTour: a.inTour === false ? false : true,
    });
  }
  arrays[am[1]] = entries;
  arrayRe.lastIndex = open + inner.length + 2;
}

const screenLine = /static let screenEntries: \[GuideEntry\] = ([^\n]+)/.exec(source);
if (!screenLine) fail("Could not find Guide.screenEntries.");
const order = screenLine[1].split("+").map((s) => s.trim());

function resolve(name) {
  if (name === "settingsEntries") return ["settingsScreenEntries", "settingsTestBuildEntries"].flatMap(resolve);
  if (name === "settingsTestBuildEntries") return [];
  if (!arrays[name]) fail("Guide.screenEntries names " + name + ", which was not found.");
  return arrays[name];
}
const entries = order.flatMap(resolve);
if (entries.length === 0) fail("No guide entries were found.");
const ids = new Set(entries.map((e) => e.id));
if (ids.size !== entries.length) fail("Two guide entries share an id.");

function topicBlock(name) {
  const start = source.indexOf(`var ${name}: String {`);
  if (start < 0) fail("Could not find HelpTopic." + name);
  const open = source.indexOf("{", start);
  return readBalanced(source, open);
}
function topicStrings(name) {
  const block = topicBlock(name);
  const out = {};
  const re = /case \.(\w+):\s*return\s*"((?:[^"\\\n]|\\.)*)"/g;
  let m;
  while ((m = re.exec(block)) !== null) out[m[1]] = decode(m[2]);
  return out;
}
const names = {};
{
  const re = /case \.(\w+): return "(\w+)"/g;
  let m;
  const block = topicBlock("tabName");
  while ((m = re.exec(block)) !== null) names[m[1]] = m[2];
}
const summaries = topicStrings("summary");
const explanations = topicStrings("explanation");
const tabOrder = Object.keys(names);
if (tabOrder.length !== 5) fail("Expected five tabs in HelpTopic, found " + tabOrder.length);

const tabs = tabOrder.map((id) => {
  if (!summaries[id] || !explanations[id]) fail("HelpTopic is missing text for " + id);
  return {
    id,
    name: names[id],
    summary: summaries[id],
    paragraphs: explanations[id].split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean),
  };
});

const result = { tabs, entries };
const json = JSON.stringify(result, null, 2) + "\n";

if (/\bAI\b|Ollama|Apple Intelligence/.test(json)) {
  fail("The guide text mentions AI tools. The website says nothing about them beyond one plain hand-written line, so reword the guide entry.");
}
if (/\u2014|\u2013/.test(json)) {
  fail("The guide text has a long dash. Anchor's words use none.");
}

if (process.argv.includes("--check")) {
  if (!existsSync(outPath) || readFileSync(outPath, "utf8") !== json) {
    fail("website/src/content/guide.generated.json is out of date. Run: node scripts/sync-guide.mjs");
  }
  console.log(`The website guide content matches the app (${tabs.length} tabs, ${entries.length} entries).`);
} else {
  writeFileSync(outPath, json);
  console.log(`Wrote ${outPath} (${tabs.length} tabs, ${entries.length} entries).`);
}
