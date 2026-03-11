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
    mov_rbx_imm   db "    mov rbx, ", 0
    cmp_rax_rbx   db "    cmp rax, rbx", 10, 0
    mov_rbx_var   db "    mov rbx, [vars + ", 0

    kw_mul         db "MUL", 0
    mul_rax_imm    db "    mov rbx, ", 0   ; We load the literal into rbx
    mul_op         db "    mul rbx", 10, 0 ; Multiply rax by rbx
    mul_rax_var    db "    mul qword [vars + ", 0

    kw_while      db "WHILE", 0
    jmp_label     db "    jmp .WSTART", 0
    wstart_prefix db ".WSTART", 0
    wend_prefix   db ".L", 0

    ; Comparison Operators
    op_eq         db "==", 0
    op_gt         db ">", 0
    op_lt         db "<", 0

    ; Jump Templates
    je_label      db "    jne .L", 0    ; Jump if NOT equal (to skip the IF block)
    jle_label     db "    jle .L", 0    ; Jump if Less or Equal (to skip if we wanted >)
    jge_label     db "    jge .L", 0    ; Jump if Greater or Equal (to skip if we wanted <)

    kw_poke       db "POKE", 0
    kw_peek       db "PEEK", 0
    
    ; Output ASM templates
    mov_r10_imm   db "    mov r10, ", 0
    mov_r11_imm   db "    mov r11, ", 0
    poke_template db "    mov [heap + r10*8], r11", 10, 0
    peek_template db "    mov rax, [heap + r10*8]", 10, 0
    heap_section  db 10, "section .bss", 10, "    heap resq 1000", 10, 0 ; 8KB heap
    mov_r10_var   db "    mov r10, [vars + ", 0
    mov_r11_var   db "    mov r11, [vars + ", 0

    kw_read        db "READ", 0
    
    ; We will use a small 1-byte buffer in the .bss for reading
    read_template  db 10, "    ; sys_read", 10
                   db "    mov rax, 0", 10        ; syscall number
                   db "    mov rdi, 0", 10        ; stdin (for now, we'll use 0)
                   db "    lea rsi, [read_char]", 10
                   db "    mov rdx, 1", 10        ; 1 byte
                   db "    syscall", 10, 0

    read_char_bss  db 10, "section .bss", 10, "    read_char resb 1", 10, 0
    
    ; Load the read character into RAX
    load_read_rax  db "    movzx rax, byte [read_char]", 10, 0

section .bss
    input_buf     resb 4096 
    num_str       resb 20
    label_stack   resq 100
    token_buf     resb 64
    token_type    resb 1    ; 1 = Alpha, 2 = Number
    type_stack    resb 100   ; 0 = IF, 1 = WHILE

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

    mov rsi, kw_while
    call compare_token
    je .do_while

    mov rsi, kw_mul
    call compare_token
    je .do_mul

    mov rsi, kw_poke
    call compare_token
    je .do_poke

    mov rsi, kw_peek
    call compare_token
    je .do_peek


    mov rsi, kw_sub     
    call compare_token
    je .do_sub

    mov rsi, kw_read     
    call compare_token
    je .do_read


    jmp .main_loop

.do_read:
    call next_token      ; Get the variable to store the char in (e.g., 'a')
    call get_var_offset
    mov rdi, rax
    push rdi             ; Save variable offset

    ; 1. Generate the read syscall
    mov rsi, read_template
    call write_to_file

    ; 2. Move result into RAX
    mov rsi, load_read_rax
    call write_to_file

    ; 3. Store RAX into the variable
    mov rsi, mov_var_rax
    call write_to_file
    pop rax              ; Get variable offset
    call write_int_to_file
    mov rsi, close_bracket_store
    call write_to_file

    jmp .main_loop

.do_poke:
    ; --- 1. Get Index (Target register R10) ---
    call next_token
    cmp byte [token_type], 1 ; Variable?
    je .idx_var
.idx_num:
    mov rsi, mov_r10_imm
    call write_to_file
    call string_to_int
    call write_int_to_file
    mov rsi, newline
    call write_to_file
    jmp .get_val
.idx_var:
    mov rsi, mov_r10_var
    call write_to_file
    call get_var_offset
    mov rdi, rax
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file

.get_val:
    ; --- 2. Get Value (Target register R11) ---
    call next_token
    cmp byte [token_type], 1 ; Variable?
    je .val_var
.val_num:
    mov rsi, mov_r11_imm
    call write_to_file
    call string_to_int
    call write_int_to_file
    mov rsi, newline
    call write_to_file
    jmp .do_poke_exec
.val_var:
    mov rsi, mov_r11_var
    call write_to_file
    call get_var_offset
    mov rdi, rax
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file

.do_poke_exec:
    mov rsi, poke_template ; "mov [heap + r10*8], r11"
    call write_to_file
    jmp .main_loop

.do_peek:
    ; --- 1. Get Destination Variable ---
    call next_token
    call get_var_offset
    mov rdi, rax
    push rdi             ; Save destination var offset

    ; --- 2. Get Index (Load into R10) ---
    call next_token
    cmp byte [token_type], 1
    je .peek_idx_var
.peek_idx_num:
    mov rsi, mov_r10_imm
    call write_to_file
    call string_to_int
    call write_int_to_file
    mov rsi, newline
    call write_to_file
    jmp .peek_exec
.peek_idx_var:
    mov rsi, mov_r10_var
    call write_to_file
    call get_var_offset
    mov rdi, rax
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file

.peek_exec:
    ; Load from heap into RAX
    mov rsi, peek_template ; "mov rax, [heap + r10*8]"
    call write_to_file
    
    ; Store RAX into destination variable
    mov rsi, mov_var_rax
    call write_to_file
    pop rax                ; Get var offset
    call write_int_to_file
    mov rsi, close_bracket_store
    call write_to_file
    jmp .main_loop

.do_mul:
    call next_token      ; Get destination var (e.g., 'a')
    call get_var_offset
    mov rdi, rax
    push rdi             ; Save destination offset

    ; 1. Load destination into RAX
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, [rsp]
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file

    ; 2. Get source
    call next_token
    cmp byte [token_type], 2
    je .mul_literal

.mul_var:
    call get_var_offset
    mov rdi, rax
    mov rdx, rdi
    mov rsi, mul_rax_var ; "mul qword [vars + "
    call write_to_file
    mov rax, rdx
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file
    jmp .save_mul

.mul_literal:
    call string_to_int
    mov rdx, rax
    mov rsi, mul_rax_imm ; "mov rbx, "
    call write_to_file
    mov rax, rdx
    call write_int_to_file
    mov rsi, newline
    call write_to_file
    mov rsi, mul_op      ; "mul rbx"
    call write_to_file

.save_mul:
    mov rsi, mov_var_rax
    call write_to_file
    pop rax
    call write_int_to_file
    mov rsi, close_bracket_store
    call write_to_file
    jmp .main_loop

.do_let:
    call next_token     ; Get variable name
    call get_var_offset
    mov rdi, rax
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
    call get_var_offset
    mov rdi, rax
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file
    jmp .main_loop

.do_print:
    call next_token     ; Look for the thing after 'PRINT'
    
    ; Case A: It's a Variable (Type 1)
    cmp byte [token_type], 1
    jne .check_num
    call get_var_offset
    mov rdi, rax
    
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
    mov rdx, [nested_ptr]   ; get current stack pointer
    dec rdx                 ; point to top element
    mov rax, [label_stack + rdx*8]
    movzx rcx, byte [type_stack + rdx]

    cmp rcx, 1
    jne .is_if_end

.is_while_end:
    push rax
    mov rsi, jmp_label
    call write_to_file
    pop rax
    call write_int_to_file
    mov rsi, newline
    call write_to_file

    mov rsi, wend_prefix
    call write_to_file
    mov rax, [label_stack + rdx*8]
    call write_int_to_file
    mov rsi, colon_nl
    call write_to_file

    dec qword [nested_ptr]
    jmp .main_loop

.is_if_end:
    mov rsi, if_end
    call write_to_file
    mov rax, [label_stack + rdx*8]
    call write_int_to_file
    mov rsi, colon_nl
    call write_to_file

    dec qword [nested_ptr]
    jmp .main_loop

.do_sub:
    call next_token      ; Get the destination variable (e.g., 'a')
    call get_var_offset
    mov rdi, rax
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
    shl rdi, 3
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

.do_while:
    inc qword [label_count]
    mov rax, [label_count]

    mov rdx, [nested_ptr]
    mov [label_stack + rdx*8], rax

    mov byte [type_stack + rdx], 1 ; mark as WHILE
    inc qword [nested_ptr]         ; push new nesting level
    ; --- 1. Place the Start Label ---
    mov rsi, wstart_prefix
    call write_to_file
    mov rax, [label_count]
    call write_int_to_file
    mov rsi, colon_nl
    call write_to_file

    ; --- 2. Parse LHS ---
    call next_token
    call get_var_offset
    mov rdi, rax
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file

    ; --- 3. Parse Operator ---
    call next_token
    mov rsi, op_eq
    call compare_token
    je .set_jne
    mov rsi, op_gt
    call compare_token
    je .set_jle ; Use your existing IF setter
    mov rsi, op_lt
    call compare_token
    je .set_jge ; Use your existing IF setter
    
    ; ONLY jump to main loop if NO operator was found (Error)
    jmp .main_loop


.do_if:
    inc qword [label_count]       ; unique label number
    mov rax, [label_count]

    mov rdx, [nested_ptr]
    mov [label_stack + rdx*8], rax

    mov byte [type_stack + rdx], 0 ; mark as IF
    inc qword [nested_ptr]          ; push new nesting level

    ; --- 1. Parse LHS ---
    call next_token
    call get_var_offset
    mov rdi, rax
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file

    ; --- 2. Parse Operator ---
    call next_token
    mov rsi, op_eq
    call compare_token
    je .set_jne
    mov rsi, op_gt
    call compare_token
    je .set_jle
    mov rsi, op_lt
    call compare_token
    je .set_jge
    jmp .main_loop  ; unknown operator, skip

.set_jne:
    mov r12, je_label
    jmp .parse_rhs
.set_jle:
    mov r12, jle_label
    jmp .parse_rhs
.set_jge:
    mov r12, jge_label

.parse_rhs:

    call next_token
    cmp byte [token_type], 1
    je .rhs_var_if
.rhs_num_if:
    call string_to_int
    mov rdx, rax
    mov rsi, mov_rbx_imm 
    call write_to_file
    mov rax, rdx
    call write_int_to_file
    mov rsi, newline
    call write_to_file
    jmp .generate_cmp_if
.rhs_var_if:
    call get_var_offset
    mov rdi, rax
    mov rsi, mov_rbx_var
    call write_to_file
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file

.generate_cmp_if:
    mov rsi, cmp_rax_rbx
    call write_to_file

    mov rsi, r12 ; The jump (jne L / jle L / jge L)
    call write_to_file
    
    ; Get the label number for the current nesting level
    mov rdx, [nested_ptr]
    dec rdx
    mov rax, [label_stack + rdx*8]
    call write_int_to_file
    
    mov rsi, newline
    call write_to_file
    jmp .main_loop

.do_add:
    call next_token
    call get_var_offset
    mov rdi, rax
    push rdi
    call load_var

    call next_token
    cmp byte [token_type], 2
    je .add_literal

.add_variable:
    ; get source variable offset
    call get_var_offset
    mov rdx, rax                ; rdx = source offset

    mov rsi, add_rax_var        ; "    add rax, [vars + "
    call write_to_file

    mov rax, rdx
    call write_int_to_file

    mov rsi, close_bracket_load ; "]\n"
    call write_to_file
    jmp .save_result


.add_literal:
    call string_to_int          ; rax = literal

    mov rdx, rax                ; save literal

    mov rsi, add_rax_imm        ; "    add rax, "
    call write_to_file

    mov rax, rdx
    call write_int_to_file

    mov rsi, newline
    call write_to_file


.save_result:
    ; store RAX back into destination variable
    mov rsi, mov_var_rax
    call write_to_file

    pop rax                     ; destination offset
    call write_int_to_file

    mov rsi, close_bracket_store
    call write_to_file

    jmp .main_loop
    
.finish_up:
    ; 1. Write the Exit syscall
    mov rsi, asm_exit
    call write_to_file
    
    ; 2. Write the Print Routine (so the program can use PRINT)
    mov rsi, print_routine
    call write_to_file

    ; 3. Write the BSS section for variables
    mov rsi, vars_section
    call write_to_file

    ; 4. Write the BSS section for the heap (Arrays)
    mov rsi, heap_section
    call write_to_file

    mov rsi, read_char_bss       ; For READ
    call write_to_file

    ; 5. Close output file and exit compiler
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

get_var_offset:
    movzx rax, byte [token_buf]
    sub rax, 'a'
    shl rax, 3
    ret

; Load variable into RAX
load_var:
    mov rsi, mov_rax_var
    call write_to_file
    mov rax, rdi
    call write_int_to_file
    mov rsi, close_bracket_load
    call write_to_file
    ret

; Store RAX back into variable
store_var:
    mov rsi, mov_var_rax
    call write_to_file
    mov rdi, rdi   ; Offset in RDI
    call write_int_to_file
    mov rsi, close_bracket_store
    call write_to_file
    ret

; --- FILE UTILITIES ---

write_to_file:
    push rdi
    push rcx
    push rdx

    mov rdi, rsi
    mov rcx, -1
    xor al, al
    repne scasb
    not rcx
    dec rcx
    mov rdx, rcx

    mov rax, 1
    mov rdi, [out_fd]
    syscall

    pop rdx
    pop rcx
    pop rdi
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