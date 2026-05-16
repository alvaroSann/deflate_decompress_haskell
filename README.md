# DEFLATE decompressor (RFC 1951) на Haskell

Учебная реализация распаковщика DEFLATE для курса «Теория реализации языков программирования».  
Проект представляет собой библиотеку на Haskell, принимающую сжатые данные в чистом формате DEFLATE и возвращающую исходную байтовую строку.

## Требования

- [GHCup](https://www.haskell.org/ghcup/) (установите GHC и Cabal)
- GHC >= 9.0, Cabal >= 3.0

## Быстрый старт

1. Клонируйте репозиторий:

`git clone https://github.com/alvaroSann/deflate-decompress.git`
`cd deflate-decompress`

2. Соберите проект:

`cabal build`

3. Запустите интерактивную среду:

`cabal repl`

4. Внутри REPL протестируйте распаковку:

```haskell
import Codec.Deflate
import qualified Data.ByteString as BS

-- пустой блок
let emptyDeflate = BS.pack [0x01, 0x00, 0x00, 0xff, 0xff]
decompress emptyDeflate
-- Должно быть: Right ""

-- stored-блок со строкой "Hello"
let helloStored = BS.pack [0x01, 0x05, 0x00, 0xFA, 0xFF, 0x48,0x65,0x6c,0x6c,0x6f]
decompress helloStored
-- Должно быть: Right "Hello"
```

5. Запустите подготовленные тесты:

`cabal test`

## Структура проекта

* src/Data/BitStream.hs – побитовое чтение (LSB first)
* src/Data/Huffman.hs – построение канонических деревьев Хаффмана, декодирование символов, чтение длин
* src/Codec/Deflate/GlobalTypes.hs – константы (таблицы длин и расстояний) и фиксированные деревья Хаффмана
* src/Codec/Deflate/Decoder.hs – обработка блоков DEFLATE (stored, fixed, dynamic) и LZ77
* src/Codec/Deflate.hs – публичная функция decompress

## Примечания

Библиотека реализует только «чистый» DEFLATE (без zlib/gzip обёрток). Для работы с .gz или .zlib нужно предварительно снять обёртку.

Код старались выполнять с подробными комментариями на русском языке, насколько это было возможно, покуда код не загромждался чрезмерным обилием комментарного текста.

## Авторы

* Pristalov R. & Tsedenov A.

МФТИ ФПМИ, 3 курс, 2026
