; bootcompiler.asm
; Stage-1 bootstrap compiler
; Supports: println("text")

; build:
; nasm -f elf32 bootcompiler.asm -o bootcompiler.o
; ld -m elf_i386 bootcompiler.o -o bootcompiler

section .data

in_file     db "program.imp",0
out_file    db "output/program.asm",0

msg_open    db "Open failed",10
msg_open_len equ $-msg_open

msg_write   db "Write failed",10
msg_write_len equ $-msg_write

data_prefix db "section .data",10
            db 'msg: db "'
data_prefix_len equ $-data_prefix

data_suffix db '"',',10',10
            db "len: equ $ - msg",10
            db "section .text",10
            db "global _start",10
            db "_start:",10
            db "    mov eax,4",10
            db "    mov ebx,1",10
            db "    mov ecx,msg",10
            db "    mov edx,len",10
            db "    int 0x80",10
            db "    mov eax,1",10
            db "    xor ebx,ebx",10
            db "    int 0x80",10
data_suffix_len equ $-data_suffix

section .bss

infd        resd 1
outfd       resd 1
buf         resb 512
strlen      resd 1
strptr      resd 1

section .text
global _start

_start:

; open source
mov eax,5
mov ebx,in_file
mov ecx,0
int 0x80
cmp eax,0
jl open_fail
mov [infd],eax

; read source
mov eax,3
mov ebx,[infd]
mov ecx,buf
mov edx,512
int 0x80
cmp eax,0
jle open_fail

; close source
mov eax,6
mov ebx,[infd]
int 0x80

; find first quote
mov esi,buf

find_quote:
mov al,[esi]
cmp al,'"'
je quote_found
inc esi
jmp find_quote

quote_found:
inc esi
mov [strptr],esi

; measure string length
xor ecx,ecx

len_loop:
mov al,[esi]
cmp al,'"'
je len_done
inc esi
inc ecx
jmp len_loop

len_done:
mov [strlen],ecx

; open output file
mov eax,5
mov ebx,out_file
mov ecx,0x241
mov edx,0o666
int 0x80
cmp eax,0
jl write_fail
mov [outfd],eax

; write prefix
mov eax,4
mov ebx,[outfd]
mov ecx,data_prefix
mov edx,data_prefix_len
int 0x80

; write extracted string
mov eax,4
mov ebx,[outfd]
mov ecx,[strptr]
mov edx,[strlen]
int 0x80

; write suffix
mov eax,4
mov ebx,[outfd]
mov ecx,data_suffix
mov edx,data_suffix_len
int 0x80

; close output
mov eax,6
mov ebx,[outfd]
int 0x80

; exit success
mov eax,1
xor ebx,ebx
int 0x80

open_fail:
mov eax,4
mov ebx,1
mov ecx,msg_open
mov edx,msg_open_len
int 0x80
jmp exit

write_fail:
mov eax,4
mov ebx,1
mov ecx,msg_write
mov edx,msg_write_len
int 0x80

exit:
mov eax,1
xor ebx,ebx
int 0x80