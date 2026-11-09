// Checks that Dictate in the Journal stays on the phone and stays optional (E2 in docs/OPTIONAL_FEATURES.md).
// Run it from anywhere:  node scripts/check-dictation.mjs
// 1. Speech recognition is used in one file only, Support/Dictation.swift.
// 2. That file tells the recogniser to work on the device only and never says otherwise, so a language the
//    phone cannot do on its own is refused instead of sent to Apple's servers.
// 3. It checks that the phone supports on-device recognition before it asks for any permission.
// 4. Dictation.swift never writes sound to a file itself. A voice note kept while dictating (VN2) is written by
//    Support/DictationAudio.swift only, which is made only when Keep a voice note while dictating is on, and
//    that switch is off to begin with, needs Dictate to be on, and stays off in showcase mode.
// 5. The switch is off to begin with and stays off in showcase mode and the demo store, and nothing defaults it on.
// 6. The Journal editor shows the Dictate button only through that switch.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const swiftRoot = join(root, "iOS");
const dictationPath = "Support/Dictation.swift";

function swiftFiles(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name.startsWith(".") || name === "build" || name === "DerivedData") continue;
    const path = join(dir, name);
    if (statSync(path).isDirectory()) out.push(...swiftFiles(path));
    else if (name.endsWith(".swift")) out.push(path);
  }
  return out;
}

const code = (text) => text.split("\n").filter((line) => !line.trim().startsWith("//")).join("\n");
const problems = [];
const files = swiftFiles(swiftRoot);
let dictation = "";
let audio = "";
const audioPath = "Support/DictationAudio.swift";

for (const file of files) {
  const rel = relative(root, file);
  const text = code(readFileSync(file, "utf8"));
  if (rel.endsWith(dictationPath)) {
    dictation = text;
    continue;
  }
  if (rel.endsWith(audioPath)) {
    audio = text;
    continue;
  }
  if (/\bDictationAudioSink\b/.test(text) && !rel.endsWith("Support/Dictation.swift")) {
    problems.push(`${rel}: uses DictationAudioSink; only ${dictationPath} may`);
  }
  if (/import\s+Speech\b|\bSFSpeech\w*|\bSpeechAnalyzer\b|\bSpeechTranscriber\b|\bDictationTranscriber\b/.test(text)) {
    problems.push(`${rel}: uses speech recognition; only ${dictationPath} may`);
  }
}

if (!dictation) {
  problems.push(`${dictationPath} is missing`);
} else {
  if (!/requiresOnDeviceRecognition\s*=\s*true/.test(dictation)) problems.push("Dictation.swift no longer sets requiresOnDeviceRecognition = true");
  if (/requiresOnDeviceRecognition\s*=\s*(false|[^t\s])/.test(dictation)) problems.push("Dictation.swift sets requiresOnDeviceRecognition to something other than true");
  const supports = dictation.search(/supportsOnDeviceRecognition/);
  const asks = dictation.search(/requestAuthorization|requestRecordPermission/);
  if (supports < 0) problems.push("Dictation.swift no longer checks supportsOnDeviceRecognition");
  else if (asks >= 0 && supports > asks) problems.push("Dictation.swift asks for a permission before it checks the phone can do it on its own");
  if (/\bAVAudioFile\b|\bAVAudioRecorder\b|\.write\(to:|\bFileHandle\b|createFile\(/.test(dictation)) problems.push("Dictation.swift writes sound to a file itself; that belongs in DictationAudio.swift only");
  if (!/static var keepsVoiceNote: Bool \{ isEnabled && UserDefaults\.standard\.bool\(forKey: keepVoiceNoteKey\) \}/.test(dictation)) problems.push("DictationSettings.keepsVoiceNote no longer needs Dictate on and an off-by-default switch");
  const makes = [...dictation.matchAll(/DictationAudioSink\(/g)].length;
  if (makes !== 1) problems.push(`Dictation.swift makes a voice note sink ${makes} times; it must be once, inside the keep switch`);
  else if (!/if keeping \{[^}]*DictationAudioSink\(/s.test(dictation)) problems.push("Dictation.swift makes the voice note sink outside the keep switch");
  if (/\bURLSession\b|\bURLRequest\b|\bNWConnection\b/.test(dictation)) problems.push("Dictation.swift opens a network connection");
  if (!/DemoMode\.isOn/.test(dictation)) problems.push("DictationSettings.isEnabled no longer stays off in showcase mode and the demo store");
  if (!/UserDefaults\.standard\.bool\(forKey: enabledKey\)/.test(dictation)) problems.push("DictationSettings.isChosen no longer reads an off-by-default boolean");
}

for (const file of files) {
  const rel = relative(root, file);
  const text = code(readFileSync(file, "utf8"));
  if (/@AppStorage\(\s*DictationSettings\.enabledKey\s*\)[^\n]*=\s*true/.test(text)) problems.push(`${rel}: sets the Dictate switch to on by default`);
  if (/register\(defaults:[^)]*dictationEnabled[^)]*true/.test(text)) problems.push(`${rel}: registers the Dictate switch as on by default`);
}

try {
  const editor = readFileSync(join(swiftRoot, "Anchor/Anchor/Views/Journal/JournalEntryEditorView.swift"), "utf8");
  if (!/if showsDictate\s*\{/.test(editor)) problems.push("The Journal editor no longer shows the Dictate button only when showsDictate is true");
  if (!/dictationChosen\s*&&\s*!DemoMode\.isOn/.test(editor)) problems.push("showsDictate in the Journal editor no longer needs the switch and no showcase mode");
} catch {
  problems.push("Views/Journal/JournalEntryEditorView.swift is missing");
}

if (problems.length) {
  console.error("The dictation check failed:");
  for (const p of problems) console.error("  - " + p);
  process.exit(1);
}
console.log(`The dictation check passed. ${files.length} Swift files read, speech recognition is used in one file and works on the device only.`);
