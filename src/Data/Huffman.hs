-- Построение канонических деревьев Хаффмана, декодирование символов и чтение длин кодов

module Data.Huffman 
    (HuffmanTree (..), buildTree, decodeSymbol, readLengths) where

import Control.Monad.Except
import Control.Monad.State
import Data.Bits
import Data.List (sortBy, mapAccumL, foldl')

-- Создадим объект двоичного дерева Хаффмана, который по структуре суть обычное дерево:
-- лист (Leaf) хранит символ aka целое число, а значение -1 означает "пустой лист", если это не лист, то дерево можно разбить на узел (Node) и поддеревья:
data HuffmanTree = Leaf Int | Node HuffmanTree HuffmanTree
    deriving Show

updateList :: [a] -> Int -> a -> [a]
updateList xs i x = take i xs ++ [x] ++ drop (i + 1) xs

-- Функция строит каноническое дерево Хаффмана по списку длин кодов.
-- На вход подаётся аргумент lengths - список длин для символов 0..(n - 1), а длина 0 означает, что символ не используется и в дерево не попадёт.
-- Если длины будут некорректно, то возвращаем Nothing
-- Длина 0 означает, что символ не используется и в дерево не попадёт.
buildTree :: [Int] -> Maybe HuffmanTree
buildTree lengths = Just tree
  where
    maxLen = 15  -- макс. длина в RFC 1951

    -- Великое построение дерева

    -- 1) подсчитываем, сколько символов имеют каждую длину от 1 до maxLen, получаем лист значений blCount:
    blCount = foldl'
        (\arr l -> if l > 0 then updateList arr l (arr !! l + 1) else arr)
        (replicate (maxLen + 1) 0)
        lengths

    -- 2) вычисляем next_code для каждой длины.
    -- next_code[i] - это наименьшее числовое значение для кода длины i, вычислять их будем итеративно как code = 0 - база, а дальше для bits из 1..maxLen применяем
    -- code = (code + blCount [bits - 1]) << 1
    nextCode = 0 : snd (mapAccumL
        (\code bits -> let c = (code + blCount !! (bits - 1)) `shiftL` 1 in (c, c))
        0 [1..maxLen])

    -- 3) сортируем символы парами из символа и длины: сначала по длине, а после по символу как требуется в RFC 1951
    syms_n_lens = [(i, l) | (i, l) <- zip [0..] lengths, l > 0]
    sorted = sortBy (\(s1, l1) (s2, l2) -> compare l1 l2 <> compare s1 s2) syms_n_lens

    -- 4) присваиваем коды символам в порядке сортировки, проходя по sorted, где текущий next_code[len] берётся как код символа, а после увеличиваем счётчик для символа длины len на 1 (то есть next_code[len] += 1):
    assign :: [Int] -> [(Int, Int)] -> ([Int], [Int]) -> ([Int], [Int])
    assign _ [] (nc, codes) = (nc, codes) -- всё закодировали
    assign nc ((sym, len) : rest) (ncUsed, codes) =
        let code = nc !! len -- берём код для символа длины len
            nc' = updateList nc len (code + 1) -- next_code[len] += 1
            codes' = updateList codes sym code -- запоминаем код символа
        in assign nc' rest (nc', codes')

    -- получаем массив кодов
    initialCodes = replicate (length lengths) 0
    (_, assignedCodes) = assign nextCode sorted (nextCode, initialCodes)

    -- Функция вставляет символ в дерево по его двоичному коду.
    -- для этого проходимся по битам кода от старшего - len - 1 до младшего - 0, и если на пути встречаем пустой лист (Leaf, -1), то заменяем его на узел или лист: 
    insertPath :: Int -> Int -> Int -> HuffmanTree -> HuffmanTree
    insertPath sym code len = process (len - 1)
      where
        -- мы в листе
        process k (Leaf _)
            | k < 0 = Leaf sym -- если k < 0, значит мы прошли все биты, поэтому на этой глубине пустой лист заполняем символом sym
            | otherwise =
                -- иначе są ещё биты, которые нужно учесть, но поскольку мы в листе, то тут создаём узел: если бит k равен 1, идём в правое поддерево, если бит k равен 0 - в левое
                let (l, r) = if testBit code k
                             then (Leaf (-1), process (k - 1) (Leaf (-1)))
                             else (process (k - 1) (Leaf (-1)), Leaf (-1))
                in Node l r

        -- мы в узле
        process k (Node l r)
            -- если весь код прочитан, а мы в узле, то туда ничего не записать - случилась коллизия
            | k < 0 = error "Error occured due to colission between Huffman's codes"
            -- если k = 1, то рекурсивно спускаемся в правое поддерево
            | testBit code k = Node l (process (k - 1) r)
            | otherwise = Node (process (k - 1) l) r

    -- наконец, построение дерева
    tree = foldl' (\t (sym, code, len) -> insertPath sym code len t) (Leaf (-1)) [(sym, code, len) | (sym, code, len) <- zip3 [0..] assignedCodes lengths, len > 0] 
      where zip3 a b c = zip a (zip b c) >>= \(x, (y, z)) -> [(x, y, z)]


-- Функция декодирует следующий символ из битового потока через проход по дереву и возврат конечного символа при спуске в лист:
decodeSymbol :: Monad m => HuffmanTree -> m Bool -> m Int
decodeSymbol (Leaf sym) _ = return sym -- дошли до листа, декодинг завершён, даём символ
decodeSymbol (Node l r) readBitFn = do
    bit <- readBitFn -- читаем бит в узле
    if bit then decodeSymbol r readBitFn -- по 1 идём в правого сына
           else decodeSymbol l readBitFn -- по 0 идём в левого сына


-- Функция читает последовательность длин кодов в динамическом блоке DEFLATE посредством функции decodeSymbol, используя предоставленное дерево Хаффмана, запрашиваемую длину для прочтения и действия чтения битов. Внутри обрабатываются коды согласно RFC, а именно:
-- коды < 16 отвечают за длину в чистом виде и добавляются в список как есть;
-- код 16 отвечает за повтор предыдущей длины несколько раз, а кол-во повторений кодируется в следующих двух битах extra;
-- код 17 отвечает за повтор длины 0 несколько, чтобы компактно кодировать пласт пропусков, неиспользуемых в блоке;
-- код 18 отвечает за повтор длины как код 17, но большее число раз.
readLengths :: Monad m => HuffmanTree -> Int -> m Bool -> (Int -> m Int) -> m [Int]
readLengths tree cnt readBitFn readBitsFn = process []
  where
    process acc
        | length acc >= cnt = return (reverse (take cnt acc)) -- набрали нужное количество
        | otherwise = do
            sym <- decodeSymbol tree readBitFn -- декодируем символ длины с помощью поданного дерева
            case sym of
                _ | sym < 16 -> process (sym : acc) -- 0..15 - сама длина, просто добавляем в список
                16 -> do -- повтор предыдущей длины несколько раз. это самое несколько кодируется в следующих двух битах (extra)
                    extra <- readBitsFn 2 -- 2 доп. бита
                    let repeatCnt = 3 + extra
                        -- берём предыдущую длины и добавляем repeatCnt - число повторений - её копий: 
                        lastLen = if null acc then 0 else head acc
                    process (replicate repeatCnt lastLen ++ acc)
                17 -> do -- кодируем повторение длины 0
                    extra <- readBitsFn 3
                    let repeatCnt = 3 + extra
                    process (replicate repeatCnt 0 ++ acc)
                18 -> do -- кодируем повторение длины 0 много раз
                    extra <- readBitsFn 7
                    let repeatCnt = 11 + extra
                    process (replicate repeatCnt 0 ++ acc)
                _ -> error "Error: Incorrect symbol in set of code lengths"
