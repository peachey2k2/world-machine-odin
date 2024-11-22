package engine

import "core:fmt"
import "core:strings"

import "extra-vendor:imgui"
import impl_sdl "extra-vendor:imgui/imgui_impl_sdl2"
import impl_opengl "extra-vendor:imgui/imgui_impl_opengl3"
// import sdl_impl "extra-vendor:imgui/impl/sdl"
// import gl_impl "extra-vendor:imgui/impl/opengl"

import "src:utils"

@(private="file") _context : ^imgui.Context
@(private="file") _io : ^imgui.IO

init_ui::proc() {
    // imgui.debug_check_version_and_data_layout(
    //     string(imgui.get_version()),
    //     size_of(imgui.IO),
    //     size_of(imgui.Style),
    //     size_of(imgui.Vec2),
    //     size_of(imgui.Vec4),
    //     size_of(imgui.Draw_Vert),
    //     size_of(imgui.Draw_Idx),
    // )
    imgui.CHECKVERSION()

    _context = imgui.CreateContext()
    _io = imgui.GetIO()

    _io.ConfigFlags |= {.NavEnableKeyboard, .NavEnableGamepad}

    imgui.StyleColorsDark()

    impl_sdl.InitForOpenGL(_window, _context)
    impl_opengl.Init("#version 430")

    // utils.connect_engine_signal(.FRAME_RENDER_UI, draw_demo_window)
    utils.connect_engine_signal(.FRAME_RENDER_UI, draw_debug_window)
}

draw_demo_window::proc() {
    imgui.ShowDemoWindow()
}

draw_debug_window::proc() {
    @(static) sb := strings.Builder{}
    imgui.SetNextWindowPos({0, 0}, .Once)
    imgui.Begin("Debug")
    imgui.Text(strings.unsafe_string_to_cstring(fmt.sbprintf(&sb, "FPS: %d%c", mean_framerate(), byte(0))))
    strings.builder_reset(&sb)
    imgui.End()
}

draw_ui::proc() {
    impl_opengl.NewFrame()
    impl_sdl.NewFrame()
    imgui.NewFrame()

    utils.emit_engine_signal(.FRAME_RENDER_UI)

    imgui.Render()
    impl_opengl.RenderDrawData(imgui.GetDrawData())
}