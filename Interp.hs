{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE FlexibleContexts #-}

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
    deriving (Eq, Show)

type Env = Map.Map String Value
type Eval a = ExceptT String IO a

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
        ExprFuncCall _ _ -> throwError "函数调用未实现"
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

                _ -> throwError "内置函数 bf 需要两个参数: [Int] 和 String"
            where
                extractInt :: Value -> Eval Integer
                extractInt (VInt n) = pure n
                extractInt _        = throwError "列表中的元素不是整数"
        ExprNull -> pure VUnit
        ExprSome _ -> throwError "optional 暂不支持"
        ExprMatch _ _ _ -> throwError "match 表达式暂不支持"
        ExprList _ -> throwError "列表表达式暂不支持"

evalLit :: Lit -> Eval Value
evalLit = \case
    LitInt n -> pure (VInt (fromIntegral n))
    LitBool b -> pure (VBool b)
    LitNull -> pure VUnit
    LitString _ -> throwError "字符串文字暂不支持"

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