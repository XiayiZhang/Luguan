module Parser (readProgramFromFile) where

import Types
import System.FilePath (takeExtension)
import Data.Char (toLower)
import Text.Read (readMaybe)
import Control.Exception (try, SomeException)


readProgramFromFile :: String -> FilePath -> IO (Either String Program)
readProgramFromFile ext path = do
    let fileExt = map toLower (takeExtension path)
        wantExt = if null ext then "" else if head ext == '.' then map toLower ext else '.':map toLower ext
    if fileExt /= wantExt
       then return $ Left $ "Unexpected extension: " ++ fileExt ++ ", expected: " ++ wantExt
       else do
           eres <- try (readFile path) :: IO (Either SomeException String)
           case eres of
             Left e -> return $ Left $ show e
             Right s ->
               case readMaybe s of
                 Just prog -> return $ Right prog
                 Nothing -> return $ Left "Failed to parse Program using Read. Ensure file contains a Haskell 'Program' value (Show/Read format)."
