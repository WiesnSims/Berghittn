// Das Gipfelbuch's Functions against a local D1 in `wrangler pages dev` (nothing deployed):
//     node --test board/test/board.test.mjs
// Set BOARD_URL to test a running server instead (e.g. http://127.0.0.1:8788; its database is
// written to).
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { cleanName, maxPoints, weekStart, LIST_SIZE, TICKETS_PER_HOUR } from '../board.js';
import { startBoard } from './local.mjs';

let base = process.env.BOARD_URL;
let server;

before(async () => {
	if (!base) {
		server = await startBoard(8789);
		base = server.url;
	}
});

after(() => server?.stop());

// Each request comes from its own made-up address, so the ticket limit only bites where a test wants it.
let address = 0;
function post(path, body, ip = `10.0.${Math.floor(++address / 250)}.${address % 250}`) {
	return fetch(`${base}/api/board/${path}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': ip },
		body: JSON.stringify(body),
	});
}

async function ticket(mode = 'solo') {
	const response = await post('ticket', { mode });
	assert.equal(response.status, 200);
	return (await response.json()).ticket;
}

function run(fields = {}) {
	return { names: ['Sepp'], wave: 1, points: 300, kills: 4, headshots: 1, fav: 'WEAPON_PISTOLE', version: '1.1.1', ...fields };
}

async function list(mode, range = 'all') {
	return (await (await fetch(`${base}/api/board/list?mode=${mode}&range=${range}`)).json()).entries;
}

test('names: trimmed, at most 16 characters, swear words become Wanderer', () => {
	assert.equal(cleanName('  Resi  '), 'Resi');
	assert.equal(cleanName('Hansi\u0000​der Große, Bergführer'), 'Hansider Große,');
	assert.equal(cleanName('F0tze'), 'Wanderer');
	assert.equal(cleanName('x_h1tl3r_x'), 'Wanderer');
	assert.equal(cleanName('Waidmannsheil'), 'Waidmannsheil');
});

test('the week starts on Monday 00:00 UTC', () => {
	// Friday 2026-10-23 15:00 UTC -> Monday 2026-10-19.
	assert.equal(weekStart(Date.UTC(2026, 9, 23, 15)), Date.UTC(2026, 9, 19) / 1000);
	assert.equal(weekStart(Date.UTC(2026, 9, 19, 0, 0, 1)), Date.UTC(2026, 9, 19) / 1000);
	assert.equal(weekStart(Date.UTC(2026, 9, 25, 23)), Date.UTC(2026, 9, 19) / 1000);
});

test('a solo run is saved once and gets its place', async () => {
	const t = await ticket();
	const first = await post('entry', { ticket: t, ...run({ names: ['Erste'], points: 900 }) });
	assert.equal(first.status, 200);
	const saved = await first.json();
	assert.ok(saved.id > 0);
	assert.ok(saved.rank >= 1 && saved.week_rank >= 1 && saved.week_rank <= saved.rank);
	assert.equal((await post('entry', { ticket: t, ...run() })).status, 403, 'a ticket counts once');
	const entries = await list('solo');
	const mine = entries.find((e) => e.id === saved.id);
	assert.deepEqual(mine.names, ['Erste']);
	assert.equal(mine.wave, 1);
	assert.equal(mine.players, 1);
});

test('ranked by wave, then points; an earlier entry keeps its place on a tie', async () => {
	const a = await (await post('entry', { ticket: await ticket(), ...run({ points: 4000 }) })).json();
	const b = await (await post('entry', { ticket: await ticket(), ...run({ points: 4100 }) })).json();
	const c = await (await post('entry', { ticket: await ticket(), ...run({ points: 4000 }) })).json();
	assert.equal(b.rank, a.rank, 'more points goes ahead of a');
	assert.equal(c.rank, a.rank + 2, 'the same points: after a (and b)');
	const ids = (await list('solo')).map((e) => e.id);
	assert.ok(ids.indexOf(b.id) < ids.indexOf(a.id) && ids.indexOf(a.id) < ids.indexOf(c.id));
});

test('refused: no ticket, the wrong numbers, too fast for the wave, too many points', async () => {
	assert.equal((await post('entry', { ticket: 'nope', ...run() })).status, 403);
	assert.equal((await post('entry', { ticket: await ticket(), ...run({ headshots: 9, kills: 4 }) })).status, 400);
	assert.equal((await post('entry', { ticket: await ticket(), ...run({ wave: 0 }) })).status, 400);
	assert.equal((await post('entry', { ticket: await ticket(), ...run({ points: -5 }) })).status, 400);
	assert.equal((await post('entry', { ticket: await ticket(), ...run({ names: ['A', 'B'] }) })).status, 400, 'solo is one name');
	assert.equal((await post('entry', { ticket: await ticket(), ...run({ wave: 3 }) })).status, 422, 'wave 3 right after wave 1 began');
	assert.equal((await post('entry', { ticket: await ticket(), ...run({ points: maxPoints(1, 1) + 1 }) })).status, 422);
	assert.equal((await post('ticket', { mode: 'versus' })).status, 400);
});

test('the Bsundan killed (1.2): kept, 0 from older games, never more than the kills', async () => {
	const with_ = await (await post('entry', { ticket: await ticket(), ...run({ bsundan: 2 }) })).json();
	const without = await (await post('entry', { ticket: await ticket(), ...run() })).json();
	const entries = await list('solo');
	assert.equal(entries.find((e) => e.id === with_.id).bsundan, 2);
	assert.equal(entries.find((e) => e.id === without.id).bsundan, 0);
	assert.equal((await post('entry', { ticket: await ticket(), ...run({ bsundan: 5, kills: 4 }) })).status, 400);
	assert.equal((await post('entry', { ticket: await ticket(), ...run({ bsundan: -1 }) })).status, 400);
});

test('co-op: one entry for the group, on its own board', async () => {
	const t = await ticket('coop');
	const response = await post('entry', { ticket: t, ...run({ names: ['Resi', 'Sepp', '–'], points: 2000 }) });
	assert.equal(response.status, 200);
	const { id } = await response.json();
	const mine = (await list('coop')).find((e) => e.id === id);
	assert.deepEqual(mine.names, ['Resi', 'Sepp', '–']);
	assert.equal(mine.players, 3);
	assert.ok(!(await list('solo')).some((e) => e.id === id), 'not on the solo board');
});

test('this week leaves out older entries; at most 50 are listed', async () => {
	// An entry from last month, written straight into the database.
	const old = Math.floor(Date.UTC(2026, 8, 1) / 1000);
	await server?.sql(`INSERT INTO entries (mode, names, wave, points, kills, headshots, fav, players, version, created)
		VALUES ('solo', '["Alt"]', 50, 99999, 500, 100, '', 1, '1.1', ${old})`);
	if (server) {
		const all = await list('solo');
		assert.deepEqual(all[0].names, ['Alt'], 'all time: the old one on top');
		assert.ok(!(await list('solo', 'week')).some((e) => e.names[0] === 'Alt'), 'this week: not there');
	}
	for (let i = 0; i < LIST_SIZE + 2; i++) {
		await post('entry', { ticket: await ticket(), ...run({ points: i }) });
	}
	assert.equal((await list('solo')).length, LIST_SIZE);
});

test(`at most ${TICKETS_PER_HOUR} tickets an hour from one address`, async () => {
	for (let i = 0; i < TICKETS_PER_HOUR; i++) {
		assert.equal((await post('ticket', { mode: 'solo' }, '10.9.9.9')).status, 200);
	}
	assert.equal((await post('ticket', { mode: 'solo' }, '10.9.9.9')).status, 429);
});
