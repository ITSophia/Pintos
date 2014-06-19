/* This file is derived from source code for the Nachos
 *   instructional operating system.  The Nachos copyright notice
 *   is reproduced in full below. */

/* Copyright (c) 1992-1996 The Regents of the University of California.
 *   All rights reserved.
 *
 *   Permission to use, copy, modify, and distribute this software
 *   and its documentation for any purpose, without fee, and
 *   without written agreement is hereby granted, provided that the
 *   above copyright notice and the following two paragraphs appear
 *   in all copies of this software.
 *
 *   IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO
 *   ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR
 *   CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE
 *   AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF CALIFORNIA
 *   HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *   THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
 *   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 *   PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS"
 *   BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 *   PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
 *   MODIFICATIONS.
 */

#include "threads/synch.h"
#include <stdio.h>
#include <string.h>
#include "threads/interrupt.h"
#include "threads/thread.h"

/* 获取waiters队列中最高的线程优先级 */
int priority_inversion_max;

/* 捕获当前拥有临界量的线程 */
static struct thread *thread_holder;

/* Initializes semaphore SEMA to VALUE.  A semaphore is a
 *   nonnegative integer along with two atomic operators for
 *   manipulating it:
 *
 *   - down or "P": wait for the value to become positive, then
 *     decrement it.
 *
 *   - up or "V": increment the value (and wake up one waiting
 *     thread, if any). */
void
sema_init (struct semaphore *sema, unsigned value)
{
    ASSERT (sema != NULL);

    sema->value = value;
    list_init (&sema->waiters);
}

/* Down or "P" operation on a semaphore.  Waits for SEMA's value
 *   to become positive and then atomically decrements it.
 *
 *   This function may sleep, so it must not be called within an
 *   interrupt handler.  This function may be called with
 *   interrupts disabled, but if it sleeps then the next scheduled
 *   thread will probably turn interrupts back on. */
void sema_down(struct semaphore *sema) {
    enum intr_level old_level;

    ASSERT(sema != NULL);
    ASSERT(!intr_context());

    old_level = intr_disable();

    /*
     * 获取到“优先级翻转”前的优先级，
     * 所有线程都要执行这部操作，
     * 不管它是不是参与“优先级翻转”
     */
    thread_current() -> origin_priority = thread_current() -> priority;

    /* 如果信号量已经为0，则把请求信号量的线程都加入阻塞队列waiters中 */
    while (sema -> value == 0) {
        /* 捕获最高线程优先级 */
        if (thread_current() -> origin_priority > priority_inversion_max) {
            priority_inversion_max = thread_current() -> origin_priority;
        }

        /*
         * list_push_back (&sema->waiters, &thread_current ()->elem);
         * 这里使用的是直接尾插，
         * 我们需要将其修改为按照线程的优先级从低到高插入
         */
        /* 插入waiters队列 */
        list_insert_ordered(
                &sema -> waiters,
                &thread_current() -> elem,
                (list_less_func *) &origin_priority_cmp_low_to_max,
                NULL
        );

        /* Do something */
        priority_inversion(sema);

        /* 将这个申请信号量的线程阻塞 */
        thread_block();
    }

    /*
     * 这里使sema -> value--，
     * 并不是说每次调用sema_down()函数的时候都会执行这个操作，
     * 显然只有在sema -> value > 0的时候才会执行；
     * 当sema -> value == 0时，
     * 再次调用sema_down()函数将进入while()循环，
     * sema_down()函数的这个线程会因为thread_block()而阻塞，
     * 所以不会进行下一步的操作，
     * 因此sema -> value--不会被执行
     *
     * 不过这里仍然有很多疑点值得商榷，
     * 我们暂时搁置一边，不予讨论
     */
    sema -> value--;

    /* 捕获获取临界值的线程 */
    if (sema -> value == 0) {
        thread_holder = thread_current();
//         printf("(sema_down) thread_holder -> name = %s\n", thread_holder -> name);
    }

    intr_set_level(old_level);
}

/* Down or "P" operation on a semaphore, but only if the
 *   semaphore is not already 0.  Returns true if the semaphore is
 *   decremented, false otherwise.
 *
 *   This function may be called from an interrupt handler. */
bool
sema_try_down (struct semaphore *sema)
{
    enum intr_level old_level;
    bool success;

    ASSERT (sema != NULL);

    old_level = intr_disable ();
    if (sema->value > 0)
    {
        sema->value--;
        success = true;
    }
    else
        success = false;
    intr_set_level (old_level);

    return success;
}

/* Up or "V" operation on a semaphore.  Increments SEMA's value
 *   and wakes up one thread of those waiting for SEMA, if any.
 *
 *   This function may be called from an interrupt handler. */
void sema_up(struct semaphore *sema) {
    enum intr_level old_level;
    struct list *waiters = &sema -> waiters;
    struct thread *t;

    ASSERT (sema != NULL);

    old_level = intr_disable();
    if (!list_empty(&sema -> waiters)) {
        t = list_entry(list_pop_front(waiters), struct thread, elem);
        thread_unblock(t);

        /* 记住恢复当前调用seam_up()函数的线程的优先级 */
        thread_current() -> priority = thread_current() -> origin_priority;
    }
    sema -> value++;
    intr_set_level(old_level);
}

static void sema_test_helper (void *sema_);

/* Self-test for semaphores that makes control "ping-pong"
 *   between a pair of threads.  Insert calls to printf() to see
 *   what's going on. */
void
sema_self_test (void)
{
    struct semaphore sema[2];
    int i;

    printf ("Testing semaphores...");
    sema_init (&sema[0], 0);
    sema_init (&sema[1], 0);
    thread_create ("sema-test", PRI_DEFAULT, sema_test_helper, &sema);
    for (i = 0; i < 10; i++)
    {
        sema_up (&sema[0]);
        sema_down (&sema[1]);
    }
    printf ("done.\n");
}

/* Thread function used by sema_self_test(). */
static void
sema_test_helper (void *sema_)
{
    struct semaphore *sema = sema_;
    int i;

    for (i = 0; i < 10; i++)
    {
        sema_down (&sema[0]);
        sema_up (&sema[1]);
    }
}

/* Initializes LOCK.  A lock can be held by at most a single
 *   thread at any given time.  Our locks are not "recursive", that
 *   is, it is an error for the thread currently holding a lock to
 *   try to acquire that lock.
 *
 *   A lock is a specialization of a semaphore with an initial
 *   value of 1.  The difference between a lock and such a
 *   semaphore is twofold.  First, a semaphore can have a value
 *   greater than 1, but a lock can only be owned by a single
 *   thread at a time.  Second, a semaphore does not have an owner,
 *   meaning that one thread can "down" the semaphore and then
 *   another one "up" it, but with a lock the same thread must both
 *   acquire and release it.  When these restrictions prove
 *   onerous, it's a good sign that a semaphore should be used,
 *   instead of a lock. */
void
lock_init (struct lock *lock)
{
    ASSERT (lock != NULL);

    lock->holder = NULL;
    sema_init (&lock->semaphore, 1);
}

/* Acquires LOCK, sleeping until it becomes available if
 *   necessary.  The lock must not already be held by the current
 *   thread.
 *
 *   This function may sleep, so it must not be called within an
 *   interrupt handler.  This function may be called with
 *   interrupts disabled, but interrupts will be turned back on if
 *   we need to sleep. */
void lock_acquire(struct lock *lock) {
    ASSERT(lock != NULL);
    ASSERT(!intr_context ());
    ASSERT(!lock_held_by_current_thread (lock));

    /*
     * 凡是有一个lock的acquire，
     * 都将发出这个acquire的线程加入到waiters队列中，
     * 这个waiters队列实际上是一个阻塞队列，
     * 我们着重需要研究的就是如何处理这个队列，
     * 也许需要修改sema_down()函数的实现方式
     */
    sema_down(&lock -> semaphore);

    /*
     * holder在这里的意思就是“持有lock的线程”，
     * 因为只有最初lock的值为1的时候，
     * 线程才会持有lock，
     * 之后lock的值会变成0，
     * 从而导致sema_down()之后线程被阻塞，
     * 此时lock -> holder = thread_current()将不会被执行
     */
    lock -> holder = thread_current();
}

/* Tries to acquires LOCK and returns true if successful or false
 *   on failure.  The lock must not already be held by the current
 *   thread.
 *
 *   This function will not sleep, so it may be called within an
 *   interrupt handler. */
bool
lock_try_acquire (struct lock *lock)
{
    bool success;

    ASSERT (lock != NULL);
    ASSERT (!lock_held_by_current_thread (lock));

    success = sema_try_down (&lock->semaphore);
    if (success)
        lock->holder = thread_current ();
    return success;
}

/* Releases LOCK, which must be owned by the current thread.
 *
 *   An interrupt handler cannot acquire a lock, so it does not
 *   make sense to try to release a lock within an interrupt
 *   handler. */
void lock_release(struct lock *lock) {
    ASSERT(lock != NULL);
    ASSERT(lock_held_by_current_thread(lock));

    lock -> holder = NULL;
    /* 也许需要修改sema_up()函数的实现方式 */
    sema_up(&lock -> semaphore);
}

/* Returns true if the current thread holds LOCK, false
 *   otherwise.  (Note that testing whether some other thread holds
 *   a lock would be racy.) */
bool
lock_held_by_current_thread (const struct lock *lock)
{
    ASSERT (lock != NULL);

    return lock->holder == thread_current ();
}

/* One semaphore in a list. */
struct semaphore_elem
{
    struct list_elem elem;              /* List element. */
    struct semaphore semaphore;         /* This semaphore. */
};

/* Initializes condition variable COND.  A condition variable
 *   allows one piece of code to signal a condition and cooperating
 *   code to receive the signal and act upon it. */
void
cond_init (struct condition *cond)
{
    ASSERT (cond != NULL);

    list_init (&cond->waiters);
}

/* Atomically releases LOCK and waits for COND to be signaled by
 *   some other piece of code.  After COND is signaled, LOCK is
 *   reacquired before returning.  LOCK must be held before calling
 *   this function.
 *
 *   The monitor implemented by this function is "Mesa" style, not
 *   "Hoare" style, that is, sending and receiving a signal are not
 *   an atomic operation.  Thus, typically the caller must recheck
 *   the condition after the wait completes and, if necessary, wait
 *   again.
 *
 *   A given condition variable is associated with only a single
 *   lock, but one lock may be associated with any number of
 *   condition variables.  That is, there is a one-to-many mapping
 *   from locks to condition variables.
 *
 *   This function may sleep, so it must not be called within an
 *   interrupt handler.  This function may be called with
 *   interrupts disabled, but interrupts will be turned back on if
 *   we need to sleep. */
void
cond_wait (struct condition *cond, struct lock *lock)
{
    struct semaphore_elem waiter;

    ASSERT (cond != NULL);
    ASSERT (lock != NULL);
    ASSERT (!intr_context ());
    ASSERT (lock_held_by_current_thread (lock));

    sema_init (&waiter.semaphore, 0);
    list_push_back (&cond->waiters, &waiter.elem);
    lock_release (lock);
    sema_down (&waiter.semaphore);
    lock_acquire (lock);
}

/* If any threads are waiting on COND (protected by LOCK), then
 *   this function signals one of them to wake up from its wait.
 *   LOCK must be held before calling this function.
 *
 *   An interrupt handler cannot acquire a lock, so it does not
 *   make sense to try to signal a condition variable within an
 *   interrupt handler. */
void
cond_signal (struct condition *cond, struct lock *lock UNUSED)
{
    ASSERT (cond != NULL);
    ASSERT (lock != NULL);
    ASSERT (!intr_context ());
    ASSERT (lock_held_by_current_thread (lock));

    if (!list_empty (&cond->waiters))
        sema_up (&list_entry (list_pop_front (&cond->waiters),
                              struct semaphore_elem, elem)->semaphore);
}

/* Wakes up all threads, if any, waiting on COND (protected by
 *   LOCK).  LOCK must be held before calling this function.
 *
 *   An interrupt handler cannot acquire a lock, so it does not
 *   make sense to try to signal a condition variable within an
 *   interrupt handler. */
void
cond_broadcast (struct condition *cond, struct lock *lock)
{
    ASSERT (cond != NULL);
    ASSERT (lock != NULL);

    while (!list_empty (&cond->waiters))
        cond_signal (cond, lock);
}

/*
 * 定义一个比较线程priority高低的函数，
 * 用于semaphore -> waiters队列“从低到高”的排序
 */
bool priority_cmp_low_to_max(
    const struct list_elem *a,
    const struct list_elem *b,
    void *aux UNUSED
) {
    struct thread *ta = list_entry(a, struct thread, elem);
    struct thread *tb = list_entry(b, struct thread, elem);

    /* 使priority“从低到高”排列 */
    if ((ta -> priority) > (tb -> priority)) {
        return false;
    } else {
        return true;
    }
}

/*
 * 定义一个比较线程priority高低的函数，
 * 用于semaphore -> waiters队列“从高到低”的排序
 */
bool priority_cmp_max_to_low(
    const struct list_elem *a,
    const struct list_elem *b,
    void *aux UNUSED
) {
    struct thread *ta = list_entry(a, struct thread, elem);
    struct thread *tb = list_entry(b, struct thread, elem);

    /* 使priority“从高到低”排列 */
    if ((ta -> priority) < (tb -> priority)) {
        return false;
    } else {
        return true;
    }
}

/*
 * 定义一个比较线程origin_priority高低的函数，
 * 用于semaphore -> waiters队列“从低到高”的排序
 */
bool origin_priority_cmp_low_to_max(
    const struct list_elem *a,
    const struct list_elem *b,
    void *aux UNUSED
) {
    struct thread *ta = list_entry(a, struct thread, elem);
    struct thread *tb = list_entry(b, struct thread, elem);

    /* 使origin_priority“从低到高”排列 */
    if ((ta -> origin_priority) > (tb -> origin_priority)) {
        return false;
    } else {
        return true;
    }
}

/*
 * 定义一个比较线程origin_priority高低的函数，
 * 用于semaphore -> waiters队列“从高到低”的排序
 */
bool origin_priority_cmp_max_to_low(
    const struct list_elem *a,
    const struct list_elem *b,
    void *aux UNUSED
) {
    struct thread *ta = list_entry(a, struct thread, elem);
    struct thread *tb = list_entry(b, struct thread, elem);

    /* 使origin_priority“从高到低”排列 */
    if ((ta -> origin_priority) < (tb -> origin_priority)) {
        return false;
    } else {
        return true;
    }
}

/* 定义一个用于处理“优先级翻转”的函数 */
void priority_inversion(struct semaphore *sema) {
    /* 取得与信号量相关的请求队列 */
    struct list *waiters = &sema -> waiters;

    /* 对请求队列中的线程按照origin_priority“从低到高”进行排序 */
    list_sort(waiters, &origin_priority_cmp_low_to_max, NULL);

//     enum intr_level old_level = intr_disable();
//     printf("(priority_inversion) priority_inversion_max = %d\n", priority_inversion_max);
//     intr_set_level(old_level);

    /* 将max_priority赋给当前正在运行的线程 */
    thread_holder -> priority = priority_inversion_max;

//     struct list_elem *e;
//     struct thread *t;
//     int max = -1;
//     for (e = list_begin(waiters); e != list_end(waiters); e = list_next(e)) {
//         t = list_entry(e, struct thread, elem);
//         if ((t -> origin_priority) > max) {
//             max = t -> origin_priority;
//         }
//     }
//     thread_holder -> priority = max;
}
