// Checks that THIRD-PARTY-NOTICES.md has not fallen behind the code (Patch LIC1).
// It reads the Swift package pins, both package.json files, the bundled model commit and the sound files, and
// fails when any of them is missing from the notices, or when a placeholder is left in. It does not judge whether a
// licence in the notices is right; that is a person's job. Run it from anywhere: node scripts/check-third-party.mjs
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, dirname, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const read = (p) => readFileSync(join(root, p), 'utf8');
const problems = [];

const notices = read('THIRD-PARTY-NOTICES.md');
const lower = notices.toLowerCase();
const mentions = (text) => lower.includes(text.toLowerCase());

if (/\[TO BE AUDITED\]/i.test(notices)) problems.push('THIRD-PARTY-NOTICES.md still has a [TO BE AUDITED] placeholder.');

// Swift packages and their pinned versions.
const resolvedPath = 'iOS/Anchor/Anchor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved';
if (existsSync(join(root, resolvedPath))) {
  const resolved = JSON.parse(read(resolvedPath));
  for (const pin of resolved.pins ?? []) {
    if (!mentions(pin.identity)) problems.push(`Swift package ${pin.identity} is not in THIRD-PARTY-NOTICES.md.`);
    const version = pin.state?.version;
    if (version && !notices.includes(version)) problems.push(`Swift package ${pin.identity} is pinned at ${version}, which THIRD-PARTY-NOTICES.md does not say.`);
  }
} else {
  problems.push(`${resolvedPath} was not found.`);
}

// npm direct dependencies.
for (const manifest of ['website/package.json', 'remotion-project/package.json']) {
  const json = JSON.parse(read(manifest));
  for (const group of ['dependencies', 'devDependencies']) {
    for (const name of Object.keys(json[group] ?? {})) {
      if (!notices.includes(name)) problems.push(`${manifest}: ${name} is not in THIRD-PARTY-NOTICES.md.`);
    }
  }
}

// The commit the bundled models came from.
const sourcePath = 'iOS/Anchor/Anchor/DiarizerModels/SOURCE.txt';
if (existsSync(join(root, sourcePath))) {
  const commit = /^commit:\s*([0-9a-f]{40})/m.exec(read(sourcePath))?.[1];
  if (!commit) problems.push(`${sourcePath} does not name a commit.`);
  else if (!notices.includes(commit)) problems.push(`The bundled models come from commit ${commit}, which THIRD-PARTY-NOTICES.md does not say.`);
}

// Every sound file the website or video carries must be named.
const walk = (dir) => readdirSync(join(root, dir)).flatMap((name) => {
  const rel = `${dir}/${name}`;
  return statSync(join(root, rel)).isDirectory() ? walk(rel) : [rel];
});
for (const dir of ['website/public', 'remotion-project/public']) {
  if (!existsSync(join(root, dir))) continue;
  for (const file of walk(dir)) {
    if (['.mp3', '.wav', '.m4a', '.aac', '.ogg'].includes(extname(file).toLowerCase()) && !notices.includes(file)) {
      problems.push(`${file} is a sound file that THIRD-PARTY-NOTICES.md does not name.`);
    }
  }
}

if (problems.length) {
  console.error('The third-party notices check failed:\n- ' + problems.join('\n- '));
  process.exit(1);
}
console.log('The third-party notices check passed. Every Swift package and version, every direct npm dependency, the model commit and every sound file is named, and no placeholder is left. It does not check that a licence is correct.');
