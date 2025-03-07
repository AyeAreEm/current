gimme_five :: fn() i64 {
    five: i32 = 5;
    return five;
}

main :: fn() void {
    x := gimme_five();
}
