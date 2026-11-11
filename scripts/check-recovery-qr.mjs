// Checks that the recovery key as a QR code (E1, SY3 in ANCHOR_PATCH_PLAN.md) stays in memory and stays optional.
// Run it from anywhere:  node scripts/check-recovery-qr.mjs
// 1. The camera (AVFoundation capture) and the QR code maker (CIQRCodeGenerator or the qrCodeGenerator filter)
//    are used in Support/RecoveryKeyQR.swift and nowhere else.
// 2. That file never saves, copies or logs anything: no image data, no file writes, no photo library, no pasteboard,
//    no print, NSLog, os_log or Logger.
// 3. The camera permission is asked only inside the scanner, which only a tap on Scan a QR code opens, and no other
//    file asks for camera access.
// 4. The QR code is shown only from the recovery key sheet, only after a tap, and it is hidden again when Anchor
//    leaves the screen. It is made from the key text that sheet already holds, and no other file calls the maker
//    except the launch self-test, which uses a fixed test key.
// 5. Both build configurations carry a camera usage line, and no widget or other target does.
// 6. The key is never put in a link: the code holds plain text with a prefix, not a URL, and the scan never opens
//    what it read.
// 7. The launch self-test (test builds) checks the code text reads back, refuses a changed key and refuses a code
//    that is not a recovery key.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const swiftRoot = join(root, "iOS");
const qrPath = "Support/RecoveryKeyQR.swift";

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
let qr = "";
let settings = "";
let selfTest = "";

for (const file of files) {
  const rel = relative(root, file);
  const text = code(readFileSync(file, "utf8"));
  if (rel.endsWith(qrPath)) {
    qr = text;
    continue;
  }
  if (rel.endsWith("Views/Settings/SettingsView.swift")) settings = text;
  if (rel.endsWith("Support/AppLock.swift")) selfTest = text;
  if (/import\s+AVFoundation\b[\s\S]*\bAVCaptureSession\b|\bAVCaptureSession\b|\bAVCaptureMetadataOutput\b|\bAVCaptureVideoPreviewLayer\b|AVCaptureDevice\.requestAccess|AVCaptureDevice\.authorizationStatus\(for:\s*\.video\)/.test(text)) {
    problems.push(`${rel}: uses the camera; only ${qrPath} may`);
  }
  if (/\bCIQRCodeGenerator\b|\bqrCodeGenerator\(\)/.test(text)) {
    problems.push(`${rel}: makes a QR code; only ${qrPath} may`);
  }
  if (/\bRecoveryKeyQR\.image\b/.test(text) && !rel.endsWith("Views/Settings/SettingsView.swift") && !rel.endsWith("Support/AppLock.swift")) {
    problems.push(`${rel}: makes the recovery key into a QR code; only the recovery key sheet in SettingsView.swift (and the launch self-test in AppLock.swift) may`);
  }
}

if (!qr) {
  problems.push(`${qrPath} is missing`);
} else {
  if (/\bpngData\b|\bjpegData\b|\bheicData\b|UIImageWriteToSavedPhotosAlbum|\bPHPhotoLibrary\b|\bPHAssetChangeRequest\b|\.write\(to:|\bFileManager\b|createFile\(|\bFileHandle\b/.test(qr)) {
    problems.push(`${qrPath} saves something; the code and the scan must stay in memory`);
  }
  if (/\bUIPasteboard\b|\bShareLink\b|\bUIActivityViewController\b|\bShareSheet\b/.test(qr)) {
    problems.push(`${qrPath} copies or shares something; the code must not leave the screen`);
  }
  if (/\bprint\(|\bNSLog\(|\bos_log\(|\bLogger\(|\bdump\(/.test(qr)) {
    problems.push(`${qrPath} prints or logs; it holds the recovery key and must say nothing`);
  }
  if (/\bUIApplication\.shared\.open\b/.test(qr.replace(/UIApplication\.openSettingsURLString[\s\S]{0,80}/g, ""))) {
    problems.push(`${qrPath} opens a link other than the phone's Settings; a scanned code must never be opened`);
  }
  if (/https?:\/\/|anchor:\/\/|anchorassist:|anchorvoice:/.test(qr)) {
    problems.push(`${qrPath} holds a link; the code must be plain text with a prefix, never a URL that something could open`);
  }
  if (!/static let prefix = "anchor-recovery-key:"/.test(qr)) problems.push(`${qrPath} no longer prefixes the code with anchor-recovery-key:`);
  if (!/metadataObjectTypes = \[\.qr\]/.test(qr)) problems.push(`${qrPath} no longer looks for QR codes only`);
  const request = qr.search(/AVCaptureDevice\.requestAccess/);
  const start = qr.search(/private func start\(\) async/);
  const requests = (qr.match(/AVCaptureDevice\.requestAccess/g) || []).length;
  if (requests !== 1) problems.push(`${qrPath} asks for camera access ${requests} times; it must be once, inside the scanner`);
  else if (start < 0 || request < start) problems.push(`${qrPath} asks for camera access outside the scanner's start`);
  if (/\bcameraAvailable\b[\s\S]{0,200}requestAccess/.test(qr)) problems.push(`${qrPath} asks for camera access while only checking whether there is a camera`);
  if (!/RecoveryKeyQR\.key\(fromScanned: value\)/.test(qr)) problems.push(`${qrPath} no longer checks what a scan read against the recovery key format`);
}

if (!settings) {
  problems.push("Views/Settings/SettingsView.swift is missing");
} else {
  if (!/@State private var showQR = false/.test(settings)) problems.push("The recovery key sheet no longer keeps the QR code hidden to begin with");
  if (!/RecoveryKeyQR\.image\(for: text\)/.test(settings)) problems.push("The recovery key sheet no longer makes the code from the key it shows");
  if (!/onChange\(of: scenePhase\) \{ _, phase in\s*if phase != \.active \{ showQR = false \}/.test(settings)) problems.push("The recovery key sheet no longer hides the QR code when Anchor leaves the screen");
  if (!/if RecoveryKeyQR\.cameraAvailable \{/.test(settings)) problems.push("Scan a QR code is shown without checking there is a camera");
  if (!/@State private var showScanner = false/.test(settings)) problems.push("The scanner no longer opens only after a tap");
  const shows = (settings.match(/RecoveryKeyQR\.image\(/g) || []).length;
  if (shows !== 1) problems.push(`SettingsView.swift makes the QR code in ${shows} places; it must be one, in the recovery key sheet`);
}

if (!/RecoveryKeyQR\.roundTrips\(recoveryText\)/.test(selfTest)
  || !/RecoveryKeyQR\.key\(fromScanned: "https:\/\/example\.com"\) == nil/.test(selfTest)
  || !/RecoveryKeyQR\.key\(fromScanned: RecoveryKeyQR\.prefix \+ "3"/.test(selfTest)) {
  problems.push("The launch self-test in Support/AppLock.swift no longer checks the QR code text and what a scan accepts");
}

const project = readFileSync(join(root, "iOS/Anchor/Anchor.xcodeproj/project.pbxproj"), "utf8");
const camera = (project.match(/INFOPLIST_KEY_NSCameraUsageDescription = /g) || []).length;
const face = (project.match(/INFOPLIST_KEY_NSFaceIDUsageDescription = /g) || []).length;
if (camera !== face || camera !== 2) problems.push(`The project has ${camera} camera usage lines and ${face} Face ID lines; the app's two configurations need one of each and no other target any`);
if (!/NSCameraUsageDescription = "[^"]*only when you tap Scan a QR code/.test(project)) problems.push("The camera usage line no longer says the camera is used only when you tap Scan a QR code");

if (problems.length) {
  console.error("The recovery key QR check failed:");
  for (const problem of problems) console.error("  " + problem);
  process.exit(1);
}
console.log("The recovery key QR check passed. The camera and the code maker are in one file, the code is made in memory only after a tap and hidden when Anchor leaves the screen, and nothing is saved, copied or logged.");
