// Exports the Web preset and prepares export/ for Cloudflare Pages.
// Usage: node tools/build_web.mjs
import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { gzipSync, constants } from 'node:zlib';

// Pages rejects files over 25 MiB; GAME_DESIGN.md asks to flag anything above 20 MiB, so stay well below both.
// The gzipped wasm currently fits in one part; splitting kicks in if the engine grows.
const MAX_PART_BYTES = 16 * 1024 * 1024;
const FLAG_BYTES = 20 * 1024 * 1024;
const EXPORT_DIR = 'export';
const WASM = join(EXPORT_DIR, 'index.wasm');

rmSync(EXPORT_DIR, { recursive: true, force: true });
mkdirSync(EXPORT_DIR);
// Co-op (M7): the relay only lets players with the host's build into a room, so a browser running a
// stale cached build is told to reload instead of desyncing. Read by Net, packed via include_filter.
const commit = execFileSync('git', ['rev-parse', '--short', 'HEAD']).toString().trim();
const buildId = `${commit}-${Date.now().toString(36)}`;
writeFileSync('build_id.txt', buildId);
try {
	execFileSync('godot', ['--headless', '--export-release', 'Web', join(EXPORT_DIR, 'index.html')], { stdio: 'inherit' });
} finally {
	rmSync('build_id.txt', { force: true });
}
console.log(`build id: ${buildId}`);

const size = statSync(WASM).size;
// Pages serves unknown extensions as octet-stream without compression, so we gzip ourselves
// and the loader inflates with the browser's DecompressionStream.
const gz = gzipSync(readFileSync(WASM), { level: constants.Z_BEST_COMPRESSION });
const count = Math.ceil(gz.length / MAX_PART_BYTES);
const partSize = Math.ceil(gz.length / count);
const names = [];
for (let i = 0; i < count; i++) {
	const name = `index.wasm.part${i}`;
	writeFileSync(join(EXPORT_DIR, name), gz.subarray(i * partSize, (i + 1) * partSize));
	names.push(name);
}
rmSync(WASM);
writeFileSync(join(EXPORT_DIR, 'index.wasm.parts.json'), JSON.stringify({ encoding: 'gzip', parts: names }));

for (const file of readdirSync('web').filter((f) => !f.startsWith('.'))) {
	copyFileSync(join('web', file), join(EXPORT_DIR, file));
}

let tooBig = false;
console.log(`\nwasm: ${(size / 1048576).toFixed(2)} MiB, gzipped ${(gz.length / 1048576).toFixed(2)} MiB in ${count} part(s)\n`);
for (const file of readdirSync(EXPORT_DIR).sort()) {
	const bytes = statSync(join(EXPORT_DIR, file)).size;
	const flag = bytes > FLAG_BYTES ? '  <-- over 20 MiB' : '';
	tooBig ||= bytes > FLAG_BYTES;
	console.log(`${(bytes / 1048576).toFixed(2).padStart(8)} MiB  ${file}${flag}`);
}
process.exit(tooBig ? 1 : 0);
