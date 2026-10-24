// Das Gipfelbuch end to end on this machine: a local server (board/test/local.mjs), then the game's
// solo test against it, then a co-op match over the local relay that sends the group's entry:
//     node tools/board_test.mjs
import { spawn } from 'node:child_process';
import { startBoard } from '../board/test/local.mjs';

const PORT = 8789;

function run(command, args, env = {}) {
	return new Promise((resolve) => {
		const child = spawn(command, args, { stdio: 'inherit', env: { ...process.env, ...env } });
		child.on('exit', (code) => resolve(code));
	});
}

const board = await startBoard(PORT);
let ok = false;
try {
	const solo = await run('godot', ['--headless', '--fixed-fps', '60', 'res://tests/board_solo.tscn', '--', `--board=${board.url}`]);
	const coop = await run(process.execPath, ['tools/net_test.mjs', 'res://tests/net_board.tscn'], { BOARD_URL: board.url });
	console.log(`board_solo: ${solo}, net_board: ${coop}`);
	ok = solo === 0 && coop === 0;
} finally {
	board.stop();
}
console.log(ok ? 'BOARD PASS' : 'BOARD FAIL');
process.exit(ok ? 0 : 1);
