Pintos学习手册 -- 2. Project 1: Threads
===

在这个章节中，我们将会使用到一个实现了简单的线程功能的系统。我们的工作就是扩展它，更加深刻的理解“线程同步（synchronization）”问题。

根据文档的要求，本章我们大多数情况下都是在`threads/`目录下工作的，当然有些时候会在`devices/`目录下工作。

按照要求，我建议你在开始本章之前，首先浏览一遍下列几个链接：

 - [1. Introduction](http://www.stanford.edu/class/cs140/projects/pintos/pintos_1.html#SEC1 "1. Introduction")
 
 - [C. Coding Standards](http://www.stanford.edu/class/cs140/projects/pintos/pintos_8.html#SEC138 "C. Coding Standards")
 
 - [E. Debugging Tools](http://www.stanford.edu/class/cs140/projects/pintos/pintos_10.html#SEC145 "E. Debugging Tools")
 
 - [F. Development Tools](http://www.stanford.edu/class/cs140/projects/pintos/pintos_11.html#SEC158 "F. Development Tools")
 
 - [A.3 Synchronization](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC100 "A.3 Synchronization")
 
 - [B. 4.4BSD Scheduler](http://www.stanford.edu/class/cs140/projects/pintos/pintos_7.html#SEC131 "B. 4.4BSD Scheduler")
 
其中[A.3 Synchronization](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC100 "A.3 Synchronization")和[B. 4.4BSD Scheduler](http://www.stanford.edu/class/cs140/projects/pintos/pintos_7.html#SEC131 "B. 4.4BSD Scheduler")是比较重要的一部分，需要仔细研读。

如无必要，我不会翻译上述所有的链接。但是在接下来的过程中，我会在我用到的知识点后面附上相关的说明。当然，我个人不太清楚的地方也会用_斜体字_特别标注出来。

Here we go!

---

## 2.1 Background

### 2.1.1 Understanding Threads

Pintos早已实现了“线程的创建（thread creation）”和“线程的结束（thread completion)”功能，并且拥有一个简单的线程调度算法，以及用于同步的“原语（primitives）”（包括“信号量（semaphores）”、“锁（locks）”、“条件变量（condition variables）”，以及“_障碍优化（optimization barriers）_”）。

我们首先要做的第一步就是了解Pintos提供的这个初级的线程系统。所以你需要去阅读它的代码。

下面我们来说说一些文档中提到的大致情况。

我们可以使用Pintos提供的`thread_create()`函数创建线程。通常来说一个线程内部包含有一个或多个“函数（function）”，当一个线程被创建之后，它将会被调度，其内部的函数将会被执行。当函数执行完毕，返回值之后，这个线程就终止了。通过把函数传递给`thread_create()`，每个线程看上去就像一个运行在Pintos内部的小程序一样。

在任意给定的时间内，总有一个线程处于运行或者休息（rest）状态（确切来说，这个线程是不活跃（inactive）的）。调度算法会决定接下来运行哪一个线程（如果没有一个线程在给定的时间内处于就绪态的话，一个称为“idle（空闲）”的线程就会被运行，它是使用`idle()`函数创建的）。当一个线程需要等待另一个线程的时候，信号量原语可以强制进行资讯（context）切换。

关于上下文切换的代码是写在`pintos/src/threads/switch.S`文件里面的。这个文件采用80x86汇编语言写成（你没有必要去理解它）。它的作用是保存当前运行的线程状态，并且恢复我们需要切换到的线程的运行状态。

在这里你不可避免的要使用到调试工具，比如GDB神马的；当然，`printf()`也一直是用于调试的利器，你可以在任意地方设置`printf()`，把相关的内容输出来并浏览之。考虑到调试工具的重要性，我将来可能会专门写一篇相关的博客。我在这里不会详细阐述这些调试工具如何使用，仅在有必要的地方提一下。我建议你去阅读一下[E.5 GDB](http://www.stanford.edu/class/cs140/projects/pintos/pintos_10.html#SEC151 "E.5 GDB")，以及[(2)](http://www.stanford.edu/class/cs140/projects/pintos/pintos_fot.html#FOOT2 "(2)")。

调试的时候记住及时跟踪和记录（keep track of）每个线程的地址和状态，以及每个线程的调用栈（the call stack）中都是哪些程序。你可能会注意到，当一个线程调用`switch_threads()`函数的时候，另一个线程就开始运行了，并且新创建的线程所做的第一件事就是从`switch_threads()`函数中进行返回。当你明白`switch_threads()`的“返回（returns）”和`switch_threads()`的“被调用（get called）”不是同一回事的时候，你就明白这个线程系统是如何工作的了。可以参阅[A.2.3 Thread Switching](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC99 "A.2.3 Thread Switching")获取更多信息。

**注意：**

在Pintos中，每个线程都被分配到成一个小的、固定大小（低于4kB）的栈空间。Pintos内核会检查是否发生栈溢出，但是这个功能并不完善。所以你可能会遇到一些奇奇怪怪的问题，比如说神秘的内核崩溃（kernel panics）。所以不建议你申明一些类似非静态（non-static）的局部变量的占用空间比较大的数据结构，比如说`int buf[1000];`。代替默认的申请栈空间的方法有“页式申请（the page allocator）”以及“块式申请（the block allocator）”（更多内容请参阅[A.5 Memory Allocation](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC111 "A.5 Memory Allocation")）。

### 2.1.2 Source Files

下面是一份`pintos/src/threads/`目录下的文件说明。你没有必要去修改他们，但了解一下总是好的，这有利于你更方便的查阅已有的代码：

 - `loader.S`
 - `loader.h`
   内核的引导文件。这是一份512字节大小的PC BIOS引导程序，采用汇编写成，它的作用是将内核从硬盘加载到内存中，并且跳转到`start.S`文件中的`start()`函数。你可以参阅[A.1.1 The Loader](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC92 "A.1.1 The Loader")获取更多细节。对于这部分代码，你没有必要去查看或者修改它。

 - `start.S`
   对从80x86构架的CPU的[实模式](http://zh.wikipedia.org/zh-cn/%E7%9C%9F%E5%AF%A6%E6%A8%A1%E5%BC%8F "维基百科上关于实模式的介绍")进入[保护模式](http://zh.wikipedia.org/wiki/%E4%BF%9D%E8%AD%B7%E6%A8%A1%E5%BC%8F "维基百科上关于保护模式的介绍")进行基本的设置。与之前的引导代码不同的是，这部分代码实际上是属于内核的。参见[A.1.2 Low-Level Kernel Initialization](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC93 "A.1.2 Low-Level Kernel Initialization")获取更多信息。

 - `kernel.lds.S`
   这是一段用于链接（link）的_脚本（script）_。将用于加载内核的地址和安排给`start.S`的地址放置在内核镜像的开始处。参见[A.1.1 The Loader](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC92 "A.1.1 The Loader")获取更多信息。在这里再次强调，你没有必要去查看或者修改这份代码。

 - `init.c`
 - `init.h`
   内核的初始化代码，`main()`被包含在其中。**你需要去查看一下`main()`函数的代码**，至少了解一下它是如何初始化的。当然也许你会想加入一些自己的初始化代码。参阅[A.1.3 High-Level Kernel Initialization](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC94 "on A.1.3 High-Level Kernel Initialization")获取更多细节。

 - `thread.c`
 - `thread.h`
   提供基本的线程支持。你的很多工作都将在这里完成。`thread.h`定义了很多线程结构，爱你的项目中，你可以根据自己的喜好去修改它们。参见[A.2.1 struct thread](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC97 "A.2.1 struct thread")和[A.2 Threads](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC96 "A.2 Threads")获取更多细节。

 - `switch.S`
 - `switch.h`
   用于切换线程的代码，使用汇编写成，作用正如先前说过的那样。参见[A.2.2 Thread Functions](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC98 "A.2.2 Thread Functions")获取更多细节。

 - `palloc.c`
 - `palloc.h`
   “页式分配（page allocator）”，能够给出更多的4kB倍数大小的页。参见[A.5.1 Page Allocator](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC112 "A.5.1 Page Allocator")获取更多细节。

 - `malloc.c`
 - `malloc.h`
   内核中一份对`malloc()`函数和`free()`函数的简单实现。参见[A.5.2 Block Allocator](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC107 "A.5.2 Block Allocator")获取更多细节。

 - `synch.c`
 - `synch.h`
   基本的同步原语：信号量、锁、条件变量，以及屏障优化。你需要在全部4个Project中使用到这些东西。参见[A.3 Synchroization](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC100 "A.3 Synchroization")获取更多信息。

 - `io.h`
   I/O设备的接口。这份文件基本被`devices/`目录下的代码使用，你没有必要去接触它。

 - `vaddr.h`
 - `pte.h`
   全部有关“虚拟地址（virtual addresses）”以及“页表（page table）”的函数和宏。你将在Project 3中使用它们，但是现在你可以忽略之。

 - `flags.h`
   一些关于80x86的“标志（flags）”寄存器的红定义。看上去相当的无趣。更多信息请参见[[IA32-v1](http://www.stanford.edu/class/cs140/projects/pintos/pintos_13.html#IA32-v1 "IA32-v1")]，章节3.4.3，”EFLAGS Register“。

#### 2.1.2.1 "devices/" code

实现内核中基本的线程代码也用到了`pintos/src/devices/`目录下的一些文件：

 - `timer.c`
 - `timer.h`
   系统的滴答定时器，默认每秒钟跳动100次。你可以在这个Project中修改这部分代码。

 - `vga.c`
 - `vga.h`
   VGA显示器的驱动。作为输入的文本在屏幕上的响应。你没有必要查看这份代码，`printf()`已经为你调用了VGA显示器。

 - `serial.c`
 - `serial.h`
   串行接口的驱动。再次强调，`printf()`已经为你调用了这份代码，所以你没有必要自己去实现。它将串行输入过渡到输入层（the input layer）（见下方说明）。

 - `block.c`
 - `block.h`
   一份提供了对”块设备（block devices）“的抽象的代码，在这里，随机存取的磁盘式的设备被组织为固定大小的数组。Pintos原生支持2种块设备：[IDE Disk](http://zh.wikipedia.org/wiki/%E9%9B%86%E6%88%90%E8%AE%BE%E5%A4%87%E7%94%B5%E8%B7%AF "维基百科上关于IDE Disk的介绍")和”_分区（partitions）_“。这部分直到Project 2才会被使用到。

 - `ide.c`
 - `ide,h`
   支持最高4个IDE Disk。

 - `partition.c`
 - `partition,h`
   允许将一块磁盘分为多个相互独立的分区进行使用。

 - `kbd.c`
 - `kbd.h`
   键盘驱动。将键盘输入过渡到输入层（见下方说明）

 - `input.c`
 - `input.h`
   输入层。将从键盘或者串行接口输入的信息组织成队列。

 - `intq.c`
 - `intq.h`
   为了组织运行在内核的线程和中断机制的环形队列而创建的中断队列。在键盘和串行接口中有使用到。

 - `rtc.c`
 - `rtc.h`
   时钟（Real-time clock）驱动，能够让内核获取当前的日期和时钟。在默认情况下，它仅仅被`pintos/src/threads/init.c`用于设置生成随机数的初始种子值。

 - `speaker.c`
 - `speaker.h`
   使得PC机上的扬声器能够播放出铃声，可以认为就是扬声器的驱动。

 - `pit.c`
 - `pit.h`
   配置8254可编程中断定时器（the 8254 Programmable Interrupt Timer）的代码。这份代码在`pintos/src/devices/timer.c`以及`pintos/src/speaker.c`中都有被使用到，因为每个设备都使用到了PIT的输出频道。

#### 2.1.2.2 "lib/" files

最后，`pinos/src/lib/`以及`pintos/src/lib/kernel/`目录下也包含了一些有用的代码（`pintos/src/lib/user/`将会在Project 2中使用到，它并不是内核的一部分）。这里有一些细节性的东西值得注意一下：

 - `ctype.h`
 - `inttypes.h`
 - `limits.h`
 - `stdarg.h`
 - `stdbool.h`
 - `stddef.h`
 - `stdint.h`
 - `stdio.c`
 - `stdio.h`
 - `stdlib.c`
 - `stdlib.h`
 - `string.c`
 - `string.h`
   以上是C标准库的子集。参见[C.2 C99](http://www.stanford.edu/class/cs140/projects/pintos/pintos_8.html#SEC140 "C.2 C99")和[C.3 Unsafe String Functions](http://www.stanford.edu/class/cs140/projects/pintos/pintos_8.html#SEC141 "C.3 Unsafe String Functions")获取更多细节，**这两份文件一定要看**。

 - `debug.c`
 - `debug.h`
   调试代码时可以用到。参见[E. Debugging Tools](http://www.stanford.edu/class/cs140/projects/pintos/pintos_10.html#SEC145 "E. Debugging Tools")获取更多细节。

 - `random.c`
 - `random.h`
   [伪随机数](http://zh.wikipedia.org/zh-cn/%E4%BC%AA%E9%9A%8F%E6%9C%BA%E6%80%A7 "维基百科上关于伪随机的介绍")生成器。随机数的实际顺序不会因为在两个Pintos上运行而不同，除非你做了以下三件事之一：
    - 每次运行Pintos的时候都通过`-rs`参数设置新的随机数种子。
    
    - 在其他的Bochs虚拟机上运行Pintos。
    
    - 使用`-r`选项设置Pintos。

 - `round.h`
   四舍五入（rounding）的宏定义。

 - `syscall-nr.h`
   系统调用的数字。直到Project 2才会被用到。

 - `kernel/list.c`
 - `kernel/list.h`
   实现了一个双向链表。Pintos所有的代码都用到了这部分，你可能也会在自己的Project 1中用到。

 - `kernel/bitmap.c`
 - `kernel/bitmap.h`
   位图的实现。如果你愿意的话，你可以在你的代码中用到它，但是也许你在Project 1中不会用到。

 - `kernel/hash.c`
 - `kernel/hash.h`
   哈希表的实现。在Project 3中会被用到。

 - `kernel/console.c`
 - `kernel/console.h`
 - `kernel/stdio.h`
   实现了`printf()`以及其他的一些函数。

### 2.1.3 Synchronization

我认为这部分比较重要，并且我对原文的理解不是很清楚，所以我对这部分进行通篇的翻译。注意我不清楚的地方会用_斜体字_标注出来。

正确的同步机制是我们解决Project 1中的问题的关键。任何涉及同步的问题都能够使用一种简单的方式解决，即把中断机制关掉：当中断被关掉的时候，就不存在“并发（concurrency）”的问题了，因此也没有发生冲突的可能。这种方式确实很诱人，但是，**请不要这样做**。正相反，我们应当使用信号量、锁、以及条件变量去解决你的同步问题。如果你不确定同步原语在何种情况下使用的话，阅读[A.3 Synchronization](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC100 "A.3 Synchronization")或者`pintos/src/threads/synch.c`中的注释。

在这里我们需要解释一下，为什么上文说“关闭中断之后就不会发生冲突”了呢？首先说说什么是“中断”，以及为什么要有中断机制。

我们都知道，现在CPU的运算速度足够快，但是外围设备的速度却远远跟不上CPU的速度。当CPU对外围设备发送一条指令，等待其返回的过程是相当漫长的，如果在这期间CPU一直处于忙等待状态的话，显然效率是十分低下的。那么现在，我们假设有一种机制，我们就称之为“中断”好了。当CPU给外设发送一条干活的指令后，就自己忙自己的事情去了，等到外设干完活，会自动给CPU发送一个“中断”，告诉CPU“我干完活了”，这时CPU就可以继续给外设发送指令了。从上面的描述我们可以看出，”中断“是一种信号。

“中断”可以分为“硬件中断”和“软件中断”。“硬件中断”导致处理器执行一个资讯切换来保存执行状态，而“软件中断”则通常作为CPU指令集中的一个指令，以可编程的方式直接指示这种资讯切换。无论如何，“中断”都会占用到CPU。注意线程也是会去占用CPU的。所以如果你没有处理好二者之间的竞争关系，自然就会发生冲突了。而关闭中断机制，也就可以避免这种冲突发生。不过这是一种“**鸵鸟机制**”，相当不建议采用。

更多关于“中断”的说明可以[点击这里](http://zh.wikipedia.org/wiki/%E4%B8%AD%E6%96%B7 "维基百科上关于中断的介绍")。

这个Project仅仅需要从中断程序中获取一些关于线程的状态。对于_时钟（alarm clock）_来说，时钟中断需要去官相处于睡眠态的线程。在积极的调度过程中，时钟中断需要访问一些全局变量和每个线程的变量。当你获取到这些变量之后，你需要禁止（Disable）中断，已去除时钟中断的干扰。

在你关闭中断后的这部分，书写尽可能少的代码，不然你可能会丢失一些重要的东西，比如说时钟滴答或者一些输入事件。关闭中断也会增加中断的延时，如果你关闭的太久的话，会使你的电脑卡成翔。

`pintos/src/threads/synch.c`文件中的同步原语是在禁止中断的情况下实现的。你可能会在禁用中断的情况下在这里书写很多的代码，但是你仍然需要保证它们尽可能的短小。

如果你想确定一段代码是没有被中断的话，禁用中断对于debug来说是非常有用的。当你提交你的代码的时候，请将你用于debug的代码剔除（也不要写注释，因为这会使代码的可读性下降）。

你提交的代码不应该出现忙等待。如果出现的话，`thread_yield()`可能是造成这样的原因之一。

### 2.1.4 Development Suggestions

在过去，很多团队把这份任务分割为很多小的部分，然后每个人都赶在deadline之前完成自己负责的部分，到最后载把代码合在一起。这是一个坏注意，我们相当不建议这样做。你会发现两份代码合在一起的时候会发生冲突，然后你就会花费大量的时间去debug。一些队伍就是这样，他们的代码出了问题，最终没能通过测试。

我们推荐你们尽早地把代码修改过的地方合并，使用一些版本管理软件，比如说[Subversion](http://subversion.tigris.org/ "Subversion")，或者使用[Git](http://git-scm.com/ "Git")。这样可以尽量减少最后带来的意想不到的后果，因为每个人都可以很方便的看到其它人的代码，而不是到最后的时候才看到。这些版本管理软件可以很方面的浏览代码的修改历史，以及恢复原有的代码等等。我个人是相当推荐使用的，比如我就使用Git。

在你运行的过程中可能会遭遇到意想不到的bug。这时候你就可以使用调试软件来帮助你，请仔细研读这两份文件：

 - [E. Debugging Tools](http://www.stanford.edu/class/cs140/projects/pintos/pintos_10.html#SEC145 "E. Debugging Tools")
 
 - [E.4 Backtraces](http://www.stanford.edu/class/cs140/projects/pintos/pintos_10.html#SEC149 "E.4 Backtraces")
 
另外不要忘记，`printf()`也是进行调试的利器。

---

## 2.2 Requirements

### 2.2.1 Design Document

参考[the project 1 design document template](http://www.stanford.edu/class/cs140/projects/pintos/threads.tmpl "the project 1 design document template")和[D. Project Documentation](http://www.stanford.edu/class/cs140/projects/pintos/pintos_9.html#SEC142 "D. Project Documentation")。

### 2.2.2 Alarm Clock

重构定义在`pintos/src/devices/timer.c`中的`timer_sleep()`函数。尽管Pintos中提供了实现，但是却是以“忙等待（busy waits）”的方式实现的，这就是说，它一直在循环检查当前的时钟并且调用`thread_yield()`函数，直到足够的时间过去。重构这个函数，避免忙等待。

函数：`void timer_sleep(int64_t ticks)`

&emsp;&emsp;&emsp;暂停正在被调用的线程，_直到时间提前了至少x时钟滴答（until time has advanced by at least x timer ticks）_。否则系统就处于空闲状态，直到确切的时钟滴答后再唤醒线程。仅仅需要（线程）放置在适当的就绪队列之后（just put it on the ready queue after they have waited for the right amount of time）。

&emsp;&emsp;&emsp;`timer_sleep()`是一个很有用的函数，比如闪烁光标就会用到它。

&emsp;&emsp;&emsp;传递给`timer_sleep()`函数的参数是时钟的滴答数（timer ticks），而不是毫秒（milliseconds）或者其他神马的单位。每秒钟的时钟滴答数`TIMER_FREQ`在`pintos/src/devices/timer.h`的宏中有定义，默认值是每秒钟100下。我们不推荐你修改这个值，因为一次修改可能导致很多的错误。

其他的一些函数，比如说`timer_msleep()`、`timer_usleep()`、`timer_nsleep()`分别接受毫秒、微秒、纳秒为参数，但是当有必要的时候，它们都会调用`timer_sleep()`函数。你没有必要去修改这些函数。

如果你的延时看上去太短了或者太长了，请重新了解一下Pintos的`-r`选项（参见[1.1.4 Debugging versus Testing](http://www.stanford.edu/class/cs140/projects/pintos/pintos_1.html#SEC6 "1.1.4 Debugging versus Testing")获取更多信息。

这份关于时钟的实现在接下来的几个Project中不是必须的，尽管对于Project 4来说很有用处。

### 2.2.3 Priority Scheduling

在Pintos中实现“优先级调度（priority scheduling）”。当一个相较于当前正在运行的线程具有更高优先级的线程被加入到就绪链表中时，当前的线程应该立即让位给新的线程。类似地，当线程正在等待一个锁、一个信号量、或者一个条件变量的时候，具有高优先级的线程应当被率先唤醒。一个线程可能提升或者降低它自己的优先级，但是降低优先级就意味着，它必须立即放弃对CPU的占用。

线程的优先级的取值范围是从`PRI_MIN(0)`到`PRI_MAX(63)`。低的数字意味这着低的优先级，所以`0`代表的是最低的优先级，而`63`代表最高的优先级。线程的初始化优先级会作为参数传递给`thread_create()`函数。如果没有什么特别的状况的话，`PRI_DEFAULT(31)`作为默认的优先级参数。关于`PRI_`的宏被定义在`pintos/src/threads/thread.h`文件中，并且你不应该去改动它们。

一个可能遇到的问题，叫做“优先级倒置（priority inversion）”。我们假设有三个不同优先级的线程，一个具有高优先级，我们称之为“H”；一个具有中等的优先级，我们称之为“M”；最后一个优先级最低，我们称之为“L”。现在具有这样一种情况，如果H需要等待L（比如说，为了等待L的锁），并且M正处于就绪链表中，然后H就永远不会占用到CPU了，因为低优先级的线程永远不会得到任何的CPU运行时间。一个修复这个问题的方法就是，当L正持有锁的时候，让H“捐赠（donate）”出它的优先级给L，当L释放的时候再将优先级恢复到原先的样子（这样H就能获取到这个锁了）。

实现这个优先级倒置机制。你需要考虑到各种需要进行优先级调度的情况。_当多个优先级被“捐赠”给一个线程的时候，考虑如何处理这种情况（be sure to handle multiple donations, in which multiple priorities are donated to a single thread）_。你也要处理一些嵌套的“捐赠”：如果H正在等待M的锁，而M正在等待L的锁，那么M和L都应该同时被提升到H的优先级。如果有必要的话，你也许需要设置一个允许嵌套“捐赠”的级数，比如说，8级。

为了锁操作，你必须实现优先级的捐赠机制。你没有必要为其他的Pintos同步结构实现这样的机制，但是你必须为所有状况设置优先级。

最后，实现下列两个函数，使得线程可以测试和修改它自己的优先级。在`pintos/src/threads/thread.c`中有提供这些函数的框架。

函数：`void thread_set_priority(int new_priority)`

&emsp;&emsp;&emsp;将当前线程的优先级设置为`new_priority`的值。如果当前线程不再具有最高的优先级，释放它，

函数：`int thread_get_priority(void)`

&emsp;&emsp;&emsp;返回当前正在运行的线程的优先级。在存在优先级捐赠的情况下，返回优先级更高（被捐赠的）的那个。

你没有必要提供任何允许一个线程可以直接修改其他线程优先级的借口。

在接下来的Project中，线程优先级将不会被使用到。

### 2.2.4 Advanced Scheduler

实现一个类似4.4BSD的[多级反馈队列](http://www.baike.com/wiki/%E4%BD%9C%E4%B8%9A%E8%B0%83%E5%BA%A6%E7%AE%97%E6%B3%95 "互动百科上关于各种作业调度算法的介绍")的作业调度算法，减少你的系统的平均响应时间。参见[4.4BSD Scheduler](http://www.stanford.edu/class/cs140/projects/pintos/pintos_7.html#SEC131 "4.4BSD Scheduler")获取更多的详细信息。

就像之前所述的优先级调度（priority scheduler）那样，在这里_积极的调度算法（Advanced Scheduler）_也根据线程的优先级进行选择。但是，不存在所谓的“捐赠”情况。因此，在你开始这部分工作（指advanced scheduler）之前，触除了实现优先级捐赠，我们建议你先使优先级调度（指priority scheduler）运行起来。

默认情况下，优先级调度（priority scheduler）必须是工作着的。但是我们可以通过选项`-mlfqs`指定使用4.4BSD的调度算法。通过在`pintos/src/threads/thread.h`头文件中声明的`thread_mlfqs()`函数实现这个多级反馈队列调度算法，当`parse_options()`函数解析为`true`时我们可以调用这个算法。

当4.4BSD调度算法正在运行的时候，线程不再能够直接控制它们自己的优先级。`thread_create()`函数的`priority`参数必须被忽略，任何调用`thread_set_priority()`函数的情况也一样，而`thread_get_priority()`函数应该返回当前进程被调度器设置的优先级。

积极的调度算法（advanced scheduler）在之后的Project里将不会被用到。

---

## 2.3 FAQ

这部分比较多而杂，因此我就不翻译了。仅在有必要的时候列出。有更多需求的同学可以自行查阅[官方文档](http://www.stanford.edu/class/cs140/projects/pintos/pintos_2.html#SEC15 "Pintos Projects: Project 1 -- Threads")。

到这里为止，Project 1的实验内容我基本上是翻译完了，接下来我就开始这部分实验的实践了。

在实践过程中遇到的问题和解决方案以及学习笔记我将会在下面一一列出。敬请期待。

**未完待续**

**版权所有，转载请声明：转载自[mthli.github.io](https://mthli.github.io "mthli.github.io")**