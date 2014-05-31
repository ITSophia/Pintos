#include <stdio.h>
#include <debug.h>

void alarm_block(struct thread *thread) {
    ASSERT(!intr_context());
    ASSERT(intr_get_level() == INTR_OFF);

    (*thread).status = THREAD_BLOCKED;
    schedule();
}

void alarm_unblock(struct thread *thread) {
    enum intr_level old_level;

    ASSERT(is_thread(thread));

    old_level = intr_disable();
    ASSERT(*thread -> status == THREAD_BLOCKED);
    list_push_back(&ready_list, &thread -> elem);
    thread -> status = THREAD_READY;
    intr_set_level(old_level);
}
