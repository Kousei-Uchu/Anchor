// Checks the promo's pictures (Patch 52): every screen the video names has a picture, each is a portrait JPEG
// of the same size, and the website's copy matches the video's. Needs no Mac.
//
//   node scripts/check-promo-shots.mjs
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const promo = readFileSync(join(root, "remotion-project/src/Promo.tsx"), "utf8");
const start = promo.indexOf("const FEATURES = [");
const end = promo.indexOf("];", start);
if (start < 0 || end < 0) {
  console.error("Could not find FEATURES in remotion-project/src/Promo.tsx.");
  process.exit(1);
}
const names = [...promo.slice(start, end).matchAll(/img:\s*'([a-z0-9-]+)'/g)].map((m) => m[1]);
if (names.length === 0) {
  console.error("FEATURES names no pictures.");
  process.exit(1);
}

function jpegSize(buf) {
  if (buf[0] !== 0xff || buf[1] !== 0xd8) return null;
  let i = 2;
  while (i < buf.length) {
    if (buf[i] !== 0xff) { i++; continue; }
    const marker = buf[i + 1];
    if (marker === 0xc0 || marker === 0xc1 || marker === 0xc2) return { h: buf.readUInt16BE(i + 5), w: buf.readUInt16BE(i + 7) };
    i += 2 + buf.readUInt16BE(i + 2);
  }
  return null;
}

const problems = [];
let size;
for (const name of names) {
  const a = join(root, "remotion-project/public/shots", `${name}.jpg`);
  const b = join(root, "website/public/shots", `${name}.jpg`);
  if (!existsSync(a)) { problems.push(`The video uses shots/${name}.jpg, but it is not in remotion-project/public/shots.`); continue; }
  const bufA = readFileSync(a);
  const s = jpegSize(bufA);
  if (!s) { problems.push(`remotion-project/public/shots/${name}.jpg is not a JPEG.`); continue; }
  if (s.h <= s.w) problems.push(`shots/${name}.jpg is not portrait (${s.w}x${s.h}).`);
  size ??= s;
  if (s.w !== size.w || s.h !== size.h) problems.push(`shots/${name}.jpg is ${s.w}x${s.h}, but the others are ${size.w}x${size.h}.`);
  if (!existsSync(b)) problems.push(`website/public/shots/${name}.jpg is missing. Run: cd website && npm run sync:promo`);
  else if (!bufA.equals(readFileSync(b))) problems.push(`website/public/shots/${name}.jpg differs from the video's. Run: cd website && npm run sync:promo`);
}
if (problems.length) {
  for (const p of problems) console.error("Problem: " + p);
  process.exit(1);
}
console.log(`The promo pictures are fine (${names.length} screens, ${size.w}x${size.h}, the website's copies match).`);
