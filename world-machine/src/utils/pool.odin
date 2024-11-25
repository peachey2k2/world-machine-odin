package utils

import "core:mem"

ObjectPool::struct($T: typeid) {
    pool: Queue(^T),
    alloc_count: int,
    ptrs: [dynamic]^T,
}

@(require_results)
create_pool::proc($T: typeid, alloc_count: int = 16, capacity: int = 32) -> ObjectPool(T) {
    pool := ObjectPool(T){
        pool = create_queue(^T, capacity),
        alloc_count = alloc_count,
    }
    refill(&pool)
    return pool
}

destroy_pool::proc(pool: ^ObjectPool($T)) {
    for ptr in pool.ptrs {
        free(ptr)
    }
    delete(pool.ptrs)
    destroy(&pool.pool)
}

@(require_results)
acquire::proc(pool: ^ObjectPool($T)) -> (elem: ^T, ok: bool) {
    if is_empty(&pool.pool) {
        refill(pool)
    }
    return dequeue(&pool.pool)
}

release::proc(pool: ^ObjectPool($T), item: ^T) {
    enqueue(&pool.pool, item)
}

// @(private="file")
refill::proc(pool: ^ObjectPool($T)) {
    ptr, _ := mem.alloc(pool.alloc_count * size_of(T))
    casted_ptr := transmute([^]T)ptr
    for i in 0..<pool.alloc_count {
        enqueue(&pool.pool, &(casted_ptr[i]))
    }
    append(&pool.ptrs, casted_ptr)
}

call_for_all_pool::proc(p: ^ObjectPool($T), curry: $C, f: proc(elem: ^T, curry: C)) {
    call_for_all_regular(&p.pool, curry, f)
}

len_pool::#force_inline proc(p: ObjectPool($T)) -> int {
    return len_regular(p.pool)
}
