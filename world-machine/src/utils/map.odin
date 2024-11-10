package utils

delete_key_if::proc(in_map: ^map[$K]$V, pred: proc(key: K, value: V, curry: $C) -> bool, curry: C) {
    for key, value in in_map {
        if pred(key, value, curry) {
            delete_key(in_map, key)
        }
    }
}