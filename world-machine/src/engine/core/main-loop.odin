package core

// import "vendor:raylib"
import sdl "vendor:sdl2"

import "core:fmt"

window_should_close := false

main_loop::proc() {
    // for !raylib.WindowShouldClose() {
    //     raylib.BeginDrawing()
    //     raylib.ClearBackground(raylib.RAYWHITE)
    //     raylib.DrawText("Congrats! You created your first window!", 190, 200, 20, raylib.LIGHTGRAY)
    //     raylib.EndDrawing()
    // }
    for (window_should_close == false) {
        handle_events()
        render()
    }
}

handle_events::proc() {
    event : ^sdl.Event
    sdl.PumpEvents()
    for sdl.PollEvent(event) {
        if event == nil do continue
        #partial switch event.type {
        case .QUIT:
            window_should_close = true
        }
    }
}

render::proc() {
    sdl.RenderClear(renderer)
    // draw stuff here
    sdl.RenderPresent(renderer)
    sdl.Delay(16)
}
