; 对应原书代码：c12_MBR.ASM
; 文件说明：硬盘主引导扇区代码
; 创建日期：2014-04-02

; 设置堆栈指针；
; 在这里使用eax或者ax其实都没什么影响，
; 因为我们使用的是NASM汇编器，哈哈
mov eax, cs
mov ss, eax
mov sp, 0x7c00

; 计算GDT在实模式下的逻辑段地址；
; 另外需要注意的是，
; 在32位处理器上，即使是在实模式下，也可以使用32位寄存器
mov eax, [cs:pgdt + 0x7c00 + 0x02] ; 这里是GDT的32位线性基地址
xor edx, edx
mov ebx, 16
div ebx                            ; 通过整除16的方式获取其16位下的逻辑地址

mov ds, eax  ; 令ds指向GDT所在逻辑段段以进行操作
mov ebx, edx ; 获取段内起始偏移地址

; 创建空描述符，
; 空描述符的用意是阻止不安全的访问
mov dword [ebx + 0x00], 0x00000000
mov dword [ebx + 0x04], 0x00000000

; 安装数据段描述符，
; 注意，
; 这个数据段为4GB大小的线性地址空间
mov dword [ebx + 0x08], 0x0000ffff ; 基地址为0， 段界限为0xfffff
mov dword [ebx + 0x0c], 0x00cf9200 ; 粒度为4KB

; 安装代码段描述符
mov dword [ebx + 0x10], 0x7c0001ff ; 基地址为0x00007c00，512字节
mov dword [ebx + 0x14], 0x00409800 ; 粒度为1个字节

; 创建以上代码的别名描述符；
; 那么什么是别名呢？
; 在保护模式下，代码段是不可写入的，
; 这里是说，
; 通过该段的描述符来访问这个区域的时候，
; 处理器不云戏向里面写入数据或者更改数据；
; 但有的时候我们有又有这方面的需求，
; 所以如果需要访问呢代码段内的数据，
; 只能重新为该段安装一个新的描述符，
; 并将其定义为可读可写的数据段，
; 这样，我们的需求就可以满足啦；
; 所以综上所述，
; 当两个或者两个以上的描述符都描述和指向同一个段的时候，
; 把另外的描述符称为别名（alias）
mov dword [ebx + 0x18], 0x7c0001ff ; 基地址为0x00007c00，512字节
mov dword [ebx + 0x1c], 0x00409200 ; 粒度为1个字节

; 安装栈段描述符
mov dword [ebx + 0x20], 0x7c00fffe ; 基地址为0x00007c00
mov dword [ebx + 0x24], 0x00cf9600 ; 粒度4KB

; 初始化描述符表寄存器GDTR
mov word [cs:pgdt + 0x7c00], 39 ; 设置符表的界限为39

; 加载GDT
lgdt [cs:pgdt + 0x7c00]

; 打开A20
in al, 0x92
or al, 0000_0010B
out 0x92, al

; 打开A20
cli

; 设置PE位
mov eax, cr0
or eax, 1
mov cr0, eax

; 进入保护模式
jmp dword 0x0010:flush ; 16位的描述符选择子：32位偏移
                       ; 这条指令会隐式地修改寄存器cs

; 32位代码段
[bits 32]

flush:
    ; 这段代码执行完毕之后，
    ; cs指向512字节的32位代码段，基地址是0x00007c00；
    ; ds指向512字节的32位数据段，该段是上述代码段的别名；
    ; es、fs、gs指向同一个段，该段是一个4GB的32位数据段，基地址为0x00000000；
    ; ss指向4KB的32位栈段，基地址为0x00007c00
    mov eax, 0x0018
    mov ds, eax
    mov eax, 0x0008 ; 加载数据段（0:4GB）选择子
    mov es, eax
    mov fs, eax
    mov gs, eax
    mov eax, 0x0020 ; 0000 0000 0010 0000
    mov ss, eax

    xor esp, esp ; esp清零
    
    ; 写入一些字符；
    ; 在此之后主要是有关所谓“冒泡排序”内容了，
    ; 我在这里就不予赘述，
    ; 大家可以结合原书第217页开始的讲解自行理解，
    ; 当然，
    ; 如果以后有必要的话，
    ; 我也会自己回头过来重新审视这段代码
    mov dword [es:0x0b8000], 0x072e0750
    mov dword [es:0x0b8004], 0x072e074d
    mov dword [es:0x0b8008], 0x07200720
    mov dword [es:0x0b800c], 0x076b076f

    mov ecx, pgdt - string - 1

@@1:
    push ecx
    xor bx, bx

@@2:
    mov ax, [string + bx]
    cmp ah, al
    jge @@3
    xchg al, ah
    mov [string + bx], ax

@@3:
    inc bx
    loop @@2
    pop ecx
    loop @@1

    mov ecx, pgdt - string
    xor ebx, ebx

@@4:
    mov ah, 0x07
    mov al, [string + ebx]
    mov [es:0xb80a0 + ebx * 2], ax
    inc ebx
    loop @@4

hlt

; -------------------------------------------------------------------------------

string db 's0ke4or92xap3fv8giuzjcy5l1m7hd6bnqtw.'

; -------------------------------------------------------------------------------

; 初始化GDT的线性基地址
pgdt dw 0
     dd 0x00007e00

; -------------------------------------------------------------------------------

times 510 - ($ - $$) db 0
                     db 0x55, 0xaa
