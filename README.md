# Berghittn

Browser-first wave-survival shooter. Design: see `GAME_DESIGN.md`.

## Toolchain (recorded at project start)

- Godot **4.7.2.stable.official.ed1daf0bf**, Compatibility renderer (WebGL2)
- Web export template variant: single-threaded, no GDExtension (`thread_support=false`)
- Node.js 24.21.0, wrangler 4.151.1 (run via `npx wrangler@latest`)

## Build

```
godot --headless --import                                   # first run only / after new assets
godot --headless --export-release "Web" export/index.html
```

Output goes to `export/` (gitignored).
