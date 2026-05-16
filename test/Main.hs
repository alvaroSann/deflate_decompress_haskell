module Main where

import Codec.Deflate
import qualified Data.ByteString as BS
import System.Exit (exitFailure)

main :: IO ()
main = do
    -- Тест №1: пустой stored-блок
    let emptyDeflate = BS.pack [0x01, 0x00, 0x00, 0xff, 0xff]
    case decompress emptyDeflate of
        Right result | result == BS.empty -> putStrLn "PASS"
        other -> putStrLn ("FAIL: " ++ show other) >> exitFailure

    -- Тест №2: stored-блок с "Hello"
    let helloStored = BS.pack [0x01, 0x05, 0x00, 0xFA, 0xFF, 0x48,0x65,0x6c,0x6c,0x6f]
    case decompress helloStored of
        Right result | result == BS.pack [0x48,0x65,0x6c,0x6c,0x6f] -> putStrLn "PASS"
        other -> putStrLn ("FAIL" ++ show other) >> exitFailure

    -- Тест №3: stored-блок с "Jeszcze Polska nie zginęła"
    let hymnStored = BS.pack
            [ 0x01               -- header
            , 0x1C, 0x00         -- LEN = 28 (little-endian)
            , 0xE3, 0xFF         -- NLEN = ~LEN (little-endian)
            
            , 0x4A, 0x65, 0x73, 0x7A, 0x63, 0x7A, 0x65    -- "Jeszcze"
            , 0x20                                        -- пробел
            , 0x50, 0x6F, 0x6C, 0x73, 0x6B, 0x61          -- "Polska"
            , 0x20                                        -- пробел
            , 0x6E, 0x69, 0x65                            -- "nie"
            , 0x20                                        -- пробел
            , 0x7A, 0x67, 0x69, 0x6E                      -- "zgin"
            , 0xC4, 0x99                                  -- 'ę'
            , 0xC5, 0x82                                  -- 'ł'
            , 0x61                                        -- 'a'
            ]

    let expected = BS.pack [0x4A, 0x65, 0x73, 0x7A, 0x63, 0x7A, 0x65, 0x20 , 0x50, 0x6F, 0x6C, 0x73, 0x6B, 0x61 , 0x20 , 0x6E, 0x69, 0x65 , 0x20 , 0x7A, 0x67, 0x69, 0x6E , 0xC4, 0x99 , 0xC5, 0x82 , 0x61]
    
    case decompress hymnStored of
        Right result | result == expected -> putStrLn "PASS"
        other -> putStrLn ("FAIL: " ++ show other) >> exitFailure

    putStrLn "All tests passed."
