package engine

import sdl "vendor:sdl2"

TILE_SIZE :: 16
TILES_PER_ROW :: 16

block_atlas : ^sdl.Texture

init_block_atlas::proc() {
    block_atlas = sdl.CreateTexture(
        _renderer,
        .RGBA8888,
        .STATIC,
        TILE_SIZE * TILES_PER_ROW,
        TILE_SIZE * TILES_PER_ROW
    )
}