# Imperium Stage 3A

## Goal

Stage 3A is the first real Imperium surface syntax layer.

It is **not** the full language manifesto. Its job is:

- keep the trusted Stage 2 compiler unchanged
- build a new front-end in a separate compiler path
- lower new syntax to the same semantic core first
- keep bootstrap risk low

## Compiler layering

- Stage 0: [compiler.asm](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage0\compiler.asm)
- Stage 2 trust base: [compiler.imp](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage2\compiler.imp)
- Stage 3 front-end: [compiler.imp](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage3\compiler.imp)

Build flow:

1. Stage 0 builds Stage 2
2. Stage 2 builds Stage 3
3. Stage 3 eventually becomes the user-facing compiler

## Stage 3A subset

These are the features to implement first:

- `module app.main`
- `import std.io.{print}`
- `function main() { ... }`
- `value x: i32 = expr`
- `variable y: i32 = expr`
- `x = expr`
- `if expr { ... } else { ... }`
- `while expr { ... }`
- `return expr`
- `print(expr)`
- arithmetic expressions and function calls

These should stay out for now:

- classes
- inheritance
- interfaces
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

The current [compiler.imp](C:\Users\trist\OneDrive\Documents\GitHub\Forge\stages\stage3\compiler.imp) is only a pipeline scaffold.

It deliberately:

- consumes stdin safely
- emits a valid empty program
- proves the Stage 3 build/bootstrap/test path works

It does **not** implement Stage 3A syntax yet.
