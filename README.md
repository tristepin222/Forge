# Forge

Imperium Compiler Bootstrap

Forge is a minimal, self-contained bootstrap compiler written in x86-64 NASM for Linux. It is intended to be the Stage 0 compiler used to build a later compiler in its own high-level language.

### Language Docs

- Current implemented subset: [docs/stage3a.md](C:\Users\trist\OneDrive\Documents\GitHub\Forge\docs\stage3a.md)
- Long-term design reference: [docs/imperium-reference-v1.md](C:\Users\trist\OneDrive\Documents\GitHub\Forge\docs\imperium-reference-v1.md)

### Repository Layout

The canonical compiler sources and scripts are now split by stage:

```text
stages/
  stage0/compiler.asm
  stage2/compiler.ium
  stage3/compiler.ium
  stage3/compiler.imp
  stage3/src/selfhost/

scripts/
  test_stage0.sh
  build_stage2.sh
  test_stage2.sh
  bootstrap_stage2.sh
  compare_stage2_generations.sh
  build_stage3.sh
  test_stage3.sh
  test_stage3_selfhost_sample.sh
  test_stage3_selfhost_parts.sh
  test_stage3_selfhost.sh
  bootstrap_stage3.sh
  benchmark_stage3.sh
  check_stage3_perf.sh
  compare_stage3_generations.sh
```

The root `build_*.sh` / `test_*.sh` files remain as compatibility wrappers.

Extension convention:
- `.ium` = bootstrap-language source
- `.imp` = Imperium source

The Stage 3 self-host scaffold is split into source parts under
`stages/stage3/src/selfhost/` and bundled into `stages/stage3/compiler.imp`.
Its sample input now lives at `stages/stage3/src/selfhost/sample.imp`.
The bundler supports two modes:
- `STAGE3_SELFHOST_SAMPLE_MODE=stub` keeps the lexer source table stubbed and produces a lean self-host bundle
- `STAGE3_SELFHOST_SAMPLE_MODE=generated` injects the sample into the lexer as generated `source_length` / `source_char_at` code
Use:

```bash
chmod +x bundle_stage3_selfhost.sh
./bundle_stage3_selfhost.sh
```

to regenerate the bundled scaffold after editing those parts.

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
nasm -f elf64 stages/stage0/compiler.asm -o compiler.o
ld -o compiler compiler.o
```

### The Compilation Pipeline

Running the compiler processes `program.ium` and generates a standalone Linux executable.

1. **Generate Assembly:** `./compiler` (Reads `program.ium`, outputs `output/program.asm`)
2. **Assemble:** `nasm -f elf64 output/program.asm -o output/program.o`
3. **Link:** `ld -o output/program output/program.o`
4. **Run:** `./output/program`

**Automatic Build:**
If you're using the provided script:

```bash
chmod +x build.sh
./build.sh
```

This will compile your `program.ium`, link it, and execute it in one go.

### Regression Tests

There is also a small Stage 0 regression corpus under `tests/stage0`.

```bash
chmod +x test_stage0.sh
./test_stage0.sh
```

The runner rebuilds the compiler, swaps each test program into `program.ium`, compiles it, runs the generated binary, and compares stdout against the expected `.out` file.

### Building Stage 2

To compile the current trusted Stage 2 compiler source with the Stage 0 compiler:

```bash
chmod +x build_stage1.sh
./build_stage1.sh
```

This script:
- builds the Stage 0 compiler
- swaps `stages/stage2/compiler.ium` into `program.ium`
- assembles the generated `output/stage1.asm`
- links the resulting `output/stage1` compiler

### Running `stage1_test.ium`

If you have a small Stage 1 input program in `stage1_test.ium`, you can build Stage 1, compile that test, and run the resulting binary with:

```bash
chmod +x run_stage1_test.sh
./run_stage1_test.sh
```

### Stage 2 Tests

To run the current Stage 2 regression subset:

```bash
chmod +x test_stage1.sh
./test_stage1.sh
```

This suite runs the current Stage 2 regression corpus. By default it builds `output/stage1` first, but you can also point it at an existing compiler binary:

```bash
BUILD_STAGE1=0 STAGE1_BIN=output/stage1_gen2 ./test_stage1.sh
```

### Stage 2 Bootstrap Validation

To build the trusted Stage 2 compiler with Stage 0, rebuild it with itself, and rerun the Stage 2 regression suite against the second-generation compiler:

```bash
chmod +x bootstrap_stage1.sh
./bootstrap_stage1.sh
```

To compare first-generation vs second-generation Stage 2 outputs across the same corpus:

```bash
chmod +x compare_stage1_generations.sh
./compare_stage1_generations.sh
```

### Building Stage 3

To build the Stage 3 front-end scaffold with the trusted Stage 2 compiler:

```bash
chmod +x build_stage3.sh
./build_stage3.sh
```

This compiles `stages/stage3/compiler.ium` and produces `output/stage3`.

For the self-host path there are now two intermediate checks:

```bash
./test_stage3_selfhost_sample.sh
./test_stage3_selfhost_parts.sh
./test_stage3_selfhost.sh
```

- `test_stage3_selfhost_sample.sh` compiles the smaller Imperium sample at `stages/stage3/src/selfhost/sample.imp`
- `test_stage3_selfhost_parts.sh` compiles cumulative self-host bundle prefixes to find the first expensive or broken section
- `test_stage3_selfhost.sh` compiles, assembles, and links a lean bundled self-host scaffold

Use the sample smoke first when bringing `stages/stage3/compiler.ium` closer to the self-host source. Use the full smoke after that to measure whether the bundled compiler source itself is getting close enough for real bootstrap work.

The current Stage 3 milestone supports only the first real surface-syntax slice:
- optional `module ...`
- `function main() { ... }`
- `value` / `variable` / `constant` declarations inside `main`
- mutability enforcement: assignment is allowed only for `variable` / `var`
- plain assignment `x = expr`
- compound assignment `+=` / `-=`
- `print(expr)`
- `return expr`
- `if lhs <op> rhs { ... } else { ... }` with `==`, `!=`, `<`, `<=`, `>`, `>=`
- `while lhs <op> rhs { ... }` with `==`, `!=`, `<`, `<=`, `>`, `>=`
- `loop { ... }` and `break`
- `for name in start..end { ... }` with arithmetic-expression endpoints and exclusive end
- `continue` in `while`, `loop`, and `for`
- `match expr { literal => { ... } default => { ... } }` with integer and boolean literal arms
- `match` on enum variants, including one payload binding like `State::Done(x)`
- arithmetic expressions with `+`, `-`, `*` in assignment, `print`, and `return`
- arithmetic expressions on both sides of `if` / `while` conditions
- multiple function definitions
- expression-bodied functions with `=> expr`
- optional typed parameters in function definitions
- optional return-type syntax in function definitions
- `public function ...`
- `private function ...`
- top-level `struct ... { ... }` with struct literals and field reads
- top-level `enum ... { ... }` with unit variant constants
- single-payload enum variants like `Done(i32)`
- top-level `class ... { ... }` with stored field layouts, optional base-type syntax parsed and ignored for now, and methods inside the class body compiled as normal functions
- top-level `interface ... { function ... }` blocks with stored method names
- top-level `implement ... for Struct { function ... }` blocks with methods compiled as normal functions
- aliases `pub`, `fn`, `let`, `var`

### Stage 3 Benchmarking

Use the benchmark harness to measure trusted rebuilds, self-host smoke, and warm bootstrap timings:

```bash
./benchmark_stage3.sh --only bootstrap --timing
./benchmark_stage3.sh --only bootstrap-forced --timing
./benchmark_stage3.sh --only bootstrap --json --timing
```

- `--timing` keeps phase timings but suppresses most chatter
- `--json` writes machine-readable results to `output/benchmarks/stage3_benchmark_latest.json`
- JSON aggregates include `avg_ms`, `median_ms`, `min_ms`, and `max_ms`

The committed warm baseline lives at [stage3_warm_baseline.json](C:\Users\trist\OneDrive\Documents\GitHub\Forge\perf\stage3_warm_baseline.json).
To compare the current machine against that baseline:

```bash
./check_stage3_perf.sh
./check_stage3_perf.sh --benchmark bootstrap-forced
./check_stage3_perf.sh --repeat 5 --stat avg
```

The perf check defaults to `--repeat 3 --stat median`, warns on moderate regressions, and only fails on larger ones.
- `import ...` parsed and ignored semantically for now
- `from ... import ... as ...` parsed and ignored semantically for now
- string literals in `print(...)`
- string-literal assignment to variables
- `true` / `false`
- struct literals assigned to variables
- enum constants like `State::Idle`
- enum payload construction like `State::Done(5)`
- struct field reads in expressions
- struct field assignment with `=` / `+=` / `-=`
- method-call syntax on struct values, lowered through a typed `self: StructName` first parameter
- untyped `self` inside `implement ... for Struct` methods and class-body methods auto-binds to that type
- class literals and method calls through the same struct-backed layout machinery
- function call statements with zero or more arithmetic-expression arguments
- forward references for function calls
- function call expressions, including nested calls inside call arguments
- grouped arithmetic expressions with parentheses

Current Stage 3 parameter limitation:
- return types are parsed and ignored semantically for now
- imports are parsed and ignored semantically for now
- `public` / `private` are currently syntax-only top-level modifiers for `function`, `struct`, `enum`, `class`, and `interface`
- `implement` currently checks that the named interface exists and stores interface method names, but method/signature checking is not enforced yet
- string literals are currently supported only in `print(...)`
- string escapes are not supported yet
- string variables are currently compile-time string bindings intended for `print(name)`
- booleans currently lower to `1` and `0`
- enum payload support is currently limited to a single payload slot per variant

To run the Stage 3 test suite:

```bash
chmod +x test_stage3.sh
./test_stage3.sh
```

To run the intermediate self-host smoke gate for the Stage 3 scaffold:

```bash
chmod +x test_stage3_selfhost.sh
./test_stage3_selfhost.sh
```

This rebundles `stages/stage3/compiler.imp`, builds `output/stage3`,
compiles the self-host scaffold with that compiler, assembles/links the
result, and checks that the produced smoke binary exits cleanly.

At the current milestone, Stage 3 is **not self-hosting yet**.

There is now a Stage 3 self-host scaffold at
`stages/stage3/compiler.imp`, but the bootstrap/compare scripts remain intentionally gated until that source is explicitly marked ready.
That scaffold is bundled from `stages/stage3/src/selfhost/`, with its sample source in `stages/stage3/src/selfhost/sample.imp`, and now includes a first real lexer slice plus a minimal top-level parser over the self-host source shape with `module`, `import`, `from ... import ... as ...`, parser-only `@name` / `@name(...)` annotations, `private`, `class`, `interface`, and `implement ... for ... { ... }`, `async fn`, `await`, `unsafe { ... }`, `try` / `catch` / `finally`, generic function parameter lists like `[T]`, `where`, `requires`, and `ensures`, top-level `enum` / `struct`, `public function` plus `pub fn`, `value` / `variable` / `constant` plus `let` / `var`, typed signatures, expression-bodied helpers, simple block statements, assignment, calls, arithmetic expressions, grouped expressions, string literals, boolean literals, negative literals, struct literals, field access/assignment, `if` / `else`, `while`, `loop`, `for name in start..end { ... }`, `break`, `continue`, `match ... { ... default => ... }`, `<` / `<=` / `>` / `>=` / `==` / `!=` comparisons, and multiple functions.

When the self-host source is ready, create the marker file:

```text
stages/stage3/compiler.bootstrap-ready
```

Before enabling that marker, use `./test_stage3_selfhost_sample.sh` and then
`./test_stage3_selfhost.sh` as the intermediate gates for the self-host source.
Those prove that the current scaffold can be compiled, assembled, and linked by the trusted Stage 3 compiler.
The current self-host runtime path now lexes real stdin and emits a small real Stage 3 subset instead of the old fixed empty-main smoke program. Right now that backend is intentionally limited to the early regression surface: top-level functions, basic bindings/assignment, arithmetic expressions, `print`, `return`, zero-arg calls, and first-cut `if` / `while`.
They still do **not** prove that the resulting second-generation binary is a regression-capable compiler.
Once the marker exists, `./bootstrap_stage3.sh` reruns those two preflight checks automatically and then runs a second-generation compiler smoke on `tests/stage3/basic_empty_main.imp` before attempting the full Stage 3 regression suite.

After that, you can bootstrap and compare Stage 3 generations with:

```bash
chmod +x bootstrap_stage3.sh compare_stage3_generations.sh
./bootstrap_stage3.sh
./compare_stage3_generations.sh
```

`compare_stage3_generations.sh` now defaults to behavioral parity:
- same runtime output
- same exit status

If you want exact assembly identity too, run:

```bash
STRICT_ASM=1 ./compare_stage3_generations.sh
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
* [x] Self-hosted Compiler (Stage 2 trust base)
* [ ] Imperium Syntax Front-end (Stage 3A)

---
