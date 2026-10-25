-- Die Bsundan (1.2): the rare variants killed in the run (solo: the player's, co-op: the team's).
-- Entries from before 1.2 have 0. Applied with: npx wrangler d1 migrations apply berghittn-board --remote
ALTER TABLE entries ADD COLUMN bsundan INTEGER NOT NULL DEFAULT 0;
