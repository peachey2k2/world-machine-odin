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

@(private) m_window : ^sdl.Window
@(private) m_renderer : ^sdl.Renderer

@(private) m_window_should_close := false

@(private) m_world_should_tick := false
@(private) m_ticks_thread : ^thread.Thread

@(private) m_world_should_update := false
@(private) m_world_thread : ^thread.Thread

init::proc() {
    utils.init_signals()
    utils.init_logger()
    set_ext_vars()
    init_sdl()

    // modloader.load_mods()
    // modloader.init_functions()

    init_block_atlas()
    // modloader.init_blocks()

    init_world()

    m_world_should_tick = true
    m_ticks_thread = thread.create_and_start(tick_loop)

    m_world_should_update = true
    m_world_thread = thread.create_and_start(world_loop)

    m_last_frame_tick = time.tick_now()
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

    m_window = sdl.CreateWindow(
        APP_NAME,
        sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED,
        WINDOW_SIZE.x, WINDOW_SIZE.y,
        sdl.WINDOW_SHOWN
    )
    if (m_window == nil) {
        fmt.printf("Window could not be created! SDL_Error: %s\n", sdl.GetError())
        os.exit(1)
    }

    m_renderer = sdl.CreateRenderer(m_window, -1, sdl.RENDERER_ACCELERATED | sdl.RENDERER_PRESENTVSYNC)
    if (m_renderer == nil) {
        fmt.printf("Renderer could not be created! SDL_Error: %s\n", sdl.GetError())
        os.exit(1)
    }

    // sdl.FillRect(surface, nil, sdl.MapRGB(surface.format, 0xFF, 0x00, 0xFF))
    sdl.SetRenderDrawColor(m_renderer, 0xFF, 0x00, 0xFF, 0xFF)
    sdl.RenderFillRect(m_renderer, nil)
    sdl.RenderPresent(m_renderer)
}

deinit::proc() {
    utils.deinit_everything()

    m_world_should_tick = false
    m_world_should_update = false

    sdl.DestroyRenderer(m_renderer)
    sdl.DestroyWindow(m_window)
    sdl.Quit()

    thread.join_multiple(m_ticks_thread, m_world_thread)

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