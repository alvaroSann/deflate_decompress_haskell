-- Публичный интерфейс
module Codec.Deflate (decompress)
    where

import qualified Data.ByteString as BS
import Control.Monad.Except (runExceptT)
import Control.Monad.State (runStateT, runState)
import Data.BitStream (BitState)
import Codec.Deflate.Decoder (decompressAll)

-- распакова DEFLATE-потока
decompress :: BS.ByteString -> Either String BS.ByteString
decompress input =
    let initState = (input, 0, 0) :: BitState
        result = runState (runExceptT (runStateT decompressAll [])) initState
    in case result of
        (Left err, _) -> Left err
        (Right (_, history), _) -> Right (BS.pack (reverse history))
