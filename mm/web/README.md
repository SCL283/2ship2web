# 2Ship Web (WebAssembly port) — work in progress

Runs 2 Ship 2 Harkinian in a browser tab. **Status: written but never compiled.** It was prepared without an Emscripten
toolchain, so expect to fix build errors before it runs. See "Getting it to build" below.

The structure is adapted from [ShipWeb](https://github.com/samfisher753/ShipWeb), the same port for Ship of Harkinian.

## How it works

| Piece | What it does |
| --- | --- |
| `CMake/EmscriptenConfig.cmake` | Emscripten flags (WebGL2/GLES3, no threads, IndexedDB), and the dependencies the web has no packages for (SDL2, Ogg/Vorbis, libpng from Emscripten ports; spdlog, nlohmann_json, tinyxml2, libzip fetched). |
| `CMake/WebTargets.cmake` | The two web targets: the game (`2ship`) and the ROM extractor (`2ship-extractor`). |
| `mm/src/code/graph.c`, `main.c` | The frame loop is driven by the browser (`emscripten_set_main_loop`) instead of a `while` loop, with the game logic paced to `R_UPDATE_RATE`. |
| `mm/2s2h/BenPort.cpp` | No audio thread (audio is mixed on the main thread), interpolated frames are spread across browser frames, and the desktop extractor UI is skipped. |
| `mm/2s2h/mixer.c` | Opus decoding is stubbed (no opusfile port in Emscripten). |
| `mm/web/extractor/` | ZAPD + OTRExporter as a standalone module, run in a Web Worker to turn the player's ROM into `mm.o2r`. |
| `mm/web/rom-setup.js`, `persistence.js`, `shell.html` | ROM picker and validation (the same CRCs as `Extract.cpp`), browser storage (IndexedDB) for saves and the extracted assets, the page itself. |
| `mm/web/patches/` | Patches for the `libultraship` and `ZAPDTR` submodules (applied in CI, so no forks are needed). |
| `.github/workflows/web-pages.yml` | Builds and publishes to GitHub Pages. |

**No game data is hosted.** The page asks each player for their own Majora's Mask ROM (N64 NTSC-U 1.0 or GameCube
NTSC-U), extracts it locally in the browser, and keeps the result in that browser's storage. Never commit a ROM, `mm.o2r`
or extracted assets to the repo or the Pages site; the workflow refuses to publish any `.o2r` file by name.

## Hosting on GitHub Pages

1. Fork `HarbourMasters/2ship2harkinian` (or push this code to your own repo), on a branch named `web-port`.
2. In the repo: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
3. Push to `web-port` (or run the **web-pages** workflow manually from the Actions tab). The first build takes a long
   time (30+ minutes); later ones reuse caches.
4. The site appears at `https://<your-user>.github.io/<repo>/`. Open it, pick your ROM, wait a few minutes for the
   one-time extraction, and the game starts.

The build uses no threads, so it doesn't need the `COOP`/`COEP` headers that GitHub Pages can't set.

## Getting it to build

Locally (Linux, or WSL on Windows), with [emsdk](https://emscripten.org/docs/getting_started/downloads.html) 6.0.12 active:

```sh
git submodule update --init --recursive

# 1. native build of 2ship.o2r (the port's own assets; needs the normal build dependencies, see .github/workflows/apt-deps.txt)
cmake -S . -B build-native -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-native --target Generate2ShipOtr

# 2. patch the submodules for the web, then build
git -C libultraship apply --ignore-whitespace ../mm/web/patches/libultraship.patch
git -C ZAPDTR apply --ignore-whitespace ../mm/web/patches/zapdtr.patch
emcmake cmake -S . -B build-web -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-web --target 2ship 2ship-extractor

# 3. serve and open (any static server; the site needs no special headers)
cd build-web/mm && cp 2ship.html index.html && python3 -m http.server 8080
```

Open http://localhost:8080 and watch the browser console. When the build fails, the first error is usually the useful
one; fix it, re-run the `cmake --build` line, repeat. Most likely trouble spots, in order:

1. **ZAPD / OTRExporter for wasm** (CMake errors about PNG, StormLib, threads). This is the part with no ShipWeb
   precedent: ShipWeb extracts with Torch, 2Ship uses ZAPD.
2. Anything in 2Ship that uses threads or the desktop only (`std::thread`, sockets, file dialogs).
3. Link errors for libraries that exist natively but not as Emscripten ports.
4. Runtime: WebGL shader problems, out of memory (extractor), audio.

## Known gaps (not done yet)

- Menu entries that make no sense in a browser (open app folder, window/renderer backend, quit) are still shown.
- Custom audio / mods need threads or file access that the web build doesn't have.
- No gamepad hot-plug testing, mobile/touch controls, or fullscreen button.
- ShipWeb's own web-layer files have no license file; they were adapted here with credit. Ask the author
  (samfisher753) before publishing a public site built from them.
