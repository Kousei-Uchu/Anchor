// Checks that finding who is speaking (VN4a, E2, D38, D63, D64, D73 in ANCHOR_PATCH_PLAN.md) keeps nothing about a voice
// and never goes online. Run it from anywhere:  node scripts/check-speaker-separation.mjs
// 1. FluidAudio is imported in one file only, Support/SpeakerSeparation.swift, and is linked into the app and not the widget.
// 2. The package is pinned to one exact version, so a build never picks up a newer one by itself.
// 3. That file never goes online and never fetches a model: no URLSession or URLRequest, none of the library's download or
//    model-loading calls, and the models are loaded from the app's own files with MLModel(contentsOf:).
// 4. launch switches the library's own network off: forbidDownloads sets ModelHub.offlineMode and AnchorApp calls it.
// 5. Nothing computed from a voice is kept: the file never writes anything, never touches UserDefaults, the Keychain, SwiftData or
//    the file system, never reads the library's sound prints or speaker list, never asks it to write them out, and nothing it
//    returns can be saved (no Codable). The library is run with export: .none and exposeChunkEmbeddings: false.
// 6. The recording is only ever read from a working copy that is removed in a defer, and StoredFiles makes that copy in the
//    phone's temporary folder, removes only inside it, and clears it at every start.
// 7. Only the test-build screen calls SpeakerSeparation.separate until the people screen (VN4a3) exists.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const appRoot = join(root, "iOS/Anchor/Anchor");
const runnerPath = "Support/SpeakerSeparation.swift";

function swiftFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name.startsWith(".")) continue;
    const path = join(dir, name);
    if (statSync(path).isDirectory()) out.push(...swiftFiles(path));
    else if (name.endsWith(".swift")) out.push(path);
  }
  return out;
}

const code = (text) => text.split("\n").map((line) => line.replace(/\/\/.*$/, "")).join("\n");
const files = swiftFiles(root + "/iOS").map((path) => ({
  path,
  rel: relative(appRoot, path),
  text: code(readFileSync(path, "utf8")),
}));
const problems = [];
const runner = files.find((f) => f.rel === runnerPath);

// 1. One importer.
for (const f of files) {
  if (/^\s*import\s+FluidAudio\b/m.test(f.text) && f.rel !== runnerPath) {
    problems.push(`${f.rel}: imports FluidAudio; only ${runnerPath} may`);
  }
}
if (!runner) {
  problems.push(`${runnerPath} is missing.`);
} else {
  if (!/^\s*import\s+FluidAudio\b/m.test(runner.text)) problems.push(`${runnerPath} does not import FluidAudio.`);

  // 3. Offline.
  const online = [
    [/\bURLSession\b|\bURLRequest\b|\bNWConnection\b|\bNWPathMonitor\b/, "goes online"],
    [/\bdownloadIfNeeded\b|\bprepareModels\b|\bforceRedownload\b|\bModelRegistry\b|\bREGISTRY_URL\b|\bHFClient\b|\bDownloadUtils\b/, "uses the library's download calls"],
    [/\bOfflineDiarizerModels\.load\b|\bDiarizerModels\.|\bAsrModels\b|\bModelHub\.loadModels\b|\bModelHub\.download\b|\bModelHub\.fetch/, "uses the library's own model loading, which can download"],
  ];
  for (const [pattern, why] of online) if (pattern.test(runner.text)) problems.push(`${runnerPath}: ${why}.`);
  if (!/MLModel\(contentsOf:/.test(runner.text)) problems.push(`${runnerPath}: does not load the models with MLModel(contentsOf:) from the app's own files.`);
  if (!/Bundle\.main\.url\(forResource:\s*"DiarizerModels"/.test(runner.text)) problems.push(`${runnerPath}: does not read the models from the DiarizerModels folder in the app.`);

  // 4. Offline switch.
  if (!/static func forbidDownloads\(\)\s*\{[^}]*ModelHub\.offlineMode\s*=\s*true/.test(runner.text)) {
    problems.push(`${runnerPath}: forbidDownloads does not set ModelHub.offlineMode = true.`);
  }
  if (/ModelHub\.offlineMode\s*=\s*false/.test(runner.text)) problems.push(`${runnerPath}: turns the library's offline mode off.`);
  const app = files.find((f) => f.rel === "AnchorApp.swift");
  if (!app || !/SpeakerSeparation\.forbidDownloads\(\)/.test(app.text)) problems.push("AnchorApp.swift does not call SpeakerSeparation.forbidDownloads() at launch.");

  // 5. Nothing kept.
  const kept = [
    [/\.write\(|\.createFile\(|\bFileHandle\b|\bOutputStream\b|\bwriteToFile\b|\bFileManager\b[^\n]*\b(copyItem|moveItem|createDirectory)\b/, "writes to storage"],
    [/\bUserDefaults\b|\bSecItem\w*|\bKeychain\w*|\bModelContext\b|\bmodelContext\b|\.insert\(|@Model\b|\bAppStorage\b|\bSceneStorage\b/, "reaches storage, the Keychain or the database"],
    [/\bCodable\b|\bEncodable\b|\bNSCoding\b|\bNSSecureCoding\b|\bJSONEncoder\b|\bPropertyListEncoder\b/, "makes something that can be saved"],
    [/\bspeakerDatabase\b|\bchunkEmbeddings\b|\bSpeakerManager\b|\binitializeKnownSpeakers\b|\bextractEmbedding\b|\bknownSpeakers\b|\bSpeakerProfile\b/, "reads the library's sound prints or speaker list"],
    [/\.embedding\b|\bembeddingsPath\b|\bembeddingExportPath\b|\bexposeChunkEmbeddings:\s*true\b/, "keeps or writes out a sound print"],
  ];
  for (const [pattern, why] of kept) if (pattern.test(runner.text)) problems.push(`${runnerPath}: ${why}.`);
  if (!/OfflineDiarizerConfig\(\s*export:\s*\.none,\s*exposeChunkEmbeddings:\s*false\s*\)/.test(runner.text)) {
    problems.push(`${runnerPath}: does not run the library with export: .none and exposeChunkEmbeddings: false.`);
  }

  // 6. Working copy.
  if (!/StoredFiles\.workingCopy\(/.test(runner.text)) problems.push(`${runnerPath}: does not read from StoredFiles.workingCopy.`);
  if (!/defer\s*\{\s*StoredFiles\.removeWorkingCopy\(/.test(runner.text)) problems.push(`${runnerPath}: does not remove the working copy in a defer.`);
  if (/StoredFiles\.read\(|\.url\(for:|\.folder\.url|VoiceNoteStore\.url/.test(runner.text)) problems.push(`${runnerPath}: reads a recording from its own file.`);
}

const stored = files.find((f) => f.rel === "Support/LockMyData.swift");
if (!stored) {
  problems.push("Support/LockMyData.swift is missing.");
} else {
  if (!/workingFolder:\s*URL\s*\{\s*FileManager\.default\.temporaryDirectory/.test(stored.text)) problems.push("StoredFiles' working folder is not in the temporary directory.");
  if (!/static func removeWorkingCopy\([^)]*\)\s*\{[^}]*workingFolder\.standardizedFileURL/.test(stored.text)) problems.push("StoredFiles.removeWorkingCopy does not stay inside the working folder.");
  if (!/runIfWaiting\(\)\s*\{[^}]*StoredFiles\.clearWorkingCopies\(\)/.test(stored.text)) problems.push("The start does not clear leftover working copies.");
}

// 7. Callers.
for (const f of files) {
  if (f.rel === runnerPath) continue;
  if (/SpeakerSeparation\.separate\(/.test(f.text) && f.rel !== "Support/SpeakerTryIt.swift") {
    problems.push(`${f.rel}: calls SpeakerSeparation.separate; only the test-build screen may until VN4a3 exists`);
  }
}
const tryIt = files.find((f) => f.rel === "Support/SpeakerTryIt.swift");
if (tryIt && !/^\s*#if DEBUG/m.test(tryIt.text)) problems.push("Support/SpeakerTryIt.swift is not inside #if DEBUG.");

// 1 and 2. The project.
const pbx = readFileSync(join(root, "iOS/Anchor/Anchor.xcodeproj/project.pbxproj"), "utf8");
const packageRef = pbx.match(/XCRemoteSwiftPackageReference "FluidAudio" \*\/ = \{[^}]*requirement = \{([^}]*)\}/);
if (!packageRef) problems.push("project.pbxproj does not have the FluidAudio package.");
else if (!/kind = exactVersion;\s*version = \d+\.\d+\.\d+;/.test(packageRef[1])) problems.push("The FluidAudio package is not pinned to one exact version.");
const linked = [...pbx.matchAll(/(\w+) \/\* FluidAudio in Frameworks \*\//g)].map((m) => m[1]);
if (linked.length === 0) problems.push("FluidAudio is not linked into the app.");
const widgetPhase = pbx.match(/3A536E339EDB4F25B97E71C1 \/\* Frameworks \*\/ = \{[^}]*\}/);
if (widgetPhase && /FluidAudio/.test(widgetPhase[0])) problems.push("FluidAudio is linked into the widget.");
const widgetFiles = pbx.match(/40C3E4C4FD2F471D8AAF7A78 \/\* Sources \*\/ = \{[^}]*\}/);
if (widgetFiles && /SpeakerSeparation|SpeakerTryIt/.test(widgetFiles[0])) problems.push("A speaker file is built into the widget.");
if (!/DiarizerModels in Resources/.test(pbx)) problems.push("The DiarizerModels folder is not copied into the app.");

if (problems.length) {
  console.log(`FAIL: ${problems.length} problem(s)`);
  for (const p of problems) console.log("  - " + p);
  process.exit(1);
}
console.log("The speaker separation check passed. One file imports the library, it is pinned, it cannot go online, and nothing computed from a voice is kept.");
