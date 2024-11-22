package engine

import sdl "vendor:sdl2"

// Position of a chunk
ChunkPos::[3]i32 

// Position of a block in __world__ space
BlockPos::[3]i32

// Position of a block in __chunk__ space
ChunkedBlockPos::[3]u8

// Position of an entity or a point in __world__ space
Position::[3]f64

// Position of an entity or a point in __chunk__ space
ChunkedPosition::[3]f64

// Velocity of an entity
Velocity::[3]f64

// Unique IDs are created at runtime, and are used to index into the block atlas
BlockID::u32
ItemID::u32
TextureID::u32

Color::sdl.Color

Range::struct($T:typeid) {
    min, max : T,
}

IndirectCommand::struct {
    count:          u32,
    instance_count: u32,
    first:          u32,
    base_instance:  u32,
}

Block::struct {
    itemID:     ItemID, // needed for conversion
    textureID:  TextureID,
    name:       string,
    tooltip:    string,
}

SmallChunk::struct {
    data:   [16*16*16]u8,
    blocks: [dynamic]BlockID,
}

LargeChunk::struct {
    data: [16*16*16]BlockID,
}

ChunkBitMask::[16*16]u16

// This is the main chunk struct. Small chunks are used when the chunk has
// less than 256 unique blocks. Use dedicated functions to modify the chunk.
// Do not modify the chunk directly, you're probably going to mess it up.
Chunk::struct { // yxz
    small:      ^SmallChunk,
    large:      ^LargeChunk,
    cull_mask:  ^ChunkBitMask,
}

// Used when constructing a chunk
ChunkLayout:: [16*16*16]u32

// raw texture data
RawTexture::struct {
    data:   []Color,
    width:  u32,
    height: u32,
}

BlockFaces::enum {
    NORTH, SOUTH,
    EAST,  WEST,
    TOP,   BOTTOM,
}

ObjectType::enum {
    BLOCK, ENTITY, ITEM, FLUID,
}

// Returned by raycast functions
RayTarget::struct {
    id:     u64,
    pos:    BlockPos,
    face:   BlockFaces,
    type:   ObjectType,
}

MobStats::struct {
    health:         f64,
    speed:          f64,
    attack:         f64,
    defense:        f64,
    attack_speed:   f64,
    attack_range:   f64,
}


ModID::u64

InitItemInfo::struct {
    name, tooltip, texture, model: cstring,
}

InitBlockInfo::struct {
    name:       cstring,
    tooltip:    cstring,
    texture:    RawTexture,
    // model: // TODO: implement this
}

InitEntityInfo::struct {
    name, texture, model: cstring,
    // spawn_callback: proc "c" (^EntityData),
    // stats: EntityStats, // cba to implement this rn
}


ApiFunctions::struct {
    add_block:      proc "c" (block: InitBlockInfo),
    add_entity:     proc "c" (entity: InitEntityInfo),
    add_item:       proc "c" (item: InitItemInfo),
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

