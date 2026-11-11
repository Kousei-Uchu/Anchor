// Checks that finding who is speaking (VN4a, E2, D38, D63, D64, D73 in ANCHOR_PATCH_PLAN.md) keeps nothing about a voice
// and never goes online. Run it from anywhere:  node scripts/check-speaker-separation.mjs
// 11. Guessing from the words (VN4c1) only prepares words and reads an answer; AIAsk is the one place text goes to a model.
// 9. Replay and tap (VN4b) uses no model and no recogniser, and keeps and sends nothing.
// 12. Guessing from the words (VN4c2): only the people screen sends words, only through AIAsk, behind the AI switch.
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
// 7. Only the people finder (Support/PeopleFinder.swift) and the test-build screen call SpeakerSeparation.separate, and only the
//    people finder calls FileTranscription.words.
// 8. The people finder keeps nothing and goes nowhere: no storage, no network, nothing it returns can be saved, it works from a
//    working copy removed in a defer, and the people screen goes through it. FileTranscription works on the phone only
//    (requiresOnDeviceRecognition = true) and checks the phone can recognise the language on its own.

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
  if (/SpeakerSeparation\.separate\(/.test(f.text) && f.rel !== "Support/SpeakerTryIt.swift" && f.rel !== "Support/PeopleFinder.swift") {
    problems.push(`${f.rel}: calls SpeakerSeparation.separate; only the people finder and the test-build screen may`);
  }
  if (/FileTranscription\.words\(/.test(f.text) && f.rel !== "Support/PeopleFinder.swift") {
    problems.push(`${f.rel}: calls FileTranscription.words; only the people finder may`);
  }
}
const tryIt = files.find((f) => f.rel === "Support/SpeakerTryIt.swift");
if (tryIt && !/^\s*#if DEBUG/m.test(tryIt.text)) problems.push("Support/SpeakerTryIt.swift is not inside #if DEBUG.");

// 8. The people finder and the recogniser.
const finder = files.find((f) => f.rel === "Support/PeopleFinder.swift");
if (!finder) {
  problems.push("Support/PeopleFinder.swift is missing.");
} else {
  const finderCode = finder.text.split("#if DEBUG")[0];
  const rules = [
    [/\bURLSession\b|\bURLRequest\b|\bNWConnection\b|\bNWPathMonitor\b/, "goes online"],
    [/\bUserDefaults\b|\bSecItem\w*|\bKeychain\w*|\bModelContext\b|\bmodelContext\b|\.insert\(|@Model\b|\bAppStorage\b|\bSceneStorage\b|\bUIPasteboard\b/, "reaches storage, the Keychain, the database or the clipboard"],
    [/\.write\(|\.createFile\(|\bFileHandle\b|\bOutputStream\b|\bwriteToFile\b/, "writes to storage"],
    [/\bCodable\b|\bEncodable\b|\bNSCoding\b|\bJSONEncoder\b|\bPropertyListEncoder\b/, "makes something that can be saved"],
    [/StoredFiles\.read\(|\.url\(for:|VoiceNoteStore\.url/, "reads a recording from its own file"],
  ];
  for (const [pattern, why] of rules) if (pattern.test(finderCode)) problems.push(`Support/PeopleFinder.swift: ${why}.`);
  if (!/StoredFiles\.workingCopy\(/.test(finderCode)) problems.push("Support/PeopleFinder.swift does not read from StoredFiles.workingCopy.");
  if (!/defer\s*\{\s*StoredFiles\.removeWorkingCopy\(/.test(finderCode)) problems.push("Support/PeopleFinder.swift does not remove its working copy in a defer.");
}
const screen = files.find((f) => f.rel === "Views/Journal/PeopleScreen.swift");
if (screen && /SpeakerSeparation\.|FileTranscription\./.test(screen.text)) problems.push("Views/Journal/PeopleScreen.swift reaches the model or the recogniser itself; it goes through PeopleFinder.");
const dictation = files.find((f) => f.rel === "Support/Dictation.swift");
const transcriber = dictation ? dictation.text.slice(Math.max(dictation.text.indexOf("enum FileTranscription"), 0)) : "";
if (!/enum FileTranscription/.test(transcriber)) problems.push("Support/Dictation.swift has no FileTranscription.");
else {
  if (!/SFSpeechURLRecognitionRequest/.test(transcriber) || !/request\.requiresOnDeviceRecognition\s*=\s*true/.test(transcriber)) problems.push("FileTranscription does not work on the phone only (requiresOnDeviceRecognition = true).");
  if (!/\bsupportsOnDeviceRecognition\b/.test(transcriber)) problems.push("FileTranscription does not check the phone can recognise the language on its own.");
  if (/\bUserDefaults\b|\bURLSession\b|\.write\(/.test(transcriber)) problems.push("FileTranscription keeps something or goes online.");
}

// 9. Replay and tap (VN4b): no model and no recogniser reads anything, and nothing is kept or sent.
for (const rel of ["Support/TapTurns.swift", "Support/ReplayPlayer.swift", "Views/Journal/PeopleTapScreen.swift"]) {
  const f = files.find((x) => x.rel === rel);
  if (!f) { problems.push(`${rel} is missing.`); continue; }
  const code = f.text.split("#if DEBUG")[0];
  const rules = [
    [/\bFluidAudio\b|SpeakerSeparation\.(separate|isAvailable|forbidDownloads|turns|personCount)\b|\bFileTranscription\b|\bSFSpeech\w*|\bOfflineDiarizer\w*/, "reaches the model or the recogniser; replay and tap uses neither"],
    [/\bURLSession\b|\bURLRequest\b|\bNWConnection\b|\bNWPathMonitor\b/, "goes online"],
    [/\bUserDefaults\b|\bSecItem\w*|\bKeychain\w*|\bModelContext\b|\bmodelContext\b|\.insert\(|@Model\b|\bAppStorage\b|\bSceneStorage\b|\bUIPasteboard\b/, "reaches storage, the Keychain, the database or the clipboard"],
    [/\.write\(|\.createFile\(|\bFileHandle\b|\bOutputStream\b|\bwriteToFile\b|\bworkingCopy\(/, "writes a file"],
    [/\bCodable\b|\bEncodable\b|\bNSCoding\b|\bJSONEncoder\b|\bPropertyListEncoder\b/, "makes something that can be saved"],
  ];
  for (const [pattern, why] of rules) if (pattern.test(code)) problems.push(`${rel}: ${why}.`);
}
const replay = files.find((x) => x.rel === "Support/ReplayPlayer.swift");
if (replay && !/AVAudioPlayer\(data:/.test(replay.text)) problems.push("Support/ReplayPlayer.swift does not play from memory with AVAudioPlayer(data:).");
const tapScreen = files.find((x) => x.rel === "Views/Journal/PeopleTapScreen.swift");
if (tapScreen && !/PeopleScreen\(/.test(tapScreen.text)) problems.push("Views/Journal/PeopleTapScreen.swift does not open the people screen.");

// 10. Switched on (VN4a4): off to begin with, off in showcase mode, and the only way in is the voice note's own menu.
const settings = files.find((x) => x.rel === "Support/PeopleSettings.swift");
if (!settings) problems.push("Support/PeopleSettings.swift is missing.");
else {
  if (!/DemoMode\.isOn/.test(settings.text)) problems.push("Support/PeopleSettings.swift does not stay off in showcase mode.");
  if (!/UserDefaults\.standard\.bool\(forKey:\s*key\)/.test(settings.text)) problems.push("Support/PeopleSettings.swift does not read the switch with bool(forKey:), which is off until switched on.");
}
for (const f of files) {
  if (/register\(defaults:[^)]*findWhoIsSpeaking[^)]*true/.test(f.text)) problems.push(`${f.rel}: registers Find who is speaking as on by default.`);
  if (f.rel === "Support/SpeakerTryIt.swift" || f.rel.startsWith("Views/Journal/People")) continue;
  if (/\bPeopleScreen\(|\bPeopleTapScreen\(/.test(f.text) && f.rel !== "Views/Journal/JournalEntryEditorView.swift") problems.push(`${f.rel}: opens the people screen; only a voice note's menu may.`);
}
const editor = files.find((x) => x.rel === "Views/Journal/JournalEntryEditorView.swift");
if (editor && !/if PeopleSettings\.isOn[^\n]*case \.voice/.test(editor.text)) problems.push("The Journal editor shows the people buttons without checking PeopleSettings.isOn on a voice note.");

// 11. Guessing from the words (VN4c1): Support/SpeakerWords.swift only prepares words and reads an answer. It never talks to a
//     model, never goes online, keeps nothing and makes nothing that can be saved; the one place text goes to a model is AIAsk.
const words = files.find((x) => x.rel === "Support/SpeakerWords.swift");
if (!words) problems.push("Support/SpeakerWords.swift is missing.");
else {
  const code = words.text.split("#if DEBUG")[0];
  const rules = [
    [/\bAIAsk\b|\bAIProvid\w*|\.generate\(|\bFoundationModels\b|\bLanguageModelSession\b|\bFluidAudio\b|\bSFSpeech\w*|\bFileTranscription\.words\b/, "reaches a model, a provider or a recogniser itself"],
    [/\bURLSession\b|\bURLRequest\b|\bNWConnection\b|\bNWPathMonitor\b/, "goes online"],
    [/\bUserDefaults\b|\bSecItem\w*|\bKeychain\w*|\bModelContext\b|\bmodelContext\b|\.insert\(|@Model\b|\bAppStorage\b|\bSceneStorage\b|\bUIPasteboard\b/, "reaches storage, the Keychain, the database or the clipboard"],
    [/\.write\(|\.createFile\(|\bFileHandle\b|\bOutputStream\b|\bwriteToFile\b|\bworkingCopy\(/, "writes a file"],
    [/\bCodable\b|\bEncodable\b|\bNSCoding\b|\bJSONEncoder\b|\bPropertyListEncoder\b/, "makes something that can be saved"],
  ];
  for (const [pattern, why] of rules) if (pattern.test(code)) problems.push(`Support/SpeakerWords.swift: ${why}.`);
}

// 12. Guessing from the words, the screen (VN4c2): only the people screen sends words, only through AIAsk, only the text that
//     SpeakerWords.prompt made, only after checking the AI switch, and a greyed-out button stands in while it is off.
for (const f of files) {
  if (/\.findSpeakerChanges\b/.test(f.text) && f.rel !== "Support/AIProviders.swift" && f.rel !== "Views/Journal/PeopleScreen.swift") {
    problems.push(`${f.rel}: uses the Suggest who is speaking tool; only the people screen may.`);
  }
}
const guessScreen = files.find((x) => x.rel === "Views/Journal/PeopleScreen.swift");
if (guessScreen) {
  const t = guessScreen.text;
  if (!/ask\.run\(\s*\.findSpeakerChanges\s*,\s*on:\s*prompt\.text\b/.test(t)) problems.push("Views/Journal/PeopleScreen.swift does not send only the prompt's text through AIAsk with the Suggest who is speaking tool.");
  if (!/SpeakerWords\.prompt\(/.test(t)) problems.push("Views/Journal/PeopleScreen.swift does not build what it sends with SpeakerWords.prompt.");
  if (!/guard AIGate\.isEnabled\b/.test(t)) problems.push("Views/Journal/PeopleScreen.swift does not check the AI switch before guessing from the words.");
  if (!/\.aiAsk\(ask\)/.test(t)) problems.push("Views/Journal/PeopleScreen.swift does not show the consent sheet (.aiAsk).");
  if (/\.generate\(|\bURLSession\b|\bURLRequest\b|\bUserDefaults\b|\bCodable\b/.test(t)) problems.push("Views/Journal/PeopleScreen.swift talks to a provider, goes online, keeps something or makes something saveable.");
}

// Patch VN5: speaker tags in exports. The choices are kept on the export screen only, and nothing but the exports
// that are handed to someone reads them.
const exportRules = files.find((x) => x.rel === "Support/SpeakerExport.swift");
if (!exportRules) problems.push("Support/SpeakerExport.swift is missing.");
else {
  const t = exportRules.text.split("#if DEBUG")[0];
  if (/\bCodable\b|\bEncodable\b|\bDecodable\b|\bUserDefaults\b|\bModelContext\b|\bFileManager\b|\bURLSession\b|\bKeychain\b|\b@AppStorage\b|\bimport SwiftData\b/.test(t)) problems.push("Support/SpeakerExport.swift keeps something, makes the choices saveable or goes online.");
}
const exportScreen = files.find((x) => x.rel === "Views/Bridge/SpeakerExportView.swift");
if (exportScreen && /\bUserDefaults\b|\b@AppStorage\b|\bModelContext\b|\bCodable\b/.test(exportScreen.text)) problems.push("Views/Bridge/SpeakerExportView.swift keeps the choices.");
for (const f of files) {
  if (/SpeakerExport\b|SpeakerExportChoices|speakers:/.test(code(f.text)) && !/^(Support\/SpeakerExport\.swift|Views\/Bridge\/SpeakerExportView\.swift|Views\/Bridge\/BridgeExportView\.swift|Views\/Plan\/DataControlView\.swift|Views\/Journal\/JournalAssist\.swift|AnchorApp\.swift)$/.test(f.rel)) {
    problems.push(`${f.rel} uses the speaker export choices, which only the exports handed to someone may do.`);
  }
}
const dataView = files.find((x) => x.rel === "Views/Plan/DataControlView.swift");
if (dataView) {
  // The full JSON and the encrypted backup keep every line as it is, so a restore is exact.
  const json = dataView.text.match(/journalEntries:\s*journalEntries\.map\(JournalEntryDTO\.init\)/);
  if (!json) problems.push("The full export no longer reads journal entries as they are.");
  if (/JournalEntryDTO[^\n]*speakers/.test(dataView.text)) problems.push("The full export or backup applies speaker choices.");
}

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
