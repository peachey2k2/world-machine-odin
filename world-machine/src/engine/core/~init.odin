package core

import "../../modloader"
import "../../consts"
import "../../utils/signals"

import "core:os"
import "core:fmt"
import "core:strings"

// import "vendor:raylib"
import sdl "vendor:sdl2"

window : ^sdl.Window
renderer : ^sdl.Renderer

init::proc() {
    signals.init()
    set_ext_vars()
    // init_raylib()
    init_sdl()

    // modloader.load_mods()
    // modloader.init_functions()

    // render.init_atlas()
    // modloader.init_blocks()
}

// init_raylib::proc() {
//     raylib.InitWindow(800, 450, "World Machine")
//     raylib.SetTargetFPS(60)
// }

init_sdl::proc() {
    init_flags := sdl.InitFlags{
        .VIDEO,
        .AUDIO,
        .EVENTS,
        .JOYSTICK,
        .HAPTIC,
        .GAMECONTROLLER,
        .SENSOR,
        .TIMER,
    }
    if (sdl.Init(init_flags) < 0) {
        fmt.printf("SDL could not initialize! SDL_Error: %s\n", sdl.GetError())
        os.exit(1)
    }

    window = sdl.CreateWindow(
        strings.clone_to_cstring(consts.name),
        sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED,
        consts.window_size.x, consts.window_size.y,
        sdl.WINDOW_SHOWN
    )
    if (window == nil) {
        fmt.printf("Window could not be created! SDL_Error: %s\n", sdl.GetError())
        os.exit(1)
    }

    renderer = sdl.CreateRenderer(window, -1, sdl.RENDERER_ACCELERATED)
    if (renderer == nil) {
        fmt.printf("Renderer could not be created! SDL_Error: %s\n", sdl.GetError())
        os.exit(1)
    }

    // sdl.FillRect(surface, nil, sdl.MapRGB(surface.format, 0xFF, 0x00, 0xFF))
    sdl.SetRenderDrawColor(renderer, 0xFF, 0x00, 0xFF, 0xFF)
    sdl.RenderFillRect(renderer, nil)
    sdl.RenderPresent(renderer)
}

deinit::proc() {
    signals.deinit_everything()

    sdl.DestroyWindow(window)
    sdl.Quit()
}

set_ext_vars::proc() {
    // this whole system needs an overhaul at some point
    when ODIN_OS == .Windows {
        // TODO: Implement
    } else when ODIN_OS == .Linux {
        // os.set_env("__NV_PRIME_RENDER_OFFLOAD", "1")
        // os.set_env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    } else when ODIN_OS == .Darwin {
        // TODO: Implement
    }
}