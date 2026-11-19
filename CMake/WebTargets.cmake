# Web (Emscripten) targets for 2Ship. Included from the root CMakeLists.txt after the game target exists.
#
# Outputs, in ${CMAKE_BINARY_DIR}/mm:
#   2ship.html, 2ship.js, 2ship.wasm, 2ship.data      the game (2ship.data holds 2ship.o2r and the controller database)
#   extractor-worker.js, 2ship-extractor.js/.wasm/.data   the ROM extractor, run in a Web Worker by the page
#
# The site contains no Nintendo content: the player's ROM is extracted in their browser (see mm/web/rom-setup.js).
# Adapted from ShipWeb (github.com/samfisher753/ShipWeb), the same port for Ship of Harkinian.

set(WEB_SRC_DIR ${CMAKE_SOURCE_DIR}/mm/web)
set(WEB_OUTPUT_DIR ${CMAKE_BINARY_DIR}/mm)

################################################################################
# ROM extractor: ZAPD + OTRExporter compiled to a standalone module
################################################################################
if(TARGET OTRExporter)
    target_include_directories(OTRExporter PRIVATE ${CMAKE_SOURCE_DIR}/ZAPDTR/lib/tinyxml2)
endif()
add_executable(2ship-extractor ${WEB_SRC_DIR}/extractor/ExtractorMain.cpp)
target_compile_definitions(2ship-extractor PRIVATE TWOSHIP_PORT_VERSION="${CMAKE_PROJECT_VERSION}")
target_link_libraries(2ship-extractor PRIVATE ZAPDLib)
target_link_options(2ship-extractor PRIVATE
    "--no-entry"
    "SHELL:-s ENVIRONMENT=worker"
    "SHELL:-s EXPORTED_RUNTIME_METHODS=FS,ccall"
    "SHELL:-s FORCE_FILESYSTEM=1"
    # The ROM (32-54MB), ZAPD's working data and the generated archive all live in memory at once.
    "SHELL:-s MAXIMUM_MEMORY=4GB"
    # ZAPD reads its asset descriptions from <cwd>/assets (see ExtractorMain.cpp).
    "SHELL:--preload-file ${CMAKE_SOURCE_DIR}/mm/assets/extractor@/work/assets"
    "SHELL:--preload-file ${CMAKE_SOURCE_DIR}/mm/assets/xml@/work/assets/xml"
)
set_target_properties(2ship-extractor PROPERTIES SUFFIX ".js" RUNTIME_OUTPUT_DIRECTORY ${WEB_OUTPUT_DIR})
set_property(TARGET 2ship-extractor APPEND PROPERTY LINK_DEPENDS ${CMAKE_SOURCE_DIR}/mm/assets/xml)
configure_file(${WEB_SRC_DIR}/extractor-worker.js ${WEB_OUTPUT_DIR}/extractor-worker.js COPYONLY)

################################################################################
# The game
################################################################################
# 2ship.o2r (the port's own assets: shaders, custom textures, ...) isn't built by the web toolchain: ZAPD is needed to
# build it, so build it natively first (target Generate2ShipOtr in a normal build), which leaves it in the source root.
set(WEB_2SHIP_O2R "${CMAKE_SOURCE_DIR}/2ship.o2r" CACHE FILEPATH "2ship.o2r to bundle with the web build")
if(NOT EXISTS ${WEB_2SHIP_O2R})
    message(FATAL_ERROR
        "2ship.o2r not found at ${WEB_2SHIP_O2R}.\n"
        "Build it with a normal (native) build first: cmake -B build-native && cmake --build build-native --target Generate2ShipOtr")
endif()

# The ZAPD stand-in that Extract.cpp links against (the real one lives in the extractor module).
target_sources(2ship PRIVATE ${WEB_SRC_DIR}/ZapdStub.cpp)

# Everything in this folder is bundled into 2ship.data. Files put there by hand are bundled too (e.g. a mm.o2r, to
# skip the ROM screen while developing; never publish such a build).
set(WEB_PRELOAD_DIR ${CMAKE_BINARY_DIR}/preload)
file(MAKE_DIRECTORY ${WEB_PRELOAD_DIR})

file(COPY ${WEB_2SHIP_O2R} DESTINATION ${WEB_PRELOAD_DIR})
if(EXISTS ${CMAKE_BINARY_DIR}/gamecontrollerdb.txt)
    file(COPY ${CMAKE_BINARY_DIR}/gamecontrollerdb.txt DESTINATION ${WEB_PRELOAD_DIR})
else()
    message(WARNING "gamecontrollerdb.txt wasn't downloaded: gamepads not in SDL's built-in list won't be recognised")
endif()

configure_file(${WEB_SRC_DIR}/version.js.in ${CMAKE_BINARY_DIR}/mm/web-version.js @ONLY)
target_link_options(2ship PRIVATE
    "SHELL:--preload-file ${WEB_PRELOAD_DIR}@/"
    "SHELL:--shell-file ${WEB_SRC_DIR}/shell.html"
    "SHELL:--pre-js ${CMAKE_BINARY_DIR}/mm/web-version.js"
    "SHELL:--pre-js ${WEB_SRC_DIR}/persistence.js"
    "SHELL:--pre-js ${WEB_SRC_DIR}/rom-setup.js"
    "-lidbfs.js"
)
# The page runs the ROM extractor when there are no extracted assets yet.
add_dependencies(2ship 2ship-extractor)
set_property(TARGET 2ship APPEND PROPERTY LINK_DEPENDS
    ${WEB_2SHIP_O2R}
    ${WEB_SRC_DIR}/shell.html
    ${CMAKE_BINARY_DIR}/mm/web-version.js
    ${WEB_SRC_DIR}/persistence.js
    ${WEB_SRC_DIR}/rom-setup.js
)
