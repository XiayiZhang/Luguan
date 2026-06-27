# Luguan 开发指南

## 环境要求

- **GHC** >= 8.8（推荐使用 GHC 8.10 或更新版本）
- **Cabal** >= 2.4（推荐使用 Cabal 3.x）
- 支持 Windows/macOS/Linux

---

## 快速开始

### 1. 克隆并构建

```shell
git clone https://github.com/XiayiZhang/Luguan.git
cd Luguan
cabal build
```

### 2. 运行测试程序

```shell
cabal run Luguan examples/hello.🦌🧪️
cabal run Luguan examples/helloworld.🦌🧪️
cabal run Luguan examples/if_example.🦌🧪️
cabal run Luguan examples/while_count.🦌🧪️
cabal run Luguan examples/brainfuck.🦌🧪️
cabal run Luguan examples/bubblesort.🦌🧪️
cabal run Luguan examples/func_add.🦌🧪️
```

### 3. 使用 REPL

```shell
cabal repl
```

在 GHCi 中可以直接导入模块进行测试：

```haskell
:l Main
import Parser
import Interp

-- 解析并运行
let Right prog = parseProgram "print 42;"
runProgram prog

-- 直接运行源码
runSource "x = 1 + 2; print x;"
```

---

## 项目结构

```bash
Luguan/
├── Main.hs # 程序入口
├── Types.hs # AST 数据类型定义
├── Parser.hs # Parsec 解析器
├── Interp.hs # AST 解释器/求值器
├── Brainfuck.hs # Brainfuck 子语言解释器
├── Luguan.cabal # Cabal 构建配置
├── Setup.hs # Cabal 安装脚本
├── CHANGELOG.md # 版本变更日志
├── README.md # 项目说明
├── LICENSE # Apache-2.0 许可证
├── examples/ # 示例程序 (.🦌🧪️)
└── docs/ # 文档
```

---

## 模块依赖关系

```bash
Main.hs
 ├── Parser.hs
 │    └── Types.hs
 ├── Interp.hs
 │    ├── Types.hs
 │    ├── Parser.hs
 │    └── Brainfuck.hs
 └── Types.hs
```

---

## 构建配置

`Luguan.cabal` 中定义的依赖：

| 依赖 | 用途 |
| :-: | :-: |
| `base >=4.13 && <4.14` | Haskell 标准库 |
| `filepath >=1.4` | 文件扩展名处理 |
| `mtl` | monad 转换器（ExceptT、State） |
| `containers` | Map、Sequence 等容器 |
| `parsec` | 解析器组合子库 |

---

## 扩展示例

### 添加新语句类型

1. 在 `Types.hs` 的 `Stmt` 中添加新构造器
2. 在 `Parser.hs` 的 `stmtParser` 中添加解析规则
3. 在 `Interp.hs` 的 `evalStmt` 中添加求值逻辑

### 添加新内置函数

1. 在 `Interp.hs` 的 `evalExpr` 中 `ExprFuncCall` 分支下添加新匹配
2. 遵循现有内置函数（如 `bf`、`read`、`insert`）的模式

### 添加新类型

1. 在 `Types.hs` 的 `Type` 中添加新构造器
2. 在 `Types.hs` 的 `Value` 中添加对应的运行时值类型（在 `Interp.hs` 中）
3. 在 `Parser.hs` 的 `typeParser` 中添加解析
4. 在相关的运算符求值函数中处理新类型

---

## 测试

当前项目没有正式的测试套件。推荐使用 GHCi 进行手动测试：

```haskell
-- 测试解析
parseProgram "print 42;"

-- 测试求值
runSource "x = 10; print x;"

-- 测试 Brainfuck
import Brainfuck
bf [0,0,0] "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++. :-: . :-: --.>+."

-- 测试错误处理
runSource "print 1/0;"
```

---

## 已知限制

1. **函数调用尚未完整实现**：`ExprFuncCall` 在解释器中只匹配了内置函数名（`bf`、`read`、`insert`、`replace`、`delete`），用户定义函数的调用尚未实现
2. **`match` 表达式未实现**：在解释器中抛出错误
3. **无独立作用域**：所有变量共享全局环境
4. **输入仅支持整数**：`input` 语句只能读取整数值
5. **字符串仅支持字面量和打印**：无字符串操作函数
