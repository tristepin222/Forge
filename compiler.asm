; bootcompiler.asm
; Minimal bootstrap compiler in x86 Linux
; Input file: program.imp (must contain 'hello')
; Output file: program.asm (prints Hello, world)
; Assemble: nasm -f elf32 bootcompiler.asm -o bootcompiler.o
; Link: ld -m elf_i386 bootcompiler.o -o bootcompiler

section .data
in_file     db "program.imp",0
out_file    db "program.asm",0
msg_open    db "Opening source file failed",10,0
msg_write   db "Writing output failed",10,0

; Output assembly to be written
msg_output  db 'section .data',10
            db 'msg: db "Hello, world",10',10
            db 'len: equ $ - msg',10
            db 'section .text',10
            db 'global _start',10
            db '_start:',10
            db '    mov eax,4',10
            db '    mov ebx,1',10
            db '    mov ecx,msg',10
            db '    mov edx,len',10
            db '    int 0x80',10
            db '    mov eax,1',10
            db '    xor ebx,ebx',10
            db '    int 0x80',10
msg_output_len equ $ - msg_output

section .bss
infd        resd 1
outfd       resd 1
buf         resb 16
read_bytes  resd 1

section .text
global _start

_start:
    ; --- open input file ---
    mov eax,5          ; sys_open
    mov ebx,in_file
    mov ecx,0          ; O_RDONLY
    int 0x80
    cmp eax,0
    jl open_fail
    mov [infd],eax

    ; --- read input file ---
    mov eax,3          ; sys_read
    mov ebx,[infd]
    mov ecx,buf
    mov edx,16
    int 0x80
    mov [read_bytes],eax
    cmp eax,5          ; must be exactly 5 bytes ("hello")
    jne write_fail

    ; --- close input file ---
    mov eax,6          ; sys_close
    mov ebx,[infd]
    int 0x80

    ; --- verify "hello" ---
    mov al,[buf+0]
    cmp al,'h'
    jne write_fail
    mov al,[buf+1]
    cmp al,'e'
    jne write_fail
    mov al,[buf+2]
    cmp al,'l'
    jne write_fail
    mov al,[buf+3]
    cmp al,'l'
    jne write_fail
    mov al,[buf+4]
    cmp al,'o'
    jne write_fail

    ; --- open output file ---
    mov eax,5          ; sys_open
    mov ebx,out_file
    mov ecx,0x201      ; O_WRONLY | O_CREAT | O_TRUNC
    mov edx,0o666      ; permissions 0666
    int 0x80
    cmp eax,0
    jl write_fail
    mov [outfd],eax

    ; --- write output ---
    mov eax,4          ; sys_write
    mov ebx,[outfd]
    mov ecx,msg_output
    mov edx,msg_output_len
    int 0x80

    ; --- close output ---
    mov eax,6          ; sys_close
    mov ebx,[outfd]
    int 0x80

    ; --- exit successfully ---
    mov eax,1          ; sys_exit
    xor ebx,ebx
    int 0x80

; --- error handling ---
open_fail:
    mov eax,4
    mov ebx,1
    mov ecx,msg_open
    mov edx,28
    int 0x80
    jmp exit

write_fail:
    mov eax,4
    mov ebx,1
    mov ecx,msg_write
    mov edx,21
    int 0x80
    jmp exit

exit:
    mov eax,1
    xor ebx,ebx
    int 0x80