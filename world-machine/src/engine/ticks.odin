package engine

import "core:time"

import "src:utils"

TICKS_PER_SECOND :: 20
TICK_RATE :: time.Second / TICKS_PER_SECOND

@(private="file") _tick_desync := time.Duration(0)

tick_loop::proc() {
    for world_should_tick() {
        _tick_desync += last_frame_time()
        if _tick_desync >= TICK_RATE {
            _tick_desync -= TICK_RATE

            utils.emit_engine_signal(.TICK_START)
            tick()
            utils.emit_engine_signal(.TICK_END)
        }
    }
}

@(private="file")
tick::proc() {
    utils.bench("tick")
}
