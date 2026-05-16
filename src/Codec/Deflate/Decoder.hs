-- Основная часть декодера DEFLATE, обработка всех трёх типов блоков и LZ77
module Codec.Deflate.Decoder (DecompressM, decompressAll)
    where

import Control.Monad.Except
import Control.Monad.State
import Control.Monad (replicateM, replicateM_, unless)
import Data.Bits
import Data.Word
import Data.List (foldl')
import qualified Data.ByteString as BS

import Data.BitStream
import Data.Huffman
import Codec.Deflate.GlobalTypes

-- Монада декомпрессора
-- храним историю вывода как список Word8 в обратном порядке
type DecompressM a = StateT [Word8] (ExceptT String (State BitState)) a

addByte :: Word8 -> DecompressM ()
addByte w = modify (w:)

-- копирование из истории (LZ77): distance — расстояние назад, length — сколько байт
copyBytes :: Int -> Int -> DecompressM ()
copyBytes dist len = replicateM_ len $ do
    hist <- get
    let byte = hist !! (dist - 1)
    modify (byte:)

-- поднимаем операции чтения битов из BitReader в DecompressM
readBitD :: DecompressM Bool
readBitD = lift readBit

readBitsD :: Int -> DecompressM Int
readBitsD n = lift $ readBits n

skipToByteBoundaryD :: DecompressM ()
skipToByteBoundaryD = lift skipToByteBoundary


-- основной цикл декодирования внутри блока
decodeData :: HuffmanTree -> HuffmanTree -> DecompressM ()
decodeData litTree distTree = do
    sym <- decodeSymbol litTree readBitD
    if sym < 256
        then do
            addByte (fromIntegral sym)
            decodeData litTree distTree
        else if sym == 256
            then return () -- конец блока
            else do -- длина + расстояние
                let (baseLen, extraLenBits) = lengthCodes !! (sym - 257)
                extraLen <- if extraLenBits > 0 then readBitsD extraLenBits else return 0
                let length = baseLen + extraLen
                distSym <- decodeSymbol distTree readBitD
                
                let (baseDist, extraDistBits) = distCodes !! distSym
                extraDist <- if extraDistBits > 0 then readBitsD extraDistBits else return 0
                
                let distance = baseDist + extraDist
                
                copyBytes distance length
                decodeData litTree distTree

-- блок без сжатия (BTYPE=00)
processStoredBlock :: DecompressM ()
processStoredBlock = do
    skipToByteBoundaryD
    len  <- readBitsD 16
    nlen <- readBitsD 16
    
    -- проверка, что NLEN - побитовое дополнение LEN
    if nlen /= (complement len .&. 0xFFFF)
        then lift $ throwError "Error: LEN/NLEN mismatch in stored block"
        else replicateM_ len $ do
            byte <- readBitsD 8
            addByte (fromIntegral byte)

-- блок с фикс. кодами Хаффмана (BTYPE=01)
processFixedBlock :: DecompressM ()
processFixedBlock = decodeData fixedLitLenTree fixedDistTree

-- блок с дин. кодами Хаффмана (BTYPE=10)
processDynamicBlock :: DecompressM ()
processDynamicBlock = do
    hlit  <- (+257) <$> readBitsD 5
    hdist <- (+1) <$> readBitsD 5
    hclen <- (+4) <$> readBitsD 4

    -- порядок обхода кодов
    let codesOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    clLens <- replicateM hclen (readBitsD 3)
    let clArr = foldl'
            (\arr (i, len) -> updateList arr (codesOrder !! i) len)
            (replicate 19 0)
            (zip [0..] clLens)

    -- дерево для декодирования длин кодов
    codeTree <- case buildTree clArr of
        Just t -> return t
        Nothing -> lift $ throwError "Error: Failed to build code length tree"

    -- читаем длины для литералов/длин и расстояний
    litLenLengths <- lift $ readLengths codeTree hlit readBit readBits
    distLengths <- lift $ readLengths codeTree hdist readBit readBits

    -- строим основные деревья
    litTree <- case buildTree litLenLengths of
        Just t -> return t
        Nothing -> lift $ throwError "Error: Failed to build literal/length tree"
    
    distTree <- case buildTree distLengths of
        Just t -> return t
        Nothing -> lift $ throwError "Error: Failed to build distance tree"

    decodeData litTree distTree

updateList :: [a] -> Int -> a -> [a]
updateList xs i x = take i xs ++ [x] ++ drop (i + 1) xs

-- разбираем поток на блоки, пока не встретим финальный
decompressAll :: DecompressM ()
decompressAll = do
    final <- readBitD -- BFINAL
    btype <- readBitsD 2 -- BTYPE
    case btype of
        0 -> processStoredBlock
        1 -> processFixedBlock
        2 -> processDynamicBlock
        _ -> lift $ throwError $ "Error: Unknown block type: " ++ show btype
    unless final decompressAll
