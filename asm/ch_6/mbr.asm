; 对应书中源码：c06_mbr.asm
; 文件说明：硬盘主引导扇区代码
; 创建日期：2014-03-29

; jmp表示无条件跳转，
; 直接跳转到start代码段而不是顺序执行
jmp near start

; 设置数字段
mytext: 
    db \
    'L', 0x07, \
    'a', 0x07, \
    'b', 0x07, \
    'e', 0x07, \
    'l', 0x07, \
    ' ', 0x07, \
    'o', 0x07, \
    'f', 0x07, \
    'f', 0x07, \
    's', 0x07, \
    'e', 0x07, \
    't', 0x07, \
    ':', 0x07

; 如同ch_5中那样，
; 用number作为标号，
; 取得其汇编地址，
; 方便访问数据
number:
    db 0, 0, 0, 0, 0

start:
    ; 设置数据段基地址
    mov ax, 0x7c0
    mov ds, ax
    ; 设置附加段基地址
    mov ax, 0xb800
    mov es, ax
    ; 首先了解一下cld：
    ;     cld用于串操作指令中，
    ;     用来操作方向标志位df的，
    ;     cld使其复位，即df = 0，
    ;     df = 0表示数据传送的方向为正，
    ;     即从内存区域中的低地址端传送到高地址端；
    ;     另外这个操作在串操作指令中，使地址增量
    ; 当然也需要了解一下std：
    ;     std同样用于串操作指令中，
    ;     也是用来操作方向标志位df的，
    ;     std使其置位，即df = 1，
    ;     df = 1表示数据传送的方向为负，
    ;     即从内存区域中的高地址端传送到低地址端；
    ;     另外这个操作在串操作指令中，使地址减量
    cld
    ; si，source index，
    ; 表示源索引、串复制源地址、数组索引等等
    mov si, mytext
    ; di，destination index，
    ; 表示目的索引、目的地址、数组索引等等。
    ; 其实我觉得你有必要看看有关si和di的一些用法，
    ; 并且记住它们
    mov di, 0
    ; 除以2是因为要获取到需要显示的字符的显示属性和ASCII码
    mov cx, (number - mytext) / 2 ; 实际上等于13
    ; rep即repeat，
    ; 当cx不为0则一直重复；
    ; movsw每传送一次数据，
    ; cx就会自减一次
    rep movsw

    ; 得到标号所代表的偏移地址
    mov ax, number

    ; 计算各个数位
    mov bx, ax
    ; 在这里cx = 5，正好取得需要的5个数
    mov cx, 5
    mov si, 10

digit:
    xor dx, dx
    div si
    mov [bx], dl
    inc bx
    ; loop的话呢，也是cx不为0时就重复，
    ; 当然每loop一次，cx就会自减一次
    loop digit

    ; 显示各个数位
    mov bx, number
    mov si, 4

show:
    mov al, [bx + si]
    add al, 0x30 ; ASCII字符
    mov ah, 0x40 ; 显示属性， 所以ax的前8位是显示属性，后8位是ASCII值
    mov [es:di], ax
    add di, 2    ; 指向显示缓冲区的下一个单元
    dec si       ; si自减一次
    jns show     ; jns，如果未设置符号位，则跳转

    mov word [es:di], 0x0744 ; 最后再多显示一个‘D’字符

    ; $符号的意思是：
    ;     转移到当前指令继续执行，
    ;     $是当前行的汇编地址
    jmp near $

; $$符号的意思是：
;     当前汇编节（段）的起始汇编地址
; 所以$ - $$就是求出这个程序的实际大小，
; 再用510减去程序的实际大小，就是需要填充的字节数
times 510 - ($ - $$) db 0
                     db 0x55, 0xaa
