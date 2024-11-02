package array

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

