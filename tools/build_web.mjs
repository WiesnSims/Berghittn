// Exports the Web preset and prepares export/ for Cloudflare Pages.
// Usage: node tools/build_web.mjs
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, openSync, readSync, closeSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

// Pages rejects files over 25 MiB; GAME_DESIGN.md asks to flag anything above 20 MiB, so stay well below both.
const MAX_PART_BYTES = 16 * 1024 * 1024;
const FLAG_BYTES = 20 * 1024 * 1024;
const EXPORT_DIR = 'export';
const WASM = join(EXPORT_DIR, 'index.wasm');

rmSync(EXPORT_DIR, { recursive: true, force: true });
mkdirSync(EXPORT_DIR);
execFileSync('godot', ['--headless', '--export-release', 'Web', join(EXPORT_DIR, 'index.html')], { stdio: 'inherit' });

const size = statSync(WASM).size;
const count = Math.ceil(size / MAX_PART_BYTES);
const partSize = Math.ceil(size / count);
const names = [];
const fd = openSync(WASM, 'r');
for (let i = 0; i < count; i++) {
	const buf = Buffer.alloc(Math.min(partSize, size - i * partSize));
	readSync(fd, buf, 0, buf.length, i * partSize);
	const name = `index.wasm.part${i}`;
	writeFileSync(join(EXPORT_DIR, name), buf);
	names.push(name);
}
closeSync(fd);
rmSync(WASM);
writeFileSync(join(EXPORT_DIR, 'index.wasm.parts.json'), JSON.stringify(names));

for (const file of readdirSync('web').filter((f) => !f.startsWith('.'))) {
	copyFileSync(join('web', file), join(EXPORT_DIR, file));
}

let tooBig = false;
console.log(`\nwasm: ${(size / 1048576).toFixed(2)} MiB split into ${count} parts\n`);
for (const file of readdirSync(EXPORT_DIR).sort()) {
	const bytes = statSync(join(EXPORT_DIR, file)).size;
	const flag = bytes > FLAG_BYTES ? '  <-- over 20 MiB' : '';
	tooBig ||= bytes > FLAG_BYTES;
	console.log(`${(bytes / 1048576).toFixed(2).padStart(8)} MiB  ${file}${flag}`);
}
process.exit(tooBig ? 1 : 0);
