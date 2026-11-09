// Checks that the unlisted beta page stays unlisted.
// Run it from anywhere:  node scripts/check-beta-hidden.mjs
// The page at /beta may be named only where it is defined (the route, its
// title and description, and its own file). It must be marked noindex in its
// meta, in the prerender and in a response header, must not be linked from
// anywhere else in the website, and the sign-up switch must be a plain flag.

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, relative } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const site = join(root, "website");
const problems = [];

function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    if (name === "node_modules" || name === "dist" || name === "dist-ssr") continue;
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

const allowed = new Set(["src/App.tsx", "src/content/meta.ts", "src/pages/Beta.tsx", "src/content/beta.ts"]);
for (const file of walk(join(site, "src")).concat(walk(join(site, "public")))) {
  if (!/\.(tsx?|json|txt|xml|html|md)$/.test(file)) continue;
  const rel = relative(site, file);
  if (allowed.has(rel)) continue;
  const text = readFileSync(file, "utf8");
  if (/["'`(=]\/beta\b/.test(text) || /\bbeta\.html\b/.test(text)) problems.push(`${rel} names the beta page. It should not be linked or listed.`);
}
for (const name of ["sitemap.xml", "robots.txt"]) {
  const p = join(site, "public", name);
  if (existsSync(p) && /\/beta\b/.test(readFileSync(p, "utf8"))) problems.push(`public/${name} lists /beta.`);
}

const meta = readFileSync(join(site, "src/content/meta.ts"), "utf8");
if (!/'\/beta':\s*\{[^}]*noindex:\s*true/s.test(meta)) problems.push("The /beta entry in content/meta.ts is not marked noindex: true.");

const prerender = readFileSync(join(site, "scripts/prerender.mjs"), "utf8");
if (!/meta\.noindex/.test(prerender) || !/name=\\?"robots\\?"/.test(prerender)) problems.push("scripts/prerender.mjs does not write a robots noindex tag for noindex routes.");

const vercel = JSON.parse(readFileSync(join(site, "vercel.json"), "utf8"));
const header = (vercel.headers || []).find((h) => h.source === "/beta");
if (!header || !header.headers.some((h) => h.key.toLowerCase() === "x-robots-tag" && /noindex/.test(h.value))) problems.push("vercel.json has no X-Robots-Tag noindex header for /beta.");

const flag = readFileSync(join(site, "src/content/beta.ts"), "utf8");
if (!/export const BETA_SIGNUP_OPEN = (true|false);/.test(flag)) problems.push("BETA_SIGNUP_OPEN in content/beta.ts is not a plain true or false.");

if (problems.length) {
  console.error("The beta page check failed:");
  for (const p of problems) console.error("  " + p);
  process.exit(1);
}
console.log("The beta page check passed. /beta is noindex in the meta, the prerender and the header, and is linked from nowhere.");
