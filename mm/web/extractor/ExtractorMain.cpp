// Entry point of the web ROM extractor. It's a separate module (ZAPD + OTRExporter, no game) that runs inside a Web
// Worker (see mm/web/extractor-worker.js), so the page stays responsive during the minutes extraction takes.
//
// It does what Extractor::CallZapd does on desktop (mm/2s2h/Extractor/Extract.cpp): run ZAPD in-process on the ROM
// with the asset XMLs, producing mm.o2r. Idea and structure adapted from ShipWeb's Torch-based extractor
// (github.com/samfisher753/ShipWeb).

#include <atomic>
#include <cstddef>
#include <filesystem>
#include <string>
#include <vector>

#include <emscripten.h>

namespace fs = std::filesystem;

extern "C" int zapd_report(int argc, char** argv, std::atomic<size_t>* extractCount, std::atomic<size_t>* totalExtract);

// Paths inside the worker's in-memory file system. The worker writes the ROM to kRomPath. The asset descriptions
// (mm/assets/extractor and mm/assets/xml) are preloaded under kWorkDir/assets, which is ZAPD's working directory.
static const char* kRomPath = "/rom.z64";
static const char* kWorkDir = "/work";
static const char* kOutDir = "/out";

EM_JS(void, twoship_extract_progress, (int done, int total), { postMessage({ type: "progress", done, total }); });

// Called by ZAPD (patched, see web/patches) after each file it extracts, since nothing can poll its counters while it
// runs on this single thread.
extern "C" void ZAPD_Web_Progress(size_t done, size_t total) {
    static size_t sLastReported = 0;
    // Thousands of files would be thousands of messages; this is plenty for a progress bar.
    if (done == total || done >= sLastReported + 10) {
        sLastReported = done;
        twoship_extract_progress((int)done, (int)total);
    }
}

// Extracts kRomPath (big-endian, already validated) into kOutDir. versionStr is ZAPD's name for the ROM version
// ("N64_US" or "GC_US"); portVersion is the game version ("major.minor.patch") stored in the archive.
// Returns the archive name (mm.o2r), or an empty string if extraction failed.
extern "C" EMSCRIPTEN_KEEPALIVE const char* TwoShip_ExtractRom(const char* versionStr, const char* portVersion) {
    static std::string archiveName;
    archiveName.clear();

    const std::string otrFile = "mm.o2r";
    const std::string xmlPath = std::string("assets/xml/") + versionStr;
    const std::string confPath = std::string("assets/Config_") + versionStr + ".xml";

    std::error_code ec;
    fs::current_path(kWorkDir, ec);
    if (ec) {
        return archiveName.c_str();
    }

    // Same arguments as Extractor::CallZapd.
    std::vector<std::string> args = {
        "ZAPD", "ed",
        "-i",   xmlPath,
        "-b",   kRomPath,
        "-fl",  "assets/filelists",
        "-gsf", "0",
        "-rconf", confPath,
        "-se",  "OTR",
        "--otrfile", otrFile,
        "--portVer", portVersion,
        "-o",   "placeholder",
        "-osf", "placeholder",
    };
    std::vector<char*> argv;
    for (auto& arg : args) {
        argv.push_back(arg.data());
    }

    std::atomic<size_t> extractCount{ 0 }, totalExtract{ 0 };
    zapd_report((int)argv.size(), argv.data(), &extractCount, &totalExtract);

    fs::remove(kRomPath, ec); // free the memory as soon as possible
    if (!fs::exists(otrFile)) {
        return archiveName.c_str();
    }

    fs::create_directories(kOutDir, ec);
    fs::copy_file(otrFile, std::string(kOutDir) + "/" + otrFile, fs::copy_options::overwrite_existing, ec);
    if (ec) {
        return archiveName.c_str();
    }
    fs::remove(otrFile, ec);

    archiveName = otrFile;
    return archiveName.c_str();
}
