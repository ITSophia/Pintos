Pintos学习手册 -- 1. Introduction
===

## 写在前面的话：

大家好，我是李明亮。

这个学期我参加了学校的操作系统小组，开始了自行学习研究[Pintos](http://en.wikipedia.org/wiki/Pintos "维基百科上关于Pintos的介绍")这个小型的操作系统框架的旅程。

很多人会问，你们为什么不去学习[Linux 0.11](https://www.kernel.org/pub/linux/kernel/Historic/old-versions/ "Linux 0.11版本内核下载地址")（或者[0.01](https://www.kernel.org/pub/linux/kernel/Historic/ "Linux 0.01版本内核下载地址")）版本的内核呢？

这个嘛，原因解释起来比较复杂。总体来说就是历史遗留问题。在我加入这个小组之前，组里基于Pintos这个操作系统框架的研究已经有一部分的资料积累了，所以不太可能重新开始。

不过老师给我们新人的任务是自行实现Pintos这个项目的4个Project，在下个学期中旬之前完成。所以在这里我可能会参考Linux 0.11版本的代码，然后自行实现一遍。

下面是我参考[Pintos官方文档](http://www.stanford.edu/class/cs140/projects/pintos/pintos.html "Pintos官方文档")，结合自己的实践写成的笔记和部分翻译。有些我自己不太清楚的地方会使用_斜体字_特别标注出来。

我个人比较懒，所以博客下面没有添加评论版块。如果你有任何问题，或者能够解决我特别标注出来的问题的话，欢迎发送邮件到[matthewlee0725@gmail.com](matthewlee0725@gmail.com "我的Gmail")和我讨论。

空谈误国，实干兴邦。让我们操练起来！

---

## 1.1 Getting Started

根据官方的介绍，我们推荐使用运行着[*NIX系统](http://zh.wikipedia.org/zh-cn/%E7%B1%BBUnix%E7%B3%BB%E7%BB%9F "类UNIX系统")的机器来学习Pintos。比如我使用的就是[Arch Linux](http://zh.wikipedia.org/wiki/Arch_Linux "维基百科上关于Arch Linux的介绍")。  

Pintos项目的源代码点击[这里获取](http://www.stanford.edu/class/cs140/projects/pintos/pintos.tar.gz "Pintos源代码下载链接")。

通过`tar -xvzf pintos.tar.gz`命令解压`pintos.tar.gz`压缩包，可以得到一个叫做`pintos/`的文件夹。通常来说我们不建议去重命名这个文件夹，起码我不会这样做，因为以前貌似试过，然后貌似就无法执行`make`命令了。

### 1.1.1 Source Tree Overview

让我们来了解一下`pintos/`目录下的各个文件夹：

 - `threads/`
   基本的内核代码，我们会在Project 1中修改它。

 - `userprog/`
   加载用户程序的代码，我们会在Project 2中修改它。

 - `vm/`
   一个几乎空着的目录，我们将会在Project 3中实现对虚拟内存的管理。

 - `filesys/`
   基本文件系统的代码。我们将在Project 2中使用到它，但此时并不需要修改，但是到Project 4的时候就有的忙了。

 - `devices/`
   管理I/O设备的代码，包括键盘、时钟、硬盘等等。在Project 1中你需要修改时钟（timer）的实现方式。

 - `lib/`
   这里实现了一个标准C函数库的子集。这个目录下的代码不仅会在编译Pintos的时候用到，在Project 2，用户程序中也会用到。内核代码和用户程序代码可以通过使用`#include <...>`的方式将这个目录下的头文件包含进去。你基本没有必要修改这部分的代码。
 
 - `lib/kernel/`
   这里是仅仅被包含在Pintos内核中的一部分C函数库。这部分代码实现了一些数据类型，因此你可以很方面的在你的内核代码中使用它，它们分别是：位图（bitmaps）、双向链表（doubly linked lists），以及哈希表（hash tables）。这个目录下的头文件可以通过使用`#include <...>`将其包含在内核代码中。

 - `lib/user/`
   这里是仅仅在用户程序中用到的一部分C函数库。这个目录下的头文件可以通过使用`#include <...>`将其包含在用户程序代码中。

 - `tests/`
   用于测试每个Project。如果你觉得对你的任务有所帮助的话，你可以修改这部分的代码，但是我们在对你的代码进行测试之前，会将其替换成最初的样子。

 - `misc/`
   未知。

 - `utils/`
   这里包含了一些重要的文件。由于我们不是斯坦福大学的学生，没有条件远程登陆到斯坦福大学的教学机器上，所以在我们自己的电脑上运行和调试Pintos全部依赖这个文件夹下的可执行文件。
  
   这个目录下原生包含以下4个可执行文件：
    - `backtrace`
    - `pintos`
    - `pintos-gdb`
    - `pintos-mkdisk`

  以上的可执行文件我们目前已经够用了。如果希望得到更多的可执行文件（我目前也不知道有啥用），可以在这个目录下执行`make`命令，`make`过后将会产生如下3个可执行文件：
    - `setitimer-helper`
    - `squish-pty`
    - `squish-unix`
  
  记住**务必**将这些可执行文件包含在你的`PATH`中。在你自己的`.bashrc`文件中进行设置是一个不错的选择，这样你就不用每次开机都设置一遍`PATH`了。

### 1.1.2 Building Pintos

进入`pintos/src/threads/`目录，执行`make`命令，之后会生成一个`build/`文件夹。让我们来了解一下`build`文件夹下的一些文件：
 
 - `Makefile`
   一份`pintos/src/Makefile.build`的拷贝。它描述了如何去编译一个内核。你可以通过[Adding Source Files](http://www.stanford.edu/class/cs140/projects/pintos/pintos_2.html#Adding&nbspSource&nbspFiles "Adding Source Files")查看到更多的相关信息。

 - `kernel.o`
   整个内核的目标文件。它是每个独立的内核源代码生成的目标文件全部链接在一起的结果。同时也包含了debug信息，所以你可以通过使用[GDB](http://zh.wikipedia.org/zh-cn/GNU%E4%BE%A6%E9%94%99%E5%99%A8 "维基百科上关于GDB的介绍")（参考[E.5 GDB](http://www.stanford.edu/class/cs140/projects/pintos/pintos_10.html#SEC151 "E.5 GDB")部分）或者[backtrace](http://www.gnu.org/software/libc/manual/html_node/Backtraces.html "Backtraces的官方网站")（参考[E.4 Backtraces](http://www.stanford.edu/class/cs140/projects/pintos/pintos_10.html#SEC149 "E.4 Backtraces")部分）来调试它。

 - `kernel.bin`
   内核的镜像文件，是Pintos实际运行在内存中的那部分。它将`kernel.o`中的debug信息去除掉了，这样可以节省很多空间，好处就是它可以不必违反（bumping up）内核引导512kB的设计限制。

 - `loader.bin`
   内核引导的镜像文件，一段使用汇编语言写成的短小的代码块，用于将内核从硬盘加载到内存中并启动之。确切来说它只有512字节的长度，符合PC BIOS的尺寸。

`build/`子目录同样包含了目标文件（`.o`）以及它们的依赖文件（`.d`），这些都是编译器产生的。这些依赖文件将会告诉`make`哪些修改过的代码或者头文件需要被重新编译。

### 1.1.3 Running Pintos
 
首先，我们需要在我们的*NIX系统上安装[Bochs虚拟机](http://bochs.sourceforge.net/ "Bochs虚拟机的下载链接")，方便我们运行和调试Pintos。

我将**全程**使用Bochs虚拟机进行实验，而不会使用[QEMU虚拟机](http://zh.wikipedia.org/zh-cn/QEMU "维基百科上关于QEMU虚拟机的介绍")或者其他什么的虚拟机。所以如果你有意参考我的博客来进行实验的话，请**务必**安装并配置好Bochs虚拟机。

如果你足够激进的话，你可以直接在物理机上运行Pintos，根据官方介绍，这在理论上是可行的，当然这也是我们的终极目标。

关于如何安装Bochs虚拟机，我们在这里不做说明，请自行[Google](https://www.google.com "Google")。

OK，我假设你已经设置好`PATH`，并且已经安装好Bochs虚拟机了。现在让我们切入到`pintos/src/threads/build/`目录下，输入命令`pintos run alarm-multiple`。好啦理论上没啥问题的话，Bochs将会显示这样一个画面：

![Instroduction/pintos_run_alarm-multiple](/img/Instroduction/pintos_run_alarm-multiple.png)

当然你可能觉得Bochs的输出太快了，这时候你可以使用命令`pintos run alarm-multiple > logfile`把输出重定向输出到一个叫做“logfile”（当然你也可以不起这个名称）的文件，这样我们就可以很方便查看输出的数据了。

另外，我们可以观察到终端的输出和Bochs的输出是一致的。这是因为Pintos默认绑定了Bochs的标准输入输出。如果你只想在终端下观察Pintos的运行状态的话，可以在刚才的运行命令中加入`-t`参数。

更多设置可以参考[官方文档](http://www.stanford.edu/class/cs140/projects/pintos/pintos_1.html#SEC2 "Pintos Projects: Introduction")，在这里不与赘述。

### 1.1.4 Debugging versus Testing

在这里介绍一下一些有关debug的说明。

当你在debug的时候，最好运行两次以上，确保它们的运行结果都是一致的。当然，在第2次运行或者更多次运行的时候，你可以很方便的建立新的观察（new observations），而不是丢弃或者使用原有的观察。我们把这种行为称之为“重现（reproducibility）”。Bochs虚拟机支持“重现”功能，这也是Pintos默认的。

当然啦，为了实现一次“重现”，你需要确保每次都有和之前相同的输入，比如相同的命令行参数、相同的硬盘、相同的Bochs虚拟机等等，同时你也不能在Pintos运行期间键入任何内容，因为你无法确定你的每次输入是否和原先的相同。

尽管“重现”是一种有效的debug方式，但是当它遇到“线程同步（thread synchronization）”的时候就不那么适用了。因为在一些特殊的情况下，“重现”将会产生和之前一模一样的效果（其他则不然），你无法确定你的代码是否正确。

为了使你的代码易于测试，Pintos加入了一个称为“jitter”的特性，这种特性对于Bochs虚拟机来说就是，它将产生随机间隔的中断，但是这种中断确是以一种可以完全预测的方式进行的。当你使用参数`-j seed`调用Pintos的时候，时间中断将会以随机间隔的方式执行，对于单一的种子值来说，执行将会被“重现”，但是对于多变的种子值来说，时钟的行为也是多变的。你应该使用足够多的种子值来测试你的代码。

另一方面，Bochs虚拟机在“重现”的时候，计时（timings）并不是真实存在的，这就是说，“重现”过程中1秒钟的延时相较于第一运行会更长或更短。你可以使用`-r`参数确保Bochs的计时为真实意义上的1秒钟。另外，运行在实时模式（real-time mode）下的时候并不是“重现”，同样地，`-j`参数和`-r`参数也是相互独立的。

---

## 1.2 Grading

这里主要讲了一些关于代码的提交和测试的问题，我在这里就挑一些比较重要的地方说一说。我们毕竟不是斯坦福大学的学生，所以其他方面都不予赘述，有兴趣的同学可以参阅[官方文档](http://www.stanford.edu/class/cs140/projects/pintos/pintos_1.html#SEC2 "Pintos Projects: Introduction")。

### 1.2.1 Testing
所有的测试代码和相关文件都包含在`pintos/src/test/`目录下。

所有的程序都会有bug，Pintos也不例外。所以如果你认为你的代码没有问题，而是Pintos用于测试的代码自身的问题，你可以向斯坦福官方反映。如果有必要的话，他们会对此做出修改。

### 1.2.1 Design

程序的设计思路是很重要的一部分，建议你参考以下两点提升你的文档质量。

#### 1.2.2.1 Design Document

 - 数据结构（Data Structures）
   注意添加注释，说明每一项的功能是怎样的。

 - 算法（Algorithms）
   实现操作系统需要的功能的方法有很多种，你需要让我们明白你为什么要这样做。

 - 同步（Synchronization）
   操作系统是一个复杂的、多线程的东西，所以多线程之间的同步是一件很有难度的事情。在这里你需要描述你是怎么同步这些活动的。

 - 合理性（Rationale）
   其他的部分询问的更多是“为什么”和“怎么做”，但在这里你更多需要解释的是你选择的实现方式的合理性。

你可以参考[D. Project Documentation](http://www.stanford.edu/class/cs140/projects/pintos/pintos_9.html#SEC142 "D. Project Documentation")来书写你的文档。

#### 1.2.2.2 Source Code

注意你的代码风格要与Pintos官方提供的源代码风格尽量**保持一致**。

同时也要保证你的代码的可读性，一定要**写好注释**。

---

## 1.3 Legal and Ethical Issues

点击[License](http://www.stanford.edu/class/cs140/projects/pintos/pintos_14.html#SEC172 "License")进行查看。

另外代码尽量自己实现，参考其他操作系统（比如[FreeBSD](http://zh.wikipedia.org/zh-cn/FreeBSD "维基百科上关于FreeBSD的介绍")）的代码请**注明引用**。

---

## 1.4 Acknowledgements

 - The Pintos core and this documentation were originally written by Ben Pfaff [blp@cs.stanford.edu](mailto:blp@cs.stanford.edu "blp@cs.stanford.edu").

 - Additional features were contributed by Anthony Romano [chz@vt.edu](chz@vt.edu "chz@vt.edu").

 - The GDB macros supplied with Pintos were written by Godmar Back [gback@cs.vt.edu](gback@cs.vt.edu "gback@cs.vt.edu"), and their documentation is adapted from his work.

 - The original structure and form of Pintos was inspired by the Nachos instructional operating system from the University of California, Berkeley ([[Christopher](http://www.stanford.edu/class/cs140/projects/pintos/pintos_13.html#Christopher "Christopher")]).

 - The Pintos projects and documentation originated with those designed for Nachos by current and former CS 140 teaching assistants at Stanford University, including at least Yu Ping, Greg Hutchins, Kelly Shaw, Paul Twohey, Sameer Qureshi, and John Rector.

 - Example code for monitors (see section [A.3.4 Monitors](http://www.stanford.edu/class/cs140/projects/pintos/pintos_6.html#SEC104 "A.3.4 Monitors") is from classroom slides originally by Dawson Engler and updated by Mendel Rosenblum.

---

## 1.5 Trivia

Pintos在某种意义上来说可以是对[Nachos](http://en.wikipedia.org/wiki/Nachos "维基百科上关于Nachos的介绍")的简单重构。但是这两者之间存在着比较大的分歧。首先，Pintos运行在一个真实或者模拟的80x86构架的机器上，而Nachos是运行在宿主操作系统之上的。其次，Pintos像现实生活中的大多数操作系统那样，采用[C语言](http://zh.wikipedia.org/zh-cn/C%E8%AF%AD%E8%A8%80 "维基百科上关于C语言的介绍")编写而成，而Nachos使用[C++](http://zh.wikipedia.org/zh-cn/C%2B%2B "维基百科上关于C++的介绍")写成。

为啥命名为“Pintos”呢？首先，就像Nachos那样，Pintos也是一种常见的墨西哥食品。其次，Pintos很小，而单词“pint”也是“小”的意思。第三，就像撞衫那样，同学们会相互斥责（like drivers of the eponymous car, students are likely to have trouble with blow-ups）（这第三点貌似翻译的很不正经哈哈）。

---

Introduction部分到这里就结束了，有疑问的同学可以发送邮件到[matthewlee0725@gmail.com](matthewlee0725@gmail.com "我的Gmail")和我进行讨论。

**版权所有，转载请声明：转载自[mthli.github.io](https://mthli.github.io "mthli.github.io")**