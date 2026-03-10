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
    print_code    db "    call print_rax", 10, 0
    mov_rax_imm   db "    mov rax, ", 0
    mov_rax_var   db "    mov rax, [vars + ", 0
    mov_var_rax   db "    mov [vars + ", 0
    close_bracket_load  db "]", 10, 0
    close_bracket_store db "], rax", 10, 0
    vars_section  db 10, "section .bss", 10, "    vars resq 26", 10, 0
    newline       db 10, 0
    print_routine:
        db 10, "print_rax:", 10
        db "    push rbp", 10           ; Save base pointer
        db "    mov rbp, rsp", 10
        db "    sub rsp, 32", 10        ; Space for string buffer
        db "    mov rdi, 10", 10
        db "    lea rsi, [rbp-1]", 10
        db "    mov byte [rsi], 10", 10 ; Add newline
        db ".loop:", 10
        db "    xor rdx, rdx", 10
        db "    div rdi", 10
        db "    add dl, '0'", 10
        db "    dec rsi", 10
        db "    mov [rsi], dl", 10
        db "    test rax, rax", 10
        db "    jnz .loop", 10
        db "    mov rax, 1", 10         ; sys_write
        db "    mov rdi, 1", 10         ; stdout
        db "    mov rdx, rbp", 10
        db "    sub rdx, rsi", 10       ; length
        db "    syscall", 10
        db "    leave", 10              ; restore stack
        db "    ret", 10, 0
    
    ; Keywords for Lexer
    kw_let        db "LET", 0
    kw_var        db "VAR", 0
    kw_if         db "IF", 0
    kw_print      db "PRINT", 0
    kw_end        db "END", 0
    kw_add        db "ADD", 0
    kw_sub        db "SUB", 0

    label_count   dq 0    
    nested_ptr    dq 0
    out_fd        dq 0

    add_rax_imm   db "    add rax, ", 0
    add_rax_var   db "    add rax, [vars + ", 0
    sub_rax_imm     db "    sub rax, ", 0
    sub_rax_var     db "    sub rax, [vars + ", 0

section .bss
    input_buf     resb 4096 
    num_str       resb 20
    label_stack   resq 100
    token_buf     resb 64
    token_type    resb 1    ; 1 = Alpha, 2 = Number

section .text
    global _start

_start:
    ; 1. Open input file
    mov rax, 2          
    mov rdi, input_file
    mov rsi, 0          
    syscall
    push rax            

    ; 2. Create output file
    mov rax, 85         
    mov rdi, output_file
    mov rsi, 0o644      
    syscall
    mov [out_fd], rax   

    ; 3. Read input
    pop rdi             
    mov rax, 0          
    mov rsi, input_buf
    mov rdx, 4095
    syscall
    mov byte [input_buf + rax], 0 

    ; 4. Start Compiling
    mov rsi, asm_head
    call write_to_file

    mov rbx, input_buf

.main_loop:
    call next_token
    test al, al         ; EOF?
    jz .finish_up

    ; --- Dispatcher ---
    mov rsi, kw_let
    call compare_token
    je .do_let

    mov rsi, kw_var
    call compare_token
    je .do_var

    mov rsi, kw_if
    call compare_token
    je .do_if

    mov rsi, kw_print
    call compare_token
    je .do_print

    mov rsi, kw_end
    call compare_token
    je .do_end

    mov rsi, kw_add     
    call compare_token
    je .do_add

    mov rsi, kw_sub     
    call compare_token
    je .do_sub

    jmp .main_loop

.do_let:
    call next_token     ; Get variable name
    movzx rdi, byte [token_buf]
    sub rdi, 'a'
    imul rdi, 8
    push rdi            ; Save var offset

    call next_token     ; Get value
    call string_to_int  ; Result in RAX
    push rax

    mov rsi, mov_rax_imm
    call write_to_file
    pop rax
    call write_int_to_file
    mov rsi, newline
    call write_to_file

    mov rsi, mov_var_rax
    call write_to_file
    pop rax             ; Get var offset
    call write_int_to_file
    mov rsi, close_bracket_store
    call write_to_file
    jmp .main_loop

.do_var:
    call next_token
    movzx rdi, byte [token_buf]
    sub rdi, 'a'
    imul rdi, 8
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file
    jmp .main_loop

.do_if:
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
    jmp .main_loop

.do_print:
    call next_token     ; Look for the thing after 'PRINT'
    
    ; Case A: It's a Variable (Type 1)
    cmp byte [token_type], 1
    jne .check_num
    movzx rdi, byte [token_buf]
    sub rdi, 'a'
    imul rdi, 8
    
    ; Generate: mov rax, [vars + offset]
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file
    jmp .do_call_print

.check_num:
    ; Case B: It's a Literal Number (Type 2)
    cmp byte [token_type], 2
    jne .do_call_print ; If nothing found, just print current RAX
    call string_to_int
    
    ; Generate: mov rax, constant
    mov rsi, mov_rax_imm
    call write_to_file
    call write_int_to_file
    mov rsi, newline
    call write_to_file

.do_call_print:
    mov rsi, print_code ; This writes "call print_rax"
    call write_to_file
    jmp .main_loop

.do_end:
    dec qword [nested_ptr]
    mov rdx, [nested_ptr]
    mov rax, [label_stack + rdx*8]
    mov rsi, if_end
    call write_to_file
    call write_int_to_file
    mov rsi, colon_nl
    call write_to_file
    jmp .main_loop

.do_sub:
    call next_token      ; Get the destination variable (e.g., 'a')
    movzx rdi, byte [token_buf]
    sub rdi, 'a'
    imul rdi, 8
    push rdi             ; Save destination offset

    ; Step 1: Load destination into RAX
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, [rsp]       ; Get offset from stack
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file

    ; Step 2: Get the source (the value to subtract)
    call next_token
    cmp byte [token_type], 2 ; Is it a literal number?
    je .sub_literal

.sub_variable:
    movzx rsi, byte [token_buf]
    sub rsi, 'a'
    imul rsi, 8
    mov rdx, rsi         ; Save source offset
    mov rsi, sub_rax_var
    call write_to_file
    mov rax, rdx
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file
    jmp .save_sub_result

.sub_literal:
    call string_to_int
    mov rdx, rax         ; Save the number
    mov rsi, sub_rax_imm
    call write_to_file
    mov rax, rdx
    call write_int_to_file
    mov rsi, newline
    call write_to_file

.save_sub_result:
    ; Step 3: Store RAX back into destination
    mov rsi, mov_var_rax
    call write_to_file
    pop rax              ; Get destination offset back
    call write_int_to_file
    mov rsi, close_bracket_store
    call write_to_file
    jmp .main_loop

.do_add:
    call next_token     ; Get the destination variable (e.g., 'a')
    movzx rdi, byte [token_buf]
    sub rdi, 'a'
    imul rdi, 8
    push rdi            ; Save destination offset

    ; Step 1: Load destination into RAX
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, [rsp]      ; Get offset back from stack top
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file

    ; Step 2: Get the source (the value to add)
    call next_token
    cmp byte [token_type], 2 ; Is it a number?
    je .add_literal

.add_variable:
    movzx rsi, byte [token_buf]
    sub rsi, 'a'
    imul rsi, 8
    mov rdx, rsi        ; Save source offset
    mov rsi, add_rax_var
    call write_to_file
    mov rax, rdx
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file
    jmp .save_result

.add_literal:
    call string_to_int
    mov rdx, rax        ; Save the number
    mov rsi, add_rax_imm
    call write_to_file
    mov rax, rdx
    call write_int_to_file
    mov rsi, newline
    call write_to_file

.save_result:
    ; Step 3: Store RAX back into destination
    mov rsi, mov_var_rax
    call write_to_file
    pop rax             ; Get destination offset
    call write_int_to_file
    mov rsi, close_bracket_store
    call write_to_file
    jmp .main_loop

.finish_up:
    mov rsi, asm_exit
    call write_to_file
    
    mov rsi, print_routine
    call write_to_file

    mov rsi, vars_section
    call write_to_file

    ; Close output file
    mov rax, 3
    mov rdi, [out_fd]
    syscall

    mov rax, 60
    xor rdi, rdi
    syscall

; --- LEXER FUNCTIONS ---

next_token:
    ; Skip whitespace
.skip:
    mov al, [rbx]
    test al, al
    jz .eof
    cmp al, ' '
    jbe .inc_skip
    jmp .read
.inc_skip:
    inc rbx
    jmp .skip

.read:
    mov rdi, token_buf
    xor rcx, rcx
    
    ; Determine type by first char
    mov al, [rbx]
    mov byte [token_type], 1 ; Alpha
    cmp al, '0'
    jl .loop
    cmp al, '9'
    jg .loop
    mov byte [token_type], 2 ; Number

.loop:
    mov al, [rbx]
    cmp al, ' '
    jbe .done
    test al, al
    jz .done
    mov [rdi], al
    inc rdi
    inc rbx
    jmp .loop
.done:
    mov byte [rdi], 0
    mov al, [token_type]
    ret
.eof:
    xor al, al
    ret

compare_token:
    ; Compares token_buf to RSI
    mov rcx, 0
.c_loop:
    mov al, [token_buf + rcx]
    mov dl, [rsi + rcx]
    cmp al, dl
    jne .diff
    test al, al
    jz .same
    inc rcx
    jmp .c_loop
.diff:
    clc ; Not equal
    ret
.same:
    cmp al, 0 ; Set Zero Flag
    ret

string_to_int:
    ; Converts token_buf to integer in RAX
    xor rax, rax
    mov rsi, token_buf
.s_loop:
    movzx rcx, byte [rsi]
    test rcx, rcx
    jz .s_done
    sub rcx, '0'
    imul rax, 10
    add rax, rcx
    inc rsi
    jmp .s_loop
.s_done:
    ret

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
    mov rax, 1
    mov rdi, [out_fd]
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