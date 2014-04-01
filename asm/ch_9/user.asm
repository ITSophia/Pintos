; 对应原书代码：c-9_1.asm
; 文件说明：用户程序
; 创建日期：2014-04-01

; 如前面一样，
; 既然是用户程序，
; 我也就不会花很多时间在这段代码上了，
; 仅仅提供原书代码中的注释，
; 并且适当加上一点小小的补充；
; 当然，
; 如果将来有必要的话，
; 我还是会回头过来重新审视这段代码的

; ===============================================================================

SECTION header vstart=0                   ; 定义用户程序头头部段  
    program_length  dd program_end        ; 程序总长度[0x00]
    
    ; 用户程序接入点
    code_entry      dw start              ; 偏移地址[0x04]
                    dd section.code.start ; 段地址[0x06]
    
    realloc_tbl_len dw (header_end-realloc_begin) / 4 ; 段重定向表项个数[0x0a]                                       
    realloc_begin:
    ; 段重定向表
    code_segment    dd section.code.start   ; [0x0c]
    data_segment    dd section.data.start   ; [0x14]
    stack_segment   dd section.stack.start  ; [0x1c]
    
header_end:                
    
; ===============================================================================

SECTION code align=16 vstart=0 ; 定义代码段（16字节对齐）

new_int_0x70:
    push ax
    push bx
    push cx
    push dx
    push es
      
    .w0:
        ; 在这里有必要隆重介绍一下NMI和INTR两种中断方式。
        ; 首先是NMI：
        ;     NMI（Non Maskable Interrupt）非屏蔽中断，
        ;     顾名思义，这种中断是不会被阻塞的，
        ;     也就是说，
        ;     当NMI中发生时，
        ;     其结果是必然会中断
        ; 再说说INTR：
        ;     INTR是可屏蔽中断的意思，
        ;     顾名思义，这种中断是可以被屏蔽的，
        ;     也就是说是可以被忽略的，
        ;     所以当INTR发生时，
        ;     其结果是不一定会发生中断
        mov al, 0x0a  ; 阻断NMI。当然，通常是不必要的
        or al, 0x80                          
        out 0x70, al
        in al, 0x71   ; 读寄存器A；关于寄存器A可以参阅原书第155页                        
        test al, 0x80 ; 测试第7位UIP
        jnz .w0       ; 以上代码对于更新周期结束中断来说是不必要的       
                                         
        xor al, al
        or al, 0x80
        out 0x70, al
        in al, 0x71 ; 读RTC当前时间（秒）
        push ax

        mov al, 2
        or al, 0x80
        out 0x70, al
        in al, 0x71 ; 读RTC当前时间（分）
        push ax

        mov al, 4
        or al, 0x80
        out 0x70, al
        in al, 0x71 ; 读RTC当前时间（时）
        push ax

        mov al, 0x0c ; 寄存器C的索引。且开放NMI。关于寄存器C可参阅原书第157页
        out 0x70, al
        ; 读一下RTC的寄存器C，否则只发生一次中断。
        ; 此处不考虑闹钟和周期性中断的情况
        in al, 0x71 
                                         
        mov ax, 0xb800
        mov es, ax

        pop ax
        call bcd_to_ascii
        mov bx, 12 * 160 + 36 * 2 ; 从屏幕上的12行36列开始显示

        mov [es:bx], ah
        mov [es:bx + 2], al ; 显示2位小时数数字

        mov al, ':'
        mov [es:bx + 4], al  ; 显示分隔符号':'           
        not byte [es:bx + 5] ; 反转显示属性

        pop ax
        call bcd_to_ascii
        mov [es:bx + 6], ah
        mov [es:bx + 8], al  ; 显示2位分钟数字                 

        mov al, ':'
        mov [es:bx + 10], al
        not byte [es:bx + 11]              

        pop ax
        call bcd_to_ascii
        mov [es:bx + 12], ah
        mov [es:bx + 14], al
      
        mov al, 0x20 ; 中断结束命令EOI
        out 0xa0, al ; 向从片中发送
        out 0x20, al ; 向主片中发送

        pop es
        pop dx
        pop cx
        pop bx
        pop ax

        iret

; -------------------------------------------------------------------------------

; BCD转ASCII
; 输入：AL=BCD码
; 输出：AX=ASCII码
bcd_to_ascii:                       
      mov ah, al   ; 拆分成两个数字
      and al, 0x0f ; 仅保留低4位
      add al, 0x30 ; 转换成ASCII

      shr ah, 4    ; 逻辑右移4位
      and ah, 0x0f                        
      add ah, 0x30

      ret

; -------------------------------------------------------------------------------

start:
    mov ax, [stack_segment]
    mov ss, ax
    mov sp, ss_pointer
    mov ax, [data_segment]
    mov ds, ax
      
    mov bx, init_msg ; 显示初始信息
    call put_string

    mov bx, inst_msg ; 显示安装信息
    call put_string
      
    mov al, 0x70
    mov bl, 4
    mul bl ; 计算0x70号中断在IVT中的偏移
    mov bx, ax                          

    cli ; 防止改动期间发生新的0x70号中断

    push es
    mov ax, 0x0000
    mov es, ax
    mov word [es:bx], new_int_0x70 ; 偏移地址
                                        
    mov word [es:bx + 2], cs ; 段地址
    pop es

    mov al, 0x0b ; RTC寄存器B
    or al, 0x80  ; 阻断NMI          
    out 0x70, al
    mov al, 0x12 ; 设置寄存器B，禁止周期性中断，开放更新结束后中断                   
    out 0x71, al ; BCD码，24小时制

    mov al, 0x0c
    out 0x70, al
    in al, 0x71 ; 读取RTC寄存器C，复位未决的中断状态      

    in al, 0xa1  ; 读8259从片的IMR寄存器
    and al, 0xfe ; 清除bit 0（此位连接RTC）
    out 0xa1, al ; 写回此寄存器

    sti ; 重新开放中断 

    mov bx, done_msg ; 显示安装完成的信息  
    call put_string

    mov bx, tips_msg ; 显示提示信息
    call put_string
      
    mov cx, 0xb800
    mov ds, cx
    mov byte [12 * 160 + 33 * 2], '@' ; 屏幕第12行35列
       
    .idle:
        hlt                              ; 使CPU进入低功耗状态，直到用中断唤醒
        not byte [12 * 160 + 33 * 2 + 1] ; 反转显示属性
        jmp .idle

; -------------------------------------------------------------------------------

; 显示串（0结尾）
; 输入：DS:BX = 串地址
put_string:
                                         
    mov cl, [bx]
    or cl, cl ; 判断cl是否为0           
    jz .exit  ; 如果是就返回主程序   
    call put_char
    inc bx    ; 指向下一个字节
    jmp put_string

   .exit:
        ret

; -------------------------------------------------------------------------------

; 显示一个字符
; 输入：cl = 字符ascii码
put_char:                                         
    push ax
    push bx
    push cx
    push dx
    push ds
    push es

    ; 以下获取当前光标位置
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
    in al, dx  ; 低8位
    mov bx, ax ; bx = 代表光标位置的16位数

    cmp cl, 0x0d ; 判断是否为回车符
    jnz .put_0a  ; 不是的话则继续判断看看是否为换行等字符
    mov ax, bx
    mov bl, 80
    div bl
    mul bl
    mov bx, ax
    jmp .set_cursor

    .put_0a:
        cmp cl, 0x0a   ; 判断是否位换行符，
        jnz .put_other ; 不是的话就正常显示字符
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

; ===============================================================================

SECTION data align=16 vstart=0

    init_msg db 'Starting...', 0x0d, 0x0a, 0
                   
    inst_msg db 'Installing a new interrupt 70H...', 0
    
    done_msg db 'Done.', 0x0d, 0x0a, 0

    tips_msg db 'Clock is now working.', 0
                   
; ===============================================================================

SECTION stack align=16 vstart=0
           
    resb 256

ss_pointer:
 
; ===============================================================================

SECTION program_trail

program_end:
