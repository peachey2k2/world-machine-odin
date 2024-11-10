package engine

ChunkPos::[3]i32 
BlockPos::[3]u32
Position::[3]f64
Velocity::[3]f64

BlockID::u32

Range::struct($T:typeid) {
    min, max : T,
}

IndirectCommand::struct {
    count, instance_count, first, base_instance: u32,
}

Block::struct {
    // itemID: u64, not needed, we already can index into it
    textureID: u32,
    name: string,
    tooltip: string,
    texture: string,
}

SmallChunk::struct {
    data: [16*16*16]u8,
    blocks: [dynamic]u64,
}

LargeChunk::struct {
    data: [16*16*16]u32,
}

// This is the main chunk struct. Small chunks are used when the chunk has
// less than 256 unique blocks. Use dedicated functions to modify the chunk.
// Do not modify the chunk directly, you're probably going to mess it up.
Chunk::struct {
    small: ^SmallChunk,
    large: ^LargeChunk,
}

// Used when constructing a chunk
ChunkLayout:: [16*16*16]u32

BlockFaces::enum {
    NORTH, EAST, TOP, SOUTH, WEST, BOTTOM,
}

ObjectType::enum {
    BLOCK, ENTITY, ITEM, FLUID,
}

// Returned by raycast functions
RayTarget::struct {
    id: u64,
    pos: BlockPos,
    face: BlockFaces,
    type: ObjectType,
}

MobStats::struct {
    health: f64,
    speed: f64,
    attack: f64,
    defense: f64,
    attack_speed: f64,
    attack_range: f64,
}


ModID::u64

InitItemInfo::struct {
    name, tooltip, texture, model: cstring,
}

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
    add_item: proc "c" (item: InitItemInfo),
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

