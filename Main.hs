module Main where

import System.Environment (getArgs)
import Parser (readlgFile, readProgramFromFile)
import Brainfuck (bf)
import Interp (runProgram, runSource)
import Types (Program)

main :: IO ()
main = do
	-- print $ bf [0,0,0] "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+."
	args <- getArgs
	case args of
		[path] -> do
			res <- readProgramFromFile "🦌🧪️" path--读取".🦌🧪️"文件
			case res of
				Right prog -> do
					print prog
					runProgram prog
				Left err -> putStrLn $ "Error: " ++ err
		_ -> putStrLn "Usage: Luguan <file>"
