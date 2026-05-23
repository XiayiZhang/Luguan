module Types where

type VarName = String

data Lit
    = LitInt Int
    | LitBool Bool
    | LitNull
    | LitString String
    deriving (Show, Eq, Read)

data Expr
    = ExprLit Lit
    | ExprVar VarName
    | ExprBinOp BinOp Expr Expr
    | ExprNot Expr
    | ExprFuncCall VarName [Expr]
    | ExprNull
    | ExprSome Expr
    | ExprMatch Expr Expr Expr
    | ExprList [Expr]
    deriving (Show, Eq, Read)

data BinOp
    = Add | Sub | Mul | Div--算术
    | Eq | Neq | Lt | Leq--比较
    | And | Or--逻辑
    deriving (Show, Eq, Read)

data Stmt
    = Assign VarName Expr
    | If Expr [Stmt] [Stmt]
    | While Expr [Stmt]
    | Input VarName
    | Print Expr
    | Block [Stmt]
    deriving (Show, Eq, Read)

data Type = TypeInt | TypeBool |TypeOptional Type
    deriving (Show, Eq, Read)

type Param = (VarName, Type)

data Func = Func
    { funcName :: VarName
    , funcParams :: [Param]
    , funcReturnType :: Type
    , funcBody :: [Stmt]
    }
    deriving (Show, Eq, Read)

data Program = Program
    { progFuncs :: [Func]
    , progMain :: [Stmt]
    }
    deriving (Show, Eq, Read)