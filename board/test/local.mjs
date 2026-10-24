// A local Gipfelbuch server for tests: `wrangler pages dev` on an empty site with a fresh local D1,
// its migrations applied. Used by board.test.mjs and tools/board_test.mjs.
import { execFileSync, spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('../..', import.meta.url));

function wrangler(args) {
	return execFileSync('npx', ['wrangler@latest', ...args], { cwd: ROOT, shell: true, stdio: 'pipe' }).toString();
}

export async function startBoard(port) {
	const dir = mkdtempSync(join(tmpdir(), 'gipfelbuch-'));
	const site = join(dir, 'site');
	const state = join(dir, 'state');
	mkdirSync(site);
	writeFileSync(join(site, 'index.html'), 'Gipfelbuch test');
	wrangler(['d1', 'migrations', 'apply', 'berghittn-board', '--local', '--persist-to', `"${state}"`]);
	const dev = spawn('npx', ['wrangler@latest', 'pages', 'dev', `"${site}"`, '--port', String(port), '--ip', '127.0.0.1',
		'--persist-to', `"${state}"`], { cwd: ROOT, shell: true });
	await new Promise((resolve, reject) => {
		const timer = setTimeout(() => reject(new Error('wrangler pages dev did not start')), 90_000);
		const watch = (chunk) => {
			if (/Ready on/i.test(String(chunk))) {
				clearTimeout(timer);
				resolve();
			}
		};
		dev.stdout.on('data', watch);
		dev.stderr.on('data', watch);
	});
	return {
		url: `http://127.0.0.1:${port}`,
		sql: async (command) => wrangler(['d1', 'execute', 'berghittn-board', '--local', '--persist-to', `"${state}"`,
			'--command', JSON.stringify(command.replace(/\s+/g, ' '))]),
		stop: () => {
			// shell: true on Windows starts a tree; kill all of it.
			if (process.platform === 'win32') {
				execFileSync('taskkill', ['/pid', String(dev.pid), '/t', '/f'], { stdio: 'ignore' });
			} else {
				dev.kill();
			}
			try {
				rmSync(dir, { recursive: true, force: true });
			} catch {
				// workerd may still hold the files for a moment; the temp folder is cleaned up later.
			}
		},
	};
}
