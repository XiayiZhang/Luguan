{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE FlexibleContexts #-}
{-# OPTIONS_GHC -Wno-incomplete-patterns #-}

module Interp
    ( runProgram
    , runSource
    ) where

import Types
import Parser
import Control.Monad.Except
import qualified Data.Map.Strict as Map
import Brainfuck (bf)

data Value
    = VInt Integer
    | VBool Bool
    | VUnit
    | VString String
    | VList [Value]
    |VSome Value
    deriving (Eq, Show)

type Env = Map.Map String Value
type Eval a = ExceptT String IO a

insertAt :: Int -> a -> [a] -> [a]
insertAt i x xs = take i xs ++ [x] ++ drop i xs

replaceAt :: [a] -> Int -> a -> [a]
replaceAt xs i x = take i xs ++ [x] ++ drop (i + 1) xs

runProgram :: Program -> IO ()
runProgram prog = do
    result <- runExceptT (evalProgram Map.empty prog)
    case result of
        Left err -> putStrLn ("运行错误: " ++ err)
        Right _ -> pure ()

runSource :: String -> IO ()
runSource src =
    case parseProgram src of
        Left err -> putStrLn ("解析错误: " ++ show err)
        Right prog -> runProgram prog

evalProgram :: Env -> Program -> Eval Env
evalProgram env (Program _ stmts) = evalStmts env stmts

evalStmts :: Env -> [Stmt] -> Eval Env
evalStmts env [] = pure env
evalStmts env (s:ss) = do
    env' <- evalStmt env s
    evalStmts env' ss

evalStmt :: Env -> Stmt -> Eval Env
evalStmt env stmt =
    case stmt of
        Assign name expr -> do
            v <- evalExpr env expr
            pure (Map.insert name v env)

        If cond thenBranch elseBranch -> do
            VBool b <- evalExpr env cond
            if b
                then evalStmts env thenBranch
                else evalStmts env elseBranch

        While cond body ->
            let loop e = do
                    VBool b <- evalExpr e cond
                    if b then evalStmts e body >>= loop else pure e
            in loop env

        Input name -> do
            line <- liftIO getLine
            case reads line of
                [(n, "")] -> pure (Map.insert name (VInt n) env)
                _ -> throwError "输入不是整数"

        Print expr -> do
            v <- evalExpr env expr
            liftIO (putStrLn (showValue v))
            pure env

        Block stmts -> evalStmts env stmts

        {-ExprIndex arrExpr idxExpr -> do
            VList vec <- evalExpr env arrExpr
            VInt idx <- evalExpr env idxExpr
            let i = fromIntegral idx
            if i < 0 || i >= length vec
            then throwError "数组索引越界"
            else pure (vec !! i)-}
            
        AssignIndex arrExpr idxExpr valExpr -> do
            arrVal <- evalExpr env arrExpr
            idxVal <- evalExpr env idxExpr
            newVal <- evalExpr env valExpr
            case (arrVal, idxVal) of
                (VList vec, VInt idx) -> do
                    let i = fromIntegral idx
                        len = length vec
                    if i < 0 || i >= len
                        then throwError "Index out of bounds"
                        else do
                            let newVec = take i vec ++ [newVal] ++ drop (i+1) vec
                    -- 假设 arrExpr 是变量（简化处理）
                            case arrExpr of
                                ExprVar name -> pure $ Map.insert name (VList newVec) env
                                _ -> throwError "Left side of index assignment must be a variable"
                _ -> throwError "Index assignment requires an array and an integer index"

evalExpr :: Env -> Expr -> Eval Value
evalExpr env expr =
    case expr of
        ExprLit lit -> evalLit lit
        ExprVar name ->
            case Map.lookup name env of
                Just v -> pure v
                Nothing -> throwError ("未定义变量: " ++ name)
        ExprBinOp op a b -> do
            va <- evalExpr env a
            vb <- evalExpr env b
            evalBinOp op va vb
        ExprNot e -> do
            VBool v <- evalExpr env e
            pure (VBool (not v))
        --ExprFuncCall _ _ -> throwError "函数调用未实现"
        ExprFuncCall "bf" args -> do -- 2026.5.30 1:38
            case args of
                [listArg, strArg] -> do
                    vList <- evalExpr env listArg
                    vStr  <- evalExpr env strArg
                    ints <- case vList of
                        VList vs -> mapM extractInt vs
                        _ -> throwError "bf arg1 must a list"
                    s <- case vStr of
                        VString str -> pure str
                        _ -> throwError "bf arg2 must be a string"
                    let ints' = map fromIntegral ints
                    let result = bf ints' s
                    pure (VList (map (VInt . fromIntegral) result))

                _ -> throwError "bf need 2 value [Int] & String"
            where
                extractInt :: Value -> Eval Integer
                extractInt (VInt n) = pure n
                extractInt _        = throwError "列表中的元素不是整数"
        ExprFuncCall "insert" args -> do
            case args of
                [listExpr, idxExpr, elemExpr] -> do
                    vList <- evalExpr env listExpr
                    vIdx  <- evalExpr env idxExpr
                    vElem <- evalExpr env elemExpr

                    case (vList, vIdx) of
                        (VList xs, VInt idx) -> do
                            let i = fromIntegral idx
                            if i < 0 || i > length xs   -- 允许在末尾插入（i == length）
                                then throwError "Index out of bounds for insert"
                                else pure $ VList (insertAt i vElem xs)
                        _ -> throwError "insert expects a list and an integer index"
                _ -> throwError "insert requires 3 arguments: list, index, element"
        ExprFuncCall "replace" args -> do
            case args of
                [listExpr, idxExpr, elemExpr] -> do
                    vList <- evalExpr env listExpr
                    vIdx  <- evalExpr env idxExpr
                    vElem <- evalExpr env elemExpr

                    case (vList, vIdx) of
                        (VList xs, VInt idx) -> do
                            let i = fromIntegral idx
                            if i < 0 || i > length xs   -- 允许在末尾插入（i == length）
                                then throwError "replace out of bounds for insert"
                                else pure $ VList (replaceAt xs i vElem)
                        _ -> throwError "replace expects a list and an integer index"
                _ -> throwError "replace requires 3 arguments: list, index, element"
        ExprFuncCall "read" args -> do
            case args of
                [listExpr, i] -> do
                    vList <- evalExpr env listExpr
                    vIdx  <- evalExpr env i

                    case (vList, vIdx) of
                        (VList xs, VInt idx) -> do
                            let i = fromIntegral idx
                            if i < 0 || i >= length xs
                                then throwError "Index out of bounds for read"
                                else pure $ xs !! i
                        _ -> throwError "read expects a list and an integer index"
                _ -> throwError "read requires 2 arguments: list, index"
        ExprFuncCall "delete" args -> do
            case args of
                [listExpr, i] -> do
                    vList <- evalExpr env listExpr
                    vIdx  <- evalExpr env i

                    case (vList, vIdx) of
                        (VList xs, VInt idx) -> do
                            let i = fromIntegral idx
                            if i < 0 || i >= length xs
                                then throwError "Index out of bounds for delete"
                                else pure $ VList (take i xs ++ drop (i + 1) xs)
                        _ -> throwError "delete expects a list and an integer index"
                _ -> throwError "delete requires 2 arguments: list, index"
        ExprNull -> pure VUnit
        ExprSome s ->do
            v <- evalExpr env s
            pure (VSome v)
        ExprMatch {} -> throwError "match 表达式暂不支持"
        ExprString s -> pure (VString s)
        ExprList es -> do
            vs <- mapM (evalExpr env) es
            pure (VList vs)  

evalLit :: Lit -> Eval Value
evalLit = \case
    LitInt n -> pure (VInt (fromIntegral n))
    LitBool b -> pure (VBool b)
    LitNull -> pure VUnit
    LitString s -> pure (VString s)

evalBinOp :: BinOp -> Value -> Value -> Eval Value
evalBinOp op (VInt a) (VInt b) =
    case op of
        Add -> pure (VInt (a + b))
        Sub -> pure (VInt (a - b))
        Mul -> pure (VInt (a * b))
        Div -> if b == 0
                   then throwError "除零错误"
                   else pure (VInt (a `div` b))
        Eq -> pure (VBool (a == b))
        Neq -> pure (VBool (a /= b))
        Lt -> pure (VBool (a < b))
        Leq -> pure (VBool (a <= b))
        And -> throwError "逻辑运算需要布尔值"
        Or -> throwError "逻辑运算需要布尔值"
evalBinOp op (VBool a) (VBool b) =
    case op of
        And -> pure (VBool (a && b))
        Or -> pure (VBool (a || b))
        Eq -> pure (VBool (a == b))
        Neq -> pure (VBool (a /= b))
        _ -> throwError ("运算符不适用于布尔值: " ++ show op)
evalBinOp _ _ _ = throwError "类型不匹配的二元运算"

showValue :: Value -> String
showValue = \case
    VInt i -> show i
    VBool b -> show b
    VUnit -> "()"
    VString s -> s
    VList l -> show l