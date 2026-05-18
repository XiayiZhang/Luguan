module Brainfuck where

import Control.Monad.State
import Data.Sequence (Seq, (|>), index, adjust)
import qualified Data.Sequence as Seq

data Instr = Inc | Dec | Lef | Rig | Output | Input | Loop [Instr]
  deriving Show

parse :: String -> [Instr]
parse = go []
  where
    go acc [] = reverse acc
    go acc ('+':cs) = go (Inc : acc) cs
    go acc ('-':cs) = go (Dec : acc) cs
    go acc ('>':cs) = go (Rig : acc) cs
    go acc ('<':cs) = go (Lef : acc) cs
    go acc ('.':cs) = go (Output : acc) cs
    go acc (',':cs) = go (Input : acc) cs
    go acc ('[':cs) =
      let (sub, rest) = extractLoop cs
          loopInstr = Loop (parse sub)
      in go (loopInstr : acc) rest
    go acc (']':_) = error "unmatched ']'"
    go acc (_:cs) = go acc cs--忽略

    --匹配[]
    extractLoop :: String -> (String, String)
    extractLoop s = loop 0 s ""
      where
        loop _ [] _ = error "unmatched '['"
        loop 0 (']':rest) acc = (reverse acc, rest)
        loop n (']':rest) acc = loop (n-1) rest (']':acc)
        loop n ('[':rest) acc = loop (n+1) rest ('[':acc)
        loop n (c:rest)   acc = loop n rest (c:acc)

--
type Mem = Seq Int
type BFState = State (Mem, Int, [Int]) ()

exec :: [Instr] -> BFState
exec [] = return ()
exec (i:is) = do
  (mem, ptr, out) <- get
  case i of
    Inc -> put (adjust (+1) ptr mem, ptr, out) >> exec is
    Dec -> put (adjust (subtract 1) ptr mem, ptr, out) >> exec is
    Rig -> do
      let newPtr = ptr + 1
      let newMem = if newPtr >= Seq.length mem then mem |> 0 else mem
      put (newMem, newPtr, out) >> exec is
    Lef -> put (mem, max 0 (ptr - 1), out) >> exec is
    Output -> do
      let val = index mem ptr
      put (mem, ptr, val:out) >> exec is
    Input -> exec is   -- 忽略输入
    Loop body -> do
      (m, p, _) <- get
      if index m p == 0
        then exec is
        else do
          exec body
          exec (Loop body : is)


bf :: [Int] -> String -> [Int]
bf initialMem prog = reverse output
  where
    instrs = parse prog
    (_, (_, _, output)) = runState (exec instrs) (Seq.fromList initialMem, 0, [])