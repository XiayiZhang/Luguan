module Parser (readlgFile) where

import Types
import System.FilePath (takeExtension)
import Data.Char (toLower)
import Text.Read (readMaybe)
import Control.Exception (try, SomeException)
import Text.Parsec hiding (try)
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
            eres <- try (readFile path) :: IO (Either SomeException String)
            return $ case eres of
                Left e  -> Left (show e)
                Right s -> Right s

--  --------------------------------------------------------------------

langDef :: Token.LanguageDef ()
langDef = emptyDef
  { Token.commentStart    = "/*"
  , Token.commentEnd      = "*/"
  , Token.commentLine     = "//"
  , Token.nestedComments  = True
  , Token.identStart      = letter
  , Token.identLetter     = alphaNum
  , Token.reservedNames   = ["if", "else", "then"]
  , Token.reservedOpNames = ["=", "+", "-", "*", "/", "==", "<", ">"]
  , Token.caseSensitive   = True
  }

lexer :: Token.TokenParser ()
lexer = Token.makeTokenParser langDef

identifier = Token.identifier lexer
reserved   = Token.reserved lexer
reservedOp = Token.reservedOp lexer
integer    = Token.integer lexer
whiteSpace = Token.whiteSpace lexer
semi       = Token.semi lexer
comma      = Token.comma lexer
parens     = Token.parens lexer

-- 还没写完

textParser :: String -> Either ParseError String
textParser = parse (many anyChar) ""