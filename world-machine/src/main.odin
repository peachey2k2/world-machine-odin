package main

import "engine"

main::proc() {
    engine.init()
    engine.main_loop()
    engine.deinit()
}