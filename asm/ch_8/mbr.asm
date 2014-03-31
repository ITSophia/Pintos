; 原书对应程序：c08_mbr.asm
; 文件说明：硬盘主引导扇区代码（加载程序）
; 创建日期：2014-03-30

; 声明常数（用户程序的起始逻辑扇区的区号），
; 注意equ的作用就是一个代码替换的指令，
; 有点C语言中宏定义的味道;
; 另外，常数的申明不会占用汇编地址
app_lba_start equ 100

; NASM汇编使用SECTION或者SEGMENT来定义段;
; align是用来指定SEGMENT的汇编地址的对其方式的，
; 因为Intel处理器要求段在内存中的起始物理地址起码是16字节对齐的，
; 也就是说，必须是16的倍数，或者能被16整除;
; vstart是用来使段内标号的汇编地址从该段的开头开始计算的，
; 如果没有用vstart说明，
; 则这个标号的汇编地址是从整个程序的开头开始计算的
SECTION mbr align = 16 vstart = 0x7c00
    ; 设置堆栈
    mov ax, 0
    mov ss, ax ; ss是stack segment，栈段寄存器
    mov sp, ax ; sp是stack pointer，栈指针寄存器

    ; 以下两条mov语句用于存放phy_base处的一个双字单元，
    ; 因为双字是32位的，
    ; 所以在16位的8086上，只能用两个寄存器存放，
    ; 又因为Intel处理器是低端序列的，
    ; 所以高16位存放在phy_base + 0x02处，
    ; 低16位存放在phy_base处
    mov ax, [cs:phy_base]
    mov dx, [cs:phy_base + 0x02]
    ; 一条div 16（右移4位）使得phy_base处的地址变为16位的段地址
    mov bx, 16
    div bx
    mov ds, ax
    mov es, ax

    ; 以下开始读取程序的起始部分;
    ; 首先用异或将di清零
    xor di, di
    ; 把程序在硬盘上的起始逻辑扇区号移入源索引寄存器si中
    mov si, app_lba_start
    ; 异或使bx清零
    xor bx, bx
    ; call调用read_hard_disk_0过程（函数），
    ; 在这里做好看一下原书上第128页的图8-13，
    ; 十分清楚地介绍了过程与过程调用
    call read_hard_disk_0

    ; @1一直到最后的calc_segment_base我就不多介绍了，
    ; 仅仅引用原书中给出的注释，
    ; 如果有兴趣的话可以自己对照原书自己理解一下。
    ; 当然，
    ; 如果将来我觉得有必要的话，
    ; 还是会回头过来好好看一下的。
    ; 以下判断整个用户程序有多大
    mov dx, [2] ; 曾经把dx写成了ds，花了20分钟排错
    mov ax, [0]
    mov bx, 512 ; 每个扇区512个字节
    div bx
    cmp dx, 0
    jnz @1      ; 未除尽，因此结果比实际扇区少1
    dec ax      ; 已经读了一个扇区，扇区总数减1

    @1:
        cmp ax, 0   ; 考虑实际长度小于等于512个字节的情况
        jz direct

        ; 读取剩余的扇区
        push ds    ; 以下要用到并改变ds寄存器
        mov cx, ax ; 循环次数（剩余扇区）

    @2:
        mov ax, ds
        add ax, 0x20 ; 得到下一个以512字节为边界的段地址
        mov ds, ax

        xor bx, bx ; 每次读时，偏移地址始终为0x0000
        inc si     ; 下一个逻辑扇区
        call read_hard_disk_0
        loop @2    ; 循环读，直到读完整个功能程序

        pop ds ; 恢复数据段基址到用户程序头部段

    ; 计算入口点代码段
    direct:
        mov dx, [0x08]
        mov ax, [0x06]
        call calc_segment_base
        mov [0x06], ax ; 回填修正后的入口点代码段地址

        ; 开始处理段重定位表
        mov cx, [0x0a] ; 需要重定位的项目数量
        mov bx, 0x0c   ; 重定位表首地址

    realloc:
        mov dx, [bx+0x02] ; 32位地址的高16位
        mov ax, [bx]
        call calc_segment_base
        mov [bx], ax      ; 回填段的基址
        add bx, 4         ; 下一个重定位项（每项占4个字节）
        loop realloc

        jmp far [0x04]    ; 跳转到用户程序

;-------------------------------------------------------------------------------

; 从硬盘读取一个逻辑扇区，
; 输入：di:is = 起始逻辑扇区号
;       ds:bx = 目标缓冲区地址
read_hard_disk_0:
    ; 进行压栈，保存数据
    push ax
    push bx
    push cx
    push dx

    ; 在这里有必要了解一些in和out指令，
    ; 1. in
    ;     in是从端口读入指令，
    ;     其目的操作数必须是寄存器al或者ax，
    ;     也不允许内存单元作为操作数，
    ;     它也不影响任何标志位
    ; 2. out
    ;     out是端口输出位，
    ;     可以参考in指令进行理解
    mov dx, 0x1f2
    mov al, 1
    out dx, al ; 读取的扇区数

    inc dx     ; 使得dx = 0x1f3
    mov ax, si
    out dx, al ; lba地址7 ~ 0

    inc dx     ; 使得dx = 0x1f4
    mov al, ah
    out dx, al ; lba地址15 ~ 8

    inc dx     ; 使得dx = 0x1f5
    mov ax, di
    out dx, al ; lba地址23 ~ 16

    inc dx       ; 使得dx = 0x1f6
    mov al, 0xe0 ; lba28模式，主盘
    or al, ah    ; lba地址27~24
    out dx, al

    ; 在这里介绍一下一个特别的端口，叫做0x1f7：
    ;     0x1f7既是命令端口，又是状态端口；
    ;     在通过这个端口发送读命令之后，硬盘就开始忙乎了，
    ;     在硬盘进行内部操作期间，它将这个端口的第7位置“1”，
    ;     表示自己很忙;
    ;     当硬盘工作完毕，它就会将此位清零，
    ;     说明自己工作完毕，
    ;     同时将第3位置“1”，
    ;     表示自己已经准备好，请主机发送或者接受数据.
    ; 另外再说说0x1f1端口：
    ;     这个端口是错误寄存器，
    ;     包含硬盘驱动器最后一次执行命令后的状态（错误原因）
    inc dx       ; 使得dx = 0x1f7
    mov al, 0x20 ; 读命令
    out dx, al

    .waits:
        in al, dx
        and al, 0x88
        cmp al, 0x08
        jnz .waits ; 不忙，且硬盘已经准备好数据传输

        mov cx, 256 ; 总共要读取的字数
        mov dx, 0x1f0
    
    .readw:
        in ax, dx
        mov [bx], ax
        add bx, 2
        loop .readw

        pop dx
        pop cx
        pop bx
        pop ax

        ret

;-------------------------------------------------------------------------------

; 计算16位段地址，
; 输入：dx:ax = 32位物理地址
; 返回：ax = 16位段地址
calc_segment_base:
    push dx

    add ax, [cs:phy_base]
    adc dx, [cs:phy_base+0x02]
    shr ax, 4
    ror dx, 4
    and dx, 0xf000
    or ax, dx

    pop dx

    ret

;-------------------------------------------------------------------------------

; 用户程序被加载的物理地址
phy_base dd 0x10000

times 510-($-$$) db 0
                 db 0x55, 0xaa
