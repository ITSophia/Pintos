/* This file is derived from source code for the Nachos
   instructional operating system.  The Nachos copyright notice
   is reproduced in full below. */

/* Copyright (c) 1992-1996 The Regents of the University of California.
   All rights reserved.

   Permission to use, copy, modify, and distribute this software
   and its documentation for any purpose, without fee, and
   without written agreement is hereby granted, provided that the
   above copyright notice and the following two paragraphs appear
   in all copies of this software.

   IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO
   ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR
   CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE
   AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF CALIFORNIA
   HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

   THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY
   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
   PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS"
   BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
   PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
   MODIFICATIONS.
*/

#include "threads/synch.h"
#include <stdio.h>
#include <string.h>
#include "threads/interrupt.h"
#include "threads/thread.h"

/* Initializes semaphore SEMA to VALUE.  A semaphore is a
   nonnegative integer along with two atomic operators for
   manipulating it:

   - down or "P": wait for the value to become positive, then
     decrement it.

   - up or "V": increment the value (and wake up one waiting
     thread, if any). */
void
sema_init (struct semaphore *sema, unsigned value)
{
  ASSERT (sema != NULL);

  sema->value = value;
  list_init (&sema->waiters);
}

/* Down or "P" operation on a semaphore.  Waits for SEMA's value
   to become positive and then atomically decrements it.

   This function may sleep, so it must not be called within an
   interrupt handler.  This function may be called with
   interrupts disabled, but if it sleeps then the next scheduled
   thread will probably turn interrupts back on. */
void
sema_down (struct semaphore *sema)
{
  enum intr_level old_level;

  ASSERT (sema != NULL);
  ASSERT (!intr_context ());

  old_level = intr_disable ();
  while (sema->value == 0)
    {
      list_push_back (&sema->waiters, &thread_current ()->elem);
      thread_block ();
    }
  sema->value--;
  intr_set_level (old_level);
}

/* Down or "P" operation on a semaphore, but only if the
   semaphore is not already 0.  Returns true if the semaphore is
   decremented, false otherwise.

   This function may be called from an interrupt handler. */
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
   and wakes up one thread of those waiting for SEMA, if any.

   This function may be called from an interrupt handler. */
void
sema_up (struct semaphore *sema)
{
  enum intr_level old_level;

  ASSERT (sema != NULL);

  old_level = intr_disable ();
  if (!list_empty (&sema->waiters))
    thread_unblock (list_entry (list_pop_front (&sema->waiters),
                                struct thread, elem));
  sema->value++;
  intr_set_level (old_level);
}

static void sema_test_helper (void *sema_);

/* Self-test for semaphores that makes control "ping-pong"
   between a pair of threads.  Insert calls to printf() to see
   what's going on. */
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
   thread at any given time.  Our locks are not "recursive", that
   is, it is an error for the thread currently holding a lock to
   try to acquire that lock.

   A lock is a specialization of a semaphore with an initial
   value of 1.  The difference between a lock and such a
   semaphore is twofold.  First, a semaphore can have a value
   greater than 1, but a lock can only be owned by a single
   thread at a time.  Second, a semaphore does not have an owner,
   meaning that one thread can "down" the semaphore and then
   another one "up" it, but with a lock the same thread must both
   acquire and release it.  When these restrictions prove
   onerous, it's a good sign that a semaphore should be used,
   instead of a lock. */
void
lock_init (struct lock *lock)
{
  ASSERT (lock != NULL);

  lock->holder = NULL;
  sema_init (&lock->semaphore, 1);

  /* 初始化承载链表中最高优先级的变量，初值设为-1 */
  lock -> priority_max = -1;
  /* 初始化lock中用于管理相关线程的链表 */
  list_init(lock -> acquire_list);
}

/*
 * 定义一个用于比较线程优先级的函数，
 * 方便插入
 */
bool priority_cmp(
        const struct list_elem *a,
        const struct list_elem *b,
        void *aux UNUSED
) {
    struct thread *ta = list_entry(a, struct thread, elem);
    struct thread *tb = list_entry(b, struct thread, elem);

    /* 在这里使用升序 */
    if ((ta -> priority) > (tb -> priority)) {
        return false;
    } else {
        return true;
    }
}

/* 判断是不是有线程持有lock */
bool is_thread_hold_lock(const struct lock *lock) {
    if (lock -> holder == NULL) {
        return false;
    } else {
        return true;
    }
}

/* 获取持有lock的线程在acquire_list中所处的位置 */
struct list_elem *get_lock_holder_elem(
        struct list *acquire_list,
        struct thread *lock_holder,
        void *aux
) {
    struct list_elem *e;
    struct thread *t;
    
    /* 在acquire_list中遍历查找 */
    for (
            e = list_begin(acquire_list); 
            e != list_end(acquire_list); 
            e = list_next(e)
    ) {
        t = list_entry(e, struct thread, elem);
        /* 用tid判断线程是否符合要求，因为tid是唯一的 */
        if (t -> tid == lock_holder -> tid) {
            break;
        }
    }

    return e;
}

/* 翻转线程的优先级 */
void priority_swap_to_max(struct list_elem *e, int priority_max) {
    struct thread *t;

    t = list_entry(e, struct thread, elem);
    /* 也许这部分应该写入thread_set_priority()函数中 */
    t -> origin_priority = t -> priority;
    t -> priority = priority_max;
}

/* 还原线程的优先级 */
void priority_swap_to_origin(struct thread *t) {
    t -> priority = t -> origin_priority;
}

/* Acquires LOCK, sleeping until it becomes available if
   necessary.  The lock must not already be held by the current
   thread.

   This function may sleep, so it must not be called within an
   interrupt handler.  This function may be called with
   interrupts disabled, but interrupts will be turned back on if
   we need to sleep. */
void
lock_acquire (struct lock *lock)
{
  /* 定义一些需要用到的变量 */
  struct list_elem *max_priority_elem;
  struct thread *max_priority_thread;
  struct list_elem *lock_holder_elem;
  struct list_elem *temp;

  ASSERT (lock != NULL);
  ASSERT (!intr_context ());
  ASSERT (!lock_held_by_current_thread (lock));

  /*
   * 注释掉原有的代码
   * sema_down (&lock->semaphore);
   * lock->holder = thread_current ();
   */

  /* 首先确定acquire_list中最高的优先级 */
  if (lock -> priority_max < thread_current() -> priority) {
      lock -> priority_max = thread_current() -> priority;
  }

  /* 
   * 首先把当前请求的线程按照优先级升序加入到acquire_list中
   * 
   * 注意，
   * 一个线程如果没有获得lock，
   * 那么它就会被被阻塞，
   * 而不会一直申请，
   * 所以理论上acquire_list中应该不会出现重复的元素
   */
  list_insert_ordered(
          &(lock -> acquire_list),
          &(thread_current() -> elem),
          (list_less_func *) &priority_cmp,
          NULL
  );

  /*
   * 首先判断是不是有线程持有lock，
   * 如果没有，
   * 则直接把lock赋给acquire_list中优先级最高的那个线程；
   * 如果有，
   * 则对acquire_list中的线程进行适当的操作
   *
   * 注意之前ASSERT已经确定了当前请求的线程并不持有lock
   */
  if (is_thread_hold_lock(lock) == false) {
      /* 取得acquire_list中优先级最高的线程 */
      max_priority_elem = list_max(
              &lock -> acquire_list,
              (list_less_func *) &priority_cmp,
              NULL
      );
      max_priority_thread = list_entry(
              max_priority_elem,
              struct thread,
              elem
      );
      sema_down(&lock -> semaphore);
      /* 将lock赋给这个线程 */
      lock -> holder = max_priority_thread;
  } else {
      /*
       * 再从acquire_list中挑选出一个合适的线程进行分配，
       * 总体来说就是，
       * 在acquire_list中找到持有lock的线程，
       * 将它和之后的线程的优先级全部提升到priority_max，
       * 这样就能避免“优先级翻转”以及“嵌套”这种情况了
       *
       * 由于已经有线程持有lock了，
       * 所以我们不需要在这里将lock赋给任意一个线程，
       * 所需要的就是提升优先级，
       * 尽可能的让当前持有lock的线程运行完毕，
       * 将lock释放出去
       */
      /* 在acquire_list中找到持有lock的线程 */
      lock_holder_elem = get_lock_holder_elem(
              &lock -> acquire_list,
              &lock -> holder,
              NULL;
      );
      /* 将这个线程及其之后的线程的优先级全部提升到priority_max */
      for (
              temp = lock_holder_elem; 
              temp != list_end(&lock -> acquire_list); 
              temp = list_next(temp)
      ) {
          priority_swap_to_max(temp, priority_max);
      }
}

/* Tries to acquires LOCK and returns true if successful or false
   on failure.  The lock must not already be held by the current
   thread.

   This function will not sleep, so it may be called within an
   interrupt handler. */
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

   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to release a lock within an interrupt
   handler. */
void
lock_release (struct lock *lock)
{
  ASSERT (lock != NULL);
  ASSERT (lock_held_by_current_thread (lock));

  lock->holder = NULL;
  sema_up (&lock->semaphore);
}

/* Returns true if the current thread holds LOCK, false
   otherwise.  (Note that testing whether some other thread holds
   a lock would be racy.) */
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
   allows one piece of code to signal a condition and cooperating
   code to receive the signal and act upon it. */
void
cond_init (struct condition *cond)
{
  ASSERT (cond != NULL);

  list_init (&cond->waiters);
}

/* Atomically releases LOCK and waits for COND to be signaled by
   some other piece of code.  After COND is signaled, LOCK is
   reacquired before returning.  LOCK must be held before calling
   this function.

   The monitor implemented by this function is "Mesa" style, not
   "Hoare" style, that is, sending and receiving a signal are not
   an atomic operation.  Thus, typically the caller must recheck
   the condition after the wait completes and, if necessary, wait
   again.

   A given condition variable is associated with only a single
   lock, but one lock may be associated with any number of
   condition variables.  That is, there is a one-to-many mapping
   from locks to condition variables.

   This function may sleep, so it must not be called within an
   interrupt handler.  This function may be called with
   interrupts disabled, but interrupts will be turned back on if
   we need to sleep. */
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
   this function signals one of them to wake up from its wait.
   LOCK must be held before calling this function.

   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
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
   LOCK).  LOCK must be held before calling this function.

   An interrupt handler cannot acquire a lock, so it does not
   make sense to try to signal a condition variable within an
   interrupt handler. */
void
cond_broadcast (struct condition *cond, struct lock *lock)
{
  ASSERT (cond != NULL);
  ASSERT (lock != NULL);

  while (!list_empty (&cond->waiters))
    cond_signal (cond, lock);
}
