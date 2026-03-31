# Self-Host Compiler Gap Analysis

## Date: March 31, 2026

## Problem
Bootstrap test `./bootstrap_stage3.sh` failed with:
> "Stage 3 bootstrap stopped: the second-generation binary ran, but it did not emit valid assembly for the Stage 3 smoke input."

## Root Cause
The self-hosted `stages/stage3/compiler.imp` is **missing the entire code-generation backend**.

## Comparison: Original vs Self-Host Output

### Original Stage 3 Compiler (`output/stage3`)
Compiling `tests/stage3/basic_empty_main.imp` produces:
```asm
BITS 64
section .text
global _start

_start:
    call main
    mov rax, 60
    xor rdi, rdi
    syscall

main:
    ret

flush_write_buf:
    [...]

write_char_rax:
    [...]

[... more helper functions ...]

section .bss
vars resq 128
int_buf resb 32
[... data section ...]
```

### Self-Host Compiler (`output/stage3_gen2`)
Same input produces:
```asm
BITS 64
section .text
global _start

_start:
    call main
    mov rdi, rax      # WRONG! should be xor rdi, rdi
    mov rax, 60
    syscall

[EOF - nothing else]
```

## What's Missing in `compiler.imp`

1. **Function definitions** — No generation of actual `main:` label or function body
2. **Helper routines** — No `flush_write_buf`, `write_char_rax`, `print_rax`, `print_int_raw`
3. **BSS data section** — No variable/buffer allocations
4. **Return type inference** — Exiting with `mov rdi, rax` instead of `xor rdi, rdi` (rax should be 0 for empty main)
5. **Writer buffer logic** — No write buffering infrastructure

## Next Steps

1. Port the **exit/return handling** from `stages/stage3/compiler.ium` to `compiler.imp`
   - Currently using wrong exit value (rax from main instead of 0)
2. Port the **function prologue/epilogue** generation
   - Add `main:` label and `ret` for empty functions
3. Port the **helper function emission logic**
   - `flush_write_buf`, `write_char_rax`, `print_rax`, etc.
4. Add **BSS section generation** for variable storage and buffers

## Files
- Bootstrap-language version (working): `stages/stage3/compiler.ium` (~3500 lines)
- Self-host version (incomplete): `stages/stage3/compiler.imp` (~150 lines of actual code)
- Self-host parts: `stages/stage3/src/selfhost/*.imp` (modular source)

## Key Insight
The self-host compiler successfully **parses** the input (smoke test passes), but **generates minimal code**. It needs the full backend from the bootstrap version ported to Imperium syntax.
