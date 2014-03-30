;===============================================================================
SECTION header vstart=0
    program_length  dd program_end

    code_entry      dw start
                    dd section.code_1.start

    realloc_tbl_len dw (header_end-code_1_segment)/4

    code_1_segment  dd section.code_1.start
    code_2_segment  dd section.code_2.start
    data_1_segment  dd section.data_1.start
    data_2_segment  dd section.data_2.start
    stack_segment   dd section.stack.start

    header_end:

;===============================================================================
SECTION code_1 align=16 vstart=0
put_string:
    mov cl,[bx]
    or cl,cl
    jz .exit
    call put_char
    inc bx
    jmp put_string

    .exit:
        ret

;-------------------------------------------------------------------------------
put_char:
    push ax
    push bx
    push cx
    push dx
    push ds
    push es

    mov dx,0x3d4
    mov al,0x0e
    out dx,al
    mov dx,0x3d5
    in al,dx
    mov ah,al

    mov dx,0x3d4
    mov al,0x0f
    out dx,al
    mov dx,0x3d5
    in al,dx
    mov bx,ax

    cmp cl,0x0d
    jnz .put_0a
    mov ax,bx
    mov bl,80
    div bl
    mul bl
    mov bx,ax
    jmp .set_cursor

    .put_0a:
        cmp cl,0x0a
        jnz .put_other
        add bx,80
        jmp .roll_screen

    .put_other:
        mov ax,0xb800
        mov es,ax
        shl bx,1
        mov [es:bx],cl

        shr bx,1
        add bx,1

     .roll_screen:
        cmp bx,2000
        jl .set_cursor

        mov ax,0xb800
        mov ds,ax
        mov es,ax
        cld
        mov si,0xa0
        mov di,0x00
        mov cx,1920
        rep movsw
        mov bx,3840
        mov cx,80
    .cls:
        mov word[es:bx],0x0720
        add bx,2
        loop .cls

        mov bx,1920

    .set_cursor:
        mov dx,0x3d4
        mov al,0x0e
        out dx,al
        mov dx,0x3d5
        mov al,bh
        out dx,al
        mov dx,0x3d4
        mov al,0x0f
        out dx,al
        mov dx,0x3d5
        mov al,bl
        out dx,al

        pop es
        pop ds
        pop dx
        pop cx
        pop bx
        pop ax

        ret

;-------------------------------------------------------------------------------
start:
    mov ax,[stack_segment]
    mov ss,ax
    mov sp,stack_end

    mov ax,[data_1_segment]
    mov ds,ax

    mov bx,msg0
    call put_string

    push word [es:code_2_segment]
    mov ax,begin
    push ax

    retf

    continue:
    mov ax,[es:data_2_segment]
    mov ds,ax

    mov bx,msg1
    call put_string

    jmp $

;===============================================================================
SECTION code_2 align=16 vstart=0
begin:
    push word [es:code_1_segment]
    mov ax,continue
    push ax

    retf
;===============================================================================
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

;===============================================================================
SECTION data_2 align=16 vstart=0
msg1 db '  The above contents is written by LeeChung. '
     db '2011-05-06'
     db 0

;===============================================================================
SECTION stack align=16 vstart=0
    resb 256

stack_end:

;===============================================================================
SECTION trail align=16
program_end:
