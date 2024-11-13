package engine

import "core:os"
import "core:fmt"
import "core:strings"
import "core:thread"
import "core:time"

import gl "vendor:OpenGL"
import sdl "vendor:sdl2"

import "src:utils"

APP_NAME : cstring = "World Machine"
VERSION := "0.0.1"
WINDOW_SIZE := [2]i32{800, 450}

@(private) _window : ^sdl.Window
@(private) _context : sdl.GLContext

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
    
    do_requirement_checks()
    
    // modloader.load_mods()
    // modloader.init_functions()
    
    init_mod_blocks()
    init_block_atlas()
    init_block_mesh()

    init_ui()
    
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

    sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, 4)
    sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, 3)
    sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, gl.CONTEXT_CORE_PROFILE_BIT)

    _window = sdl.CreateWindow(
        APP_NAME,
        sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED,
        WINDOW_SIZE.x, WINDOW_SIZE.y,
        {sdl.WindowFlags.OPENGL, sdl.WindowFlags.SHOWN}
    )
    if (_window == nil) {
        fmt.printf("Window could not be created! SDL_Error: %s\n", sdl.GetError())
        os.exit(1)
    }

    // _renderer = sdl.CreateRenderer(_window, -1, sdl.RENDERER_ACCELERATED | sdl.RENDERER_PRESENTVSYNC)
    // if (_renderer == nil) {
    //     fmt.printf("Renderer could not be created! SDL_Error: %s\n", sdl.GetError())
    //     os.exit(1)
    // }

    // sdl.SetRenderDrawColor(_renderer, 0xFF, 0x00, 0xFF, 0xFF)
    // sdl.RenderFillRect(_renderer, nil)
    // sdl.RenderPresent(_renderer)

    _context = sdl.GL_CreateContext(_window)
    sdl.GL_MakeCurrent(_window, _context)
    sdl.GL_SetSwapInterval(1)

    gl.load_up_to(4, 3, sdl.gl_set_proc_address) // Load OpenGL functions

    sdl.SetRelativeMouseMode(true)
    sdl.SetWindowGrab(_window, true)
}

deinit::proc() {
    utils.deinit_everything()

    _world_should_tick = false
    _world_should_update = false

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

do_requirement_checks::proc() {
    temp_i32 := i32(0)

    check::proc(value: $T, range: Range(T), name: string) {
        utils.assert_and_log(
            range.min == 0 || value >= range.min,
            "Requirement check failed for ", name, ". (Have", value, "but at least" ,range.min, "required)"
        )
        utils.assert_and_log(
            range.max == 0 || value <= range.max,
            "Requirement check failed for", name, "(Have", value, "but at most", range.max, "required)"
        )
        utils.log(.INFO, "Requirement check passed for", name, "( Have", value, "in", range, ")")
    }

    gl.GetIntegerv(gl.MAX_TEXTURE_SIZE, &temp_i32)
    check(temp_i32, Range(i32){8192, 0}, "MAX_TEXTURE_SIZE")

    gl.GetIntegerv(gl.MAX_TEXTURE_UNITS, &temp_i32)
    check(temp_i32, Range(i32){8, 0}, "MAX_TEXTURE_UNITS")

    gl.GetIntegerv(gl.MAX_COMBINED_TEXTURE_IMAGE_UNITS, &temp_i32)
    check(temp_i32, Range(i32){8, 0}, "MAX_COMBINED_TEXTURE_IMAGE_UNITS")
}