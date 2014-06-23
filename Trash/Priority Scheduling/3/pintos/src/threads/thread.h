#ifndef THREADS_THREAD_H
#define THREADS_THREAD_H

#include <debug.h>
#include <list.h>
#include <stdint.h>

/* States in a thread's life cycle. */
enum thread_status
  {
    THREAD_RUNNING,     /* Running thread. */
    THREAD_READY,       /* Not running but ready to run. */
    THREAD_BLOCKED,     /* Waiting for an event to trigger. */
    THREAD_DYING        /* About to be destroyed. */
  };

/* Thread identifier type.
   You can redefine this to whatever type you like. */
typedef int tid_t;
#define TID_ERROR ((tid_t) -1)          /* Error value for tid_t. */

/* Thread priorities. */
#define PRI_MIN 0                       /* Lowest priority. */
#define PRI_DEFAULT 31                  /* Default priority. */
#define PRI_MAX 63                      /* Highest priority. */

/* A kernel thread or user process.

   Each thread structure is stored in its own 4 kB page.  The
   thread structure itself sits at the very bottom of the page
   (at offset 0).  The rest of the page is reserved for the
   thread's kernel stack, which grows downward from the top of
   the page (at offset 4 kB).  Here's an illustration:

        4 kB +---------------------------------+
             |          kernel stack           |
             |                |                |
             |                |                |
             |                V                |
             |         grows downward          |
             |                                 |
             |                                 |
             |                                 |
             |                                 |
             |                                 |
             |                                 |
             |                                 |
             |                                 |
             +---------------------------------+
             |              magic              |
             |                :                |
             |                :                |
             |               name              |
             |              status             |
        0 kB +---------------------------------+

   The upshot of this is twofold:

      1. First, `struct thread' must not be allowed to grow too
         big.  If it does, then there will not be enough room for
         the kernel stack.  Our base `struct thread' is only a
         few bytes in size.  It probably should stay well under 1
         kB.

      2. Second, kernel stacks must not be allowed to grow too
         large.  If a stack overflows, it will corrupt the thread
         state.  Thus, kernel functions should not allocate large
         structures or arrays as non-static local variables.  Use
         dynamic allocation with malloc() or palloc_get_page()
         instead.

   The first symptom of either of these problems will probably be
   an assertion failure in thread_current(), which checks that
   the `magic' member of the running thread's `struct thread' is
   set to THREAD_MAGIC.  Stack overflow will normally change this
   value, triggering the assertion. */
/* The `elem' member has a dual purpose.  It can be an element in
   the run queue (thread.c), or it can be an element in a
   semaphore wait list (synch.c).  It can be used these two ways
   only because they are mutually exclusive: only a thread in the
   ready state is on the run queue, whereas only a thread in the
   blocked state is on a semaphore wait list. */
struct thread {
    /* Owned by thread.c. */
    tid_t tid;                          /* Thread identifier. */
    enum thread_status status;         /* Thread state. */
    char name[16];                      /* Name (for debugging purposes). */
    uint8_t *stack;                     /* Saved stack pointer. */
    int priority;                       /* Priority. */
    struct list_elem allelem;          /* List element for all threads list. */

    /* Shared between thread.c and synch.c. */
    struct list_elem elem;             /* List element. */

    /*
     * 用于2.2.3 Priority Scheduling，
     * 在这里需要详细说明一下下面定义的四个变量的作用：
     * 1. struct lock *wait_on_lock
     *    hold_lock用于承载与线程本身相关的lock，
     *    也就是当前线程请求的lock；
     *    有趣的是，我们在lock的结构体定义中会看到一个holder，
     *    这个holder是用来承载当前持有lock的线程；
     *    那么这两个东西是不是冲突了呢？
     *    答案是否定的，
     *    因为一个线程可以持有一个lock，我们假设这个lock是A，
     *    同时这个线程也可以申请获取另一个lock，我们假设这个lock是B，
     *    显然持有lock A与申请获取lock B两者并不冲突，
     *    上述情况是普遍存在的；
     *    wait_on_lock变量在解决“优先级继承”中的“嵌套”问题也有重要作用
     * 2. struct list donation_list
     *    我之前使用semaphore的waiters队列来管理与一个lock有关的所有线程，
     *    尽管这样子看上去没有什么问题，
     *    我也不排除存在这样的解决方式，
     *    但显然这样会使得管理与lock相关的线程变得非常的困难，
     *    尤其是在面对“优先级继承”的“嵌套”问题上
     * 3. struct list_elem donation_list_elem
     *    既然都定义了donation_list，
     *    那么定义一个donation_list_elem也没有什么问题
     * 4. int init_priority
     *    用于thread_set_priority()，类似于缓冲的作用，
     *    具体参见thread_set_priority()函数
     *
     * 以上我们总是提到一个“优先级继承”的“嵌套”问题，
     * 在这里有必要详细的了解一下，
     * 假设H线程请求M线程正持有的lock，
     * 而M线程请求L线程正持有的lock，
     * H -> M -> L这样的情况就是“嵌套”；
     * 为了解决“嵌套”问题，
     * 我们需要同时把M线程和L线程的优先级提升到H线程的优先级上，
     * 但是这只是一种思路，实现的方式显然是多样的：
     * 1. 就像之前我说的，
     *    使用semaphore的waiters队列来管理与一个lock有关的所有线程，
     *    这样在waiters队列中提升优先级，
     *    只需要提升队列中一系列相关联的线程的优先级就可以了，
     *    不过这种实现方式已经被我扔在Trash文件夹里面了，
     *    也就是说，我遇到了意想不到的困难
     * 2. 使用本次代码中的实现方式，
     *    然而这是参考https://github.com/rtwilson/Pintos-Project-1实现的，
     *    人家的实现方式确实巧妙，
     *    然而这种实现方式无论如何我是没想到的，
     *    也只有在实现之后才能体会到它的巧妙
     */
    struct lock *wait_on_lock;
    struct list donation_list;
    struct list_elem donation_list_elem;
    int init_priority;

    #ifdef USERPROG
    /* Owned by userprog/process.c. */
    uint32_t *pagedir;                  /* Page directory. */
    #endif

    /* Owned by thread.c. */
    unsigned magic;                     /* Detects stack overflow. */
};

/* If false (default), use round-robin scheduler.
   If true, use multi-level feedback queue scheduler.
   Controlled by kernel command-line option "-o mlfqs". */
extern bool thread_mlfqs;

void thread_init (void);
void thread_start (void);

void thread_tick (void);
void thread_print_stats (void);

typedef void thread_func (void *aux);
tid_t thread_create (const char *name, int priority, thread_func *, void *);

void thread_block (void);
void thread_unblock (struct thread *);

struct thread *thread_current (void);
tid_t thread_tid (void);
const char *thread_name (void);

void thread_exit (void) NO_RETURN;
void thread_yield (void);

/* Performs some operation on thread t, given auxiliary data AUX. */
typedef void thread_action_func (struct thread *t, void *aux);
void thread_foreach (thread_action_func *, void *);

int thread_get_priority (void);
void thread_set_priority (int);

int thread_get_nice (void);
void thread_set_nice (int);
int thread_get_recent_cpu (void);
int thread_get_load_avg (void);

/* 刷新当前线程的优先级 */
void refresh_priority(void);

/* “优先级继承” */
void donate_priority(void);

/* 从donation_list中移除线程 */
void remove_with_lock(struct lock *lock);

/* 对优先级进行降序 */
bool cmp_priority (
    const struct list_elem *a,
    const struct list_elem *b,
    void *aux
);

/* 判断设置优先级过后，当前线程是否应该放弃对CPU的占用 */
void test_yield(void);

#endif /* threads/thread.h */
