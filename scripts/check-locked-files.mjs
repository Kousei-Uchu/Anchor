// Checks that voice notes and Journal photos are only read and written through StoredFiles (Patch 35d,
// docs/ENCRYPTION.md), so a locked file is never read as if it were plain, and a new file is never saved plain by
// a screen that forgot about locking.
// 1. Nothing reads an image or a sound straight from a path or a file URL: UIImage(contentsOfFile:) and
//    AVAudioPlayer(contentsOf:) are not used anywhere. Images come from StoredFiles.read, sounds from its data.
// 2. Nothing hands a voice note's own file URL to Share or Messages: they take StoredFiles.sendableCopy, which
//    opens a locked file into a copy that is removed afterwards.
// 3. The Journal photo store writes only with StoredFiles.write.
// 4. A finished recording is sealed (sealIfOn), and a file restored from a backup is sealed too.
// 5. The wiring is complete: the launch turns FileLock.isOn on from LockMyFiles, and the start runs the waiting
//    job and the sweep.
// 6. Files only reach a backup as plain bytes: the backup writer opens a locked file before it writes it.
// Run it from anywhere:  node scripts/check-locked-files.mjs

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const appRoot = join(root, "iOS/Anchor/Anchor");

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

const files = swiftFiles(appRoot).map((path) => ({ rel: relative(appRoot, path), text: readFileSync(path, "utf8") }));
const get = (rel) => files.find((f) => f.rel === rel)?.text ?? "";
const problems = [];

// 1 to 2. Forbidden ways in, outside comments.
const forbidden = [
  [/UIImage\(contentsOfFile:/, "reads an image straight from a path; use StoredFiles.read and UIImage(data:)"],
  [/AVAudioPlayer\(contentsOf:/, "plays a sound straight from a file URL; use StoredFiles.read and AVAudioPlayer(data:)"],
  [/ShareLink\(item:\s*VoiceNoteStore/, "shares a voice note's own file; use SharedVoiceNote"],
  [/attachment:[^\n]*VoiceNoteStore\.url\(for/, "attaches a voice note's own file; use StoredFiles.sendableCopy"],
  [/fileName\.map\(VoiceNoteStore\.url/, "attaches a voice note's own file; use StoredFiles.sendableCopy"],
];
for (const f of files) {
  f.text.split("\n").forEach((line, i) => {
    const code = line.replace(/\/\/.*$/, "");
    for (const [pattern, why] of forbidden) {
      if (pattern.test(code)) problems.push(`${f.rel}:${i + 1} ${why}.`);
    }
  });
}

// 3. The photo store.
const journal = get("Views/Journal/JournalEntryEditorView.swift");
const store = journal.match(/enum JournalAttachmentStore \{[\s\S]*?\n\}\n/);
if (!store) problems.push("JournalAttachmentStore was not found in JournalEntryEditorView.swift.");
else {
  if (!/StoredFiles\.write\(/.test(store[0])) problems.push("JournalAttachmentStore.save does not write through StoredFiles.write.");
  if (/\.write\(to:/.test(store[0].replace(/\/\/.*$/gm, ""))) problems.push("JournalAttachmentStore writes a file by itself.");
  if (!/StoredFiles\.read\(/.test(store[0])) problems.push("JournalAttachmentStore.image does not read through StoredFiles.read.");
}

// 4. Recordings and restored files.
if (!/StoredFiles\.sealIfOn\(\.voiceNotes/.test(get("Views/Thread/ThreadMessagesView.swift")))
  problems.push("A finished recording is not sealed (StoredFiles.sealIfOn in VoiceNoteRecorder.stop).");
if (!/StoredFiles\.sealIfOn\(/.test(get("Views/Plan/DataControlView.swift")))
  problems.push("A file restored from a backup is not sealed (StoredFiles.sealIfOn in BackupArchive.restoreFiles).");

// 5. Wiring.
if (!/FileLock\.isOn\s*=\s*LockMyFiles\.isOn/.test(get("Support/AppLock.swift")))
  problems.push("FieldLockWiring.install does not turn FileLock.isOn on from LockMyFiles.isOn.");
const app = get("AnchorApp.swift");
for (const call of ["LockMyFiles.recoverInterruptedRun()", "LockMyFiles.runIfWaiting()", "LockMyFiles.sweepAtLaunch()", "LockMyFilesSelfTest.run()"]) {
  if (!app.includes(call)) problems.push(`AnchorApp.swift does not call ${call}.`);
}

// 6. Backups hold plain bytes.
const backup = get("Views/Plan/DataControlView.swift");
const writer = backup.match(/static func write\(json: Data[\s\S]*?\n    \}\n/);
if (!writer || !/StoredFiles\.isSealed\(at:/.test(writer[0]) || !/StoredFiles\.read\(/.test(writer[0]))
  problems.push("BackupArchive.write does not open a locked file before it writes it into the backup.");

if (problems.length) {
  console.log(problems.join("\n"));
  process.exit(1);
}
console.log(`The locked files check passed. ${files.length} Swift files read.`);
