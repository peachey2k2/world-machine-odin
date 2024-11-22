package engine

import "core:time"
import "core:math/linalg"
import "core:math/bits"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL"

import "src:utils"

TILE_SIZE :: 16
TILES_PER_ROW :: 16

// we only keep the block atlas in memory as a strip to save on memory
// and upload it to gpu in parts
_block_atlas_strip := RawTexture{}
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
        format         = gl.RGBA,
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
            format  = gl.RGBA,
            type    = gl.UNSIGNED_BYTE,
            pixels  = &_block_atlas_strip.data[0]
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
        format  = gl.RGBA,
        type    = gl.UNSIGNED_BYTE,
        pixels  = &_block_atlas_strip.data[0]
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
        if mean_frame_time() > 5 * time.Millisecond do break
    }
    for {
        if is_empty(&_render_chunks_to_deactivate) do break
        chunk_pos := dequeue(&_render_chunks_to_deactivate)
        render_deactivate_chunk(chunk_pos)
        if mean_frame_time() > 5 * time.Millisecond do break
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

@(private="file")
render_activate_chunk::proc(pos: ChunkPos) {
    data, size := calculate_chunk_data(pos)
    if size == 0 do return
    edit_mesh(pos, data[:], size)

    _should_update_blocks_mesh = true
}

@(private="file")
render_update_chunk::proc(pos: ChunkPos) {
    data, size := calculate_chunk_data(pos)
    if size == 0 {
        render_deactivate_chunk(pos)
        return
    }
    edit_mesh(pos, data[:], size)

    _should_update_blocks_mesh = true
}

@(private="file")
render_deactivate_chunk::proc(pos: ChunkPos) {
    // TODO: implement
}

// i hate this whole entire thing going here

@(private="file") CS :: 16 // chunk size
@(private="file") CS_2 :: CS * CS // squared

@(private="file")
BlockVertData::u64

@(private="file")
create_mesh_data::#force_inline proc(
    #any_int pos_x, pos_y, pos_z: int,
    #any_int size_u, size_v: int,
    #any_int face: int,
    #any_int texture: int
) -> BlockVertData {
    tex_u, tex_v := texture % TILES_PER_ROW, texture / TILES_PER_ROW
    return BlockVertData(
        (u64(pos_x) << 0) | (u64(pos_y) << 5) | (u64(pos_z) << 10) | // 5 bits each
        (u64(size_u) << 15) | (u64(size_v) << 20) | // 5 bits each
        (u64(face) << 25) | // 3 bits
        (u64(tex_u) << 32) | (u64(tex_v) << 48) // 16 bits each 
    )
    // here's a visualized memory layout
    // XXXXXYYY YYZZZZZU UUUUVVVV VFFF----
    // UUUUUUUU UUUUUUUU VVVVVVVV VVVVVVVV
}

get_axis_idx::#force_inline proc(axis: int, #any_int a, b, c: int) -> int {
    switch axis {
        case 0: return b + CS*a + CS_2*c
        case 1: return b + CS*c + CS_2*a
        case 2: return c + CS*a + CS_2*b
    }
    return 0
}

@(private="file")
calculate_chunk_data::proc(pos: ChunkPos) -> (vertex_data: [6*CS*CS*CS]BlockVertData, size: u32) {
    size = 0

    chunk := _chunks[pos]

    cull_mask := chunk.cull_mask^
    face_masks := [BlockFaces]ChunkBitMask{}

    // https://github.com/cgerikj/binary-greedy-meshing/blob/master/src/mesher.h

    for a in 1..<16-1 {
        aCS := a * CS 
        for b in 1..<16-1 {
            column := cull_mask[aCS + b]

            ba_idx := (b-1) + (a-1)*CS
            ab_idx := (a-1) + (b-1)*CS
            
            face_masks[.NORTH][ab_idx]  = column & ~cull_mask[aCS + b + 1]
            face_masks[.EAST][ab_idx]   = column & ~cull_mask[aCS + b - 1]

            face_masks[.SOUTH][ba_idx]  = column & ~cull_mask[aCS + b + CS]
            face_masks[.WEST][ba_idx]   = column & ~cull_mask[aCS + b - CS]

            face_masks[.TOP][ab_idx]    = column & ~(cull_mask[aCS + b] >> 1)
            face_masks[.BOTTOM][ab_idx] = column & ~(cull_mask[aCS + b] << 1)
        }
    }

    if chunk.large != nil {
        // don't run the greedy mesher for large chunks
        // instead run a simple face culler

        // blocks := chunk.large.data
        // TODO: can't be bothered rn

    } else {
        // run the greedy mesher
        
        blocks := chunk.small.data
        
        for face in BlockFaces {
            face_casted := int(face)
            axis := face_casted / 2

            forward_merged := [CS_2]u8{}
            right_merged := [CS]u8{}

            switch axis {
            case 0, 1:
                for layer in 0..<CS {
                    bits_idx := layer*CS

                    for forward in 0..<CS {
                        bits_here := face_masks[face][forward + bits_idx]
                        if bits_here == 0 do continue

                        next_bits := face_masks[face][forward+1 + bits_idx] if forward < CS-1 else 0

                        right_merged := u8(1)

                        for bits_here > 0 {
                            bit_pos := u8(bits.trailing_zeros(bits_here))
                            block := blocks[get_axis_idx(axis, forward+1, bit_pos+1, layer+1)]

                            forward_merged_ref := &forward_merged[bit_pos]

                            if (
                                (next_bits >> bit_pos & 1 != 0) &&
                                (block == blocks[get_axis_idx(axis, forward+2, bit_pos+1, layer+1)]) \
                            ) {
                                forward_merged_ref^ += 1
                                bits_here &=  ~(1 << bit_pos)
                                continue
                            }

                            for right in (bit_pos+1)..<CS {
                                if (
                                    ((bits_here >> right & 1) == 0) ||
                                    (forward_merged_ref^ != forward_merged[right]) ||
                                    (block != blocks[get_axis_idx(axis, forward+1, right+1, layer+1)]) \
                                ) {
                                    break
                                }
                                forward_merged[right] = 0
                                right_merged += 1
                            }
                            forward_merged_ref^ &= ~((1 << (bit_pos + right_merged)) - 1)

                            mesh_front  := u8(forward) - forward_merged_ref^
                            mesh_left   := bit_pos
                            mesh_up     := layer + (~face_casted & 1)

                            mesh_width  := right_merged
                            mesh_length := forward_merged_ref^ + 1

                            forward_merged_ref^ = 0
                            right_merged = 1

                            switch axis {
                            case 0: vertex_data[size] = create_mesh_data(
                                pos_x   = mesh_front + (face_casted==1 ? mesh_length : 0),
                                pos_y   = mesh_up,
                                pos_z   = mesh_left,
                                size_u  = mesh_length,
                                size_v  = mesh_width,
                                face    = face_casted,
                                texture = chunk.small.blocks[block-1]
                            )
                            case 1: vertex_data[size] = create_mesh_data(
                                pos_x   = mesh_up,
                                pos_y   = mesh_front + (face_casted==2 ? mesh_length : 0),
                                pos_z   = mesh_left,
                                size_u  = mesh_length,
                                size_v  = mesh_width,
                                face    = face_casted,
                                texture = chunk.small.blocks[block-1]
                            )
                            }
                            size += 1
                        }
                    }
                }
            case 2:
                for forward in 0..<CS {
                    bits_idx := forward*CS
                    bits_forward_idx := (forward+1)*CS

                    for right in 0..<CS {
                        bits_here := face_masks[face][right + bits_idx]
                        if bits_here == 0 do continue

                        bits_forward := face_masks[face][right + bits_forward_idx] if forward < CS-1 else 0
                        bits_right   := face_masks[face][right+1 + bits_idx]       if right   < CS-1 else 0
                        rightCS := right * CS

                        for bits_here > 0 {
                            bit_pos := u8(bits.trailing_zeros(bits_here))
                            
                            bits_here &= ~(1 << bit_pos)

                            block := blocks[get_axis_idx(axis, right+1, forward+1, bit_pos)]
                            forward_merged_ref := &forward_merged[rightCS + int(bit_pos) - 1]
                            right_merged_ref := &right_merged[bit_pos - 1]

                            if (
                                (right_merged_ref^ == 0) &&
                                (bits_forward >> bit_pos & 1 != 0) &&
                                (block == blocks[get_axis_idx(axis, right+1, forward+2, bit_pos)]) \
                            ) {
                                forward_merged_ref^ += 1
                                continue
                            }

                            if (
                                (bits_right >> bit_pos & 1 != 0) &&
                                (forward_merged_ref^ == forward_merged[(rightCS+CS) + int(bit_pos) - 1]) &&
                                (block == blocks[get_axis_idx(axis, right+2, forward+1, bit_pos)]) \ 
                            ) {
                                forward_merged_ref^ = 0
                                right_merged_ref^ += 1
                                continue
                            }

                            mesh_left   := u8(right) - right_merged_ref^
                            mesh_front  := u8(forward) - forward_merged_ref^
                            mesh_up     := u8(bit_pos) - 1 + u8(~face_casted & 1)

                            mesh_width  := right_merged_ref^ + 1
                            mesh_length := forward_merged_ref^ + 1

                            forward_merged_ref^ = 0
                            right_merged_ref^ = 0

                            vertex_data[size] = create_mesh_data(
                                pos_x   = mesh_left + (face_casted==4 ? mesh_width : 0),
                                pos_y   = mesh_front,
                                pos_z   = mesh_up,
                                size_u  = mesh_width,
                                size_v  = mesh_length,
                                face    = face_casted,
                                texture = chunk.small.blocks[block-1]
                            )
                            size += 1
                        }
                    }
                }
            }
        }
    }
    return vertex_data, size
}

edit_mesh::proc(pos: ChunkPos, data: []BlockVertData, size: u32) {
    // utils.bench("edit_mesh")
    using _block_mesh.bufs

    ssbo_data : [4]i32
    ssbo_data.xyz = pos
    ssbo_data.w = 0

    cmd : ^IndirectCommand
    exists := false
    idx := 0

    for e, i in ssb.buffer {
        if e.xyz == pos {
            exists = true
            idx = i
            break
        }
    }

    // create if it doesn't exist
    if !exists {
        cmd, idx = create_indirect_command(size)
        inject_at(&ssb.buffer, idx, ssbo_data)

    // resize and/or move if it does
    } else {
        idx_new : int
        cmd, idx_new = resize_indirect_command(&indirect.buffer[idx], size)
        if idx_new != idx {
            ordered_remove(&ssb.buffer, idx)
            inject_at(&ssb.buffer, idx_new, ssbo_data)
        }
    }

    if attrib.size > len(attrib.buffer) {
        reserve(&attrib.buffer, attrib.size + 1024)
    }

    // despacito
    copy(attrib.buffer[cmd.base_instance:], data[:size])
}

create_indirect_command::proc(size: u32) -> (cmd: ^IndirectCommand, idx: int) {
    using _block_mesh.bufs

    command := IndirectCommand{
        count = 0,
        instance_count = size,
        first = 0,
        base_instance = 0, // we'll find the right place later
    }

    // check if empty. this might seem redundant, but it prevents a crash
    if len(indirect.buffer) == 0 {
        attrib.size = int(size)
        append(&indirect.buffer, command)
        cmd = &indirect.buffer[0]
        idx = 0
        return
    }

    // check the start
    if indirect.buffer[0].base_instance >= size {
        inject_at(&indirect.buffer, 0, command)
        cmd = &indirect.buffer[0]
        idx = 0
        return
    }

    // check for any other gaps
    for i in 1..<len(indirect.buffer) {        
        prev_end := (indirect.buffer[i-1].base_instance + indirect.buffer[i-1].instance_count)
        cur_start := indirect.buffer[i].base_instance

        if (cur_start - prev_end >= size ) {
            cmd.base_instance = prev_end
            inject_at(&indirect.buffer, i, command)
            cmd = &indirect.buffer[i]
            idx = i
            return
        }
    }

    // if no gaps, put to the end
    last := indirect.buffer[len(indirect.buffer)-1]
    cmd.base_instance = last.base_instance + last.instance_count
    attrib.size = int(cmd.base_instance + size)
    append(&indirect.buffer, command)
    cmd = &indirect.buffer[len(indirect.buffer)-1]
    idx = len(indirect.buffer)-1
    return
}

resize_indirect_command::proc(cmd: ^IndirectCommand, new_size: u32) -> (cmd_new:^IndirectCommand, idx_new: int) {
    using _block_mesh.bufs

    // get index with pointer arithmetic
    idx_old, has := utils.index_of(&indirect.buffer, cmd)
    if !has {
        utils.log(.ERROR, "resize_indirect_command: command not found. idx_old:", idx_old, "new_size:", new_size)
        return
    }

    // if we're shrinking, we don't need to do anything
    if cmd.instance_count >= new_size {
        cmd.instance_count = new_size
        cmd_new = cmd
        idx_new = idx_old
        return
    }

    // if it's at the end, we might need to increase our buffer size
    if idx_old == len(indirect.buffer)-1 {
        attrib.size =  max(attrib.size, int(cmd.base_instance + new_size))
        cmd.instance_count = new_size
        cmd_new = cmd
        idx_new = idx_old
        return
    }

    // the last check should prevent us from going out of bounds here
    next := indirect.buffer[idx_old+1]

    // if we can expand, we do
    if cmd.base_instance + new_size <= next.base_instance {
        cmd.instance_count = new_size
        cmd_new = cmd
        idx_new = idx_old
        return
    }

    // if we can't, we find a new place for it
    ordered_remove(&indirect.buffer, idx_old)
    cmd_new, idx_new = create_indirect_command(new_size)
    return
}