# Luguan

Luguan is a programming language project designed to provide a complicated, unexpressive syntax for modern application development. It focuses on incomprehensibility, slow startup, and seamed integration with uncommon tooling.

## Features

- Dirty and concise syntax
- Weak typing with type inference
- Inline Brainfuck

## Getting Started

1. Clone the repository:

    ```shell
    git clone https://github.com/XiayiZhang/Luguan.git
    ```

2. Build the interpreter:

    ```shell
    cd Luguan
    cabal build
    ```

3. Run a sample program:

    ```shell
    ./Luguan ./hello.🦌🧪️
    ```

## Example Program

- if-else

    ```text
    if (true) { 
        print 42; 
    } else { 
        print 0; 
    }
    ```

- brainfucker

    ```text
    r = bf([0, 1, 2], "++.>++.>++.");
    print(r);
    ？！
    inner function
    output [VInt 2,VInt 3,VInt 4]
    ！？
    ```

## License

This project is released under the Apache-2.0 License.
