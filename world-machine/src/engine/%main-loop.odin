package engine

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

import "core:fmt"
import "core:time"
import "core:math"
import "core:math/linalg"

import "src:utils"

import "extra-vendor:imgui/imgui_impl_sdl2"

_mean_framerate := i64(0)
_mean_frame_time := time.Duration{}

_last_frame_times := [20]time.Duration{}
_current_frame := u64(0)
_last_frame_tick := time.Tick{}

_camera : struct {
    pos, front, up, right: linalg.Vector3f32,
    yaw, pitch: f32,
    sensitivity, fov: f32,
} = {
    front = linalg.Vector3f32{0, 0, -1},
    up    = linalg.Vector3f32{0, 1, 0},
    right = linalg.Vector3f32{1, 0, 0},

    sensitivity = 0.1,
    fov         = 45,
}

main_loop::proc() {
    for (_window_should_close == false) {
        bm := utils.bench_start("main_loop")
        defer utils.bench_end(bm)

        gl.Viewport(0, 0, WINDOW_SIZE[0], WINDOW_SIZE[1])
        gl.ClearColor(0.45, 0.55, 0.60, 1.00)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        
        handle_events()
        render()
        draw_ui()
        update_framerate()
        
        sdl.GL_SwapWindow(_window)
    }
}

handle_events::proc() {
    event : sdl.Event
    sdl.PumpEvents()
    for sdl.PollEvent(&event) {
        imgui_impl_sdl2.ProcessEvent(&event)
        #partial switch event.type {
        case .QUIT:        on_quit()
        case .KEYDOWN:     on_key_down(&event)
        case .KEYUP:       on_key_up(&event)
        case .MOUSEMOTION: on_mouse_motion(&event)
        }
    }
}

render::proc() {
    
    // draw stuff here
    
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

on_mouse_motion::proc(event:^sdl.Event) {
    mouse_event := event.motion

    _camera.yaw += f32(mouse_event.xrel) * _camera.sensitivity
    _camera.pitch += f32(mouse_event.yrel) * _camera.sensitivity

    _camera.pitch = math.clamp(_camera.pitch, -89.0, 89.0)
    _camera.yaw = math.mod(_camera.yaw, 360.0)

    front := linalg.Vector3f32{
        math.cos(math.to_radians(_camera.yaw)) * math.cos(math.to_radians(_camera.pitch)),
        math.sin(math.to_radians(_camera.pitch)),
        math.sin(math.to_radians(_camera.yaw)) * math.cos(math.to_radians(_camera.pitch)),
    }
    _camera.front = linalg.normalize(front)
    _camera.right = linalg.normalize(linalg.cross(_camera.front ,linalg.Vector3f32{0, 1, 0}))
    _camera.up    = linalg.normalize(linalg.cross(_camera.right, _camera.front))

    fmt.printf("Yaw: %f, Pitch: %f\n", _camera.yaw, _camera.pitch)
}

world_should_tick::proc() -> bool { return _world_should_tick }
world_should_update::proc() -> bool { return _world_should_update }
relative_frame_time::proc() -> time.Duration { return time.tick_diff(_last_frame_tick, time.tick_now()) }
