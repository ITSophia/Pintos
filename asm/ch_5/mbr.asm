; 对应原书代码：c05_mbr.asm
; 文件说明：硬盘主引导扇区代码
; 创建日期：2014-03-28

mov ax, 0xb800 ; 指向文本模式的显示缓冲区
mov es, ax     ; 把ax中的地址复制到附加寄存器ex中

; 以下代码将显示字符串“Label offset:"
; 注意屏幕上的每个字符对应着两个字节：
;     前一个是ASCII字符，
;     后一个是字符的显示属性，比如颜色啊什么的
mov byte [es:0x00], 'L'
mov byte [es:0x01], 0x07
mov byte [es:0x02], 'a'
mov byte [es:0x03], 0x07
mov byte [es:0x04], 'b'
mov byte [es:0x05], 0x07
mov byte [es:0x06], 'e'
mov byte [es:0x07], 0x07
mov byte [es:0x08], 'l'
mov byte [es:0x09], 0x07
mov byte [es:0x0a], ' '
mov byte [es:0x0b], 0x07
mov byte [es:0x0c], "o"
mov byte [es:0x0d], 0x07
mov byte [es:0x0e], 'f'
mov byte [es:0x0f], 0x07
mov byte [es:0x10], 'f'
mov byte [es:0x11], 0x07
mov byte [es:0x12], 's'
mov byte [es:0x13], 0x07
mov byte [es:0x14], 'e'
mov byte [es:0x15], 0x07
mov byte [es:0x16], 't'
mov byte [es:0x17], 0x07
mov byte [es:0x18], ':'
mov byte [es:0x19], 0x07

; 取得标号number的偏移地址，
; number方便用于获取数据的汇编地址，详见书中
; 详见书中第56~58页。
; 这个number标号在本段代码的末尾。
; 实际上这种把数据段和代码段混合在同一段内存的做法并不好，
; 书中自己也是这样说的，
; 不过在这里暂时不予理会
mov ax, number
; 把数字10放入到bx中，备用
mov bx, 10

; 设置数据段的基地址，
; 这里不甚理解：
;     为什么要用代码段的cs寄存器，
;     这与数据段有关系？
; 书中是这样解释这个问题的：
;     因为之前我们把数据段和代码段混合在一起了，
;     也就是在同一段内存中，
;     自然cs和ds也指向同一段内存啦
mov cx, cs
mov ds, cx

; 首先求个位上的数字。
; 显然在这里你需要深入了解一下div指令
mov dx, 0
div bx
mov [0x7c00 + number + 0x00], dl ; 保存个位上的数字
; 求十位上的数字
; 这里采用“异或”的方式将dx清零，
; 效率比使用mov清零的效率要高
xor dx, dx
div bx
mov [0x7c00 + number + 0x01], dl ; 保存十位上的数字
; 求百位上的数字
xor dx, dx
div bx
mov [0x7c00 + number + 0x02], dl ; 保存百位上的数字
; 求千位上的数字
xor dx, dx
div bx
mov [0x7c00 + number + 0x03], dl ; 保存千位上的数字
; 求万位上的数字
xor dx, dx
div bx
mov [0x7c00 + number + 0x04], dl ; 保存万位上的数字

; 接下来用十进制显示标号的偏移地址，
; 首先处理万位上的数
mov al, [0x7c00 + number + 0x04]
add al, 0x30             ; 转换为ASCII对应的字符
mov [es:0x1a], al
mov byte [es:0x1b], 0x04 ; 注意一下这里byte的用处
; 处理千位对应的数
mov al, [0x7c00 + number + 0x03]
add al, 0x30
mov [es:0x1c], al
mov byte [es:0x1d], 0x04
; 处理百位上对应的数
mov al, [0x7c00 + number + 0x02]
add al, 0x30
mov [es:0x1e], al
mov byte [es:0x1f], 0x04
; 处理十位上对应的数
mov al,[0x7c00 + number + 0x01]
add al, 0x30
mov [es:0x20], al
mov byte [es:0x21], 0x04
; 处理个位上对应的数
mov al, [0x7c00 + number + 0x00]
add al,0x30
mov [es:0x22],al
mov byte [es:0x23],0x04
; 最后加上一点儿标志，表明这是一个十进制数
mov byte [es:0x24], 'D'
mov byte [es:0x25], 0x07

; 声明标号number，并进行初始化。
; 其实我觉得这里有个问题：
;     为什么要用5个byte来进行初始化？
; 我的理解是：
;     根据对源码的观察，
;     实际上number在这里仅仅是起到做汇编地址的作用，
;     而与它被初始化的内容无关。
;     也就是说，想初始化成什么样子，
;     就初始化成什么样子。
;     我修改了初始化的值和个数再运行，
;     事实证明确实和初始化的没有关系。
number:
    db 1, 1

; 无限循环
infi:
    jmp near infi

; 填充不够的存储区，
; 使其达到启动扇区的要求
times 203 db 0
db 0x55, 0xaa
