-- Утилита для распаковки DEFLATE-потока, заданного в виде hex-строки.
-- Использование: cabal run deflate-test -- <hex-строка>
-- Пример: cabal run deflate-test -- f348cdc9c9d75108cf2fca4951640000

module Main where

import Codec.Deflate (decompress)
import qualified Data.ByteString as BS
import Data.Word (Word8)
import Numeric (readHex)
import System.Environment (getArgs)
import System.Exit (exitFailure)

main :: IO ()
main = do
    args <- getArgs
    case args of
        [hex] -> do
            let bytes = hexToBytes hex
            case decompress (BS.pack bytes) of
                Left err -> putStrLn ("Ошибка распаковки: " ++ err) >> exitFailure
                Right result -> BS.putStr result >> putStrLn ""   -- BS.putStr + перевод строки
        _ -> putStrLn "Использование: cabal run deflate-test -- <hex-строка>"

-- Преобразование hex-строки в список байт
hexToBytes :: String -> [Word8]
hexToBytes [] = []
hexToBytes (a:b:rest) =
    let [(val, "")] = readHex [a,b]
    in fromIntegral val : hexToBytes rest
hexToBytes _ = error "Нечётная длина hex-строки"
