package engine

import "core:math/noise"
import "core:fmt"
import "core:math"
import "core:math/bits"
import "core:sync"

import "src:utils"

RENDER_DISTANCE := i32(8)
WORLD_HEIGHT := i32(256)

_noise_seed := i64(3169)

_chunks := map[ChunkPos]Chunk{}

// These should only be accesed by the main and world threads.
// One-to-one queues are only thread safe if there is only one producer and one consumer.
@(private="file") _chunks_to_generate : utils.OneToOneQueue(ChunkPos)
@(private="file") _chunks_to_remove : utils.OneToOneQueue(ChunkPos)
@(private="file") _chunks_to_generate_at : utils.OneToOneQueue(ChunkPos)

@(private="file") _small_chunk_pool : utils.ObjectPool(SmallChunk)
@(private="file") _large_chunk_pool : utils.ObjectPool(LargeChunk)
@(private="file") _render_mask_pool : utils.ObjectPool(ChunkBitMask)

// This is used to signal the world thread that there is work to be done.
_world_futex := sync.Futex(0)

init_world::proc() {
    utils.bench("init_world")

    _chunks_to_generate = utils.create_one_to_one_queue(ChunkPos)
    _chunks_to_remove = utils.create_one_to_one_queue(ChunkPos)
    _chunks_to_generate_at = utils.create_one_to_one_queue(ChunkPos)

    _small_chunk_pool = utils.create_pool(SmallChunk, 16)
    _large_chunk_pool = utils.create_pool(LargeChunk, 16)
    _render_mask_pool = utils.create_pool(ChunkBitMask, 16)
    
    clear(&_chunks)
    utils.enqueue(&_chunks_to_generate_at, ChunkPos{0,0,0})

    utils.defer_deinit(deinit_world)
}

deinit_world::proc() {
    _world_should_update = false
    sync.atomic_store(&_world_futex, 1)
    sync.futex_signal(&_world_futex)
    sync.futex_wait(&_world_loop_running, 1)

    utils.destroy(&_chunks_to_generate)
    utils.destroy(&_chunks_to_remove)
    utils.destroy(&_chunks_to_generate_at)

    for _, chunk in _chunks {
        if chunk.small != nil {
            delete(chunk.small.blocks)
        }
    }
    
    utils.call_for_all(&_small_chunk_pool, struct{}{}, proc(chunk: ^SmallChunk, _: struct{}) {
        delete(chunk.blocks)
    })

    utils.destroy(&_small_chunk_pool)
    utils.destroy(&_large_chunk_pool)
    utils.destroy(&_render_mask_pool)

    clear(&_chunks)
}

add_chunk_to_generate::proc(pos: ChunkPos) {
    utils.enqueue(&_chunks_to_generate, pos)
    sync.atomic_store(&_world_futex, 1)
    sync.futex_signal(&_world_futex)
}

add_chunk_to_remove::proc(pos: ChunkPos) {
    utils.enqueue(&_chunks_to_remove, pos)
    sync.atomic_store(&_world_futex, 1)
    sync.futex_signal(&_world_futex)
}

add_chunk_to_generate_at::proc(pos: ChunkPos) {
    utils.enqueue(&_chunks_to_generate_at, pos)
    sync.atomic_store(&_world_futex, 1)
    sync.futex_signal(&_world_futex)
}

_world_loop_running := sync.Futex(0)

world_loop::proc() {
    using utils

    sync.atomic_store(&_world_loop_running, 1)

    for world_should_update() {
        for !is_empty(&_chunks_to_generate_at) && _world_should_update {
            if is_empty(&_chunks_to_generate) && is_empty(&_chunks_to_remove) {
                pos, _ := dequeue(&_chunks_to_generate_at)
                queue_generations_at(pos, RENDER_DISTANCE)
            }
        }
        for !is_empty(&_chunks_to_generate) && _world_should_update {
            pos, _ := dequeue(&_chunks_to_generate)
            generate_chunk(pos)
        }
        for !is_empty(&_chunks_to_remove) && _world_should_update {
            pos, _ := dequeue(&_chunks_to_remove)
            remove_chunk(pos)
        }
        
        if is_empty(&_chunks_to_generate) && is_empty(&_chunks_to_remove) && is_empty(&_chunks_to_generate_at) {
            sync.atomic_store(&_world_futex, 0)
        }

        sync.futex_wait(&_world_futex, 0)
    }

    sync.atomic_store(&_world_loop_running, 0)
    sync.futex_signal(&_world_loop_running)
}

queue_generations_at::proc(center: ChunkPos, radius: i32) {
    utils.bench("queue_generations_at")

    Curry::struct {
        center: ChunkPos,
        radius: i32,
    }

    utils.delete_key_if(&_chunks, Curry{center, radius}, proc(pos: ChunkPos, chunk: Chunk, curry:Curry) -> bool {
        if bool(
            abs(pos.x - curry.center.x) > curry.radius ||
            abs(pos.y - curry.center.y) > curry.radius ||
            abs(pos.z - curry.center.z) > curry.radius
        ) {
            utils.enqueue(&_chunks_to_remove, pos)
            return true
        }
        return false
    })

    for x := -radius; x <= radius; x += 1 {
        for y := -radius; y <= radius; y += 1 {
            for z := -radius; z <= radius; z += 1 {
                pos := ChunkPos{
                    center.x + x,
                    center.y + y,
                    center.z + z,
                }
                _, has := _chunks[pos]
                if !has {
                    utils.enqueue(&_chunks_to_generate, pos)
                }
            }
        }
    }
}

generate_chunk::proc(pos: ChunkPos) {
    chunk_layout := ChunkLayout{}
    mask, ok := utils.acquire(&_render_mask_pool)
    if !ok {
        fmt.println("Failed to acquire render mask")
        return
    }

    for x := i32(0); x < 16; x += 1 {
        for z := i32(0); z < 16; z += 1 {
            height := cast(i32)noise.noise_2d(_noise_seed, {
                f64((pos.x*16 + x) / WORLD_HEIGHT),
                f64((pos.z*16 + z) / WORLD_HEIGHT)
            })
            height = clamp(height - pos.y*16, 0, 16)
            
            for y := i32(0); y < 16; y += 1 {
                chunk_layout[y + x*16 + z*16*16] = 1
            }
            mask[x + z*16] = transmute(u16)((1 << transmute(u32)height) - 1)
        }
    }
    _chunks[pos] = construct_chunk(chunk_layout[:], mask)
    utils.enqueue(&_render_chunks_to_update, pos)
}

construct_chunk::proc(layout: []BlockID, mask: ^ChunkBitMask) -> (chunk: Chunk) {
    @(static) block_counts := map[BlockID]u32{}

    chunk.cull_mask = mask

    for block in layout {
        block_counts[block] += 1
    }

    if len(block_counts) > 255 {
        chunk.large, _ = utils.acquire(&_large_chunk_pool)
        chunk.small = nil
        copy(chunk.large.data[:], layout[:])
    } else {
        chunk.small, _ = utils.acquire(&_small_chunk_pool)
        chunk.large = nil
    
        i := u32(0)
        for id, &count in block_counts {
            append(&chunk.small.blocks, id)
            // small.blocks is only a 1-way conversion, so we do this instead
            i += 1
            count = i // keep in mind this starts from 1, 0 is reserved for air.
        }
    
        for i in 0..<16*16*16 {
            idx := layout[i]
            chunk.small.data[i] = u8(idx == 0 ? 0 : block_counts[idx])
        }
    }

    clear(&block_counts)
    return chunk
}

remove_chunk::proc(pos: ChunkPos) {
    chunk, has := _chunks[pos]
    if !has do return

    delete_key(&_chunks, pos)
    if chunk.small != nil {
        clear(&chunk.small.blocks)
        utils.release(&_small_chunk_pool, chunk.small)
    } else {
        utils.release(&_large_chunk_pool, chunk.large)
    }
    utils.release(&_render_mask_pool, chunk.cull_mask)
}

world_to_chunk_space::proc {
    world_to_chunk_space_blockpos,
    world_to_chunk_space_position,
}

world_to_chunk_space_blockpos::proc(pos: BlockPos) -> (which_chunk: ChunkPos, at_where: ChunkedBlockPos) {
    which_chunk = ChunkPos{
        pos.x / 16,
        pos.y / 16,
        pos.z / 16,
    }
    at_where = ChunkedBlockPos{
        u8(pos.x % 16),
        u8(pos.y % 16),
        u8(pos.z % 16),
    }
    return which_chunk, at_where
}

world_to_chunk_space_position::proc(pos: Position) -> (which_chunk: ChunkPos, at_where: ChunkedPosition) {
    which_chunk = ChunkPos{
        cast(i32)math.floor(pos.x / 16),
        cast(i32)math.floor(pos.y / 16),
        cast(i32)math.floor(pos.z / 16),
    }
    at_where = ChunkedPosition{
        math.remainder(pos.x, 16),
        math.remainder(pos.y, 16),
        math.remainder(pos.z, 16),
    }
    return which_chunk, at_where
}

change_block::proc(at: BlockPos, to: BlockID) {
    // TODO: Implement
}

get_block::proc(at: BlockPos) -> (block: BlockID) {
    chunk_pos, block_pos_in_chunk := world_to_chunk_space(at)

    chunk, has := _chunks[chunk_pos]
    if !has do return 0 // TODO: handle this better

    if chunk.large != nil {
        return chunk.large.data[block_pos_in_chunk.x + block_pos_in_chunk.y*16 + block_pos_in_chunk.z*16*16]
    } else {
        idx := chunk.small.data[block_pos_in_chunk.x + block_pos_in_chunk.y*16 + block_pos_in_chunk.z*16*16]
        return chunk.small.blocks[idx]
    }
}

// find_extremes::proc // TODO: Implement

set_chunk_block:: proc {
    set_chunk_block_vec,
    set_chunk_block_nums,
}

set_chunk_block_vec:: #force_inline proc(chunk: Chunk, at: ChunkedBlockPos, to: BlockID) {
    if chunk.large != nil {
        chunk.large.data[at.x + at.y*16 + at.z*16*16] = to
    } else {
        idx := chunk.small.data[at.x + at.y*16 + at.z*16*16]
        chunk.small.data[at.x + at.y*16 + at.z*16*16] = u8(idx == 0 ? 0 : to)
    }
}

set_chunk_block_nums:: #force_inline proc(chunk: Chunk, #any_int x, y, z: int, to: BlockID) {
    if chunk.large != nil {
        chunk.large.data[x + y*16 + z*16*16] = to
    } else {
        idx := chunk.small.data[x + y*16 + z*16*16]
        chunk.small.data[x + y*16 + z*16*16] = u8(idx == 0 ? 0 : to)
    }
}



