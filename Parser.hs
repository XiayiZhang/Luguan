module Parser (readlgFile, readProgramFromFile, parseProgram) where

import Types
import System.FilePath (takeExtension)
import Data.Char (toLower)
import Data.Functor.Identity
import qualified Control.Exception as CE
import Text.Parsec
import Text.Parsec.Expr
import qualified Text.Parsec.Token as Token
import Text.Parsec.Language (emptyDef)

readlgFile :: String -> FilePath -> IO (Either String String)
readlgFile ext path = do
    let fileExt = map toLower (takeExtension path)
        wantExt = if null ext then ""
          else let dot = if head ext == '.' then "" else "."
               in dot ++ map toLower ext
    if not (null wantExt) && fileExt /= wantExt
        then return $ Left $ "Unexpected extension: " ++ fileExt ++ ", expected: " ++ wantExt
        else do
            eres <- CE.try (readFile path) :: IO (Either CE.SomeException String)
            return $ case eres of
                Left e  -> Left (show e)
                Right s -> Right s

readProgramFromFile :: String -> FilePath -> IO (Either String Program)
readProgramFromFile ext path = do
    eres <- readlgFile ext path
    return $ case eres of
        Left err -> Left err
        Right src -> case parseProgram src of
            Left parseErr -> Left (show parseErr)
            Right prog -> Right prog

--  --------------------------------------------------------------------

langDef :: Token.LanguageDef ()
langDef = emptyDef
  { Token.commentStart    = "/*"
  , Token.commentEnd      = "*/"
  , Token.commentLine     = "//"
  , Token.nestedComments  = True
  , Token.identStart      = letter
  , Token.identLetter     = alphaNum
  , Token.reservedNames   = ["if", "else", "then", "while", "input", "print",
                             "null", "true", "false", "func", "int", "bool",
                             "optional", "some"]
  , Token.reservedOpNames = ["=", "+", "-", "*", "/", "==", "!=", "<", "<=",
                             ">", ">=", "&&", "||", ":", "!"]
  , Token.caseSensitive   = True
  }

lexer :: Token.TokenParser ()
lexer = Token.makeTokenParser langDef

identifier :: Parsec String () String
identifier = Token.identifier lexer

reserved :: String -> Parsec String () ()
reserved   = Token.reserved lexer

reservedOp :: String -> Parsec String () ()
reservedOp = Token.reservedOp lexer

integer :: Parsec String () Integer
integer    = Token.integer lexer

whiteSpace :: Parsec String () ()
whiteSpace = Token.whiteSpace lexer

semi :: Parsec String () String
semi       = Token.semi lexer

comma :: Parsec String () String
comma      = Token.comma lexer

parens :: Parsec String () a -> Parsec String () a
parens     = Token.parens lexer

braces :: Parsec String () a -> Parsec String () a
braces     = Token.braces lexer

commaSep :: Parsec String () a -> Parsec String () [a]
commaSep   = Token.commaSep lexer

parseProgram :: String -> Either ParseError Program
parseProgram = parse (whiteSpace *> programParser <* eof) ""

programParser :: Parsec String () Program
programParser = Program <$> many funcParser <*> many stmtParser

funcParser :: Parsec String () Func
funcParser = do
    reserved "func"
    name <- identifier
    params <- parens (commaSep paramParser)
    reservedOp ":"
    retType <- typeParser
    body <- blockParser
    return $ Func name params retType body

paramParser :: Parsec String () Param
paramParser = (,) <$> identifier <*> (reservedOp ":" *> typeParser)

typeParser :: Parsec String () Type
typeParser =  TypeInt <$ reserved "int"
          <|> TypeBool <$ reserved "bool"
          <|> TypeOptional <$> (reserved "optional" *> typeParser)

blockParser :: Parsec String () [Stmt]
blockParser = braces (many stmtParser)

stmtParser :: Parsec String () Stmt
stmtParser = choice
    [ ifStmtParser
    , whileStmtParser
    , inputStmtParser
    , printStmtParser
    , assignStmtParser
    , blockStmtParser
    ]

ifStmtParser :: Parsec String () Stmt
ifStmtParser = do
    reserved "if"
    cond <- parens exprParser
    thenBranch <- blockParser
    elseBranch <- option [] (reserved "else" *> blockParser)
    return $ If cond thenBranch elseBranch

whileStmtParser :: Parsec String () Stmt
whileStmtParser = While <$> (reserved "while" *> parens exprParser) <*> blockParser

inputStmtParser :: Parsec String () Stmt
inputStmtParser = Input <$> (reserved "input" *> identifier <* semi)

printStmtParser :: Parsec String () Stmt
printStmtParser = Print <$> (reserved "print" *> exprParser <* semi)

assignStmtParser :: Parsec String () Stmt
assignStmtParser = Assign <$> identifier <*> (reservedOp "=" *> exprParser <* semi)

blockStmtParser :: Parsec String () Stmt
blockStmtParser = Block <$> blockParser

exprParser :: Parsec String () Expr
exprParser = buildExpressionParser operatorTable termParser

operatorTable :: [[Operator String () Identity Expr]]
operatorTable =
    [ [prefix "!" ExprNot]
    , [binary "*" (ExprBinOp Mul) AssocLeft, binary "/" (ExprBinOp Div) AssocLeft]
    , [binary "+" (ExprBinOp Add) AssocLeft, binary "-" (ExprBinOp Sub) AssocLeft]
    , [binary "==" (ExprBinOp Eq) AssocNone, binary "!=" (ExprBinOp Neq) AssocNone,
       binary "<" (ExprBinOp Lt) AssocNone, binary "<=" (ExprBinOp Leq) AssocNone,
       binary ">" (flipExpr ExprBinOp Lt) AssocNone, binary ">=" (flipExpr ExprBinOp Leq) AssocNone]
    , [binary "&&" (ExprBinOp And) AssocRight]
    , [binary "||" (ExprBinOp Or) AssocRight]
    ]
  where
        flipExpr constructor op = \x y -> constructor op y x

binary :: String -> (Expr -> Expr -> Expr) -> Assoc -> Operator String () Identity Expr
binary name fun assoc = Infix (reservedOp name *> pure fun) assoc

prefix :: String -> (Expr -> Expr) -> Operator String () Identity Expr
prefix name fun = Prefix (reservedOp name *> pure fun)

termParser :: Parsec String () Expr
termParser = choice
    [ parens exprParser
    , try funcCallParser
    , ExprVar <$> identifier
    , ExprLit <$> literalParser
    , ExprNull <$ reserved "null"
    , ExprSome <$> (reserved "some" *> parens exprParser)
    ]

funcCallParser :: Parsec String () Expr
funcCallParser = ExprFuncCall <$> identifier <*> parens (commaSep exprParser)

literalParser :: Parsec String () Lit
literalParser =  LitBool True <$ reserved "true"
             <|> LitBool False <$ reserved "false"
             <|> LitInt . fromInteger <$> integer

--  --------------------------------------------------------------------

textParser :: String -> Either ParseError String
textParser = parse (many anyChar) ""
