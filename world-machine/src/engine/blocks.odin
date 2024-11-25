package engine

_blocks := [dynamic]Block{}

add_block::proc (info: InitBlockInfo) {
    block := Block{
        itemID = get_new_item_id(),
        textureID = add_texture_to_atlas(info.texture^),
        name = string(info.name),
        tooltip = string(info.tooltip),
    }
    append(&_blocks, block)
}