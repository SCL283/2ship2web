// The game never extracts assets itself on the web: the page does it before the game starts, with a separate module
// (mm/web/extractor). Extractor::CallZapd (desktop only, but still compiled) references zapd_report, so this stands in
// for ZAPD, which isn't linked into the game on the web.

#include <atomic>
#include <cstddef>

extern "C" int zapd_report(int argc, char** argv, std::atomic<size_t>* extractCount, std::atomic<size_t>* totalExtract) {
    return 1;
}
