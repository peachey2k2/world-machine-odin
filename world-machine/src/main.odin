package main

import "engine"

main::proc() {
    core.init()
    core.main_loop()
    core.deinit()
}