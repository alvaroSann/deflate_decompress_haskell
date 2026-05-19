{-# LANGUAGE NoRebindableSyntax #-}
{-# OPTIONS_GHC -fno-warn-missing-import-lists #-}
{-# OPTIONS_GHC -w #-}
module PackageInfo_deflate_decompress (
    name,
    version,
    synopsis,
    copyright,
    homepage,
  ) where

import Data.Version (Version(..))
import Prelude

name :: String
name = "deflate_decompress"
version :: Version
version = Version [0,1,0,0] []

synopsis :: String
synopsis = "Educational implementation of DEFLATE decompressor."
copyright :: String
copyright = ""
homepage :: String
homepage = ""
