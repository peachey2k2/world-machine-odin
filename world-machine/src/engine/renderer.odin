package engine

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

import "src:utils"

TILE_SIZE :: 16
TILES_PER_ROW :: 16

block_atlas : ^sdl.Texture

@(private="file")
Shader::u32

@(private="file")
_block_shader : struct {
    program: Shader,
    mvp: i32,
    tex: i32,
}

@(private="file")
RenderMesh::struct {
    shader: Shader,

}

init_block_atlas::proc() {
    // block_atlas = sdl.CreateTexture(
    //     _renderer,
    //     .RGBA8888,
    //     .STATIC,
    //     TILE_SIZE * TILES_PER_ROW,
    //     TILE_SIZE * TILES_PER_ROW
    // ) //TODO: what the heeeeeeeeeeeeeeel oh my goooooooooooood no waAAAaAAAaAAAAAAy
}

init_block_mesh::proc() {
    bm := utils.bench_start("init_block_mesh")  
    defer utils.bench_end(bm)

    block_shader, ok := gl.load_shaders_source(
        #load("res:shaders/block.vert"),
        #load("res:shaders/block.frag")
    )

    utils.assert_and_log(ok, "Failed to load block shaders")

    _block_shader = {
        program = block_shader,
        mvp = gl.GetUniformLocation(block_shader, "mvp"),
        tex = gl.GetUniformLocation(block_shader, "tex"),
    }

    // sdl.GL_BindTexture(block_atlas)
}