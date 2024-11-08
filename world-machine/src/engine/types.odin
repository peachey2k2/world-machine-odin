package engine


ModID::u64

InitBlockInfo::struct {
    name, tooltip, texture, model: cstring,
}

InitEntityInfo::struct {
    name, texture, model: cstring,
    // spawn_callback: proc "c" (^EntityData),
    // stats: EntityStats, // cba to implement this rn
}


ApiFunctions::struct {
    add_block: proc "c" (block: InitBlockInfo),
    add_entity: proc "c" (entity: InitEntityInfo),
}

ModInfo::struct {
    name, version, author, description, license, source, dependencies, conflicts: cstring,
    load_order: int,
}

Mod::struct {
    info: ModInfo,
    path: string, // auto-filled by game, no need to set
    init_functions: proc "c" (^ApiFunctions),
    init_items: proc "c" (),
    init_blocks: proc "c" (),
    init_entities: proc "c" (),
}

