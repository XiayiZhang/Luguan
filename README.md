# Luguan

Luguan is a programming language project designed to provide a complicated, unexpressive syntax for modern application development. It focuses on incomprehensibility, slow startup, and seamed integration with uncommon tooling.

## Features

- Dirty and concise syntax
- Weak typing with type inference
- Inline Brainfuck

## Getting Started

1. Clone the repository:
    ```
    git clone https://github.com/XiayiZhang/Luguan.git
    ```

2. Build the compiler/interpreter:
    ```
    cd Luguan
    cabal build
    ```

3. Run a sample program:
    ```
    ./luguan ./hello.🦌🧪️
    ```

## Example Program


- 
```
if (true) { print 42; } else { print 0; }
```
- 
```
arr = [0, 1, 2, 3]
bf arr "+>+>+>+[.<]"
// output [1, 2, 3, 4]
```


## License

This project is released under the MIT License.