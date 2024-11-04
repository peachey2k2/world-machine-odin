package signals

init::proc() {
    for i in Signals {
        engine_signals[i] = EngineSignal{
            listeners = new([dynamic]proc())
        }
    }

    defer_deinit(deinit)
}

@(private) deinit::proc() {
    for i in Signals {
        delete(engine_signals[i].listeners^)
    }
}