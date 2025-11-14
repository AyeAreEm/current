" Vim syntax file
" Language: Pine

if exists("b:current_syntax")
    finish
endif

syn keyword pineTypes void bool u8 u16 u32 u64 usize i8 i16 i32 i64 isize f32 f64 string cstring char
syn keyword pineFn fn
syn keyword pineStructures struct enum
syn keyword pineConditionals if else switch case fall default
syn keyword pineRepeat for
syn keyword pineBooleans true false
syn keyword pineStatements return break continue defer extern
syn keyword pineWordOperators sizeof cast

syntax match pineOperators /\v[|$+%-;:=<>!&^()[\]{}*\/]/

syntax region pineString start=/\v"/ skip=/\v\\./ end=/\v"/ contains=pineEscapes
syntax region pineChar start=/\v'/ skip=/\v\\./ end=/\v'/ contains=pineEscapes
syntax match pineNumber /\<[0-9]\+\>/

syntax match pineHex /\<0x[0-9A-Fa-f]\+\>/
syntax match pineBinary /\<0b[0-1]\+\>/
syntax match pineOctal /\<0o[0-7]\+\>/

syntax match pineEscapes /\\[nr\"']/

hi link pineTypes Type
hi link pineFn Function
hi link pineStructures Structure
hi link pineConditionals Conditional
hi link pineRepeat Repeat
hi link pineBooleans Boolean
hi link pineStatements Keyword

hi link pineOperators Operator
hi link pineWordOperators Operator

hi link pineString String
hi link pineChar Character

hi link pineNumber Number
hi link pineHex Number
hi link pineBinary Number
hi link pineOctal Number

let b:current_syntax = "pine"
