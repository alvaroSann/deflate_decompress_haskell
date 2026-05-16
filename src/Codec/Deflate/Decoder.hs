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

-- Добавление одного байта в начало истории (так как список перевернут)
addByte :: Word8 -> DecompressM ()
addByte w = modify (w:)

-- Оптимизированное копирование из истории (LZ77)
-- Избавились от посимвольного поиска (!!) со сложностью O(N), который вешал декодер
copyBytes :: Int -> Int -> DecompressM ()
copyBytes dist len = do
    hist <- get
    let (_, targetTail) = splitAt (dist - 1) hist
        -- Корректно обрабатываем случай, когда длина копирования больше дистанции (самокопирование)
        cycledPattern = take len (cycle (take dist targetTail))
    modify (\h -> reverse cycledPattern ++ h)

-- Поднимаем операции чтения битов из BitReader в DecompressM
readBitD :: DecompressM Bool
readBitD = lift readBit

readBitsD :: Int -> DecompressM Int
readBitsD n = lift $ readBits n

skipToByteBoundaryD :: DecompressM ()
skipToByteBoundaryD = lift skipToByteBoundary

-- Вспомогательная функция для чтения дополнительных бит длины/дистанции
readExtraBits :: Int -> Int -> DecompressM Int
readExtraBits base extraBits
    | extraBits > 0 = (base +) <$> readBitsD extraBits
    | otherwise     = return base

-- Основной цикл декодирования внутри блока (переписан на более идиоматичный case-guard)
decodeData :: HuffmanTree -> HuffmanTree -> DecompressM ()
decodeData litTree distTree = do
    sym <- decodeSymbol litTree readBitD
    case sym of
        _ | sym < 256 -> do
            addByte (fromIntegral sym)
            decodeData litTree distTree
            
        256 -> return () -- Конец текущего блока
        
        _ -> do -- Коды длины (257--285)
            let (baseLen, extraLenBits) = lengthCodes !! (sym - 257)
            length <- readExtraBits baseLen extraLenBits
            
            distSym <- decodeSymbol distTree readBitD
            let (baseDist, extraDistBits) = distCodes !! distSym
            distance <- readExtraBits baseDist extraDistBits
            
            copyBytes distance length
            decodeData litTree distTree

-- Блок без сжатия (BTYPE=00)
processStoredBlock :: DecompressM ()
processStoredBlock = do
    skipToByteBoundaryD
    len  <- readBitsD 16
    nlen <- readBitsD 16
    
    -- Проверка, что NLEN — побитовое дополнение LEN
    if nlen /= (complement len .&. 0xFFFF)
        then lift $ throwError "Error: LEN/NLEN mismatch in stored block"
        else replicateM_ len $ do
            byte <- readBitsD 8
            addByte (fromIntegral byte)

-- Блок со статическими кодами Хаффмана (BTYPE=01)
processFixedBlock :: DecompressM ()
processFixedBlock = decodeData fixedLitLenTree fixedDistTree

-- Блок с динамическими кодами Хаффмана (BTYPE=10)
processDynamicBlock :: DecompressM ()
processDynamicBlock = do
    hlit  <- (+257) <$> readBitsD 5
    hdist <- (+1)   <$> readBitsD 5
    hclen <- (+4)   <$> readBitsD 4

    -- Порядок обхода кодов длин согласно спецификации RFC 1951
    let codesOrder = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    clLens <- replicateM hclen (readBitsD 3)
    let clArr = foldl'
            (\arr (i, len) -> updateList arr (codesOrder !! i) len)
            (replicate 19 0)
            (zip [0..] clLens)

    -- Дерево для декодирования длин кодов
    codeTree <- case buildTree clArr of
        Just t  -> return t
        Nothing -> lift $ throwError "Error: Failed to build code length tree"

    -- Читаем длины для литералов/длин и расстояний
    litLenLengths <- lift $ readLengths codeTree hlit readBit readBits
    distLengths   <- lift $ readLengths codeTree hdist readBit readBits

    -- Строим основные деревья для блока
    litTree <- case buildTree litLenLengths of
        Just t  -> return t
        Nothing -> lift $ throwError "Error: Failed to build literal/length tree"
    
    distTree <- case buildTree distLengths of
        Just t  -> return t
        Nothing -> lift $ throwError "Error: Failed to build distance tree"

    decodeData litTree distTree

-- Безопасное и быстрое обновление элемента списка без лишних аллокаций памяти
updateList :: [a] -> Int -> a -> [a]
updateList [] _ _     = []
updateList (_:xs) 0 y = y : xs
updateList (x:xs) n y = x : updateList xs (n - 1) y

-- Главная функция: разбираем поток на блоки, пока не встретим финальный
decompressAll :: DecompressM ()
decompressAll = do
    final <- readBitD    -- BFINAL (1 бит)
    btype <- readBitsD 2 -- BTYPE  (2 бита)
    case btype of
        0 -> processStoredBlock
        1 -> processFixedBlock
        2 -> processDynamicBlock
        _ -> lift $ throwError $ "Error: Unknown block type: " ++ show btype
    unless final decompressAll
