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
import Data.List (intercalate)
import Brainfuck (bf)

data Value
    = VInt Integer
    | VBool Bool
    | VUnit
    | VString String
    | VList [Value]
    | VSome Value
    deriving (Eq, Show)

type Env = Map.Map String Value
type Eval a = ExceptT String IO a
type FuncEnv = Map.Map String Func

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
evalProgram env (Program funcs stmts) =
    let fenv = Map.fromList [(name, f) | f@(Func name _ _ _) <- funcs]
    in evalStmts fenv env stmts

evalStmts :: FuncEnv -> Env -> [Stmt] -> Eval Env
evalStmts fenv env [] = pure env
evalStmts fenv env (s:ss) = do
    env' <- evalStmt fenv env s
    evalStmts fenv env' ss

evalStmt :: FuncEnv -> Env -> Stmt -> Eval Env
evalStmt fenv env stmt =
    case stmt of
        Assign name expr -> do
            v <- evalExpr fenv env expr
            pure (Map.insert name v env)

        If cond thenBranch elseBranch -> do
            VBool b <- evalExpr fenv env cond
            if b
                then evalStmts fenv env thenBranch
                else evalStmts fenv env elseBranch

        While cond body ->
            let loop e = do
                    VBool b <- evalExpr fenv e cond
                    if b then evalStmts fenv e body >>= loop else pure e
            in loop env

        Input name -> do
            line <- liftIO getLine
            case reads line of
                [(n, "")] -> pure (Map.insert name (VInt n) env)
                _ -> throwError "输入不是整数"

        Print expr -> do
            v <- evalExpr fenv env expr
            liftIO (putStrLn (showValue v))
            pure env
        Block stmts -> evalStmts fenv env stmts
        {-ExprIndex arrExpr idxExpr -> do
            VList vec <- evalExpr env arrExpr
            VInt idx <- evalExpr env idxExpr
            let i = fromIntegral idx
            if i < 0 || i >= length vec
            then throwError "数组索引越界"
            else pure (vec !! i)-}
            
        AssignIndex arrExpr idxExpr valExpr -> do
            arrVal <- evalExpr fenv env arrExpr
            idxVal <- evalExpr fenv env idxExpr
            newVal <- evalExpr fenv env valExpr
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

evalExpr :: FuncEnv -> Env -> Expr -> Eval Value
evalExpr fenv env expr =
    case expr of
        ExprLit lit -> evalLit lit
        ExprVar name ->
            case Map.lookup name env of
                Just v -> pure v
                Nothing -> throwError ("未定义变量: " ++ name)
        ExprBinOp op a b -> do
            va <- evalExpr fenv env a
            vb <- evalExpr fenv env b
            evalBinOp op va vb
        ExprNot e -> do
            VBool v <- evalExpr fenv env e
            pure (VBool (not v))
        --ExprFuncCall _ _ -> throwError "函数调用未实现"
        ExprFuncCall "bf" args -> do -- 2026.5.30 1:38
            case args of
                [listArg, strArg] -> do
                    vList <- evalExpr fenv env listArg
                    vStr  <- evalExpr fenv env strArg
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
                    vList <- evalExpr fenv env listExpr
                    vIdx  <- evalExpr fenv env idxExpr
                    vElem <- evalExpr fenv env elemExpr

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
                    vList <- evalExpr fenv env listExpr
                    vIdx  <- evalExpr fenv env idxExpr
                    vElem <- evalExpr fenv env elemExpr

                    case (vList, vIdx) of
                        (VList xs, VInt idx) -> do
                            let i = fromIntegral idx
                            if i < 0 || i >= length xs
                                then throwError "replace out of bounds"
                                else pure $ VList (replaceAt xs i vElem)
                        _ -> throwError "replace expects a list and an integer index"
                _ -> throwError "replace requires 3 arguments: list, index, element"

        ExprFuncCall "read" args -> do
            case args of
                [listExpr, i] -> do
                    vList <- evalExpr fenv env listExpr
                    vIdx  <- evalExpr fenv env i

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
                    vList <- evalExpr fenv env listExpr
                    vIdx  <- evalExpr fenv env i

                    case (vList, vIdx) of
                        (VList xs, VInt idx) -> do
                            let i = fromIntegral idx
                            if i < 0 || i >= length xs
                                then throwError "Index out of bounds for delete"
                                else pure $ VList (take i xs ++ drop (i + 1) xs)
                        _ -> throwError "delete expects a list and an integer index"
                _ -> throwError "delete requires 2 arguments: list, index"

        ExprNull -> pure VUnit
        ExprSome s -> do
            v <- evalExpr fenv env s
            pure (VSome v)
        ExprMatch {} -> throwError "match 表达式暂不支持"
        ExprString s -> pure (VString s)
        ExprList es -> do
            vs <- mapM (evalExpr fenv env) es
            pure (VList vs)
        _ -> throwError "未实现的表达式形式"

evalExpr fenv env (ExprFuncCall name args) =
    case Map.lookup name fenv of
        Just (Func _ params _ body) -> do
            if length params /= length args
                then throwError "参数数量不匹配"
                else do
                    vals <- mapM (evalExpr fenv env) args
                    let paramNames = map fst params
                        localEnv = Map.fromList (zip paramNames vals)
                    _ <- evalStmts fenv (Map.union localEnv env) body
                    pure VUnit
        Nothing -> throwError ("未知函数: " ++ name)

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
    VList l -> "[" ++ intercalate ", " (map showValue l) ++ "]"