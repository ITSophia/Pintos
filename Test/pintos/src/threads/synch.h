#ifndef THREADS_SYNCH_H
#define THREADS_SYNCH_H

#include <list.h>
#include <stdbool.h>

/* A counting semaphore. */
struct semaphore
  {
    unsigned value;             /* Current value. */
    struct list waiters;        /* List of waiting threads. */
  };

void sema_init (struct semaphore *, unsigned value);
void sema_down (struct semaphore *);
bool sema_try_down (struct semaphore *);
void sema_up (struct semaphore *);
void sema_self_test (void);

/* Lock. */
struct lock
  {
    struct thread *holder;      /* Thread holding lock (for debugging). */
    struct semaphore semaphore; /* Binary semaphore controlling access. */

    /*
     * 定义一个链表，
     * 这个链表用于承载所有与这个lock相关的线程
     */
    struct list acquire_list;

    /*
     * 定义一个变量，
     * 这个变量用于承载acquire_list中优先级最高的那个线程的优先级
     */
    int priority_max;
  };

void lock_init (struct lock *);
void lock_acquire (struct lock *);
bool lock_try_acquire (struct lock *);
void lock_release (struct lock *);
bool lock_held_by_current_thread (const struct lock *);

/* Condition variable. */
struct condition
  {
    struct list waiters;        /* List of waiting threads. */
  };

void cond_init (struct condition *);
void cond_wait (struct condition *, struct lock *);
void cond_signal (struct condition *, struct lock *);
void cond_broadcast (struct condition *, struct lock *);

/*
 * 定义一个用于比较线程优先级的函数，
 * 方便插入
 */
bool priority_cmp(
        const struct list_elem *a,
        const struct list_elem *b,
        void *aux
);

/* 判断是不是有线程持有lock */
bool is_thread_hold_lock(const struct lock *lock);

/* 获取持有lock的线程在acquire_list中所处的位置 */
struct list_elem *get_lock_holder_elem(
        struct list *acquire_list,
        struct thread *lock_holder,
        void *aux
);

/* 翻转线程的优先级 */
void priority_swap_to_max(struct list_elem *e, int priority_max);

/* 还原线程的优先级 */
void priority_swap_to_origin(struct thread *t);

/* Optimization barrier.

   The compiler will not reorder operations across an
   optimization barrier.  See "Optimization Barriers" in the
   reference guide for more information.*/
#define barrier() asm volatile ("" : : : "memory")

#endif /* threads/synch.h */
