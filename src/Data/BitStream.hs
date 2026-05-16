-- Побитовое чтение из ByteString в формате DEFLATE: LSB first
module Data.BitStream
    (BitState, BitReader, readBit, readBits, skipToByteBoundary) where

import Control.Monad.Except
import Control.Monad.State
import Control.Monad (replicateM)
import Data.Bits
import Data.Word
import qualified Data.ByteString as BS

-- Создадим тип состояния битового ввода, который представляет собой тройку:
-- (оставшиеся байты, аккумулятор с байтом, количество ещё не прочитанных бит в аккумуляторе)
-- аккумулятор имеет тип Word64, чтобы без проблем хранить до 64 бит,
-- мы всегда храним там только что загруженный байт и сдвигаем его по мере чтения.
type BitState = (BS.ByteString, Word64, Int)

-- Создадим монаду для чтения битов: ExceptT String над State BitState
-- ExceptT позволяет кидать ошибки, State хранит состояние.
type BitReader a = ExceptT String (State BitState) a

-- Функция для прочтения ровно одного бита в LSB first формате
-- Если в аккумуляторе не осталось битов, берём следующий байт из ByteString, помещаем его в аккумулятор и сразу отдаём младший бит, иначе выдаём текущий младший бит и сдвигаем аккумулятор вправо:
readBit :: BitReader Bool
readBit = do
    (bs, acc, bits) <- get
    if bits == 0
        then case BS.uncons bs of
            -- если байты кончились, то кидаем ошибку
            Nothing -> throwError "Unexpected end of stream"
            -- иначе байты есть, и начинаем их обработку
            Just (byte, bs') -> do
                -- помещаем байт в аккумулятор, младший бит сразу доступен
                let acc' = fromIntegral byte :: Word64
                -- сразу сдвигаем аккумулятор на 1 вправо, чтобы следующий бит стал LSB
                -- а после оставляем 7 битов для чтения
                put (bs', acc' `shiftR` 1, 7)
                -- возвращаем самый младший бит загруженного байта
                return $ (acc' .&. 1) /= 0
        else do
            -- в противном случае в аккумуляторе ещё są биты
            put (bs, acc `shiftR` 1, bits - 1)
            return $ (acc .&. 1) /= 0

-- Функция для прочтения n битов, возвращает целое число
-- Биты собираются так, что первый прочитанный бит становится битом 0, то есть младшим, затем второй бит становится битом 1 и так далее:
readBits :: Int -> BitReader Int
readBits n = sum . zipWith (\i b -> if b then 2^i else 0) [0..] <$> replicateM n readBit -- :DDD

-- Чтобы readBit корректно читал строго с границы нового байта, нам надо обнулить счётчик битов и аккмулятор с предыдущего байта, что-то вроде alignmenta этих блоков.

-- Функция пропускает оставшиеся биты в текущем байте и переходит к началу следующего:
skipToByteBoundary :: BitReader ()
skipToByteBoundary = modify $ \(bs, _, _) -> (bs, 0, 0)

