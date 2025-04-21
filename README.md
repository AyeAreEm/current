# Current
- NOTE: this language is still being development. expect bugs as features<br>

## Description
Current is a statically typed compiled programming language with manual memory management<br>
It's an ergonomic middle ground between C and C++, similar to new programming languages are in this space.<br>

## Principles
Current's main principles are simplicity and ease of use. A language with these principles would be one that doesn't stand in the way of the programmer and has features you'd expect in a modern language.<br>
To do this, we "borrow" features from other languages. For example, receiver methods from Golang, generics from Rust, options and errors from Zig, etc.

## Features
- Generics
- UTF-8 Strings
- Defer Statements
- Zero Initalised
- Options and Errors (as values)
- Name First Declaration
- Receiver Methods
- Compile Time Execution
- Default Function Arguments
- Allocators

```odin
vec2 :: struct[T] {
    x: T,
    y: T,
}

vec2[T].add :: fn(*self, other: vec2[T]) void {
    self.x += other.x;
    self.y += other.y;
}

main :: fn() void {
    pos := vec2[i32]{10, 15};
    other := vec2[i32]{20, 10};

    pos.add(other);

    nums := dyn[i32].init()!; // ! == "unwrap" / "or_return"
    defer nums.deinit()!;

    nums.push(69)!;
    nums.push(420)!;

    for (nums) [n] {
        println("%", n);
    }

    first_num: ?i32 = nums.at(0); // don't need to specify the type, just showing the '?' option type
    if (first_num) [n] {
        println("%", n);
    } else {
        println("no number at index 0");
    }
}
```

## Why not Odin, Zig, ...?
Well, mainly because all languages miss features and I wanted a language that had certain features but there was no language that had all of them<br>
- NOTE: I'm not saying these langauges are bad for not having these features. There are reasons why they don't have said features and that's respectable

### Features Odin Doesn't Have
- <del>Generics</del>
- First Class Error Unions
- Receiver Methods
- Compile Time Execution
- Immutable Variables

<del>It might be good to point out that Odin has polymorphic parameters, not generics. So `Maybe(vec2(i32))` does not work. Of course there are ways around this but I want true generics</del> As of odin dev-2025-01:6572a52a8, `Maybe(vec2(i32))` works and other generic related things<br>
Also, when I say "immutable variables", I mean "const" variables in the traditional sense. Odin does have constants but they must be compile time known, I think a language should have a way to declare a constant variable

### Features Zig Doesn't Have
- Default Function Parameters
- Polymorphic Parameters
- Nameless Struct Literal Members
- Receiver Methods
- Not Being a Pain in the Ass

While Zig does have generics, if you want `fn max(x: $T, y: T) T`, this doesn't work. You'd have to pass an `anytype` which could mean that `x` and `y` are different types unless checked inside the function or do `fn max(comptime T: type, x: T, y: T) T`<br>
Also Zig is just a pain at times. Unused variables errors, Variable that isn't mutated errors, and so on. I'm sure in critical applications this would be useful but for prototyping, it sucks.

## Noteworthy Differences from Mainstream Languages
1. There is no garbage collection
    - Like in languages such as C, you'll have to free memory yourself
1. There are no classes, just structs
    - The key difference is that all fields are public
1. Zig-like Try Catch
    - All functions that might return an error must be handled
1. Name focused declarations
    - This is mainly stylistic but it does have the benefit of grepping for declarations easier by doing 'name ::'
1. Receiever methods
    - Lets the developer add onto types for more functionality rather than being locked into what's available by the developer of the type
1. Two pointer symbols
    - `*` is a pointer to a variable. `^` is a pointer to a constant. More on why <a href="#why-two-pointer-symbols">here</a>
1. Global constants are compile time constants
    - Constants in global scope are known at compile time and are similar to `#define` or `constexpr`
1. No operator overloading
    - Usually used for math so we'll have common math structures be first class citizens
1. No function overloading
    - Feel as tho it's unnecessary in a language like this but my opinion my change

## Why Two Pointer Symbols
I have noticed one major problem with the ":=", "::" syntax. While it's clear to see which is a variable and which is a constant, there's no way to tell if a pointer points to a variable or constant<br>
Odin doesn't let you take the address of a constant because they're similar to `#define` and may not have a runtime address.<br>
Similarly in Golang, constant may or may not be addressable at runtime so you can't take the address. Golang authors also said "if you could take the address of a string constant, you could call a function [that assigns to the pointed value resulting in] possibly strange effects - you certainly wouldn't want the literal string constant to change."<br>
<br>
I thought about just changing "::" to be constant variables instead of something like `#define` but some problems arise. If you want to pass a large constant structure, you'd be forced to pass by value and copy that large amount of data. Usually you'd pass a pointer that way not performing a copy and still not allowing the function to mutate it.<br>
In that case, pointers to constant are neccessary but there isn't a proper syntactic way to do this in languages like this because there is no `const` keyword. Hence, two pointer symbols.<br>
`*` is a pointer to a variable / mutable data.<br>
`^` is a pointer to a constant / immutable data.<br>
