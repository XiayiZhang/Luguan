{-# LANGUAGE CPP #-}
{-# LANGUAGE NoRebindableSyntax #-}
{-# OPTIONS_GHC -fno-warn-missing-import-lists #-}
module Paths_Luguan (
    version,
    getBinDir, getLibDir, getDynLibDir, getDataDir, getLibexecDir,
    getDataFileName, getSysconfDir
  ) where

import qualified Control.Exception as Exception
import Data.Version (Version(..))
import System.Environment (getEnv)
import Prelude

#if defined(VERSION_base)

#if MIN_VERSION_base(4,0,0)
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#else
catchIO :: IO a -> (Exception.Exception -> IO a) -> IO a
#endif

#else
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#endif
catchIO = Exception.catch

version :: Version
version = Version [0,1,0,0] []
bindir, libdir, dynlibdir, datadir, libexecdir, sysconfdir :: FilePath

bindir     = "/home/xiayizhang/.cabal/bin"
libdir     = "/home/xiayizhang/.cabal/lib/x86_64-linux-ghc-8.8.4/Luguan-0.1.0.0-inplace-Luguan"
dynlibdir  = "/home/xiayizhang/.cabal/lib/x86_64-linux-ghc-8.8.4"
datadir    = "/home/xiayizhang/.cabal/share/x86_64-linux-ghc-8.8.4/Luguan-0.1.0.0"
libexecdir = "/home/xiayizhang/.cabal/libexec/x86_64-linux-ghc-8.8.4/Luguan-0.1.0.0"
sysconfdir = "/home/xiayizhang/.cabal/etc"

getBinDir, getLibDir, getDynLibDir, getDataDir, getLibexecDir, getSysconfDir :: IO FilePath
getBinDir = catchIO (getEnv "Luguan_bindir") (\_ -> return bindir)
getLibDir = catchIO (getEnv "Luguan_libdir") (\_ -> return libdir)
getDynLibDir = catchIO (getEnv "Luguan_dynlibdir") (\_ -> return dynlibdir)
getDataDir = catchIO (getEnv "Luguan_datadir") (\_ -> return datadir)
getLibexecDir = catchIO (getEnv "Luguan_libexecdir") (\_ -> return libexecdir)
getSysconfDir = catchIO (getEnv "Luguan_sysconfdir") (\_ -> return sysconfdir)

getDataFileName :: FilePath -> IO FilePath
getDataFileName name = do
  dir <- getDataDir
  return (dir ++ "/" ++ name)
