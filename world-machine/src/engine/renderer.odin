package engine

import "core:time"
import "core:math/linalg"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

import "src:utils"

TILE_SIZE :: 16
TILES_PER_ROW :: 16

// we only keep the block atlas in memory as a strip to save on memory
// and upload it to gpu in parts
_block_atlas_strip : RawTexture
_block_atlas_id : u32

@(private="file")
_id_counter := TextureID(0)

@(private="file") Shader::u32
@(private="file") ShaderUniform::i32
@(private="file") GPUBuffer::u32


@(private="file")
_block_mesh : struct {
    shader: struct {
        program: Shader,
        mvp: ShaderUniform,
        tex: ShaderUniform,
    },
    bufs: struct {
        attrib: struct {
            vbo: GPUBuffer,
            buffer: [dynamic]u64,
            size: int,
        },
        indirect: struct {
            vbo: GPUBuffer,
            buffer: [dynamic]IndirectCommand,
        },
        ssb: struct {
            vbo: GPUBuffer,
            buffer: [dynamic][4]i32,
        },
    },
    vao: u32,
    
} = {}

@(private="file")
_render_chunks_to_update : utils.Queue(ChunkPos)

@(private="file")
_render_chunks_to_deactivate : utils.Queue(ChunkPos)

@(private="file")
_should_update_blocks_mesh := false

init_block_atlas::proc() {
    _block_atlas_strip = {
        data = make([]Color, TILE_SIZE * TILE_SIZE  * TILES_PER_ROW),
        width = TILE_SIZE * TILES_PER_ROW,
        height = TILE_SIZE, // we only keep one row in cpu
    }

    // gl.ActiveTexture(gl.TEXTURE0)
    gl.GenTextures(1, &_block_atlas_id)
    gl.BindTexture(gl.TEXTURE_2D, _block_atlas_id)
    gl.TexImage2D(
        target         = gl.TEXTURE_2D,
        level          = 0,
        internalformat = gl.RGBA,
        width          = TILE_SIZE * TILES_PER_ROW,
        height         = TILE_SIZE * TILES_PER_ROW,
        border         = 0,
        format         = gl.RGBA8UI,
        type           = gl.UNSIGNED_BYTE,
        pixels         = nil,
    )
}

add_texture_to_atlas::proc(texture: RawTexture) -> TextureID {
    texture_id := get_new_texture_id()

    if texture_id % TILES_PER_ROW == 0 && texture_id > 0 {
        // ship it
        gl.TexSubImage2D(
            target  = gl.TEXTURE_2D,
            level   = 0,
            xoffset = 0,
            yoffset = TILE_SIZE * (transmute(i32)texture_id / TILES_PER_ROW),
            width   = TILE_SIZE * TILES_PER_ROW,
            height  = TILE_SIZE,
            format  = gl.RGBA8UI,
            type    = gl.UNSIGNED_BYTE,
            pixels  = &_block_atlas_strip.data
        )
    }

    x_start : int = TILE_SIZE * (int(texture_id) % TILES_PER_ROW)
    for y in 0..<TILE_SIZE {
        copy(
            _block_atlas_strip.data[x_start + y*TILE_SIZE*TILES_PER_ROW : (x_start+TILE_SIZE) + y*TILE_SIZE*TILES_PER_ROW],
            texture.data[y*TILE_SIZE : (y+1)*TILE_SIZE]
        )
    }
    return texture_id
}

get_new_texture_id::proc() -> TextureID {
    defer _id_counter += 1
    return _id_counter
}

init_block_mesh::proc() {
    bm := utils.bench_start("init_block_mesh")  
    defer utils.bench_end(bm)

    // upload remaining block atlas strip
    gl.TexSubImage2D(
        target  = gl.TEXTURE_2D,
        level   = 0,
        xoffset = 0,
        yoffset = TILE_SIZE * ((transmute(i32)_id_counter-1)/TILES_PER_ROW + 1),
        width   = TILE_SIZE * TILES_PER_ROW,
        height  = TILE_SIZE,
        format  = gl.RGBA8UI,
        type    = gl.UNSIGNED_BYTE,
        pixels  = &_block_atlas_strip.data
    )

    block_shader, ok := gl.load_shaders_source(
        #load("res:shaders/block.vert"),
        #load("res:shaders/block.frag")
    )

    utils.assert_and_log(ok, "Failed to load block shaders")
    
    _block_mesh = {
        shader = {
            program = block_shader,
            mvp = gl.GetUniformLocation(block_shader, "mvp"),
            tex = gl.GetUniformLocation(block_shader, "tex"),
        },
    }

    gl.GenVertexArrays(1, &_block_mesh.vao)
    gl.BindVertexArray(_block_mesh.vao)
        gl.GenBuffers(1, &_block_mesh.bufs.attrib.vbo)
        gl.GenBuffers(1, &_block_mesh.bufs.indirect.vbo)
        gl.GenBuffers(1, &_block_mesh.bufs.ssb.vbo)
    gl.BindVertexArray(0)

    _render_chunks_to_update = utils.create_queue(ChunkPos)
    _render_chunks_to_deactivate = utils.create_queue(ChunkPos)
}

render_update::proc() {
    using utils

    for {
        if is_empty(&_render_chunks_to_update) do break
        chunk_pos := dequeue(&_render_chunks_to_update)
        render_update_chunk(chunk_pos)
        if relative_frame_time() > 5 * time.Millisecond do break
    }
    for {
        if is_empty(&_render_chunks_to_deactivate) do break
        chunk_pos := dequeue(&_render_chunks_to_deactivate)
        render_deactivate_chunk(chunk_pos)
        if relative_frame_time() > 5 * time.Millisecond do break
    }

    if len(_block_mesh.bufs.indirect.buffer) > 0 do draw_blocks()
}

@(private="file")
draw_blocks::proc() {
    using _block_mesh

    gl.BindVertexArray(vao)
    gl.UseProgram(shader.program); {
        defer gl.BindVertexArray(0)

        mvp := compute_mvp()
        gl.UniformMatrix4fv(shader.mvp, 1, false, transmute(^f32)(&mvp))

        gl.ActiveTexture(gl.TEXTURE0)
        gl.BindTexture(gl.TEXTURE_2D, _block_atlas_id)
        gl.Uniform1i(shader.tex, 0)

        if _should_update_blocks_mesh {
            gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, bufs.ssb.vbo); {
                defer gl.BindBuffer(gl.SHADER_STORAGE_BUFFER, 0)
                gl.BufferData(gl.SHADER_STORAGE_BUFFER, len(bufs.ssb.buffer) * size_of([4]i32), &bufs.ssb.buffer[0], gl.DYNAMIC_DRAW)
                gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 3, bufs.ssb.vbo)
            }

            gl.BindBuffer(gl.ARRAY_BUFFER, bufs.attrib.vbo); {
                defer gl.BindBuffer(gl.ARRAY_BUFFER, 0)
                gl.BufferData(gl.ARRAY_BUFFER, bufs.attrib.size * size_of(u64), &bufs.attrib.buffer[0], gl.DYNAMIC_DRAW)
                gl.VertexAttribIPointer(0, 2, gl.UNSIGNED_INT, size_of(u64), 0)
                gl.VertexAttribDivisor(0, 1)
                gl.EnableVertexAttribArray(0)
            }

            gl.BindBuffer(gl.DRAW_INDIRECT_BUFFER, bufs.indirect.vbo); {
                defer gl.BindBuffer(gl.DRAW_INDIRECT_BUFFER, 0)
                gl.BufferData(gl.DRAW_INDIRECT_BUFFER, len(bufs.indirect.buffer) * size_of(IndirectCommand), &bufs.indirect.buffer[0], gl.DYNAMIC_DRAW)
            }

            _should_update_blocks_mesh = false
        }

        gl.BindBuffer(gl.DRAW_INDIRECT_BUFFER, bufs.indirect.vbo)
        gl.MultiDrawArraysIndirect(gl.TRIANGLE_STRIP, nil, i32(len(bufs.indirect.buffer)), 0)
    }
}

@(private="file")
compute_mvp::#force_inline proc() -> linalg.Matrix4f32 {
    // we use the same mvp for every chunk, so instead of using different
    // model matrices, we use an SSBO to send all chunk positions
    model := linalg.identity(linalg.Matrix4f32)

    view := linalg.matrix4_look_at_f32(
        eye    = _camera.pos,
        centre = _camera.pos + _camera.front,
        up     = linalg.Vector3f32{0, 1, 0},
    )

    proj := linalg.matrix4_perspective_f32(
        fovy   = _camera.fov,
        aspect = f32(WINDOW_SIZE.x) / f32(WINDOW_SIZE.y),
        near   = 0.1,
        far    = 1000,
    )

    return proj * view * model
}

render_update_chunk::proc(pos: ChunkPos) {}
render_deactivate_chunk::proc(pos: ChunkPos) {}
