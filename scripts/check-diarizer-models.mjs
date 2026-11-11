// Checks the speaker-separation model files bundled for VN4a (D73, docs/OPTIONAL_FEATURES.md, E2).
// Run it from anywhere:  node scripts/check-diarizer-models.mjs
// Until scripts/fetch-diarizer-models.sh has been run there is no folder, and this passes and says so.
// Once the folder is there:
// 1. Every file the app reads is present: Segmentation, FBank, Embedding and PldaRho as compiled folders, and
//    plda-parameters.json.
// 2. The licence and notice files are kept with them (CC-BY-4.0 asks for that), and SOURCE.txt names the commit.
// 3. Every file matches the checksum written when it was fetched, and no file is there that the list does not name,
//    so nothing can be added to or changed in the folder without this failing.
// 4. The files are a plausible size (about 21.6 MB in all), so a failed download that left small files is caught.

import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const dir = process.env.DIARIZER_DEST || join(root, "iOS/Anchor/Anchor/DiarizerModels");

if (!existsSync(dir)) {
  console.log("The diarizer models are not fetched yet (run scripts/fetch-diarizer-models.sh). Nothing to check.");
  process.exit(0);
}

const problems = [];
const folders = ["Segmentation", "FBank", "Embedding", "PldaRho"];
const inside = ["coremldata.bin", "metadata.json", "model.mil", "weights/weight.bin"];
const loose = ["plda-parameters.json", "LICENSE", "NOTICE.md", "PROVENANCE.md", "SOURCE.txt", "SHA256SUMS"];

function walk(d) {
  const out = [];
  for (const name of readdirSync(d)) {
    const path = join(d, name);
    if (statSync(path).isDirectory()) out.push(...walk(path));
    else out.push(relative(dir, path).split("\\").join("/"));
  }
  return out;
}

const present = new Set(walk(dir).filter((f) => !f.endsWith(".DS_Store")));
for (const folder of folders) {
  for (const file of inside) {
    if (!present.has(`${folder}.mlmodelc/${file}`)) problems.push(`Missing ${folder}.mlmodelc/${file}.`);
  }
}
for (const file of loose) if (!present.has(file)) problems.push(`Missing ${file}.`);

if (present.has("SOURCE.txt")) {
  if (!/^commit: [0-9a-f]{40}$/m.test(readFileSync(join(dir, "SOURCE.txt"), "utf8"))) {
    problems.push("SOURCE.txt does not name a 40-character commit.");
  }
}

let total = 0;
if (present.has("SHA256SUMS")) {
  const listed = new Map();
  for (const line of readFileSync(join(dir, "SHA256SUMS"), "utf8").split("\n")) {
    if (!line.trim()) continue;
    const match = line.match(/^([0-9a-f]{64})\s+\*?(.+)$/);
    if (!match) {
      problems.push(`SHA256SUMS has a line that is not a checksum: ${line.slice(0, 60)}`);
      continue;
    }
    listed.set(match[2], match[1]);
  }
  for (const [file, sum] of listed) {
    if (!present.has(file)) {
      problems.push(`SHA256SUMS names ${file}, which is not there.`);
      continue;
    }
    const data = readFileSync(join(dir, file));
    total += data.length;
    if (createHash("sha256").update(data).digest("hex") !== sum) problems.push(`${file} does not match its checksum.`);
  }
  for (const file of present) {
    if (file !== "SHA256SUMS" && !listed.has(file)) problems.push(`${file} is in the folder but not in SHA256SUMS.`);
  }
  if (total < 15e6 || total > 30e6) {
    problems.push(`The files add up to ${total} bytes; about 21.6 million is expected.`);
  }
}

if (problems.length) {
  console.log(`FAIL: ${problems.length} problem(s)`);
  for (const p of problems) console.log("  - " + p);
  process.exit(1);
}
console.log(`The diarizer models check passed. ${present.size} files, ${total} bytes, all matching their checksums.`);
