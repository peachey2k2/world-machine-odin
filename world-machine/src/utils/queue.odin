package utils

import "core:sync"
import "core:mem"
import "core:math/bits"

// Ring buffer with dynamic size and atomic enqueue/dequeue operations
Queue::struct($T:typeid) {
    data: [^]T,
    capacity: int,
    head, tail: int,
    expanding: b32, // only used when resizing
}

// Create a new queue for given type.
@(require_results)
create_queue::proc($T:typeid, capacity:int = 16) -> Queue(T) {
    data_ptr, _ := mem.alloc(capacity * size_of(T))
    result := Queue(T){
        data = transmute(^T)data_ptr,
        capacity = capacity,
        head = 0,
        tail = 0,
        expanding = false,
    }
    return result
}

// Destroy the queue and free the memory
destroy_regular_queue::proc(q: ^Queue($T)) {
    ptr := q.data
    q.data = nil
    free(ptr)
}

expand_regular_queue::proc(q: ^Queue($T)) {
    sync.atomic_store(&q.expanding, true)
    new_ptr, _ := mem.resize(q.data, q.capacity*size_of(T), q.capacity*2*size_of(T))
    q.data = transmute(^T)new_ptr
    copy(q.data[q.tail + q.capacity:q.capacity*2], q.data[q.tail:q.capacity])
    q.head += q.capacity
    q.capacity *= 2
    sync.atomic_store(&q.expanding, false)
    sync.futex_broadcast(transmute(^sync.Futex)&q.expanding)
}

// Add an element at the end of the queue
enqueue_regular::proc(q: ^Queue($T), elem: T) {
    assert(q.data != nil, "Queue is not initialized or destroyed")
    sync.futex_wait(transmute(^sync.Futex)&q.expanding, transmute(u32)b32(true))
    if q.head == (q.tail+1) % q.capacity do expand_queue(q)
    q.data[q.tail] = elem
    sync.atomic_store(&q.tail, (q.tail + 1) % q.capacity)
}

// Remove and return the first element from the queue
dequeue_regular::proc(q: ^Queue($T)) -> (elem: T, ok: bool) #optional_ok {
    assert(q.data != nil, "Queue is not initialized or destroyed")
    sync.futex_wait(transmute(^sync.Futex)&q.expanding, transmute(u32)b32(true))
    if is_empty(q) do return T{}, false
    elem = q.data[q.head]
    sync.atomic_store(&q.head, (q.head + 1) % q.capacity)
    return elem, true
}

is_empty_regular::proc(q: ^Queue($T)) -> bool {
    return q.head == q.tail
}

call_for_all_regular::proc(q: ^Queue($T), curry: $C, f: proc(elem: T, curry: C)) {
    if is_empty_regular(q) do return
    if q.head < q.tail {
        for i in q.head..<q.tail {
            f(q.data[i], curry)
        }
    } else {
        for i in q.head..<q.capacity {
            f(q.data[i], curry)
        }
        for i in 0..<q.tail {
            f(q.data[i], curry)
        }
    }
}

len_regular::#force_inline proc(q: Queue($T)) -> int {
    return (q.tail - q.head) %% q.capacity
}

// Use this if you're sure the queue is only filled by one thread
// and emptied by another. This is a little bit faster than the
// regular queue since it doesn't use a futex.
OneToOneQueue::struct($T:typeid) {
    data: [^]T,
    capacity: int,
    head, tail: int,
}

@(require_results)
create_one_to_one_queue::proc($T:typeid, capacity:int = 16) -> OneToOneQueue(T) {
    data_ptr, _ := mem.alloc(capacity * size_of(T))
    result := OneToOneQueue(T){
        data = transmute(^T)data_ptr,
        capacity = capacity,
        head = 0,
        tail = 0,
    }
    return result
}

destroy_one_to_one_queue::proc(q: ^OneToOneQueue($T)) {
    ptr := q.data
    q.data = nil
    free(ptr)
}

expand_one_to_one_queue::proc(q: ^OneToOneQueue($T)) {
    new_ptr, _ := mem.resize(q.data, q.capacity*size_of(T), q.capacity*2*size_of(T))
    q.data = transmute(^T)new_ptr
    copy(q.data[q.tail + q.capacity:q.capacity*2], q.data[q.tail:q.capacity])
    q.head += q.capacity
    q.capacity *= 2
}

enqueue_one_to_one::proc(q: ^OneToOneQueue($T), elem: T) {
    assert(q.data != nil, "Queue is not initialized or destroyed")
    if q.head == (q.tail+1) % q.capacity do expand_queue(q)
    q.data[q.tail] = elem
    sync.atomic_store(&q.tail, (q.tail + 1) % q.capacity)
}

dequeue_one_to_one::proc(q: ^OneToOneQueue($T)) -> (elem: T, ok: bool) #optional_ok {
    assert(q.data != nil, "Queue is not initialized or destroyed")
    if is_empty(q) do return T{}, false
    elem = q.data[q.head]
    sync.atomic_store(&q.head, (q.head + 1) % q.capacity)
    return elem, true
}

is_empty_one_to_one::proc(q: ^OneToOneQueue($T)) -> bool {
    return q.head == q.tail
}

call_for_all_one_to_one::proc(q: ^OneToOneQueue($T), curry: $C, f: proc(elem: T, curry: C)) {
    if is_empty_one_to_one(q) do return
    if q.head < q.tail {
        for i in q.head..<q.tail {
            f(q.data[i], curry)
        }
    } else {
        for i in q.head..<q.capacity {
            f(q.data[i], curry)
        }
        for i in 0..<q.tail {
            f(q.data[i], curry)
        }
    }
}

len_one_to_one::#force_inline proc(q: OneToOneQueue($T)) -> int {
    return (q.tail - q.head) %% q.capacity
}

