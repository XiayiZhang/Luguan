module Main where

import System.Environment (getArgs)
import Parser (readProgramFromFile)

main :: IO ()
main = do
	args <- getArgs
	case args of
		[path] -> do
			res <- readProgramFromFile "🦌🧪️" path--读取".🦌🧪️"文件
			case res of
				Right prog -> print prog
				Left err -> putStrLn $ "Error: " ++ err
		_ -> putStrLn "Usage: Luguan <file>"
