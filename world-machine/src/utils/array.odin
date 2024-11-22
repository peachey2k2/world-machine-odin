package utils

find_elem::proc(arr: ^$D/[dynamic]$T, elem: T) -> (idx:int, ok:bool) {
    for &item, idx in arr {
        if item == elem do return idx, true
    }
    return -1, false
}

remove_elem::proc(arr: ^$D/[dynamic]$T, elem: T) -> (ok:bool) {
    idx, has := find_elem(arr, elem)
    if !has do return false

    ordered_remove(arr, idx)
    return true
}

index_of::proc(arr: ^$D/[dynamic]$T, elem_addr: ^T) -> (idx:int, has:bool) {
    idx = transmute(int)elem_addr - transmute(int)arr
    if idx >= len(arr) || idx < 0 do return -1, false
    return idx, true
}

