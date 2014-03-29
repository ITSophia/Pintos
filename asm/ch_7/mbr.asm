; 对应书中源码：c07_mbr.asm
; 文件说明：硬盘主引导区代码
; 创建日期：2014-03-29

jmp near start

message db '1 + 2 + 3 + ... + 100 = '

start:
    ; 设置数据段的段基地址
    mov ax, 0x7c0
    mov ds, ax
    ; 设置附加段基地址到显示缓冲区
    mov ax, 0xb800
    mov es, ax

    ; 以下显示字符串。
    ; 索引寄存器si指向ds段内显示的字符串的首地址，
    ; 即标号“message”所代表的汇编地址
    mov si, message 
    ; 索引寄存器di指向es段内的偏移地址0处，es是指向0xb800的
    mov di, 0
    ; 获取循环次数
    mov cx, start - message

    ; @在这里不是表示标号的意思，
    ; 可以参考书上第57页最后一段，
    ; 那么它究竟是什么呢？
    ; 我也不知道，
    ; 暂且把它当作代码的一部分看待好啦
    @g:
        mov al, [si]
        mov [es:di], al
        inc di
        mov byte [es:di], 0x07
        ; 两次inc，
        ; 使得ds:si与es:di均指向下一个内存单元
        inc di
        inc si
        loop @g

        ; 以下开始计算1到100的和
        xor ax, ax
        mov cx, 1

    @f:
        add ax, cx ; 开始累加
        inc cx     ; 得到下1个需要被累加的数
        cmp cx, 100
        jle @f     ; jle是小于等于就跳转的意思

        ; 以下计算累加和的每个数位
        xor cx, cx
        mov ss, cx ; ss，stack segment， 栈段的意思
        mov sp, cx ; stack pointer，栈指针寄存器

        mov bx, 10
        xor cx, cx

    @d:
        inc cx ; 在这里的cx用于计算得到的位数
        xor dx, dx
        div bx
        ; 在这里使用or与使用add起到的作用相同，
        ; 详情可以参阅原书101页倒数第3段
        or dl, 0x30 
        push dx ; 关键的压栈操作
        cmp ax, 0
        ; jne是相减结果不为0则跳转，
        ; 在这里就是说，
        ; 如果不相等则跳转
        jne @d

    ; 以下显示各个数位
    @a:
        pop dx ; 关键的出栈操作
        mov [es:di], dl
        inc di ; 指向下一个内存单元
        mov byte [es:di], 0x07
        inc di ; 指向下一个内存单元
        loop @a

        jmp near $

times 510 - ($ - $$) db 0
                    db 0x55, 0xaa
