package utils

import "core:c/libc"
import "core:sync"
import "core:math/bits"

destroy_queue::proc {
    destroy_regular_queue,
    destroy_one_to_one_queue,
}

expand_queue::proc {
    expand_regular_queue,
    expand_one_to_one_queue,
}

enqueue::proc {
    enqueue_regular,
    enqueue_one_to_one,
}

dequeue::proc {
    dequeue_regular,
    dequeue_one_to_one,
}

// Ring buffer with dynamic size and atomic enqueue/dequeue operations
Queue::struct($T:typeid) {
    data: ^T,
    capacity: int,
    head, tail: int,
    expanding: b32, // only used when resizing
}

// Create a new queue for given type.
create_queue::proc($T:typeid, capacity:int = 16) -> Queue(T) {
    result := Queue(T){
        data = transmute(T)libc.malloc(capacity * size_of(T)),
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
    libc.free(ptr)
}

expand_regular_queue::proc(q: ^Queue($T)) {
    sync.atomic_store(&q.expanding, true)
    q.data = libc.realloc(q.data, q.capacity * 2 * size_of(T))
    libc.memcpy(
        q.data + q.tail + q.capacity,
        q.data + q.tail,
        (q.capacity - q.tail) * size_of(T)
    )
    q.capacity *= 2
    sync.atomic_store(&q.expanding, false)
}

// Add an element at the end of the queue
enqueue_regular::proc(q: ^Queue($T), elem: T) {
    assert(data != nil, "Queue is not initialized or destroyed")
    sync.futex_wait(transmute(^sync.Futex)&q.expanding, false)
    if head == tail do expand_queue(q)
    q.data[q.tail] = elem
    sync.atomic_store(&q.tail, (q.tail + 1) % q.capacity)
}

// Remove and return the first element from the queue
dequeue_regular::proc(q: ^Queue($T)) -> (elem: T, ok: bool) {
    assert(data != nil, "Queue is not initialized or destroyed")
    if head == tail do return T{}, false
    elem = q.data[q.head]
    sync.atomic_store(&q.head, (q.head + 1) % q.capacity)
    return elem, true
}

// Use this if you're sure the queue is only filled by one thread
// and emptied by another. This is faster than the regular queue.
OneToOneQueue::struct($T:typeid) {
    data: ^T,
    capacity: int,
    head, tail: int,
}

create_one_to_one_queue::proc($T:typeid, capacity:int = 16) -> OneToOneQueue(T) {
    result := OneToOneQueue(T){
        data = transmute(T)libc.malloc(capacity * size_of(T)),
        capacity = capacity,
        head = 0,
        tail = 0,
    }
    return result
}

destroy_one_to_one_queue::proc(q: ^OneToOneQueue($T)) {
    ptr := q.data
    q.data = nil
    libc.free(ptr)
}

expand_one_to_one_queue::proc(q: ^OneToOneQueue($T)) {
    q.data = libc.realloc(q.data, q.capacity * 2 * size_of(T))
    libc.memcpy(
        q.data + q.tail + q.capacity,
        q.data + q.tail,
        (q.capacity - q.tail) * size_of(T)
    )
    q.capacity *= 2
}

enqueue_one_to_one::proc(q: ^OneToOneQueue($T), elem: T) {
    assert(data != nil, "Queue is not initialized or destroyed")
    if head == tail do expand_queue(q)
    q.data[q.tail] = elem
    sync.atomic_store(&q.tail, (q.tail + 1) % q.capacity)
}

dequeue_one_to_one::proc(q: ^OneToOneQueue($T)) -> (elem: T, ok: bool) {
    assert(data != nil, "Queue is not initialized or destroyed")
    if head == tail do return T{}, false
    elem = q.data[q.head]
    sync.atomic_store(&q.head, (q.head + 1) % q.capacity)
    return elem, true
}

