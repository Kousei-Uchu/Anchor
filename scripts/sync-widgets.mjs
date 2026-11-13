// Reads the widget table the Plan, Bridge and Thread tabs are built from and writes it as JSON:
//   website/src/content/widgets.generated.json
// Sources: WidgetID (title, icon, tint, which widgets pair two to a row) in Views/Widgets/TabWidgets.swift,
// and WidgetTab (default order and the widgets hidden by default) in Views/Widgets/WidgetCustomisation.swift.
// Run with no arguments to write the file, or with --check to fail when it is out of date.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dir = join(root, "iOS/Anchor/Anchor/Views/Widgets");
const OUT = join(root, "website/src/content/widgets.generated.json");
const tab = readFileSync(join(dir, "TabWidgets.swift"), "utf8");
const cust = readFileSync(join(dir, "WidgetCustomisation.swift"), "utf8");

function matchBrace(text, open) {
  let depth = 0;
  for (let i = open; i < text.length; i++) { if (text[i] === "{") depth++; else if (text[i] === "}" && --depth === 0) return i; }
  throw new Error("Unbalanced braces");
}
function block(text, re, label) {
  const m = re.exec(text); if (!m) throw new Error(`Could not find ${label}`);
  const open = text.indexOf("{", m.index + m[0].length - 1);
  return text.slice(open + 1, matchBrace(text, open));
}
const strip = (t) => t.replace(/\/\/.*$/gm, "");
const caseIds = (s) => [...s.matchAll(/\.(\w+)/g)].map((m) => m[1]);

const widgetEnum = strip(block(tab, /enum WidgetID\b[^{]*\{/, "enum WidgetID"));
const ids = [...widgetEnum.matchAll(/^\s*case ([\w, ]+)$/gm)].flatMap((m) => m[1].split(",").map((x) => x.trim()).filter(Boolean));
if (!ids.length) throw new Error("Could not read the WidgetID cases");

const ext = strip(block(tab, /extension WidgetID\s*\{/, "extension WidgetID"));
const table = (name) => {
  const b = block(ext, new RegExp(`var ${name}: String\\s*\\{`), `WidgetID.${name}`);
  const out = {};
  for (const m of b.matchAll(/case \.(\w+): return "([^"]*)"/g)) out[m[1]] = m[2];
  return out;
};
const titles = table("title"), icons = table("icon");

const tintBlock = block(ext, /var tint: Color\s*\{/, "WidgetID.tint");
const sageIds = new Set(caseIds(/case ([^:]+):\s*return Anchor\.Theme\.sage/.exec(tintBlock.replace(/\n/g, " "))?.[1] ?? ""));
const halfBlock = block(ext, /var isHalf: Bool\s*\{/, "WidgetID.isHalf");
const maxTitle = Number(/title\.count <= (\d+)/.exec(halfBlock)?.[1] ?? 16);
const halfIds = new Set(caseIds(/case ([^:]+):\s*return true/.exec(halfBlock.replace(/\n/g, " "))?.[1] ?? ""));

const widgets = {};
for (const id of ids) {
  if (!titles[id] || !icons[id]) throw new Error(`WidgetID.${id} has no title or icon`);
  widgets[id] = { title: titles[id], icon: icons[id], tint: sageIds.has(id) ? "sage" : "accent", half: halfIds.has(id) && titles[id].length <= maxTitle };
}

const tabEnum = strip(block(cust, /enum WidgetTab\b[^{]*\{/, "enum WidgetTab"));
const orderBlock = block(tabEnum, /var defaultOrder: \[WidgetID\]\s*\{/, "defaultOrder").replace(/#if PERSONAL_BUILD[\s\S]*?#endif/g, "");
const hiddenBlock = block(tabEnum, /var defaultHidden: \[WidgetID\]\s*\{/, "defaultHidden");
const tabs = {};
for (const name of ["plan", "bridge", "thread"]) {
  const o = new RegExp(`case \\.${name}:\\s*(?:return|var ids: \\[WidgetID\\] =)\\s*\\[([^\\]]*)\\]`).exec(orderBlock);
  if (!o) throw new Error(`Could not read the default order for ${name}`);
  const h = new RegExp(`case \\.${name}: return \\[([^\\]]*)\\]`).exec(hiddenBlock);
  tabs[name] = { order: caseIds(o[1]), hidden: h ? caseIds(h[1]) : [] };
}
for (const t of Object.values(tabs)) for (const id of [...t.order, ...t.hidden]) if (!widgets[id]) throw new Error(`Unknown widget ${id}`);

const json = JSON.stringify({ widgets, tabs }, null, 1) + "\n";
if (process.argv.includes("--check")) {
  if (!existsSync(OUT) || readFileSync(OUT, "utf8") !== json) { console.error("widgets.generated.json is out of date. Run: node scripts/sync-widgets.mjs"); process.exit(1); }
  console.log(`The website's widget table matches the app (${Object.keys(widgets).length} widgets).`);
} else {
  writeFileSync(OUT, json);
  console.log(`Wrote ${Object.keys(widgets).length} widgets and the default layout of ${Object.keys(tabs).join(", ")}.`);
}
