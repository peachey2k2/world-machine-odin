package main

import "engine/core"

main::proc() {
    core.init()
    core.main_loop()
    core.deinit()
}