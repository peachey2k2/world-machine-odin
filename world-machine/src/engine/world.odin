package engine

import "../utils"
import "core:math/noise"

_noise_seed := i64(3169)

_chunks := map[ChunkPos]Chunk{}

init_world::proc() {
    bm := utils.bench_start("init_world")
    defer utils.bench_end(bm)
    
    // noise.noise_3d_improve_xz(_noise_seed, )
}

world_loop::proc() {
    for world_should_update() {
        
    }
}