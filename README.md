# Forge

Imperium Compiler Bootstrap

Forge is a minimal, self-contained bootstrap compiler written in x86-64 NASM for Linux. It is intended to be the Stage 0 compiler used to build a later compiler in its own high-level language.

### Prerequisites

Be sure your package manager is up to date:

```bash
sudo apt update
sudo apt install nasm build-essential
```

*Note: Forge targets the x86-64 Linux ABI (`elf64` / `syscall`).*

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

### Regression Tests

There is also a small Stage 0 regression corpus under `tests/stage0`.

```bash
chmod +x test_stage0.sh
./test_stage0.sh
```

The runner rebuilds the compiler, swaps each test program into `program.imp`, compiles it, runs the generated binary, and compares stdout against the expected `.out` file.

### Building Stage 1

To compile the current `stage1.imp` source with the Stage 0 compiler:

```bash
chmod +x build_stage1.sh
./build_stage1.sh
```

This script:
- builds the Stage 0 compiler
- swaps `stage1.imp` into `program.imp`
- assembles the generated `output/stage1.asm`
- links the resulting `output/stage1` compiler

### Running `stage1_test.imp`

If you have a small Stage 1 input program in `stage1_test.imp`, you can build Stage 1, compile that test, and run the resulting binary with:

```bash
chmod +x run_stage1_test.sh
./run_stage1_test.sh
```

### Stage 1 Subset Tests

To run the current Stage 1 regression subset:

```bash
chmod +x test_stage1.sh
./test_stage1.sh
```

This suite runs the current Stage 1 regression corpus. By default it builds `output/stage1` first, but you can also point it at an existing compiler binary:

```bash
BUILD_STAGE1=0 STAGE1_BIN=output/stage1_gen2 ./test_stage1.sh
```

### Stage 1 Bootstrap Validation

To build Stage 1 with Stage 0, rebuild it with itself, and rerun the Stage 1 regression suite against the second-generation compiler:

```bash
chmod +x bootstrap_stage1.sh
./bootstrap_stage1.sh
```

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
| `POKE [addr] [val]` | Write 64-bit value to heap memory | `POKE ptr 65` |
| `PEEK [var] [addr]` | Read 64-bit value from heap memory | `PEEK a ptr` |
| `READ [var]` | Read 1 byte from stdin (ASCII value) | `READ c` |
| `WRITE_STR "..."` | Emit a raw string one byte at a time | `WRITE_STR "mov eax, 1"` |
| `WRITE_CHAR [val]` | Emit one byte to stdout | `WRITE_CHAR 10` |
| `WRITE_INT [val]` | Print integer without newline | `WRITE_INT a` |
| `EXIT` | Exit the generated program | `EXIT` |

---

### Bootstrapping Progress

* [x] Integer Arithmetic
* [x] Control Flow (Nested IF/WHILE)
* [x] Global Heap (Arrays)
* [x] Byte-stream Input (READ)
* [ ] Self-hosted Compiler (Stage 1)

---
