// Runs a networked Godot test (M7) against the relay running locally in `wrangler dev`:
//     node tools/net_test.mjs [test scene, default res://tests/net_lobby.tscn]
// Set RELAY_URL to use a relay that is already running. The scene is started once per role: host,
// then guest with the code the host prints, then (after the host prints STARTED) a late joiner.
// net_four starts three guests (guest1..guest3) for four players.
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';

const scene = process.argv[2] || 'res://tests/net_lobby.tscn';
const PORT = 8790;
let relay = process.env.RELAY_URL;
let dev;

function godot(role, extra = []) {
	const args = ['--headless', scene, '--', `--relay=${relay}`, `--role=${role}`, ...extra];
	const child = spawn('godot', args, { stdio: ['ignore', 'pipe', 'pipe'] });
	const lines = createInterface({ input: child.stdout });
	const listeners = [];
	lines.on('line', (line) => {
		console.log(`[${role}] ${line}`);
		for (const l of listeners) {
			l(line);
		}
	});
	child.stderr.on('data', (d) => process.stderr.write(`[${role}!] ${d}`));
	const exited = new Promise((resolve) => child.on('exit', (code) => resolve(code)));
	const line = (pattern) => new Promise((resolve) => listeners.push((l) => {
		const m = l.match(pattern);
		if (m) {
			resolve(m);
		}
	}));
	return { child, exited, line };
}

async function main() {
	if (!relay) {
		dev = spawn('npx', ['wrangler@latest', 'dev', '--port', String(PORT), '--ip', '127.0.0.1'], { cwd: 'relay', shell: true });
		await new Promise((resolve, reject) => {
			const timer = setTimeout(() => reject(new Error('wrangler dev did not start')), 90_000);
			const watch = (chunk) => {
				if (/Ready on/i.test(String(chunk))) {
					clearTimeout(timer);
					resolve();
				}
			};
			dev.stdout.on('data', watch);
			dev.stderr.on('data', watch);
		});
		relay = `ws://127.0.0.1:${PORT}`;
	}
	const host = godot('host');
	const [, code] = await host.line(/^ROOM (\d+)/);
	const guests = scene.includes('net_four') ? ['guest1', 'guest2', 'guest3'] : ['guest'];
	const runs = [host.exited, ...guests.map((role) => godot(role, [`--room=${code}`]).exited)];
	// A late joiner once the match runs: turned away (net_lobby), or waiting for the next one (net_nomoi).
	const late = /net_(lobby|nomoi)/.test(scene);
	if (late) {
		await host.line(/^STARTED/);
		runs.push(godot('late', [`--room=${code}`]).exited);
	}
	const results = await Promise.all(runs);
	console.log(`exit codes host/${guests.join('/')}${late ? '/late' : ''}: ${results.join('/')}`);
	return results.every((c) => c === 0);
}

const timeout = setTimeout(() => {
	console.log('FAIL: timed out');
	process.exit(1);
}, Number(process.env.NET_TEST_TIMEOUT_MS || 240_000));
const ok = await main().catch((e) => {
	console.log(`FAIL: ${e.message}`);
	return false;
});
clearTimeout(timeout);
if (dev) {
	if (process.platform === 'win32') {
		spawn('taskkill', ['/pid', String(dev.pid), '/t', '/f']);
	} else {
		dev.kill();
	}
}
console.log(ok ? 'ALL PASS' : 'FAILED');
process.exit(ok ? 0 : 1);
