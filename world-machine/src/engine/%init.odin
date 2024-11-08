package engine

import "../utils"

import "core:os"
import "core:fmt"
import "core:strings"
import "core:thread"
import "core:time"

// import "vendor:raylib"
import sdl "vendor:sdl2"

APP_NAME : cstring = "World Machine"
VERSION := "0.0.1"
WINDOW_SIZE := [2]i32{800, 450}

@(private) _window : ^sdl.Window
@(private) _renderer : ^sdl.Renderer

@(private) _window_should_close := false

@(private) _world_should_tick := false
@(private) _ticks_thread : ^thread.Thread

@(private) _world_should_update := false
@(private) _world_thread : ^thread.Thread

init::proc() {
    utils.init_signals()
    utils.init_logger()
    set_ext_vars()
    init_sdl()

    // modloader.load_mods()
    // modloader.init_functions()

    init_block_atlas()
    init_mod_blocks()

    init_world()

    _world_should_tick = true
    _ticks_thread = thread.create_and_start(tick_loop)

    _world_should_update = true
    _world_thread = thread.create_and_start(world_loop)

    _last_frame_tick = time.tick_now()
    main_loop()
}

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

    _window = sdl.CreateWindow(
        APP_NAME,
        sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED,
        WINDOW_SIZE.x, WINDOW_SIZE.y,
        sdl.WINDOW_SHOWN
    )
    if (_window == nil) {
        fmt.printf("Window could not be created! SDL_Error: %s\n", sdl.GetError())
        os.exit(1)
    }

    _renderer = sdl.CreateRenderer(_window, -1, sdl.RENDERER_ACCELERATED | sdl.RENDERER_PRESENTVSYNC)
    if (_renderer == nil) {
        fmt.printf("Renderer could not be created! SDL_Error: %s\n", sdl.GetError())
        os.exit(1)
    }

    // sdl.FillRect(surface, nil, sdl.MapRGB(surface.format, 0xFF, 0x00, 0xFF))
    sdl.SetRenderDrawColor(_renderer, 0xFF, 0x00, 0xFF, 0xFF)
    sdl.RenderFillRect(_renderer, nil)
    sdl.RenderPresent(_renderer)
}

deinit::proc() {
    utils.deinit_everything()

    _world_should_tick = false
    _world_should_update = false

    sdl.DestroyRenderer(_renderer)
    sdl.DestroyWindow(_window)
    sdl.Quit()

    thread.join_multiple(_ticks_thread, _world_thread)

    os.exit(0)
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