; 对应原书代码：c12_MBR.ASM
; 文件说明：硬盘主引导扇区代码
; 创建日期：2014-04-02

mov eax, cs
mov ss, eax
mov sp, 0x7c00

mov eax, [cs:pgdt + 0x7c00 + 0x02]
xor edx, edx
mov ebx, 16
div ebx

mov ds, eax
mov ebx, edx

mov dword [ebx + 0x00], 0x00000000
mov dword [ebx + 0x04], 0x00000000

mov dword [ebx + 0x08], 0x0000ffff
mov dword [ebx + 0x0c], 0x00cf9200

mov dword [ebx + 0x10], 0x7c0001ff
mov dword [ebx + 0x14], 0x00409800

mov dword [ebx + 0x18], 0x7c0001ff
mov dword [ebx + 0x1c], 0x00409200

mov dword [ebx + 0x20], 0x7c00fffe
mov dword [ebx + 0x24], 0x00cf9600

mov word [cs:pgdt + 0x7c00], 39

lgdt [cs:pgdt + 0x7c00]

in al, 0x92
or al, 0000_0010B
out 0x92, al

cli

mov eax, cr0
or eax, 1
mov cr0, eax

jmp dword 0x0010:flush

[bits 32]

flush:
    mov eax, 0x0018
    mov ds, eax

    mov eax, 0x0008
    mov es, eax
    mov fs, eax
    mov gs, eax

    mov eax, 0x0020 ; 0000 0000 0010 0000
    mov ss, eax
    xor esp, esp     ; ESP <- 0

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

pgdt dw 0
     dd 0x00007e00

; -------------------------------------------------------------------------------

times 510 - ($ - $$) db 0
                     db 0x55, 0xaa
