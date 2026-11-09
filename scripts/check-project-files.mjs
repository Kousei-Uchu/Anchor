// Checks that every Swift file in the app and the widget folders is listed in the Xcode project, and that the
// files the widget extension builds are the ones it needs. A file that is on disk but not in
// project.pbxproj is never built, so the first Xcode build stops with "cannot find ... in scope".
// Run it from anywhere:  node scripts/check-project-files.mjs

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, basename } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const project = join(root, "iOS/Anchor");
const pbx = readFileSync(join(project, "Anchor.xcodeproj/project.pbxproj"), "utf8");

// Files that sit in the folders on purpose without being built. Add a line with the reason; do not add a file
// here only to make this check pass.
const notBuilt = {
  "MascotFace.swift": "an older drawn face that nothing uses; it is not in the project",
};

function swiftFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name.startsWith(".") || name === "Preview Content") continue;
    const path = join(dir, name);
    if (statSync(path).isDirectory()) out.push(...swiftFiles(path));
    else if (name.endsWith(".swift")) out.push(name);
  }
  return out;
}

const problems = [];
const names = [...swiftFiles(join(project, "Anchor")), ...swiftFiles(join(project, "AnchorWidget"))];
for (const name of names) {
  if (notBuilt[name]) continue;
  const asSource = new RegExp(`${name.replace(".", "\\.")} in Sources`);
  if (!asSource.test(pbx)) problems.push(`${name} is on disk but is not built by any target in project.pbxproj.`);
}

// The widget extension builds the model files, so anything they use must be built there too.
const widgetPhase = pbx.match(/\/\* Sources \*\/ = \{\s*isa = PBXSourcesBuildPhase;[^}]*?files = \(([^)]*)\)/g) || [];
const widgetBlock = widgetPhase.find((block) => block.includes("AnchorWidget.swift in Sources")) || "";
for (const name of ["AnchorModels.swift", "RecoveryModels.swift", "LockedFields.swift"]) {
  if (!widgetBlock.includes(`${name} in Sources`)) problems.push(`${name} is not built by the widget extension.`);
}
for (const name of ["AppLock.swift", "SafetyCopy.swift", "AIGate.swift", "AIProviders.swift", "AIAsk.swift", "AIConsentSheet.swift", "AIBraindumpSheet.swift", "LockMyData.swift", "LockMyDataView.swift", "JournalAssist.swift", "Dictation.swift", "DictationAudio.swift", "JournalVoice.swift", "SpeakerLabels.swift"]) {
  if (widgetBlock.includes(`${name} in Sources`)) problems.push(`${name} must not be built by the widget extension (it holds key or app-only code).`);
}

if (problems.length) {
  console.log(problems.join("\n"));
  process.exit(1);
}
console.log(`The project check passed. ${names.length} Swift files read, ${names.length - Object.keys(notBuilt).length} built.`);
