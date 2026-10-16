# Berghittn

Browser-first wave-survival shooter. Design: see `GAME_DESIGN.md`.

## Toolchain (recorded at project start)

- Godot **4.7.2.stable.official.ed1daf0bf**, Compatibility renderer (WebGL2)
- Web export template variant: single-threaded, no GDExtension (`thread_support=false`)
- Node.js 24.21.0, wrangler 4.151.1 (run via `npx wrangler@latest`)

## Build

```
godot --headless --import      # first run only / after adding assets
node tools/build_web.mjs       # headless export + wasm packing, prints every file size
```

Output goes to `export/` (gitignored). The script exits non-zero if any file is over 20 MiB.

### Why the wasm is packed

The Godot 4.7 engine wasm is ~37.7 MiB, over Cloudflare Pages' 25 MiB per-file limit.
`tools/build_web.mjs` gzips it (~9.7 MiB), splits it into parts if still above 16 MiB,
and writes `index.wasm.parts.json`. `web/wasm_parts_loader.js` (injected via the preset's
`html/head_include`) wraps `fetch` so Godot's loader receives the original wasm.
Gzip is done by us because Pages serves unknown extensions uncompressed.
Needs `DecompressionStream` (Chrome 80+, Firefox 113+, Safari 16.4+).

## Controls

WASD / arrows move, mouse look, Space jump, Shift sprint (forward only), C crouch
(not Ctrl: Ctrl+W closes the browser tab), E interact, Esc or P pause, F3 debug overlay
(FPS and position).

In browsers Esc never reaches the game; it releases pointer lock and the game pauses
because the lock is gone. Resume stays disabled for ~1 s since Chrome refuses an
immediate re-lock.

## Physics layers

1 `world`, 2 `player`, 3 `enemy`, 4 `player_blocker` (window openings: blocks players,
lets enemies through later).

## Deploy

Cloudflare Pages project `berghittn` -> https://berghittn.pages.dev

```
npx wrangler@latest pages deploy export --project-name berghittn --branch main --commit-dirty=true
```

Note: in wrangler 4.15x, `pages project create` delegates to Workers by default; the
project was created once with `--force` to get a classic Pages project. Do not pass
`--force` on deploys.
