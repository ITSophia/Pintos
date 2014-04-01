; 对应原书代码：c08.asm
; 文件说明：用户程序
; 创建日期：2014-03-31

; 这是mbr.asm调用的用户程序例子，
; 如同mbr.asm中那样，
; 对于用户程序这段，
; 我不打算给予过多注释，
; 仅仅提供原书代码中存在的注释，
; 同样，
; 如果将来有必要的话，
; 我还是会回头过来重新审视的
; ===============================================================================

SECTION header vstart=0          ; 定义用户程序头部段
    program_length  dd program_end ; 程序总长度[0x00]

    ; 用户程序入口点
    code_entry      dw start                             ; 偏移地址[0x04]
                    dd section.code_1.start              ; 段地址[0x06]
    realloc_tbl_len dw (header_end - code_1_segment) / 4 ; 段重定位表项个数[0x0a]

    ; 段重定位表
    code_1_segment  dd section.code_1.start
    code_2_segment  dd section.code_2.start
    data_1_segment  dd section.data_1.start
    data_2_segment  dd section.data_2.start
    stack_segment   dd section.stack.start

    header_end:

; ===============================================================================

SECTION code_1 align=16 vstart=0 ; 定义代码段1（16字节对齐）

; 显示串（0结尾）
; 输入：ds:bx = 串地址
put_string:
    mov cl, [bx]
    or cl, cl ; 判断cl是否等于0
    jz .exit  ; 是就返回主程序
    call put_char
    inc bx    ; 指向下一个字符
    jmp put_string

    .exit:
        ret

; -------------------------------------------------------------------------------

; 显示一个字符
; 输入：cl = 字符ascii
put_char:
    ; 压栈，保存数据
    push ax
    push bx
    push cx
    push dx
    push ds
    push es

    ; 以下取当前光标位置
    mov dx, 0x3d4
    mov al, 0x0e
    out dx, al
    mov dx, 0x3d5
    in al, dx ; 高8位
    mov ah, al

    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    mov dx, 0x3d5
    in al, dx    ; 低8位
    mov bx, ax   ; bx = 代表光标位置的16位数

    cmp cl, 0x0d ; 判断是否为回车符
    jnz .put_0a  ; 如果不是，看看是不是换行等字符
    mov ax, bx   ; 此句略显多余，但去掉后还得改书，麻烦
    mov bl, 80
    div bl
    mul bl
    mov bx, ax
    jmp .set_cursor

    .put_0a:
        cmp cl, 0x0a   ; 判断是否为换行符
        jnz .put_other ; 不是的话，那就正常显示字符
        add bx, 80
        jmp .roll_screen

    .put_other: ; 正常显示字符
        mov ax, 0xb800
        mov es, ax
        shl bx, 1
        mov [es:bx], cl

        ; 以下将光标位置推进一个字符
        shr bx, 1
        add bx, 1

     .roll_screen:
        cmp bx, 2000 ; 判断光标是否超出屏幕，如果是的话就滚屏
        jl .set_cursor

        mov ax, 0xb800
        mov ds, ax
        mov es, ax
        cld
        mov si, 0xa0
        mov di, 0x00
        mov cx, 1920
        rep movsw
        mov bx, 3840 ; 清除屏幕最底一行
        mov cx, 80

    .cls:
        mov word[es:bx], 0x0720
        add bx, 2
        loop .cls

        mov bx, 1920

    .set_cursor:
        mov dx, 0x3d4
        mov al, 0x0e
        out dx, al
        mov dx, 0x3d5
        mov al, bh
        out dx, al
        mov dx, 0x3d4
        mov al, 0x0f
        out dx, al
        mov dx, 0x3d5
        mov al, bl
        out dx, al

        pop es
        pop ds
        pop dx
        pop cx
        pop bx
        pop ax

        ret

; -------------------------------------------------------------------------------

start:
    ; 开始执行时，ds和es指向用户程序的头部段
    mov ax, [stack_segment]  ; 设置到用户程序自己的堆栈
    mov ss, ax
    mov sp, stack_end

    mov ax, [data_1_segment] ; 设置到用户程序自己的数据段
    mov ds, ax

    mov bx, msg0
    call put_string ; 显示第一段信息

    push word [es:code_2_segment]
    mov ax, begin
    push ax ; 80386以上的cpu构架可以直接push begin

    retf ; 转移到代码段2继续执行

continue:
    mov ax, [es:data_2_segment] ; 段寄存器ds切换到数据段2
    mov ds, ax

    mov bx, msg1
    call put_string ; 显示第2段信息

    jmp $

; ===============================================================================

SECTION code_2 align=16 vstart=0 ; 定义代码段2（16字节对齐）

begin:
    push word [es:code_1_segment]
    mov ax, continue
    push ax ; 80386及其以上的cpu构架可以直接push continue

    retf ; 转移到代码段1接着执行

; ===============================================================================

SECTION data_1 align=16 vstart=0
msg0 db '  This is NASM - the famous Netwide Assembler. '
     db 'Back at SourceForge and in intensive development! '
     db 'Get the current versions from http://www.nasm.us/.'
     db 0x0d,0x0a,0x0d,0x0a
     db '  Example code for calculate 1+2+...+1000:',0x0d,0x0a,0x0d,0x0a
     db '     xor dx,dx',0x0d,0x0a
     db '     xor ax,ax',0x0d,0x0a
     db '     xor cx,cx',0x0d,0x0a
     db '  @@:',0x0d,0x0a
     db '     inc cx',0x0d,0x0a
     db '     add ax,cx',0x0d,0x0a
     db '     adc dx,0',0x0d,0x0a
     db '     inc cx',0x0d,0x0a
     db '     cmp cx,1000',0x0d,0x0a
     db '     jle @@',0x0d,0x0a
     db '     ... ...(Some other codes)',0x0d,0x0a,0x0d,0x0a
     db 0

; ===============================================================================

SECTION data_2 align=16 vstart=0
msg1 db '  The above contents is written by LeeChung. '
     db '2011-05-06'
     db 0

; ===============================================================================

SECTION stack align=16 vstart=0
    resb 256

stack_end:

; ===============================================================================

SECTION trail align=16
program_end:
