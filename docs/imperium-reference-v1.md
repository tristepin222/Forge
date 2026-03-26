# Imperium - Complete Reference Sheet (v1.0)

This document is the long-term Imperium language reference and design target.

It is not the current implemented compiler subset. The executable Stage 3 subset
lives in [stage3a.md](C:\Users\trist\OneDrive\Documents\GitHub\Forge\docs\stage3a.md).

A programming language designed to be:
- Typed
- Safe (no null, no data races)
- Secure (capability-based)
- Fast (zero-cost abstractions)
- Explicit (readable syntax)

---

## 0. Philosophy

- Explicit over implicit
- Safety by default
- No ambient authority
- Effects are visible in types
- Structs + interfaces first, classes when needed

---

## 1. Hello World

```imperium
module app.main

import std.io.{print}

public function main() {
    print("Ave, Imperium")
}
```

---

## 2. Keywords

```
function value variable constant
public private class struct interface implement enum
if else for while loop match
return try catch throw
async await unsafe
module import from as
where requires ensures
true false
```

Aliases (optional): fn, let, var, pub

---

## 3. Variables

```imperium
value x: i32 = 10
variable y: i32 = 20
constant MAX: i32 = 100

value name = "Imperium"
```

---

## 4. Types

### Primitive

```
bool char str String
i8 i16 i32 i64 i128 isize
u8 u16 u32 u64 u128 usize
f32 f64
unit void never
```

### Compound

```imperium
value t: (i32, str) = (1, "one")
value a: [i32; 3] = [1, 2, 3]
value s: &[i32] = &a[0..2]
value v: Vec[i32] = Vec::new()
value m: Map[str, i32] = Map::new()
```

---

## 5. Option and Result

```imperium
value a: Option[i32] = some(1)
value b: Option[i32] = none()

value r: Result[i32, Error] = ok(42)

match a {
    some(v) => print(v)
    none() => print("none")
}
```

---

## 6. Functions

```imperium
function add(a: i32, b: i32) -> i32 {
    return a + b
}

function square(x: i32) -> i32 => x * x

function identity[T](x: T) -> T => x
```

---

## 7. Control Flow

```imperium
if x > 0 {
    return "positive"
} else {
    return "negative"
}

for n in [1,2,3] {
    print(n)
}

while x < 10 {
    x += 1
}

loop {
    break
}

match code {
    200 => "ok"
    _ => "other"
}
```

---

## 8. Ownership & Borrowing

```imperium
value s: String = "hello".to_string()

value r: &String = &s

variable v = Vec::new()
value m: &mut Vec[i32] = &mut v

value a = "x".to_string()
value b = a

value c = b.clone()
```

Rules:
- One owner
- No alias + mutation
- Moves by default

---

## 9. Structs

```imperium
struct User {
    id: u64
    name: String
}
```

---

## 10. Classes (OOP)

```imperium
public class Account {
    private variable balance: i64

    public function new(initial: i64) -> Self {
        return Self { balance: initial }
    }

    public function deposit(self: &mut Self, amount: i64) {
        self.balance += amount
    }

    public function get_balance(self: &Self) -> i64 {
        return self.balance
    }
}
```

---

## 11. Interfaces (Traits)

```imperium
public interface Drawable {
    function draw(self, canvas: Canvas)
}

implement Drawable for Account {
    function draw(self, canvas: Canvas) {
        canvas.text("account")
    }
}
```

---

## 12. Inheritance (Limited)

```imperium
abstract class Animal {
    name: String
    abstract function speak(self) -> String
}

class Dog : Animal {
    override function speak(self) -> String => "woof"
}
```

---

## 13. Enums

```imperium
enum State {
    Idle
    Loading
    Done(String)
}
```

---

## 14. Exceptions (Typed)

```imperium
class DivideByZero {
    message: String
}

function divide(a: i32, b: i32) -> i32 !throw[DivideByZero] {
    if b == 0 {
        throw DivideByZero { message: "division by zero" }
    }
    return a / b
}
```

---

## 15. Try / Catch

```imperium
try {
    value x = divide(10, 0)
} catch error: DivideByZero {
    print(error.message)
} finally {
    print("done")
}
```

---

## 16. Effects

```imperium
function read(fs: FileRead) !io -> String

function parse() !throw[ParseError] -> Ast

async function fetch(net: NetClient) !io -> Bytes
```

---

## 17. Capabilities (Security)

```imperium
function read_config(fs: FileRead) -> String {
    return fs.read_to_string("config.txt")
}
```

No global access allowed.

---

## 18. Concurrency

```imperium
async function main() {
    task t = spawn work()
    await t
}
```

---

## 19. Channels

```imperium
value (tx, rx) = channel
```

---

## 20. Pattern Matching

```imperium
match msg {
    Ping => print("ping")
    Data(x) => print(x)
}
```

---

## 21. Generics

```imperium
function swap[T](a: T, b: T) -> (T, T) => (b, a)
```

---

## 22. Error Handling (Result)

```imperium
function parse(s: str) -> Result[i32, Error]
```

---

## 23. Unsafe

```imperium
unsafe function deref(p: *const i32) -> i32 {
    return *p
}
```

---

## 24. Contracts

```imperium
function div(a: i32, b: i32) -> i32
requires b != 0
ensures result * b == a
{
    return a / b
}
```

---

## 25. Memory Layout

```imperium
@repr(c)
struct Header {
    len: u32
}
```

---

## 26. Testing

```imperium
@test
function test_add() {
    assert(add(2,3) == 5)
}
```

---

## 27. Mini Cheat Sheet

```imperium
value x = 1
variable y = 2

function add(a, b) => a + b

struct S { x: i32 }

class C { }

interface I { }

try { } catch e { }

async function f() { await g() }

unsafe { }
```

---

## 28. Core Rules

- No null
- No data races
- No hidden I/O
- No implicit mutation
- No unsafe without `unsafe`
- No capability = no access

