BITS 64
default rel

%define SYS_READ   0
%define SYS_WRITE  1
%define SYS_OPEN   2
%define SYS_CLOSE  3
%define SYS_CREAT  85
%define SYS_EXIT   60

%define O_RDONLY   0

%define TOK_EOF    0
%define TOK_IDENT  1
%define TOK_NUMBER 2
%define TOK_STRING 3
%define TOK_OP     4

%define BLOCK_IF    1
%define BLOCK_WHILE 2

%define COND_EQ 1
%define COND_NE 2
%define COND_LT 3
%define COND_LE 4
%define COND_GT 5
%define COND_GE 6

%define MAX_INPUT    262144
%define MAX_OUTPUT   1048576
%define MAX_TOKEN    128
%define MAX_VARS     128
%define MAX_NAME     32
%define MAX_BLOCKS   128

section .data
    input_file      db "program.imp", 0
    output_file     db "output/program.asm", 0

    kw_print        db "PRINT", 0
    kw_write_int    db "WRITE_INT", 0
    kw_write_char   db "WRITE_CHAR", 0
    kw_write_str    db "WRITE_STR", 0
    kw_var          db "VAR", 0
    kw_let          db "LET", 0
    kw_add          db "ADD", 0
    kw_sub          db "SUB", 0
    kw_mul          db "MUL", 0
    kw_if           db "IF", 0
    kw_while        db "WHILE", 0
    kw_end          db "END", 0
    kw_poke         db "POKE", 0
    kw_peek         db "PEEK", 0
    kw_read         db "READ", 0
    kw_alloc        db "ALLOC", 0
    kw_exit         db "EXIT", 0

    op_eq           db "==", 0
    op_ne           db "!=", 0
    op_lt           db "<", 0
    op_le           db "<=", 0
    op_gt           db ">", 0
    op_ge           db ">=", 0

    asm_header:
        db "BITS 64", 10
        db "section .text", 10
        db "global _start", 10, 10
        db "_start:", 10
        db "    mov qword [alloc_ptr], heap", 10, 0

    asm_footer:
        db "    mov rax, 60", 10
        db "    xor rdi, rdi", 10
        db "    syscall", 10, 10
        db "print_rax:", 10
        db "    push rbx", 10
        db "    push rcx", 10
        db "    push rdx", 10
        db "    push rsi", 10
        db "    push rdi", 10
        db "    mov rdi, int_buf + 31", 10
        db "    mov byte [rdi], 10", 10
        db "    mov rcx, 10", 10
        db "    cmp rax, 0", 10
        db "    jne .print_nonzero", 10
        db "    dec rdi", 10
        db "    mov byte [rdi], '0'", 10
        db "    jmp .print_emit", 10
        db ".print_nonzero:", 10
        db "    xor rsi, rsi", 10
        db "    test rax, rax", 10
        db "    jns .print_loop", 10
        db "    neg rax", 10
        db "    mov rsi, 1", 10
        db ".print_loop:", 10
        db "    xor rdx, rdx", 10
        db "    div rcx", 10
        db "    add dl, '0'", 10
        db "    dec rdi", 10
        db "    mov [rdi], dl", 10
        db "    test rax, rax", 10
        db "    jnz .print_loop", 10
        db "    test rsi, rsi", 10
        db "    jz .print_emit", 10
        db "    dec rdi", 10
        db "    mov byte [rdi], '-'", 10
        db ".print_emit:", 10
        db "    mov rax, 1", 10
        db "    mov rsi, rdi", 10
        db "    mov rdi, 1", 10
        db "    mov rdx, int_buf + 32", 10
        db "    sub rdx, rsi", 10
        db "    syscall", 10
        db "    pop rdi", 10
        db "    pop rsi", 10
        db "    pop rdx", 10
        db "    pop rcx", 10
        db "    pop rbx", 10
        db "    ret", 10, 10
        db "print_int_raw:", 10
        db "    push rbx", 10
        db "    push rcx", 10
        db "    push rdx", 10
        db "    push rsi", 10
        db "    push rdi", 10
        db "    mov rdi, int_buf + 31", 10
        db "    mov rcx, 10", 10
        db "    cmp rax, 0", 10
        db "    jne .raw_nonzero", 10
        db "    dec rdi", 10
        db "    mov byte [rdi], '0'", 10
        db "    jmp .raw_emit", 10
        db ".raw_nonzero:", 10
        db "    xor rsi, rsi", 10
        db "    test rax, rax", 10
        db "    jns .raw_loop", 10
        db "    neg rax", 10
        db "    mov rsi, 1", 10
        db ".raw_loop:", 10
        db "    xor rdx, rdx", 10
        db "    div rcx", 10
        db "    add dl, '0'", 10
        db "    dec rdi", 10
        db "    mov [rdi], dl", 10
        db "    test rax, rax", 10
        db "    jnz .raw_loop", 10
        db "    test rsi, rsi", 10
        db "    jz .raw_emit", 10
        db "    dec rdi", 10
        db "    mov byte [rdi], '-'", 10
        db ".raw_emit:", 10
        db "    mov rax, 1", 10
        db "    mov rsi, rdi", 10
        db "    mov rdi, 1", 10
        db "    mov rdx, int_buf + 31", 10
        db "    sub rdx, rsi", 10
        db "    syscall", 10
        db "    pop rdi", 10
        db "    pop rsi", 10
        db "    pop rdx", 10
        db "    pop rcx", 10
        db "    pop rbx", 10
        db "    ret", 10, 10
        db "write_char:", 10
        db "    mov [read_char], al", 10
        db "    push rax", 10
        db "    push rdi", 10
        db "    push rsi", 10
        db "    push rdx", 10
        db "    mov rax, 1", 10
        db "    mov rdi, 1", 10
        db "    mov rsi, read_char", 10
        db "    mov rdx, 1", 10
        db "    syscall", 10
        db "    pop rdx", 10
        db "    pop rsi", 10
        db "    pop rdi", 10
        db "    pop rax", 10
        db "    ret", 10, 10
        db "section .bss", 10
        db "vars      resq 128", 10
        db "heap      resb 65536", 10
        db "alloc_ptr resq 1", 10
        db "read_char resb 1", 10
        db "int_buf   resb 32", 10, 0

    str_mov_rax_imm      db "    mov rax, ", 0
    str_mov_rbx_imm      db "    mov rbx, ", 0
    str_mov_rcx_imm      db "    mov rcx, ", 0
    str_mov_al_imm       db "    mov al, ", 0
    str_mov_rax_var      db "    mov rax, [vars + ", 0
    str_mov_rbx_var      db "    mov rbx, [vars + ", 0
    str_mov_rcx_var      db "    mov rcx, [vars + ", 0
    str_mov_var_rax      db "    mov [vars + ", 0
    str_close_load       db "]", 10, 0
    str_close_store_rax  db "], rax", 10, 0
    str_close_store_rbx  db "], rbx", 10, 0
    str_add_rax_imm      db "    add rax, ", 0
    str_add_rax_var      db "    add rax, [vars + ", 0
    str_sub_rax_imm      db "    sub rax, ", 0
    str_sub_rax_var      db "    sub rax, [vars + ", 0
    str_imul_rax_rbx     db "    imul rax, rbx", 10, 0
    str_mov_rbx_ptr      db "    mov rbx, [alloc_ptr]", 10, 0
    str_add_alloc_rbx    db "    add qword [alloc_ptr], rbx", 10, 0
    str_shl_rbx_3        db "    shl rbx, 3", 10, 0
    str_mov_ptr_rbx_rcx  db "    mov [rbx], rcx", 10, 0
    str_mov_rax_ptr_rbx  db "    mov rax, [rbx]", 10, 0
    str_movzx_rax_read   db "    movzx rax, byte [read_char]", 10, 0
    str_read_syscall:
        db "    mov rax, 0", 10
        db "    mov rdi, 0", 10
        db "    mov rsi, read_char", 10
        db "    mov rdx, 1", 10
        db "    syscall", 10, 0
    str_call_print       db "    call print_rax", 10, 0
    str_call_print_raw   db "    call print_int_raw", 10, 0
    str_call_write_char  db "    call write_char", 10, 0
    str_cmp_rax_rbx      db "    cmp rax, rbx", 10, 0
    str_jmp_label        db "    jmp ", 0
    str_if_prefix        db ".IF_END_", 0
    str_while_start      db ".WHILE_START_", 0
    str_while_end        db ".WHILE_END_", 0
    str_colon_nl         db ":", 10, 0
    str_jne              db "    jne ", 0
    str_je               db "    je ", 0
    str_jge              db "    jge ", 0
    str_jg               db "    jg ", 0
    str_jle              db "    jle ", 0
    str_jl               db "    jl ", 0
    str_exit_stmt:
        db "    mov rax, 60", 10
        db "    xor rdi, rdi", 10
        db "    syscall", 10, 0

    err_parse        db "parse error", 10, 0
    err_var          db "undefined variable", 10, 0
    err_redeclare    db "duplicate variable", 10, 0
    err_block        db "unbalanced END/blocks", 10, 0
    err_outbuf       db "output buffer overflow", 10, 0
    err_vars         db "variable table full", 10, 0
    msg_parse_line   db "line: ", 0
    msg_parse_type   db " token_type: ", 0
    msg_parse_token  db " token: ", 0
    msg_newline      db 10, 0

section .bss
    source_buf       resb MAX_INPUT + 1
    output_buf       resb MAX_OUTPUT
    token_buf        resb MAX_TOKEN
    int_tmp          resb 32

    source_ptr       resq 1
    output_ptr       resq 1
    output_fd        resq 1
    token_type       resd 1
    label_count      resd 1

    tmp_offset       resq 1
    tmp_label2       resd 1
    tmp_cond         resd 1

    var_count        resd 1
    var_names        resb MAX_VARS * MAX_NAME
    var_offsets      resq MAX_VARS

    block_sp         resd 1
    block_type       resd MAX_BLOCKS
    block_start_id   resd MAX_BLOCKS
    block_end_id     resd MAX_BLOCKS

section .text
    global _start

_start:
    call read_input
    lea rax, [source_buf]
    mov [source_ptr], rax
    lea rax, [output_buf]
    mov [output_ptr], rax
    mov dword [var_count], 0
    mov dword [block_sp], 0
    mov dword [label_count], 0

    lea rsi, [asm_header]
    call emit_cstr

main_parse_loop:
    call next_token
    cmp eax, TOK_EOF
    je finish_compiler

    lea rsi, [kw_var]
    call token_equals
    test eax, eax
    jnz handle_var

    lea rsi, [kw_let]
    call token_equals
    test eax, eax
    jnz handle_let

    lea rsi, [kw_print]
    call token_equals
    test eax, eax
    jnz handle_print

    lea rsi, [kw_write_int]
    call token_equals
    test eax, eax
    jnz handle_write_int

    lea rsi, [kw_write_char]
    call token_equals
    test eax, eax
    jnz handle_write_char

    lea rsi, [kw_write_str]
    call token_equals
    test eax, eax
    jnz handle_write_str

    lea rsi, [kw_add]
    call token_equals
    test eax, eax
    jnz handle_add

    lea rsi, [kw_sub]
    call token_equals
    test eax, eax
    jnz handle_sub

    lea rsi, [kw_mul]
    call token_equals
    test eax, eax
    jnz handle_mul

    lea rsi, [kw_if]
    call token_equals
    test eax, eax
    jnz handle_if

    lea rsi, [kw_while]
    call token_equals
    test eax, eax
    jnz handle_while

    lea rsi, [kw_end]
    call token_equals
    test eax, eax
    jnz handle_end

    lea rsi, [kw_poke]
    call token_equals
    test eax, eax
    jnz handle_poke

    lea rsi, [kw_peek]
    call token_equals
    test eax, eax
    jnz handle_peek

    lea rsi, [kw_read]
    call token_equals
    test eax, eax
    jnz handle_read

    lea rsi, [kw_alloc]
    call token_equals
    test eax, eax
    jnz handle_alloc

    lea rsi, [kw_exit]
    call token_equals
    test eax, eax
    jnz handle_exit

    call fatal_parse

finish_compiler:
    cmp dword [block_sp], 0
    jne block_error

    lea rsi, [asm_footer]
    call emit_cstr

    call write_output
    xor rdi, rdi
    mov rax, SYS_EXIT
    syscall

block_error:
    call fatal_block

handle_var:
    call expect_ident
    call define_variable
    jmp main_parse_loop

handle_let:
    call expect_ident
    call require_variable
    mov [tmp_offset], rax
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    call emit_load_rax_current
    mov rax, [tmp_offset]
    call emit_store_rax_to_var
    jmp main_parse_loop

handle_print:
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    call emit_load_rax_current
    lea rsi, [str_call_print]
    call emit_cstr
    jmp main_parse_loop

handle_write_int:
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    call emit_load_rax_current
    lea rsi, [str_call_print_raw]
    call emit_cstr
    jmp main_parse_loop

handle_write_char:
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    cmp eax, TOK_NUMBER
    jne .wc_not_number
    lea rsi, [str_mov_al_imm]
    call emit_cstr
    call token_to_int
    call emit_int
    call emit_newline
    lea rsi, [str_call_write_char]
    call emit_cstr
    jmp main_parse_loop
.wc_not_number:
    call emit_load_rax_current
    lea rsi, [str_call_write_char]
    call emit_cstr
    jmp main_parse_loop

handle_write_str:
    call next_token
    cmp eax, TOK_STRING
    jne parse_error_global
    lea rsi, [token_buf]
.ws_loop:
    mov al, [rsi]
    test al, al
    jz .ws_done
    push rsi
    push rax
    lea rsi, [str_mov_al_imm]
    call emit_cstr
    pop rax
    movzx rax, al
    call emit_int
    call emit_newline
    lea rsi, [str_call_write_char]
    call emit_cstr
    pop rsi
    inc rsi
    jmp .ws_loop
.ws_done:
    jmp main_parse_loop

handle_add:
    call expect_ident
    call require_variable
    mov [tmp_offset], rax
    call emit_load_rax_from_offset
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    cmp eax, TOK_NUMBER
    je .add_number
    cmp eax, TOK_IDENT
    jne parse_error_global
    call require_variable
    lea rsi, [str_add_rax_var]
    call emit_cstr
    call emit_int
    lea rsi, [str_close_load]
    call emit_cstr
    jmp .add_store
.add_number:
    lea rsi, [str_add_rax_imm]
    call emit_cstr
    call token_to_int
    call emit_int
    call emit_newline
.add_store:
    mov rax, [tmp_offset]
    call emit_store_rax_to_var
    jmp main_parse_loop

handle_sub:
    call expect_ident
    call require_variable
    mov [tmp_offset], rax
    call emit_load_rax_from_offset
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    cmp eax, TOK_NUMBER
    je .sub_number
    cmp eax, TOK_IDENT
    jne parse_error_global
    call require_variable
    lea rsi, [str_sub_rax_var]
    call emit_cstr
    call emit_int
    lea rsi, [str_close_load]
    call emit_cstr
    jmp .sub_store
.sub_number:
    lea rsi, [str_sub_rax_imm]
    call emit_cstr
    call token_to_int
    call emit_int
    call emit_newline
.sub_store:
    mov rax, [tmp_offset]
    call emit_store_rax_to_var
    jmp main_parse_loop

handle_mul:
    call expect_ident
    call require_variable
    mov [tmp_offset], rax
    call emit_load_rax_from_offset
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    call emit_load_rbx_current
    lea rsi, [str_imul_rax_rbx]
    call emit_cstr
    mov rax, [tmp_offset]
    call emit_store_rax_to_var
    jmp main_parse_loop

handle_if:
    call next_label
    mov [tmp_offset], eax
    call parse_condition
    mov edx, [tmp_offset]
    call emit_inverse_jump_if
    mov eax, [tmp_offset]
    mov edx, BLOCK_IF
    call push_block
    jmp main_parse_loop

handle_while:
    call next_label
    mov [tmp_offset], eax
    lea rsi, [str_while_start]
    call emit_cstr
    mov eax, [tmp_offset]
    call emit_int
    lea rsi, [str_colon_nl]
    call emit_cstr

    call next_label
    mov [tmp_label2], eax
    call parse_condition
    mov edx, [tmp_label2]
    call emit_inverse_jump_while
    mov eax, [tmp_offset]
    mov edx, [tmp_label2]
    mov ecx, BLOCK_WHILE
    call push_block_full
    jmp main_parse_loop

handle_end:
    call pop_block
    cmp ecx, BLOCK_IF
    je .end_if
    cmp ecx, BLOCK_WHILE
    je .end_while
    call fatal_block
.end_if:
    lea rsi, [str_if_prefix]
    call emit_cstr
    mov eax, edx
    call emit_int
    lea rsi, [str_colon_nl]
    call emit_cstr
    jmp main_parse_loop
.end_while:
    lea rsi, [str_jmp_label]
    call emit_cstr
    lea rsi, [str_while_start]
    call emit_cstr
    mov eax, ebx
    call emit_int
    call emit_newline
    lea rsi, [str_while_end]
    call emit_cstr
    mov eax, edx
    call emit_int
    lea rsi, [str_colon_nl]
    call emit_cstr
    jmp main_parse_loop

handle_poke:
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    call emit_load_rbx_current
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    call emit_load_rcx_current
    lea rsi, [str_mov_ptr_rbx_rcx]
    call emit_cstr
    jmp main_parse_loop

handle_peek:
    call expect_ident
    call require_variable
    mov [tmp_offset], rax
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    call emit_load_rbx_current
    lea rsi, [str_mov_rax_ptr_rbx]
    call emit_cstr
    mov rax, [tmp_offset]
    call emit_store_rax_to_var
    jmp main_parse_loop

handle_read:
    call expect_ident
    call require_variable
    mov [tmp_offset], rax
    lea rsi, [str_read_syscall]
    call emit_cstr
    lea rsi, [str_movzx_rax_read]
    call emit_cstr
    mov rax, [tmp_offset]
    call emit_store_rax_to_var
    jmp main_parse_loop

handle_alloc:
    call expect_ident
    call require_variable
    mov [tmp_offset], rax
    lea rsi, [str_mov_rbx_ptr]
    call emit_cstr
    mov rax, [tmp_offset]
    call emit_store_rbx_to_var
    call next_token
    cmp eax, TOK_EOF
    je parse_error_global
    call emit_load_rbx_current
    lea rsi, [str_shl_rbx_3]
    call emit_cstr
    lea rsi, [str_add_alloc_rbx]
    call emit_cstr
    jmp main_parse_loop

handle_exit:
    lea rsi, [str_exit_stmt]
    call emit_cstr
    jmp main_parse_loop

parse_error_global:
    call fatal_parse

read_input:
    mov rax, SYS_OPEN
    lea rdi, [input_file]
    mov rsi, O_RDONLY
    syscall
    test rax, rax
    js .fail
    mov rdi, rax

    mov rax, SYS_READ
    lea rsi, [source_buf]
    mov rdx, MAX_INPUT
    syscall
    test rax, rax
    js .fail
    lea rcx, [source_buf]
    mov byte [rcx + rax], 0

    mov rax, SYS_CLOSE
    syscall
    ret
.fail:
    call fatal_parse

write_output:
    mov rax, SYS_CREAT
    lea rdi, [output_file]
    mov rsi, 0644o
    syscall
    test rax, rax
    js .fail
    mov [output_fd], rax

    mov rdx, [output_ptr]
    lea rcx, [output_buf]
    sub rdx, rcx
    mov rax, SYS_WRITE
    mov rdi, [output_fd]
    lea rsi, [output_buf]
    syscall

    mov rax, SYS_CLOSE
    mov rdi, [output_fd]
    syscall
    ret
.fail:
    call fatal_parse

next_token:
    mov rdi, [source_ptr]
.skip:
    mov al, [rdi]
    cmp al, 0
    je .eof
    cmp al, ';'
    je .comment
    cmp al, '#'
    je .comment
    cmp al, ' '
    jbe .advance
    jmp .read
.advance:
    inc rdi
    jmp .skip
.comment:
    inc rdi
.comment_loop:
    mov al, [rdi]
    cmp al, 0
    je .eof_set
    cmp al, 10
    je .advance
    inc rdi
    jmp .comment_loop
.read:
    mov [source_ptr], rdi
    lea rsi, [token_buf]
    mov byte [rsi], 0
    mov al, [rdi]

    cmp al, '"'
    je .read_string

    cmp al, '-'
    je .maybe_number
    cmp al, '0'
    jb .maybe_op
    cmp al, '9'
    jbe .read_number

.maybe_op:
    cmp al, '<'
    je .read_op
    cmp al, '>'
    je .read_op
    cmp al, '='
    je .read_op
    cmp al, '!'
    je .read_op
    jmp .read_ident

.maybe_number:
    mov dl, [rdi + 1]
    cmp dl, '0'
    jb .read_ident
    cmp dl, '9'
    jbe .read_number

.read_ident:
    lea rsi, [token_buf]
.ident_loop:
    mov al, [rdi]
    cmp al, 0
    je .ident_done
    cmp al, ' '
    jbe .ident_done
    cmp al, ';'
    je .ident_done
    cmp al, '#'
    je .ident_done
    cmp al, '"'
    je .ident_done
    cmp al, '<'
    je .ident_done
    cmp al, '>'
    je .ident_done
    cmp al, '='
    je .ident_done
    cmp al, '!'
    je .ident_done
    mov [rsi], al
    inc rsi
    inc rdi
    jmp .ident_loop
.ident_done:
    mov byte [rsi], 0
    mov [source_ptr], rdi
    mov dword [token_type], TOK_IDENT
    mov eax, TOK_IDENT
    ret

.read_number:
    lea rsi, [token_buf]
    mov al, [rdi]
    cmp al, '-'
    jne .number_loop
    mov [rsi], al
    inc rsi
    inc rdi
.number_loop:
    mov al, [rdi]
    cmp al, '0'
    jb .number_done
    cmp al, '9'
    ja .number_done
    mov [rsi], al
    inc rsi
    inc rdi
    jmp .number_loop
.number_done:
    mov byte [rsi], 0
    mov [source_ptr], rdi
    mov dword [token_type], TOK_NUMBER
    mov eax, TOK_NUMBER
    ret

.read_string:
    inc rdi
    lea rsi, [token_buf]
.string_loop:
    mov al, [rdi]
    cmp al, 0
    je .string_done
    cmp al, '"'
    je .string_close
    mov [rsi], al
    inc rsi
    inc rdi
    jmp .string_loop
.string_close:
    inc rdi
.string_done:
    mov byte [rsi], 0
    mov [source_ptr], rdi
    mov dword [token_type], TOK_STRING
    mov eax, TOK_STRING
    ret

.read_op:
    lea rsi, [token_buf]
    mov al, [rdi]
    mov [rsi], al
    inc rsi
    inc rdi
    mov al, [rdi]
    cmp al, '='
    jne .op_done
    mov [rsi], al
    inc rsi
    inc rdi
.op_done:
    mov byte [rsi], 0
    mov [source_ptr], rdi
    mov dword [token_type], TOK_OP
    mov eax, TOK_OP
    ret

.eof_set:
    mov [source_ptr], rdi
.eof:
    mov dword [token_type], TOK_EOF
    xor eax, eax
    ret

expect_ident:
    call next_token
    cmp eax, TOK_IDENT
    jne .fail
    ret
.fail:
    call fatal_parse

token_equals:
    push rsi
    push rdi
    lea rdi, [token_buf]
.loop:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .no
    test al, al
    je .yes
    inc rdi
    inc rsi
    jmp .loop
.yes:
    mov eax, 1
    pop rdi
    pop rsi
    ret
.no:
    xor eax, eax
    pop rdi
    pop rsi
    ret

define_variable:
    push rdi
    call find_variable_index
    cmp eax, -1
    jne .dupe
    mov ecx, [var_count]
    cmp ecx, MAX_VARS
    jae .full
    imul edi, ecx, MAX_NAME
    lea rdx, [var_names]
    add rdi, rdx
    lea rsi, [token_buf]
.copy:
    lodsb
    stosb
    test al, al
    jnz .copy
    mov eax, [var_count]
    shl eax, 3
    mov ecx, [var_count]
    lea rdx, [var_offsets]
    mov [rdx + rcx*8], rax
    inc dword [var_count]
    pop rdi
    ret
.dupe:
    pop rdi
    lea rsi, [err_redeclare]
    call fatal
.full:
    pop rdi
    lea rsi, [err_vars]
    call fatal

require_variable:
    call find_variable_index
    cmp eax, -1
    je .missing
    movsxd rcx, eax
    lea rdx, [var_offsets]
    mov rax, [rdx + rcx*8]
    ret
.missing:
    lea rsi, [err_var]
    call fatal

find_variable_index:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    xor ebx, ebx
    mov ecx, [var_count]
.outer:
    cmp ebx, ecx
    jae .not_found
    imul edi, ebx, MAX_NAME
    lea rdx, [var_names]
    add rdi, rdx
    lea rsi, [token_buf]
.inner:
    mov al, [rsi]
    mov dl, [rdi]
    cmp al, dl
    jne .next
    test al, al
    je .found
    inc rsi
    inc rdi
    jmp .inner
.next:
    inc ebx
    jmp .outer
.found:
    mov eax, ebx
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
.not_found:
    mov eax, -1
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

parse_condition:
    call next_token
    cmp eax, TOK_EOF
    je .fail
    call emit_load_rax_current

    call next_token
    cmp eax, TOK_OP
    jne .fail
    call parse_condition_code
    mov [tmp_cond], eax

    call next_token
    cmp eax, TOK_EOF
    je .fail
    call emit_load_rbx_current

    lea rsi, [str_cmp_rax_rbx]
    call emit_cstr
    mov eax, [tmp_cond]
    ret
.fail:
    call fatal_parse

parse_condition_code:
    lea rsi, [op_eq]
    call token_equals
    test eax, eax
    jnz .eq
    lea rsi, [op_ne]
    call token_equals
    test eax, eax
    jnz .ne
    lea rsi, [op_lt]
    call token_equals
    test eax, eax
    jnz .lt
    lea rsi, [op_le]
    call token_equals
    test eax, eax
    jnz .le
    lea rsi, [op_gt]
    call token_equals
    test eax, eax
    jnz .gt
    lea rsi, [op_ge]
    call token_equals
    test eax, eax
    jnz .ge
    call fatal_parse
.eq:
    mov eax, COND_EQ
    ret
.ne:
    mov eax, COND_NE
    ret
.lt:
    mov eax, COND_LT
    ret
.le:
    mov eax, COND_LE
    ret
.gt:
    mov eax, COND_GT
    ret
.ge:
    mov eax, COND_GE
    ret

emit_inverse_jump_if:
    call emit_inverse_jump_prefix
    lea rsi, [str_if_prefix]
    call emit_cstr
    mov eax, edx
    call emit_int
    call emit_newline
    ret

emit_inverse_jump_while:
    call emit_inverse_jump_prefix
    lea rsi, [str_while_end]
    call emit_cstr
    mov eax, edx
    call emit_int
    call emit_newline
    ret

emit_inverse_jump_prefix:
    cmp eax, COND_EQ
    je .eq
    cmp eax, COND_NE
    je .ne
    cmp eax, COND_LT
    je .lt
    cmp eax, COND_LE
    je .le
    cmp eax, COND_GT
    je .gt
    cmp eax, COND_GE
    je .ge
    call fatal_parse
.eq:
    lea rsi, [str_jne]
    call emit_cstr
    ret
.ne:
    lea rsi, [str_je]
    call emit_cstr
    ret
.lt:
    lea rsi, [str_jge]
    call emit_cstr
    ret
.le:
    lea rsi, [str_jg]
    call emit_cstr
    ret
.gt:
    lea rsi, [str_jle]
    call emit_cstr
    ret
.ge:
    lea rsi, [str_jl]
    call emit_cstr
    ret

emit_load_rax_current:
    cmp dword [token_type], TOK_NUMBER
    je .num
    cmp dword [token_type], TOK_IDENT
    jne .fail
    call require_variable
    call emit_load_rax_from_offset
    ret
.num:
    lea rsi, [str_mov_rax_imm]
    call emit_cstr
    call token_to_int
    call emit_int
    call emit_newline
    ret
.fail:
    call fatal_parse

emit_load_rbx_current:
    cmp dword [token_type], TOK_NUMBER
    je .num
    cmp dword [token_type], TOK_IDENT
    jne .fail
    call require_variable
    lea rsi, [str_mov_rbx_var]
    call emit_cstr
    call emit_int
    lea rsi, [str_close_load]
    call emit_cstr
    ret
.num:
    lea rsi, [str_mov_rbx_imm]
    call emit_cstr
    call token_to_int
    call emit_int
    call emit_newline
    ret
.fail:
    call fatal_parse

emit_load_rcx_current:
    cmp dword [token_type], TOK_NUMBER
    je .num
    cmp dword [token_type], TOK_IDENT
    jne .fail
    call require_variable
    lea rsi, [str_mov_rcx_var]
    call emit_cstr
    call emit_int
    lea rsi, [str_close_load]
    call emit_cstr
    ret
.num:
    lea rsi, [str_mov_rcx_imm]
    call emit_cstr
    call token_to_int
    call emit_int
    call emit_newline
    ret
.fail:
    call fatal_parse

emit_load_rax_from_offset:
    push rax
    lea rsi, [str_mov_rax_var]
    call emit_cstr
    pop rax
    push rax
    call emit_int
    lea rsi, [str_close_load]
    call emit_cstr
    pop rax
    ret

emit_store_rax_to_var:
    push rax
    lea rsi, [str_mov_var_rax]
    call emit_cstr
    pop rax
    push rax
    call emit_int
    lea rsi, [str_close_store_rax]
    call emit_cstr
    pop rax
    ret

emit_store_rbx_to_var:
    push rax
    lea rsi, [str_mov_var_rax]
    call emit_cstr
    pop rax
    push rax
    call emit_int
    lea rsi, [str_close_store_rbx]
    call emit_cstr
    pop rax
    ret

next_label:
    inc dword [label_count]
    mov eax, [label_count]
    ret

push_block:
    push rbx
    mov ebx, [block_sp]
    cmp ebx, MAX_BLOCKS
    jae .fail
    lea r8, [block_type]
    lea r9, [block_start_id]
    lea r10, [block_end_id]
    mov [r8 + rbx*4], edx
    mov dword [r9 + rbx*4], 0
    mov [r10 + rbx*4], eax
    inc dword [block_sp]
    pop rbx
    ret
.fail:
    pop rbx
    call fatal_block

push_block_full:
    push rbx
    mov ebx, [block_sp]
    cmp ebx, MAX_BLOCKS
    jae .fail
    lea r8, [block_type]
    lea r9, [block_start_id]
    lea r10, [block_end_id]
    mov [r8 + rbx*4], ecx
    mov [r9 + rbx*4], eax
    mov [r10 + rbx*4], edx
    inc dword [block_sp]
    pop rbx
    ret
.fail:
    pop rbx
    call fatal_block

pop_block:
    mov eax, [block_sp]
    test eax, eax
    jz .fail
    dec eax
    mov [block_sp], eax
    lea r8, [block_type]
    lea r9, [block_start_id]
    lea r10, [block_end_id]
    mov ecx, [r8 + rax*4]
    mov ebx, [r9 + rax*4]
    mov edx, [r10 + rax*4]
    ret
.fail:
    call fatal_block

token_to_int:
    push rbx
    push rcx
    push rdx
    push rsi
    lea rsi, [token_buf]
    xor rax, rax
    xor rbx, rbx
    mov dl, [rsi]
    cmp dl, '-'
    jne .loop
    mov bl, 1
    inc rsi
.loop:
    movzx rdx, byte [rsi]
    test rdx, rdx
    jz .done
    sub rdx, '0'
    imul rax, rax, 10
    add rax, rdx
    inc rsi
    jmp .loop
.done:
    test rbx, rbx
    jz .ret
    neg rax
.ret:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

emit_cstr:
    push rax
    push rcx
    push rdi
    mov rdi, [output_ptr]
.loop:
    mov al, [rsi]
    test al, al
    jz .done
    lea rcx, [output_buf + MAX_OUTPUT]
    cmp rdi, rcx
    jae .overflow
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .loop
.done:
    mov [output_ptr], rdi
    pop rdi
    pop rcx
    pop rax
    ret
.overflow:
    pop rdi
    pop rcx
    pop rax
    lea rsi, [err_outbuf]
    call fatal

emit_newline:
    mov al, 10
    jmp emit_char

emit_char:
    push rcx
    push rdi
    mov rdi, [output_ptr]
    lea rcx, [output_buf + MAX_OUTPUT]
    cmp rdi, rcx
    jae .overflow
    mov [rdi], al
    inc rdi
    mov [output_ptr], rdi
    pop rdi
    pop rcx
    ret
.overflow:
    pop rdi
    pop rcx
    lea rsi, [err_outbuf]
    call fatal

emit_int:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    lea rdi, [int_tmp + 31]
    mov byte [rdi], 0
    xor rbx, rbx
    cmp rax, 0
    jne .nz
    dec rdi
    mov byte [rdi], '0'
    jmp .emit
.nz:
    jns .conv
    neg rax
    mov bl, 1
.conv:
    mov rcx, 10
.loop:
    xor rdx, rdx
    div rcx
    add dl, '0'
    dec rdi
    mov [rdi], dl
    test rax, rax
    jnz .loop
    test rbx, rbx
    jz .emit
    dec rdi
    mov byte [rdi], '-'
.emit:
    mov rsi, rdi
    call emit_cstr
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

fatal:
    push rsi
    call cstrlen
    mov rdx, rax
    pop rsi
    mov rax, SYS_WRITE
    mov rdi, 2
    syscall
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

fatal_parse:
    lea rsi, [err_parse]
    call write_stderr_cstr
    lea rsi, [msg_parse_line]
    call write_stderr_cstr
    call current_line_number
    call write_stderr_uint
    lea rsi, [msg_parse_type]
    call write_stderr_cstr
    mov eax, [token_type]
    call write_stderr_uint
    lea rsi, [msg_parse_token]
    call write_stderr_cstr
    lea rsi, [token_buf]
    call write_stderr_cstr
    lea rsi, [msg_newline]
    call write_stderr_cstr
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

fatal_block:
    lea rsi, [err_block]
    call write_stderr_cstr
    lea rsi, [msg_parse_line]
    call write_stderr_cstr
    call current_line_number
    call write_stderr_uint
    lea rsi, [msg_parse_type]
    call write_stderr_cstr
    mov eax, [token_type]
    call write_stderr_uint
    lea rsi, [msg_parse_token]
    call write_stderr_cstr
    lea rsi, [token_buf]
    call write_stderr_cstr
    lea rsi, [msg_newline]
    call write_stderr_cstr
    mov rax, SYS_EXIT
    mov rdi, 1
    syscall

write_stderr_cstr:
    push rsi
    call cstrlen
    mov rdx, rax
    pop rsi
    mov rax, SYS_WRITE
    mov rdi, 2
    syscall
    ret

write_stderr_uint:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    lea rdi, [int_tmp + 31]
    mov byte [rdi], 0
    cmp rax, 0
    jne .nz
    dec rdi
    mov byte [rdi], '0'
    jmp .emit
.nz:
    mov rcx, 10
.loop:
    xor rdx, rdx
    div rcx
    add dl, '0'
    dec rdi
    mov [rdi], dl
    test rax, rax
    jnz .loop
.emit:
    mov rsi, rdi
    call write_stderr_cstr
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

current_line_number:
    push rbx
    push rdx
    push rsi
    mov rax, 1
    lea rsi, [source_buf]
    mov rbx, [source_ptr]
.loop:
    cmp rsi, rbx
    jae .done
    mov dl, [rsi]
    cmp dl, 10
    jne .next
    inc rax
.next:
    inc rsi
    jmp .loop
.done:
    pop rsi
    pop rdx
    pop rbx
    ret

cstrlen:
    push rsi
    xor rax, rax
.loop:
    cmp byte [rsi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    pop rsi
    ret
