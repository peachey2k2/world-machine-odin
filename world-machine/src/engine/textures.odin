package engine

import "core:c/libc"

import stbi "vendor:stb/image"

// NOTE: textures need to be freed manually with `free_texture()`
create_texture::proc(buffer: []byte) -> ^RawTexture {
    x, y, channels : int
    bytes := stbi.load_from_memory(
        &buffer[0],
        libc.int(len(buffer)),
        (^libc.int)(&x),
        (^libc.int)(&y),
        (^libc.int)(&channels),
        4 // force RGBA
    )
    tex := new(RawTexture)
    tex.data = transmute([^]Color)(&bytes[0])
    tex.width = u32(x)
    tex.height = u32(y)
    return tex
}

free_texture::proc(tex: ^RawTexture) {
    stbi.image_free(tex.data)
    free(tex)
}