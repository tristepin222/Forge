section .data
    ; File paths
    input_file    db "program.imp", 0
    output_file   db "output/program.asm", 0
    
    ; Opcodes and Templates
    asm_head      db "section .text", 10, "global _start", 10, "_start:", 10, "    mov rax, 1", 10, 0
    asm_exit      db "    mov rax, 60", 10, "    xor rdi, rdi", 10, "    syscall", 10, 0
    if_cmp        db "    cmp rax, 0", 10, "    je .L", 0
    if_end        db ".L", 0
    colon_nl      db ":", 10, 0
    print_code    db "    mov rax, 0x0A41", 10, "    push rax", 10, "    mov rax, 1", 10, "    mov rdi, 1", 10, "    mov rsi, rsp", 10, "    mov rdx, 2", 10, "    syscall", 10, "    add rsp, 8", 10, "    mov rax, 1", 10, 0
    mov_rax_imm   db "    mov rax, ", 0
    mov_rax_var   db "    mov rax, [vars + ", 0
    mov_var_rax   db "    mov [vars + ", 0
    close_bracket_load  db "]", 10, 0
    close_bracket_store db "], rax", 10, 0
    vars_section  db 10, "section .bss", 10, "    vars resq 26", 10, 0
    newline       db 10, 0
    
    label_count   dq 0    
    nested_ptr    dq 0
    out_fd        dq 0      ; Store the output file descriptor here

section .bss
    input_buf     resb 4096 ; Increased buffer for file reading
    num_str       resb 20
    label_stack   resq 100

section .text
    global _start

_start:
    ; 1. Open input file (program.imp)
    mov rax, 2          ; sys_open
    mov rdi, input_file
    mov rsi, 0          ; O_RDONLY
    syscall
    push rax            ; Save input FD

    ; 2. Create/Open output file (output/program.asm)
    mov rax, 85         ; sys_creat
    mov rdi, output_file
    mov rsi, 0o644      ; Permissions: rw-r--r--
    syscall
    mov [out_fd], rax   ; Save output FD

    ; 3. Read from program.imp
    pop rdi             ; Get input FD
    mov rax, 0          ; sys_read
    mov rsi, input_buf
    mov rdx, 4095
    syscall
    mov byte [input_buf + rax], 0 ; Null terminate

    ; 4. Start Compiling
    mov rsi, asm_head
    call write_to_file

    mov rbx, input_buf
.loop:
    mov al, [rbx]
    test al, al
    jz .finish_up
    cmp al, 10
    je .next_char
    cmp al, ' '
    jbe .next_char

    cmp al, 'L'
    je .handle_let
    cmp al, 'V'
    je .handle_var
    cmp al, 'I'
    je .handle_if
    cmp al, 'P'
    je .handle_print
    cmp al, 'E'
    je .handle_end

.next_char:
    inc rbx
    jmp .loop

.handle_let:
    inc rbx
.skip_l_space:
    cmp byte [rbx], ' '
    jne .got_var
    inc rbx
    jmp .skip_l_space
.got_var:
    movzx rdi, byte [rbx]
    sub rdi, 'a'
    imul rdi, 8
    inc rbx
.skip_val_space:
    cmp byte [rbx], ' '
    jne .got_val
    inc rbx
    jmp .skip_val_space
.got_val:
    movzx rsi, byte [rbx]
    sub rsi, '0'
    push rdi 
    push rsi 
    mov rsi, mov_rax_imm
    call write_to_file
    pop rax  
    call write_int_to_file
    mov rsi, newline
    call write_to_file
    mov rsi, mov_var_rax
    call write_to_file
    pop rax  
    call write_int_to_file
    mov rsi, close_bracket_store
    call write_to_file
    inc rbx
    jmp .loop

.handle_var:
    inc rbx
.skip_v_space:
    cmp byte [rbx], ' '
    jne .got_v_name
    inc rbx
    jmp .skip_v_space
.got_v_name:
    movzx rdi, byte [rbx]
    sub rdi, 'a'
    imul rdi, 8
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file
    inc rbx
    jmp .loop

.handle_if:
    inc qword [label_count]
    mov rax, [label_count]
    mov rdx, [nested_ptr]
    mov [label_stack + rdx*8], rax
    inc qword [nested_ptr]
    mov rsi, if_cmp
    call write_to_file
    mov rax, [label_count]
    call write_int_to_file
    mov rsi, newline
    call write_to_file
    inc rbx
    jmp .loop

.handle_print:
    mov rsi, print_code
    call write_to_file
    inc rbx
    jmp .loop

.handle_end:
    dec qword [nested_ptr]
    mov rdx, [nested_ptr]
    mov rax, [label_stack + rdx*8]
    mov rsi, if_end
    call write_to_file
    call write_int_to_file
    mov rsi, colon_nl
    call write_to_file
    inc rbx
    jmp .loop

.finish_up:
    mov rsi, asm_exit
    call write_to_file
    mov rsi, vars_section
    call write_to_file

    ; Close output file
    mov rax, 3          ; sys_close
    mov rdi, [out_fd]
    syscall

    mov rax, 60         ; Exit compiler
    xor rdi, rdi
    syscall

; --- FILE UTILITIES ---

write_to_file:
    push rax
    push rdi
    push rdx
    push rsi
    push rcx
    mov rcx, rsi
    mov rdx, 0
.count_len:
    cmp byte [rcx + rdx], 0
    je .do_write
    inc rdx
    jmp .count_len
.do_write:
    mov rax, 1          ; sys_write
    mov rdi, [out_fd]   ; Targeting the file descriptor
    syscall
    pop rcx
    pop rsi
    pop rdx
    pop rdi
    pop rax
    ret

write_int_to_file:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    mov rdi, 10
    mov rcx, num_str
    add rcx, 19
    mov byte [rcx], 0
.conv:
    xor rdx, rdx
    div rdi
    add dl, '0'
    dec rcx
    mov [rcx], dl
    test rax, rax
    jnz .conv
    mov rsi, rcx
    call write_to_file
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret