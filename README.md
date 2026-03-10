# Forge

Imperium Compiler Bootstrap

Forge is a minimal, self-contained bootstrap compiler written in x86-64 Assembly. It is designed to be the "Stage 0" tool used to build the "Stage 1" compiler in its own high-level language.

### Prerequisites

Be sure your package manager is up to date:

```bash
sudo apt update
sudo apt install nasm build-essential
```

*Note: Forge targets the x86-64 Linux ABI and is not compatible with ARM/Apple Silicon without emulation.*

### Building the Compiler

To build the Forge compiler itself:

```bash
nasm -f elf64 compiler.asm -o compiler.o
ld -o compiler compiler.o
```

### The Compilation Pipeline

Running the compiler processes `program.imp` and generates a standalone Linux executable.

1. **Generate Assembly:** `./compiler` (Reads `program.imp`, outputs `output/program.asm`)
2. **Assemble:** `nasm -f elf64 output/program.asm -o output/program.o`
3. **Link:** `ld -o output/program output/program.o`
4. **Run:** `./output/program`

**Automatic Build:**
If you're using the provided script:

```bash
chmod +x build.sh
./build.sh
```

This will compile your `program.imp`, link it, and execute it in one go.

---

### Language Reference (Imperium Syntax)

Forge supports the following primitives required for bootstrapping:

| Command | Description | Example |
| --- | --- | --- |
| `LET [var] [val]` | Assign a literal or variable | `LET a 10` |
| `ADD / SUB / MUL` | Arithmetic operations | `MUL a 5` |
| `PRINT [val]` | Print integer to stdout + newline | `PRINT a` |
| `IF [cond] ... END` | Conditional blocks (`==`, `>`, `<`) | `IF a > 0` |
| `WHILE [cond] ... END` | Loop blocks | `WHILE a < 10` |
| `POKE [idx] [val]` | Write 64-bit value to Heap memory | `POKE 0 65` |
| `PEEK [var] [idx]` | Read 64-bit value from Heap memory | `PEEK a 0` |
| `READ [var]` | Read 1 byte from stdin (ASCII value) | `READ c` |

---

### Bootstrapping Progress

* [x] Integer Arithmetic
* [x] Control Flow (Nested IF/WHILE)
* [x] Global Heap (Arrays)
* [x] Byte-stream Input (READ)
* [ ] Self-hosted Compiler (Stage 1)

---