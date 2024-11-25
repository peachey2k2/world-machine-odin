package engine

import "base:runtime"

init_core_mod::proc() -> Mod {
    core_mod_info := ModInfo{
        name = "core",
        version = "0.1",
        author = "peachey2k2",
        description = "The core mod",
    }
    core_mod := Mod{
        info = core_mod_info,
        init_functions = nil,
        init_items = init_items,
        init_blocks = init_blocks,
        init_entities = init_entities,
    }
    return core_mod
}


@(private="file")
init_items::proc "c" () {

}

@(private="file")
init_blocks::proc "c" () {
    context = runtime.default_context()
    block := InitBlockInfo{
        name = "grass",
        tooltip = "test",
        texture = create_texture(#load("res:blocks/grass.png")),
    }
    add_block(block)
    free_texture(block.texture)
}

@(private="file")
init_entities::proc "c" () {

}