// After `vite build` and the SSR build: write real HTML for each route into dist/.
// The browser app still takes over and replaces it, so this is for crawlers, link previews and no-JS readers.
import { mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(root, 'dist');
const { render, ROUTE_META } = await import(pathToFileURL(join(root, 'dist-ssr/entry-server.js')).href);

const template = readFileSync(join(dist, 'index.html'), 'utf8');
const esc = (s) => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;');

for (const route of Object.keys(ROUTE_META)) {
  const meta = ROUTE_META[route];
  const html = template
    .replace(/<title>.*?<\/title>/s, `<title>${esc(meta.title)}</title>`)
    .replace(/(<meta name="description" content=")[^"]*(")/, `$1${esc(meta.description)}$2`)
    .replace(/(<meta property="og:title" content=")[^"]*(")/, `$1${esc(meta.title)}$2`)
    .replace(/(<meta property="og:description" content=")[^"]*(")/, `$1${esc(meta.description)}$2`)
    .replace('<div id="root"></div>', `<div id="root">${render(route)}</div>`);
  const out = route === '/' ? join(dist, 'index.html') : join(dist, route.slice(1), 'index.html');
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, html);
  console.log('prerendered', route);
}
rmSync(join(root, 'dist-ssr'), { recursive: true, force: true });
