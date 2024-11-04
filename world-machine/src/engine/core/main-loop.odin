package core

// import "vendor:raylib"
import sdl "vendor:sdl2"

import "core:fmt"

window_should_close := false

main_loop::proc() {
    for (window_should_close == false) {
        handle_events()
        render()
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
    sdl.RenderClear(renderer)
    // draw stuff here
    sdl.RenderPresent(renderer)
    sdl.Delay(16)
}

on_quit::proc() {
    window_should_close = true
}

on_key_down::proc(event:^sdl.Event) {
    key_event := event.key
    fmt.printf("Key down: %d\n", key_event.keysym.scancode)
    #partial switch key_event.keysym.scancode {
        case sdl.SCANCODE_ESCAPE: window_should_close = true
    }
}

on_key_up::proc(event:^sdl.Event) {
    key_event := event.key
    fmt.printf("Key up: %d\n", key_event.keysym.scancode)
}
