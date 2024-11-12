package utils

import "core:strings"
import "core:fmt"
import "core:slice"

init_signals::proc() {
    for i in Signals {
        engine_signals[i] = EngineSignal{
            listeners = new([dynamic]proc())
        }
    }

    defer_deinit(deinit_signals)
}

@(private) deinit_signals::proc() {
    for i in Signals {
        delete(engine_signals[i].listeners^)
    }
}

connect::proc{
    connect_signal,
    connect_engine_signal,
}

disconnect::proc{
    disconnect_signal,
    disconnect_engine_signal,
}

emit::proc{
    emit_signal,
    emit_engine_signal,
}

// Basic event system. Accesed with strings
Signal::struct {
    name : string,
    listeners : ^[dynamic]proc()
}

@(private) signals : map[string]Signal

create_signal::proc(name:string) -> (ok:bool) {
    _, has := &signals[name]
    if has do return false

    signals[name] = Signal{
        name = name,
        listeners = new([dynamic]proc())
    }

    return true
}

connect_signal::proc(name:string, to:proc()) -> (ok:bool) {
    signal, has := &signals[name]
    if !has do return false

    append(signal.listeners, to)
    return true
}

disconnect_signal::proc(name:string, from:proc()) -> (ok:bool) {
    signal, has := &signals[name]
    if !has do return false

    has = remove_elem(signal.listeners, from)
    if !has do return false

    return true
}

emit_signal::proc(name:string) {
    signal, has := &signals[name]
    if !has do return

    for &listener in signal.listeners {
        listener()
    }
}

// We also have dedicated signals to use within the engine
// These aren't tied to a string name for extra performance

EngineSignal::struct {
    listeners : ^[dynamic]proc()
}

Signals::enum {
    FRAME_START,
    FRAME_RENDER_WORLD,
    FRAME_RENDER_UI,
    FRAME_RENDER_DONE,
    FRAME_INPUT,
    FRAME_INPUT_DONE,
    FRAME_END,

    TICK_START,
    TICK_MIDDLE,
    TICK_END,
}

@(private) engine_signals : [Signals]EngineSignal

connect_engine_signal::proc(signal:Signals, to:proc()) -> (ok:bool) {
    append(engine_signals[signal].listeners, to)
    return true
}

disconnect_engine_signal::proc(signal:Signals, from:proc()) -> (ok:bool) {
    has := remove_elem(engine_signals[signal].listeners, from)
    if !has do return false

    return true
}

emit_engine_signal::proc(signal:Signals) {
    for &listener in engine_signals[signal].listeners {
        listener()
    }
}

// This is seperated from the main signals since we never remove these listeners
// and we call them in reverse order to not break stuff

@(private) deinit_list := [dynamic]proc(){}

defer_deinit::proc(deinit_function:proc()) {
    append(&deinit_list, deinit_function)
}

deinit_everything::proc() {
    #reverse for fn in deinit_list {
        fn()
    }
}

