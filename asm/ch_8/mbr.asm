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

    mov dx, [2]
    mov ax, [0]
    mov bx, 512
    div bx
    cmp dx, 0
    jnz @1
    dec ax
    @1:
        cmp ax,0
        jz direct

        push ds

        mov cx,ax
    @2:
        mov ax,ds
        add ax,0x20
        mov ds,ax

        xor bx,bx
        inc si
        call read_hard_disk_0
        loop @2

        pop ds

    direct:
        mov dx,[0x08]
        mov ax,[0x06]
        call calc_segment_base
        mov [0x06],ax

        mov cx,[0x0a]
        mov bx,0x0c

    realloc:
        mov dx,[bx+0x02]
        mov ax,[bx]
        call calc_segment_base
        mov [bx],ax
        add bx,4
        loop realloc

        jmp far [0x04]

;-------------------------------------------------------------------------------
read_hard_disk_0:
    push ax
    push bx
    push cx
    push dx

    mov dx,0x1f2
    mov al,1
    out dx,al

    inc dx
    mov ax,si
    out dx,al

    inc dx
    mov al,ah
    out dx,al

    inc dx
    mov ax,di
    out dx,al

    inc dx
    mov al,0xe0
    or al,ah
    out dx,al

    inc dx
    mov al,0x20
    out dx,al

    .waits:
        in al,dx
        and al,0x88
        cmp al,0x08
        jnz .waits

        mov cx,256
        mov dx,0x1f0
    
    .readw:
        in ax,dx
        mov [bx],ax
        add bx,2
        loop .readw

        pop dx
        pop cx
        pop bx
        pop ax

        ret

;-------------------------------------------------------------------------------
calc_segment_base:
    push dx

    add ax,[cs:phy_base]
    adc dx,[cs:phy_base+0x02]
    shr ax,4
    ror dx,4
    and dx,0xf000
    or ax,dx

    pop dx

    ret

;-------------------------------------------------------------------------------
phy_base dd 0x10000

times 510-($-$$) db 0
                 db 0x55,0xaa
