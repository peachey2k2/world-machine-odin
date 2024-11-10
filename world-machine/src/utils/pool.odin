package utils

import "core:mem"

ObjectPool::struct($T: typeid) {
    pool: Queue(^T),
    alloc_count: int,
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
    // for (pool.pool.head - pool.pool.tail) % pool.pool.capacity <= pool.alloc_count {
    //     expand_queue(&pool.pool)
    // }
    ptr, _ := mem.alloc(pool.alloc_count * size_of(T))
    casted_ptr := transmute([^]T)ptr
    for i in 0..<pool.alloc_count {
        enqueue(&pool.pool, &(casted_ptr[i]))
    }
}
