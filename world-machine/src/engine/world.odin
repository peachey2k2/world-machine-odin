package engine

import "../utils"
import "core:math/noise"
import "core:fmt"

RENDER_DISTANCE := i32(8)
WORLD_HEIGHT := i32(256)

_noise_seed := i64(3169)

_chunks := map[ChunkPos]Chunk{}

// These should only be accesed by the main and world threads.
// One-to-one queues are only thread safe if there is only one producer and one consumer.
_chunks_to_generate : utils.OneToOneQueue(ChunkPos)
_chunks_to_remove : utils.OneToOneQueue(ChunkPos)
_chunks_to_generate_at : utils.OneToOneQueue(ChunkPos)

// _small_chunk_pool : mem.Dynamic_Arena

init_world::proc() {
    bm := utils.bench_start("init_world")
    defer utils.bench_end(bm)

    _chunks_to_generate = utils.create_one_to_one_queue(ChunkPos)
    _chunks_to_remove = utils.create_one_to_one_queue(ChunkPos)
    _chunks_to_generate_at = utils.create_one_to_one_queue(ChunkPos)
    
    clear(&_chunks)
    utils.enqueue(&_chunks_to_generate_at, ChunkPos{0,0,0})

    utils.defer_deinit(deinit_world)
}

deinit_world::proc() {
    utils.destroy(&_chunks_to_generate)
    utils.destroy(&_chunks_to_remove)
    utils.destroy(&_chunks_to_generate_at)
}

world_loop::proc() {
    using utils

    for world_should_update() {
        for !is_empty(&_chunks_to_generate_at) {
            if is_empty(&_chunks_to_generate) && is_empty(&_chunks_to_remove) {
                pos, _ := dequeue(&_chunks_to_generate_at)
                queue_generations_at(pos, RENDER_DISTANCE)
            }
        }
        for !is_empty(&_chunks_to_generate) {
            pos, _ := dequeue(&_chunks_to_generate)
            generate_chunk(pos)
        }
        for !is_empty(&_chunks_to_remove) {
            pos, _ := dequeue(&_chunks_to_remove)
            remove_chunk(pos)
        }
    }
}

queue_generations_at::proc(center: ChunkPos, radius: i32) {
    using utils

    bm := bench_start("queue_generations_at")
    defer bench_end(bm)

    Curry::struct {
        center: ChunkPos,
        radius: i32,
    }

    predicate::proc(pos: ChunkPos, chunk: Chunk, curry:Curry) -> bool {
        if bool(
            abs(pos.x - curry.center.x) > curry.radius ||
            abs(pos.y - curry.center.y) > curry.radius ||
            abs(pos.z - curry.center.z) > curry.radius
        ) {
            enqueue(&_chunks_to_remove, pos)
            return true
        }
        return false
    }

    delete_key_if(&_chunks, predicate, Curry{center, radius})
}

generate_chunk::proc(pos: ChunkPos) {
    chunk_layout := ChunkLayout{}
    for x := i32(0); x < 16; x += 1 {
        for z := i32(0); z < 16; z += 1 {
            height := cast(i32)noise.noise_2d(_noise_seed, {
                f64((pos.x*16 + x) / WORLD_HEIGHT),
                f64((pos.z*16 + z) / WORLD_HEIGHT)
            })
            height = clamp(height - pos.y*16, 0, 16)
            
            for y := i32(0); y < 16; y += 1 {
                chunk_layout[x + y*16 + z*16*16] = 1
            }
        }
    }
    _chunks[pos] = construct_chunk(chunk_layout)
}

construct_chunk::proc(layout: ChunkLayout) -> Chunk {
    block_counts := map[BlockID]u32{}
    chunk := Chunk{}

    for block in layout {
        block_counts[block] += 1
    }

    if len(block_counts) > 255 {
        
    }
}

remove_chunk::proc(pos: ChunkPos) {

}

