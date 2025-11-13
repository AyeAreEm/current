" Vim syntax file
" Language: Current

if exists("b:current_syntax")
    finish
endif

syn keyword currentTypes void bool u8 u16 u32 u64 usize i8 i16 i32 i64 isize f32 f64 string cstring char
syn keyword currentFn fn
syn keyword currentStructures struct enum
syn keyword currentConditionals if else switch
syn keyword currentRepeat for
syn keyword currentBooleans true false
syn keyword currentStatements return break continue defer extern
syn keyword currentWordOperators sizeof cast

syntax match currentOperators /\v[|$+%-;:=<>!&^()[\]{}*\/]/

syntax region currentString start=/\v"/ skip=/\v\\./ end=/\v"/ contains=currentEscapes
syntax region currentChar start=/\v'/ skip=/\v\\./ end=/\v'/ contains=currentEscapes
syntax match currentNumber /\<[0-9]\+\>/

syntax match currentHex /\<0x[0-9A-Fa-f]\+\>/
syntax match currentBinary /\<0b[0-1]\+\>/
syntax match currentOctal /\<0o[0-7]\+\>/

syntax match currentEscapes /\\[nr\"']/

hi link currentTypes Type
hi link currentFn Function
hi link currentStructures Structure
hi link currentConditionals Conditional
hi link currentRepeat Repeat
hi link currentBooleans Boolean
hi link currentStatements Keyword

hi link currentOperators Operator
hi link currentWordOperators Operator

hi link currentString String
hi link currentChar Character

hi link currentNumber Number
hi link currentHex Number
hi link currentBinary Number
hi link currentOctal Number

let b:current_syntax = "current"
