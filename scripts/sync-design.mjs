// Reads the app's design system (Anchor.Theme and the shared components in ContentView.swift)
// and writes what the website needs to look the same:
//   website/src/content/design.generated.json   theme tokens, plus a fingerprint of each Swift component the website mirrors
//   website/src/styles/design.generated.css     the tokens as CSS variables (light, and dark under [data-anchor-scheme="dark"])
//
// Run it with no arguments to write the files, or with --check to fail when they are out of date.
// If a mirrored Swift component changes, --check names it: update website/src/components/ios/AnchorUI.tsx to match,
// then run this script once to accept the new fingerprint.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const SWIFT = join(root, "iOS/Anchor/Anchor/ContentView.swift");
const JSON_OUT = join(root, "website/src/content/design.generated.json");
const CSS_OUT = join(root, "website/src/styles/design.generated.css");
const MIRRORED = ["Card", "SectionHeader", "MenuRow", "TileButtonLabel", "TileRow", "PrimaryButtonStyle", "SecondaryButtonStyle", "EmptyState"];
// Views outside ContentView.swift that the website also copies: [file under iOS/Anchor/Anchor, struct name].
const MIRRORED_VIEWS = [
  ["Views/Plan/CrisisNumbersView.swift", "CrisisNumbersView"],
  ["Views/Now/MascotPresenceView.swift", "MascotPresenceView"],
  ["Views/Now/MascotPresenceView.swift", "MascotCharacterView"],
  ["Views/Now/MascotPresenceView.swift", "SpeechBubble"],
  ["Views/Now/SafetyPlanShortcutView.swift", "SafetyPlanShortcutView"],
  ["Views/Now/GroundingToolsView.swift", "GroundingToolRow"],
  ["Views/Now/GroundingToolsView.swift", "GroundingToolsView"],
  ["Views/Now/QuickContactsView.swift", "QuickContactsView"],
  ["Views/Recovery/RecoveryHomeView.swift", "RecoveryNowCard"],
  ["Views/Now/NextAppointmentCardView.swift", "NextAppointmentCardView"],
  ["Views/Now/DecisionPresetsQuickView.swift", "DecisionPresetsQuickView"],
  ["Views/Now/NextHourChecklistView.swift", "TasksNowCard"],
  ["Views/Now/DeEscalationAndQuietRoomView.swift", "DeEscalationCardView"],
  ["Views/Now/AffirmationsView.swift", "AffirmationsCardView"],
  ["Views/Widgets/TabWidgets.swift", "Widget"],
  ["Views/Widgets/TabWidgets.swift", "WidgetBig"],
  ["Views/Widgets/TabWidgets.swift", "WidgetCaption"],
  ["Views/Widgets/TabWidgets.swift", "WidgetPair"],
  ["Views/Widgets/WidgetCustomisation.swift", "WidgetStack"],
  ["Views/Widgets/WidgetCustomisation.swift", "MoreTile"],
  ["Views/Widgets/TabWidgets.swift", "SafetyPlanWidget"],
  ["Views/Widgets/TabWidgets.swift", "TriggerWindowsWidget"],
  ["Views/Widgets/TabWidgets.swift", "AppointmentsWidget"],
  ["Views/Widgets/TabWidgets.swift", "ContactsWidget"],
  ["Views/Widgets/TabWidgets.swift", "DeEscalationWidget"],
  ["Views/Widgets/TabWidgets.swift", "GroundingWidget"],
  ["Views/Widgets/TabWidgets.swift", "AffirmationsWidget"],
  ["Views/Widgets/TabWidgets.swift", "RecoveryWidget"],
  ["Views/Widgets/TabWidgets.swift", "MotivationsWidget"],
  ["Views/Widgets/TabWidgets.swift", "TasksWidget"],
];

const src = readFileSync(SWIFT, "utf8");

function matchBrace(text, open) {
  let depth = 0;
  for (let i = open; i < text.length; i++) {
    if (text[i] === "{") depth++;
    else if (text[i] === "}" && --depth === 0) return i;
  }
  throw new Error("Unbalanced braces in ContentView.swift");
}

function block(text, header) {
  const at = text.search(header);
  if (at < 0) throw new Error(`Could not find ${header} in ContentView.swift`);
  const open = text.indexOf("{", at);
  return { at, open, close: matchBrace(text, open), body: text.slice(open + 1, matchBrace(text, open)) };
}

const COLOR = String.raw`Color\(red:\s*([\d.]+),\s*green:\s*([\d.]+),\s*blue:\s*([\d.]+)\)(?:\.opacity\(([\d.]+)\))?|Color\.white|Color\.black`;
function css(m) {
  if (m[0] === "Color.white") return "rgb(255 255 255)";
  if (m[0] === "Color.black") return "rgb(0 0 0)";
  const c = [m[1], m[2], m[3]].map((v) => Math.round(parseFloat(v) * 255));
  return m[4] ? `rgb(${c.join(" ")} / ${parseFloat(m[4])})` : `rgb(${c.join(" ")})`;
}
const kebab = (s) => s.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase());

const theme = block(src, /enum Theme\s*\{/).body;
const tokens = { fixed: {}, scheme: {}, metrics: {} };

for (const m of theme.matchAll(new RegExp(String.raw`static let (\w+)\s*=\s*(${COLOR})`, "g"))) {
  tokens.fixed[m[1]] = css(new RegExp(COLOR).exec(m[2]));
}
for (const m of theme.matchAll(/static let (\w+):\s*CGFloat\s*=\s*([\d.]+)/g)) tokens.metrics[m[1]] = parseFloat(m[2]);
for (const m of theme.matchAll(/static func (\w+)\(_ scheme: ColorScheme\) -> Color\s*\{/g)) {
  const open = m.index + m[0].length - 1;
  const body = theme.slice(open + 1, matchBrace(theme, open));
  const t = new RegExp(String.raw`scheme == \.dark\s*\?\s*(${COLOR})\s*:\s*(${COLOR})`).exec(body);
  if (!t) throw new Error(`Theme.${m[1]} is not in the form "scheme == .dark ? A : B", so this script cannot read it.`);
  const parts = [...body.matchAll(new RegExp(COLOR, "g"))];
  tokens.scheme[m[1]] = { dark: css(parts[0]), light: css(parts[1]) };
}
for (const need of ["accent", "sage"]) if (!tokens.fixed[need]) throw new Error(`Theme.${need} was not found.`);
for (const need of ["cornerRadius", "spacing"]) if (tokens.metrics[need] === undefined) throw new Error(`Theme.${need} was not found.`);
for (const need of ["background", "cardBackground"]) if (!tokens.scheme[need]) throw new Error(`Theme.${need}(scheme) was not found.`);

const fingerprints = {};
const anchorEnum = block(src, /enum Anchor\s*\{/).body;
for (const name of MIRRORED) {
  const b = block(anchorEnum, new RegExp(String.raw`struct ${name}\b`));
  const flat = b.body.replace(/\/\/.*$/gm, "").replace(/\s+/g, " ").trim();
  fingerprints[name] = createHash("sha1").update(flat).digest("hex").slice(0, 10);
}

for (const [file, name] of MIRRORED_VIEWS) {
  const text = readFileSync(join(root, "iOS/Anchor/Anchor", file), "utf8");
  const b = block(text, new RegExp(String.raw`struct ${name}\b`));
  const flat = b.body.replace(/\/\/.*$/gm, "").replace(/\s+/g, " ").trim();
  fingerprints[name] = createHash("sha1").update(flat).digest("hex").slice(0, 10);
}

const json = JSON.stringify({ theme: tokens, mirrored: fingerprints }, null, 2) + "\n";

const lines = ["/* Generated by scripts/sync-design.mjs from Anchor.Theme in ContentView.swift. Do not edit. */", ":root {"];
for (const [k, v] of Object.entries(tokens.fixed)) lines.push(`  --anchor-${kebab(k)}: ${v};`);
for (const [k, v] of Object.entries(tokens.scheme)) lines.push(`  --anchor-${kebab(k)}: ${v.light};`);
for (const [k, v] of Object.entries(tokens.metrics)) lines.push(`  --anchor-${kebab(k)}: ${v}px;`);
lines.push("}", '[data-anchor-scheme="dark"] {');
for (const [k, v] of Object.entries(tokens.scheme)) lines.push(`  --anchor-${kebab(k)}: ${v.dark};`);
lines.push("}", "");
const cssText = lines.join("\n");

if (process.argv.includes("--check")) {
  const old = existsSync(JSON_OUT) ? JSON.parse(readFileSync(JSON_OUT, "utf8")) : { mirrored: {} };
  let bad = false;
  for (const name of Object.keys(fingerprints)) {
    if (old.mirrored?.[name] !== fingerprints[name]) {
      console.error(`Anchor.${name} changed in ContentView.swift. Update website/src/components/ios/AnchorUI.tsx to match, then run: node scripts/sync-design.mjs`);
      bad = true;
    }
  }
  if (!existsSync(JSON_OUT) || readFileSync(JSON_OUT, "utf8") !== json) { if (!bad) console.error("design.generated.json is out of date. Run: node scripts/sync-design.mjs"); bad = true; }
  if (!existsSync(CSS_OUT) || readFileSync(CSS_OUT, "utf8") !== cssText) { if (!bad) console.error("design.generated.css is out of date. Run: node scripts/sync-design.mjs"); bad = true; }
  if (bad) process.exit(1);
  console.log("Design tokens and the mirrored components are up to date.");
} else {
  writeFileSync(JSON_OUT, json);
  writeFileSync(CSS_OUT, cssText);
  console.log(`Wrote ${Object.keys(tokens.fixed).length + Object.keys(tokens.scheme).length} colours, ${Object.keys(tokens.metrics).length} metrics and ${Object.keys(fingerprints).length} component fingerprints.`);
}
