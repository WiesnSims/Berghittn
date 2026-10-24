-- Das Gipfelbuch (board/board.js). Applied with: npx wrangler d1 migrations apply berghittn-board --remote
CREATE TABLE tickets (
	id TEXT PRIMARY KEY,
	mode TEXT NOT NULL,
	ip TEXT NOT NULL,
	created INTEGER NOT NULL,
	used INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX tickets_ip ON tickets (ip, created);
CREATE INDEX tickets_created ON tickets (created);

CREATE TABLE entries (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	mode TEXT NOT NULL,
	names TEXT NOT NULL,
	wave INTEGER NOT NULL,
	points INTEGER NOT NULL,
	kills INTEGER NOT NULL,
	headshots INTEGER NOT NULL,
	fav TEXT NOT NULL,
	players INTEGER NOT NULL,
	version TEXT NOT NULL,
	created INTEGER NOT NULL
);
CREATE INDEX entries_rank ON entries (mode, wave DESC, points DESC);
CREATE INDEX entries_week ON entries (mode, created);
