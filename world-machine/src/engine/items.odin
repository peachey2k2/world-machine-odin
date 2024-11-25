package engine

@(private="file")
_id_counter := ItemID(0)

get_new_item_id::proc "contextless" () -> ItemID {
    defer _id_counter += 1
    return _id_counter
}