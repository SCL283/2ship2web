# Emscripten setup for the 2Ship web build (WebAssembly).
# Adapted from ShipWeb (github.com/samfisher753/ShipWeb), which does the same for Ship of Harkinian.
if(EMSCRIPTEN)
    message(STATUS "Configuring 2Ship for Emscripten (WebAssembly)")
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build static libraries" FORCE)
    set(CMAKE_POSITION_INDEPENDENT_CODE OFF CACHE BOOL "" FORCE)
    set(SPDLOG_BUILD_SHARED OFF CACHE BOOL "" FORCE)
    set(TINYXML2_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(YAML_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(LIBZIP_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

    # Optimize non-Debug builds. (-O3 makes the decomp code build much slower for little gain on wasm.)
    set(CMAKE_C_FLAGS_RELEASE "-O2 -DNDEBUG")
    set(CMAKE_CXX_FLAGS_RELEASE "-O2 -DNDEBUG")
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(WEB_ASSERTIONS 1)
    else()
        set(WEB_ASSERTIONS 0)
    endif()

    # Compile & Link options for Emscripten
    add_compile_options(
        "SHELL:-s USE_ZLIB=1"
        "SHELL:-s USE_LIBPNG=1"
        "SHELL:-s USE_OGG=1"
        "SHELL:-s USE_VORBIS=1"
        "SHELL:-s USE_SDL=2"
        "SHELL:-s MAX_WEBGL_VERSION=2"
        "SHELL:-s FULL_ES3=1"
        "SHELL:-s NO_DISABLE_EXCEPTION_CATCHING=1"
    )

    add_link_options(
        "SHELL:-s USE_ZLIB=1"
        "SHELL:-s USE_LIBPNG=1"
        "SHELL:-s USE_OGG=1"
        "SHELL:-s USE_VORBIS=1"
        "SHELL:-s USE_SDL=2"
        "SHELL:-s MAX_WEBGL_VERSION=2"
        "SHELL:-s FULL_ES3=1"
        "SHELL:-s INITIAL_MEMORY=256MB"
        "SHELL:-s ALLOW_MEMORY_GROWTH=1"
        "SHELL:-s STACK_SIZE=16MB"
        "SHELL:-s NO_DISABLE_EXCEPTION_CATCHING=1"
        "SHELL:-s ASSERTIONS=${WEB_ASSERTIONS}"
        "SHELL:-s EXIT_RUNTIME=0"
        # Keep function names in the wasm so stack traces / profiles are readable.
        "--profiling-funcs"
        "--bind"
    )

    # Output HTML + JS + Wasm
    set(CMAKE_EXECUTABLE_SUFFIX ".html")

    # Provide ZLIB variables so find_package(ZLIB) succeeds
    set(ZLIB_FOUND TRUE CACHE BOOL "" FORCE)
    set(ZLIB_VERSION_STRING "1.3.1" CACHE STRING "" FORCE)
    set(ZLIB_VERSION "1.3.1" CACHE STRING "" FORCE)
    set(ZLIB_INCLUDE_DIR "${EMSCRIPTEN_SYSROOT}/include" CACHE PATH "" FORCE)
    set(ZLIB_INCLUDE_DIRS "${EMSCRIPTEN_SYSROOT}/include" CACHE PATH "" FORCE)
    set(ZLIB_LIBRARIES "z" CACHE STRING "" FORCE)
    set(ZLIB_LIBRARY "z" CACHE STRING "" FORCE)
    if(NOT TARGET ZLIB::ZLIB)
        add_library(ZLIB::ZLIB INTERFACE IMPORTED)
    endif()

    # libpng comes from Emscripten's port (-s USE_LIBPNG=1), which isn't built yet at configure time, so find_package(PNG)
    # (used by ZAPD, the extractor) couldn't find it. Preset what FindPNG would search for.
    set(PNG_FOUND TRUE CACHE BOOL "" FORCE)
    set(PNG_PNG_INCLUDE_DIR "${EMSCRIPTEN_SYSROOT}/include" CACHE PATH "" FORCE)
    set(PNG_INCLUDE_DIRS "${EMSCRIPTEN_SYSROOT}/include" CACHE PATH "" FORCE)
    set(PNG_LIBRARY "png" CACHE STRING "" FORCE)
    set(PNG_LIBRARIES "png" CACHE STRING "" FORCE)
    if(NOT TARGET PNG::PNG)
        add_library(PNG::PNG INTERFACE IMPORTED)
    endif()

    # Provide SDL2 & SDL2_net imported targets
    set(SDL2_FOUND TRUE CACHE BOOL "" FORCE)
    set(SDL2_net_FOUND TRUE CACHE BOOL "" FORCE)
    if(NOT TARGET SDL2::SDL2)
        add_library(SDL2::SDL2 INTERFACE IMPORTED)
    endif()
    if(NOT TARGET SDL2_net::SDL2_net)
        add_library(SDL2_net::SDL2_net INTERFACE IMPORTED)
    endif()

    # Provide Ogg, Vorbis, Opus imported targets
    set(Ogg_FOUND TRUE CACHE BOOL "" FORCE)
    set(Vorbis_FOUND TRUE CACHE BOOL "" FORCE)
    set(Opus_FOUND TRUE CACHE BOOL "" FORCE)
    set(OpusFile_FOUND TRUE CACHE BOOL "" FORCE)
    foreach(lib Ogg::ogg Vorbis::vorbis Vorbis::vorbisenc Vorbis::vorbisfile Opus::opus Opusfile::Opusfile)
        if(NOT TARGET ${lib})
            add_library(${lib} INTERFACE IMPORTED)
        endif()
    endforeach()

    # Pre-fetch nlohmann_json, tinyxml2, libzip via FetchContent if not found
    include(FetchContent)

    # spdlog (ShipWeb pins v1.16.0: it bundles fmt 12, which clang >= 21 needs for fmt's consteval format checks)
    FetchContent_Declare(
        spdlog
        GIT_REPOSITORY https://github.com/gabime/spdlog.git
        GIT_TAG v1.16.0
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(spdlog)

    # nlohmann_json
    FetchContent_Declare(
        nlohmann_json
        GIT_REPOSITORY https://github.com/nlohmann/json.git
        GIT_TAG v3.11.3
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(nlohmann_json)

    # tinyxml2
    FetchContent_Declare(
        tinyxml2
        GIT_REPOSITORY https://github.com/leethomason/tinyxml2.git
        GIT_TAG 10.0.0
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(tinyxml2)

    # libzip
    set(BUILD_TOOLS OFF CACHE BOOL "" FORCE)
    set(BUILD_REGRESS OFF CACHE BOOL "" FORCE)
    set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(BUILD_DOC OFF CACHE BOOL "" FORCE)
    FetchContent_Declare(
        libzip
        GIT_REPOSITORY https://github.com/nih-at/libzip.git
        GIT_TAG v1.10.1
        OVERRIDE_FIND_PACKAGE
    )
    FetchContent_MakeAvailable(libzip)
    if(TARGET zip AND NOT TARGET libzip::zip)
        add_library(libzip::zip ALIAS zip)
    endif()

    add_compile_definitions(EMSCRIPTEN=1 __EMSCRIPTEN__=1 ENABLE_OPENGL=1 GFX_OPENGL=1 USE_OPENGLES=1)
endif()
