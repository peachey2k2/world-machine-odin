package utils

destroy::proc {
    destroy_regular_queue,
    destroy_one_to_one_queue,
    destroy_pool,
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

is_empty::proc {
    is_empty_regular,
    is_empty_one_to_one,
}

call_for_all::proc {
    call_for_all_regular,
    call_for_all_one_to_one,
    call_for_all_pool,
}

length::proc {
    len_regular,
    len_one_to_one,
    len_pool,
}