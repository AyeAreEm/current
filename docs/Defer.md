# Defer
Statements inside of a `defer` will be executed at the end of its scope in reverse order.<br>
This will print "hello world".
```
defer print("world");
print("hello ");
```

Having multiple defer statements can show how it executes in reverse order.<br>
This will print "worldhello".
```
defer print("world");
defer print("hello");
```
This fact is useful when freeing memory since anything relying on that memory won't be using freed memory.
```
window := window_create();
defer window.close();

renderer := renderer_init(window);
defer renderer.deinit();
```
This is the same as doing this
```
window := window_create();
renderer := renderer_init(window);

renderer.deinit();
window.close();
```

You can also defer blocks of code by using a scope block `{}` after `defer`
```
defer {
    ...
}

```
