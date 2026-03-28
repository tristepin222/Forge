# Imperium Stage 3A

## Goal

Stage 3A is the first real Imperium surface syntax layer.

It is **not** the full language manifesto. Its job is:

- keep the trusted Stage 2 compiler unchanged
- build a new front-end in a separate compiler path
- lower new syntax to the same semantic core first
- keep bootstrap risk low

For the long-term language design, see
[imperium-reference-v1.md](C:\Users\trist\OneDrive\Documents\GitHub\Forge\docs\imperium-reference-v1.md).

## Compiler layering

- Stage 0: [compiler.asm](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage0\compiler.asm)
- Stage 2 trust base: [compiler.ium](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage2\compiler.ium)
- Stage 3 front-end: [compiler.ium](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage3\compiler.ium)
- Stage 3 self-host scaffold: [compiler.imp](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage3\compiler.imp)
- Stage 3 self-host parts: `stages/stage3/src/selfhost/*.imp`
- Stage 3 self-host sample input: `stages/stage3/src/selfhost/sample.imp`

Build flow today:

1. Stage 0 builds Stage 2
2. Stage 2 builds Stage 3
3. Stage 3 eventually becomes the user-facing compiler
4. Stage 3 bootstrap only starts once the compiler itself is rewritten in Stage 3 syntax

Extension convention:

- `.ium` = bootstrap-language source
- `.imp` = Imperium source

## Stage 3A subset

These are the features to implement first:

- `module app.main`
- `import std.io.{print}`
- `from std.io import print as p`
- `public function main() { ... }`
- `private function helper() { ... }`
- top-level `struct Name { ... }`
- top-level `enum Name { ... }`
- single-payload enum variants like `Done(i32)`
- top-level `class Name { ... }`
- top-level `interface Name { ... }`
- top-level `implement Trait for Type { function ... }`
- `function main() { ... }`
- aliases `pub`, `fn`, `let`, `var`
- `value x: i32 = expr`
- `variable y: i32 = expr`
- `value` / `constant` / `let` bindings are immutable
- `variable` / `var` bindings are mutable
- `x = expr`
- `x += expr`
- `x -= expr`
- `if expr { ... } else { ... }`
- `while expr { ... }`
- `loop { ... }`
- `for name in start..end { ... }`
- `break`
- `continue`
- `match expr { literal => { ... } default => { ... } }`
- `match expr { State::Done(x) => { ... } default => { ... } }`
- `return expr`
- `print(expr)`
- `print("text")`
- `value name = "text"`
- `value ok: bool = true`
- `value p: Point = Point { x: 1, y: 2 }`
- `print(p.x)`
- `p.sum()` lowered to `sum(self: Point)`
- arithmetic expressions and function calls

These should stay out for now:

- full class semantics beyond struct-backed classes
- inheritance
- full interface checking and dispatch
- typed exceptions
- capabilities
- effects
- async/await
- ownership/borrowing checks
- generics
- contracts

## Syntax target

```imperium
module app.main

function add(a: i32, b: i32) -> i32 {
    return a + b
}

function main() {
    value x: i32 = 10
    variable y: i32 = 2

    if x > y {
        print(x)
    } else {
        print(y)
    }

    while y < 5 {
        y = y + 1
    }
}
```

## Implementation order

1. Parse braces and punctuation
2. Add Stage 3 declarations and assignment syntax
3. Add `function` blocks
4. Add `return`
5. Add `if` / `else` / `while`
6. Add builtin-style `print(expr)`
7. Parse `module` / `import` first, give them semantics later

## Current status

The current [compiler.ium](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage3\compiler.ium) is the bootstrap-language Stage 3 compiler.

There is also a self-host source scaffold at
[compiler.imp](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage3\compiler.imp).
That file is an architectural starting point for the port, not a bootstrap-ready compiler yet.
It is bundled from the split source parts under `stages/stage3/src/selfhost/`.
It now includes a first real lexer slice plus a minimal top-level parser for a generated sample program from `stages/stage3/src/selfhost/sample.imp`, with `module`, `import`, `from ... import ... as ...`, parser-only `@name` / `@name(...)` annotations, `private`, `class`, `interface`, and `implement ... for ... { ... }`, `async fn`, `await`, `unsafe { ... }`, `try` / `catch` / `finally`, generic function parameter lists like `[T]`, `where`, `requires`, and `ensures`, top-level `enum` / `struct`, `public function` plus `pub fn`, `value` / `variable` / `constant` plus `let` / `var`, multiple `function` definitions, typed parameters, optional return types, expression-bodied helpers, simple block statements, assignment, call expressions, arithmetic expressions, grouped expressions, string literals, boolean literals, negative literals, struct literals, field access/assignment, `if` / `else`, `while`, `loop`, `for name in start..end { ... }`, `break`, `continue`, `match ... { ... default => ... }`, `<` / `<=` / `>` / `>=` / `==` / `!=` comparisons, and a required `main`.
Its runtime path is still intentionally narrow: the current `compile_program()` now lexes real stdin and emits a small real Stage 3 subset instead of the old fixed empty-main smoke program. Right now that backend is intentionally limited to the early regression surface: top-level functions, basic bindings/assignment, arithmetic expressions, `print`, `return`, zero-arg calls, and first-cut `if` / `while`.

It currently supports:

- optional `module ...`
- `import ...` parsed and ignored semantically for now
- `from ... import ... as ...` parsed and ignored semantically for now
- `public function ...`
- `private function ...`
- top-level `struct ... { ... }` with stored field layouts
- top-level `enum ... { ... }` with unit variant constants
- single-payload enum variants like `Done(i32)`
- top-level `class ... { ... }` with stored field layouts, optional base-type syntax parsed and ignored for now, and methods inside the class body compiled as normal functions
- top-level `interface ... { function ... }` blocks with stored method names
- top-level `implement ... for Struct { function ... }` blocks with methods compiled as normal functions
- alias forms `pub function ...` and `pub fn ...`
- `function main() { ... }`
- declaration aliases `let` and `var`
- string literals in `print(...)`
- string-literal assignment to variables
- `true` / `false`
- struct literals assigned to variables
- enum constants like `State::Idle`
- enum payload construction like `State::Done(5)`
- struct field reads in expressions
- struct field assignment with `=` / `+=` / `-=`
- method-call syntax on struct values, lowered to normal function calls through a typed `self: StructName` first parameter
- untyped `self` inside `implement ... for Struct` methods and class-body methods auto-binds to that type
- class literals and method calls through the same struct-backed layout machinery
- `value` / `variable` / `constant` declarations inside `main`
- mutability enforcement: assignment is allowed only for `variable` / `var`
- plain assignment `x = expr`
- compound assignment `+=` / `-=`
- `print(expr)` as a builtin statement
- `return expr`
- `if lhs <op> rhs { ... } else { ... }` with `==`, `!=`, `<`, `<=`, `>`, `>=`
- `while lhs <op> rhs { ... }` with `==`, `!=`, `<`, `<=`, `>`, `>=`
- `loop { ... }` and `break`
- `for name in start..end { ... }` with arithmetic-expression range endpoints and exclusive end
- `continue` in `while`, `loop`, and `for`
- `match expr { literal => { ... } default => { ... } }` with integer and boolean literal arms
- `match` on enum variants, including one payload binding like `State::Done(x)`
- arithmetic expressions with `+`, `-`, `*` in assignment, `print`, and `return`
- grouped arithmetic expressions with parentheses
- arithmetic expressions on both sides of `if` / `while` conditions
- multiple `function name(...) { ... }` definitions
- expression-bodied functions with `=> expr`
- optional typed parameters in function definitions
- optional return-type syntax in function definitions
- function calls with zero or more arithmetic-expression arguments
- forward references for function calls
- call expressions like `value x = add(1, 2)` or `print(helper())`
- nested function calls inside call arguments like `add(id(1), id(2 + 1))`
- optional type annotation parsing in declarations, ignored semantically for now
- identifier, integer-literal, and function-call factors in expressions

Current limitation:
- return types are parsed and ignored semantically for now
- imports are parsed and ignored semantically for now
- `public` / `private` are currently syntax-only top-level modifiers for `function`, `struct`, `enum`, `class`, and `interface`
- `implement` currently checks that the named interface exists and stores interface method names, but method/signature checking is not enforced yet
- `default =>` is the canonical fallback arm in `match`; `_ =>` remains accepted as an alias for now
- string literals are currently supported only in `print(...)`
- string escapes are not supported yet
- string variables are currently compile-time string bindings intended for `print(name)`
- booleans currently lower to `1` and `0`
- enum payload support is currently limited to a single payload slot per variant

It does **not** represent a self-hosted Stage 3 compiler yet.

That means:

- [build_stage3.sh](C:\Users\trist\OneDrive\Documents\GitHub\Forge\scripts\build_stage3.sh) is valid now
- [test_stage3.sh](C:\Users\trist\OneDrive\Documents\GitHub\Forge\scripts\test_stage3.sh) is valid now
- [test_stage3_selfhost_sample.sh](C:\Users\trist\OneDrive\Documents\GitHub\Forge\scripts\test_stage3_selfhost_sample.sh) is the quick compile-only self-host syntax smoke for `stages/stage3/src/selfhost/sample.imp`
- [test_stage3_selfhost_parts.sh](C:\Users\trist\OneDrive\Documents\GitHub\Forge\scripts\test_stage3_selfhost_parts.sh) compiles cumulative self-host bundle prefixes to find the first expensive or broken section
- [test_stage3_selfhost.sh](C:\Users\trist\OneDrive\Documents\GitHub\Forge\scripts\test_stage3_selfhost.sh) compiles, assembles, and links a lean bundled self-host scaffold
- [bootstrap_stage3.sh](C:\Users\trist\OneDrive\Documents\GitHub\Forge\scripts\bootstrap_stage3.sh) and [compare_stage3_generations.sh](C:\Users\trist\OneDrive\Documents\GitHub\Forge\scripts\compare_stage3_generations.sh) stay gated until the self-host source is genuinely ready; that gate is the marker file `stages/stage3/compiler.bootstrap-ready`
- once that marker exists, `bootstrap_stage3.sh` reruns `test_stage3_selfhost_sample.sh` and `test_stage3_selfhost.sh` automatically before attempting the second-generation build
- after the second-generation binary is built, `bootstrap_stage3.sh` now runs a small compiler smoke on `tests/stage3/basic_empty_main.imp`; passing the scaffold smoke gates alone is not enough yet
- `compare_stage3_generations.sh` now treats behavioral parity as the required gate by default; exact ASM parity is optional via `STRICT_ASM=1`

Use `./test_stage3_selfhost_sample.sh` first, then `./test_stage3_selfhost.sh`, before creating the bootstrap-ready marker.
