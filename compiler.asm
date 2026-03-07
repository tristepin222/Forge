; bootcompiler_stage2.asm - Stage-2 bootstrap compiler (x86-64)
section .data
    in_file      db "program.imp",0
    out_file     db "output/program.asm",0

    msg_prefix     db 'msg'
    msg_prefix_len equ $-msg_prefix
    msg_mid        db ': db "'
    msg_mid_len    equ $-msg_mid
    msg_end        db '",10',10
    msg_end_len    equ $-msg_end

    section_text   db 10,'section .text',10,'global _start',10,'_start:',10
    section_text_len equ $-section_text

    mov_rdx_prefix db '    mov rdx, '
    mov_rdx_prefix_len equ $-mov_rdx_prefix

    mov_rax_1     db '    mov rax, 1',10
    mov_rax_1_len equ $-mov_rax_1

    mov_rdi_1     db '    mov rdi, 1',10
    mov_rdi_1_len equ $-mov_rdi_1

    mov_rsi_msg   db '    mov rsi, msg'
    mov_rsi_msg_len equ $-mov_rsi_msg

    syscall_inst  db '    syscall',10
    syscall_inst_len equ $-syscall_inst

    asm_exit       db '    mov rax, 60',10,'    xor rdi, rdi',10,'    syscall',10
    asm_exit_len   equ $-asm_exit

    newline db 10



section .bss
    infd         resq 1
    outfd        resq 1
    buf          resb 4096
    strlen       resq 1
    msg_count    resq 1
    numbuf       resb 16
    msg_len      resq 128       ; store length of each message

section .text
global _start

_start:
    ; --- Open and read source ---
    mov rax, 2
    mov rdi, in_file
    xor rsi, rsi
    syscall
    mov [infd], rax

    mov rax, 0
    mov rdi, [infd]
    mov rsi, buf
    mov rdx, 4096
    syscall
    mov [strlen], rax

    ; --- Open output ---
    mov rax, 2
    mov rdi, out_file
    mov rsi, 0101o | 01000o
    mov rdx, 0644o
    syscall
    mov [outfd], rax

    ; --- Scan source for strings ---
    xor rsi, rsi
    xor rbx, rbx

scan_loop:
    cmp rsi, [strlen]
    jge done_scan
    mov al, [buf+rsi]
    cmp al, '"'
    jne .next_byte

    ; found opening quote
    inc rsi
    mov r12, rsi
    xor r13, r13

.measure:
    cmp rsi, [strlen]
    jge .string_end
    mov al, [buf+rsi]
    cmp al, '"'
    je .string_end
    inc r13
    inc rsi
    jmp .measure

.string_end:
    cmp r13, 0
    je .skip_message

.write_data:
    push rsi
    ; write msgN: db "..."
    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel msg_prefix]
    mov rdx, msg_prefix_len
    syscall

    mov rax, rbx
    call write_number_ascii_to_file

    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel msg_mid]
    mov rdx, msg_mid_len
    syscall

    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [buf+r12]
    mov rdx, r13
    syscall

    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel msg_end]
    mov rdx, msg_end_len
    syscall

    mov [msg_len + rbx*8], r13
    inc rbx
    pop rsi

.skip_message:
.next_byte:
    cmp rsi, [strlen]
    jge done_scan
    inc rsi
    jmp scan_loop

done_scan:
    mov [msg_count], rbx

    ; --- Write text section ---
    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel section_text]
    mov rdx, section_text_len
    syscall

    xor r15, r15
gen_code_loop:
    cmp r15, [msg_count]
    jae finish_file

    ; print mov rax, 1
    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel mov_rax_1]
    mov rdx, mov_rax_1_len
    syscall

    ; print mov rdi, 1
    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel mov_rdi_1]
    mov rdx, mov_rdi_1_len
    syscall

    ; print mov rsi, msgN
    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel mov_rsi_msg]
    mov rdx, mov_rsi_msg_len
    syscall

    mov rax, r15
    call write_number_ascii_to_file

    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel newline]
    mov rdx, 1
    syscall

    ; mov rdx, <length>
    mov r13, [msg_len + r15*8]
    inc r13
    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel mov_rdx_prefix]
    mov rdx, mov_rdx_prefix_len
    syscall

    mov rax, r13
    call write_number_ascii_to_file

    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel newline]
    mov rdx, 1
    syscall

    ; syscall
    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel syscall_inst]
    mov rdx, syscall_inst_len
    syscall

    inc r15
    jmp gen_code_loop

finish_file:
    mov rax, 1
    mov rdi, [outfd]
    lea rsi, [rel asm_exit]
    mov rdx, asm_exit_len
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall

; --- Helper: write number to output file as ASCII ---
write_number_ascii_to_file:
    push rbx
    push rcx
    push rdx
    push rsi

    mov rbx, 10
    lea rsi, [numbuf+15]
    mov rcx, 0

    test rax, rax
    jnz .convert
    mov byte [rsi], '0'
    mov rcx, 1
    jmp .done_convert

.convert:
    xor rdx, rdx
    div rbx
    add dl, '0'
    mov [rsi], dl
    inc rcx
    test rax, rax
    jz .done_convert
    dec rsi
    jmp .convert

.done_convert:
    lea rsi, [numbuf+16]
    sub rsi, rcx
    mov rdx, rcx
    mov rax, 1
    mov rdi, [outfd]
    syscall

    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret