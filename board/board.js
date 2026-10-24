// Das Gipfelbuch (GAME_DESIGN section 12): the global leaderboard, in the Pages project's D1 database
// (binding BOARD, schema in board/migrations). Called by the Pages Function functions/api/board/[action].js:
//     POST /api/board/ticket  {mode}                       -> {ticket}
//     POST /api/board/entry   {ticket, names, wave, ...}   -> {id, rank, week_rank}
//     GET  /api/board/list?mode=solo|coop&range=all|week   -> {entries: [...]}
// A browser game cannot stop cheating; the tickets only make a faked result harder (section 12).

export const MODES = ['solo', 'coop'];
export const LIST_SIZE = 50;
export const NAME_MAX = 16;
export const MAX_PLAYERS = 4;
// Every wave after the first needs its 30 s break before it; a little less to be safe.
export const SECONDS_PER_WAVE = 25;
// A ticket is good this long after wave 1 started (s), and is removed a while after that.
export const TICKET_LIFE = 12 * 3600;
export const TICKETS_PER_HOUR = 30;
const MAX_WAVE = 999;
const MAX_TEXT = 48;
// Swear words and worse (after folding look-alike digits): such a name becomes "Wanderer".
const BANNED = [
	'fuck', 'cunt', 'shit', 'bitch', 'nigg', 'fagg', 'retard', 'hitler', 'nazi', 'fotze', 'wichs',
	'hurensohn', 'schwuchtel', 'kanake', 'arschloch', 'spast', 'missgeburt',
];
const LOOKALIKE = { '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', '$': 's', '!': 'i' };
export const FALLBACK_NAME = 'Wanderer';

export async function handleBoard(request, env, action) {
	try {
		if (action === 'list' && request.method === 'GET') {
			return json(await list(env, new URL(request.url)));
		}
		if (request.method !== 'POST') {
			return json({ error: 'method' }, 405);
		}
		const body = await request.json().catch(() => null);
		if (!body || typeof body !== 'object') {
			return json({ error: 'body' }, 400);
		}
		if (action === 'ticket') {
			return await ticket(env, request, body);
		}
		if (action === 'entry') {
			return await entry(env, body);
		}
		return json({ error: 'action' }, 404);
	} catch (error) {
		console.error(error);
		return json({ error: 'server' }, 500);
	}
}

// Monday 00:00 UTC of this week, in seconds.
export function weekStart(now = Date.now()) {
	const day = new Date(now);
	const sinceMonday = (day.getUTCDay() + 6) % 7;
	return Math.floor(Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate() - sinceMonday) / 1000);
}

// Printable, trimmed, at most NAME_MAX characters; a banned word turns it into FALLBACK_NAME.
export function cleanName(value) {
	const name = [...String(value ?? '').replace(/[\p{C}]/gu, '').trim()].slice(0, NAME_MAX).join('').trim();
	const folded = [...name.toLowerCase()].map((c) => LOOKALIKE[c] ?? c).join('').replace(/[^\p{L}]/gu, '');
	if (BANNED.some((word) => folded.includes(word))) {
		return FALLBACK_NAME;
	}
	return name;
}

// The most points a run could plausibly hold at this wave, per player (generous: kills, hits,
// streaks, the Venedigermandl and the events all pay).
export function maxPoints(wave, players) {
	return players * (5000 + 1500 * wave * wave);
}

function seconds() {
	return Math.floor(Date.now() / 1000);
}

function int(value, max) {
	return Number.isInteger(value) && value >= 0 && value <= max ? value : null;
}

async function ticket(env, request, body) {
	if (!MODES.includes(body.mode)) {
		return json({ error: 'mode' }, 400);
	}
	const now = seconds();
	const ip = await hash(request.headers.get('CF-Connecting-IP') || 'local');
	const recent = await env.BOARD.prepare('SELECT COUNT(*) AS n FROM tickets WHERE ip = ? AND created > ?')
		.bind(ip, now - 3600).first('n');
	if (recent >= TICKETS_PER_HOUR) {
		return json({ error: 'busy' }, 429);
	}
	const id = crypto.randomUUID();
	await env.BOARD.batch([
		env.BOARD.prepare('DELETE FROM tickets WHERE created < ?').bind(now - 2 * TICKET_LIFE),
		env.BOARD.prepare('INSERT INTO tickets (id, mode, ip, created) VALUES (?, ?, ?, ?)').bind(id, body.mode, ip, now),
	]);
	return json({ ticket: id });
}

async function entry(env, body) {
	const now = seconds();
	const found = typeof body.ticket === 'string'
		? await env.BOARD.prepare('SELECT mode, created, used FROM tickets WHERE id = ?').bind(body.ticket).first()
		: null;
	if (!found) {
		return json({ error: 'ticket' }, 403);
	}
	if (found.used || now - found.created > TICKET_LIFE) {
		return json({ error: 'ticket_used' }, 403);
	}
	const mode = found.mode;
	const names = Array.isArray(body.names) ? body.names.slice(0, MAX_PLAYERS).map(cleanName) : [];
	const players = mode === 'solo' ? 1 : names.length;
	const wave = int(body.wave, MAX_WAVE);
	const points = int(body.points, Number.MAX_SAFE_INTEGER);
	const kills = int(body.kills, Number.MAX_SAFE_INTEGER);
	const headshots = int(body.headshots, Number.MAX_SAFE_INTEGER);
	// The Bsundan killed (1.2): games before 1.2 do not send it.
	const bsundan = body.bsundan === undefined ? 0 : int(body.bsundan, Number.MAX_SAFE_INTEGER);
	// Co-op: everyone still in the room at the end (the others may have left, so one is fine too).
	if (players < 1 || names.length !== players || !wave || points === null || kills === null || headshots === null || headshots > kills
		|| bsundan === null || bsundan > kills) {
		return json({ error: 'entry' }, 400);
	}
	// Could this wave have been reached since the ticket, and do the points fit it?
	if (now - found.created < (wave - 1) * SECONDS_PER_WAVE || points > maxPoints(wave, players)) {
		return json({ error: 'implausible' }, 422);
	}
	// Taken once: the update only counts if the ticket was still unused.
	const claim = await env.BOARD.prepare('UPDATE tickets SET used = 1 WHERE id = ? AND used = 0').bind(body.ticket).run();
	if (claim.meta.changes !== 1) {
		return json({ error: 'ticket_used' }, 403);
	}
	const fav = String(body.fav ?? '').replace(/[^\w]/g, '').slice(0, MAX_TEXT);
	const version = String(body.version ?? '').replace(/[^\w.-]/g, '').slice(0, MAX_TEXT);
	const saved = await env.BOARD.prepare(
		'INSERT INTO entries (mode, names, wave, points, kills, headshots, bsundan, fav, players, version, created) '
		+ 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id',
	).bind(mode, JSON.stringify(names), wave, points, kills, headshots, bsundan, fav, players, version, now).first('id');
	return json({
		id: saved,
		rank: await rank(env, mode, wave, points, 0),
		week_rank: await rank(env, mode, wave, points, weekStart()),
	});
}

// The place of a just saved entry: the entries with a further wave, or the same wave and at least
// as many points (an earlier one keeps its place on a tie), the entry itself among them.
async function rank(env, mode, wave, points, since) {
	return env.BOARD.prepare(
		'SELECT COUNT(*) AS n FROM entries WHERE mode = ? AND created >= ? AND (wave > ? OR (wave = ? AND points >= ?))',
	).bind(mode, since, wave, wave, points).first('n');
}

async function list(env, url) {
	const mode = url.searchParams.get('mode');
	if (!MODES.includes(mode)) {
		return { error: 'mode' };
	}
	const since = url.searchParams.get('range') === 'week' ? weekStart() : 0;
	const { results } = await env.BOARD.prepare(
		'SELECT id, names, wave, points, kills, headshots, bsundan, fav, players, created FROM entries '
		+ 'WHERE mode = ? AND created >= ? ORDER BY wave DESC, points DESC, id ASC LIMIT ?',
	).bind(mode, since, LIST_SIZE).all();
	return { entries: results.map((row) => ({ ...row, names: JSON.parse(row.names) })) };
}

async function hash(text) {
	const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`berghittn:${text}`));
	return [...new Uint8Array(digest).slice(0, 12)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function json(data, status = 200) {
	return new Response(JSON.stringify(data), {
		status,
		headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
	});
}
