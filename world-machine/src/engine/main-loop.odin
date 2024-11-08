package engine

// import "vendor:raylib"
import sdl "vendor:sdl2"

import "core:fmt"
import "core:time"
import "core:math"

import "../utils"

_mean_framerate := i64(0)
_mean_frame_time := time.Duration{}

_last_frame_times := [20]time.Duration{}
_current_frame := u64(0)
_last_frame_tick := time.Tick{}


main_loop::proc() {
    for (_window_should_close == false) {
        bm := utils.bench_start("main_loop")
        defer utils.bench_end(bm)
        
        handle_events()
        render()
        update_framerate()
    }
}

handle_events::proc() {
    event : sdl.Event
    sdl.PumpEvents()
    for sdl.PollEvent(&event) {
        #partial switch event.type {
        case .QUIT:    on_quit()
        case .KEYDOWN: on_key_down(&event)
        case .KEYUP:   on_key_up(&event)
        }
    }
}

render::proc() {
    sdl.RenderClear(_renderer)
    // draw stuff here
    sdl.RenderPresent(_renderer)
}

update_framerate::proc() {
    _current_frame += 1
    cur_tick := time.tick_now()
    _last_frame_times[_current_frame % 20] = time.tick_diff(_last_frame_tick, cur_tick)
    _last_frame_tick = cur_tick

    _mean_frame_time = math.sum(_last_frame_times[:]) / 20
    _mean_framerate = 1e9 / transmute(i64)_mean_frame_time
}

on_quit::proc() {
    _window_should_close = true
}

on_key_down::proc(event:^sdl.Event) {
    key_event := event.key
    fmt.printf("Key down: %d\n", key_event.keysym.scancode)
    #partial switch key_event.keysym.scancode {
        case sdl.SCANCODE_ESCAPE: _window_should_close = true
    }
}

on_key_up::proc(event:^sdl.Event) {
    key_event := event.key
    fmt.printf("Key up: %d\n", key_event.keysym.scancode)
}

world_should_tick::proc() -> bool { return _world_should_tick }
world_should_update::proc() -> bool { return _world_should_update }

