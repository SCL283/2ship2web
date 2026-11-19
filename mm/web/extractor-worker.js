// Adapted from ShipWeb (github.com/samfisher753/ShipWeb), the same web port for Ship of Harkinian.
// Web Worker that extracts the game assets from the player's ROM with ZAPD + OTRExporter (2ship-extractor.js/.wasm).
//
// Message in:  { rom: ArrayBuffer (big-endian, validated), versionDir: "N64_US" or "GC_US", portVersion: "5.1.0" }
// Messages out: { type: "progress", done, total }
//               { type: "done", name: "mm.o2r", data: ArrayBuffer }
//               { type: "error", message }

self.onmessage = (event) => {
    const { rom, versionDir, portVersion } = event.data;

    self.Module = {
        // 2ship-extractor.data (the XML asset descriptions ZAPD reads) sits next to this script.
        print: (text) => console.log("[extractor]", text),
        printErr: (text) => console.error("[extractor]", text),
        onRuntimeInitialized() {
            try {
                Module.FS.writeFile("/rom.z64", new Uint8Array(rom));
                const name = Module.ccall("TwoShip_ExtractRom", "string", ["string", "string"], [versionDir, portVersion]);
                if (!name) {
                    postMessage({ type: "error", message: "The extraction failed." });
                    return;
                }
                const data = Module.FS.readFile("/out/" + name);
                postMessage({ type: "done", name, data: data.buffer }, [data.buffer]);
            } catch (e) {
                postMessage({ type: "error", message: String(e) });
            }
        },
        onAbort(what) {
            postMessage({ type: "error", message: "The extractor crashed: " + what });
        },
    };

    try {
        importScripts("2ship-extractor.js");
    } catch (e) {
        postMessage({ type: "error", message: "Couldn't load the extractor: " + e.message });
    }
};
