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
Проверка на произвольных данных (кастомные тесты)

Вы можете сжать любую строку, получить её DEFLATE-представление и убедиться, что декодер правильно её распаковывает.
1. Сгенерируйте сжатый поток (hex)

Локально (если установлен Python)
bash

python utils/generate_test.py "Ваш текст"

Например:
bash

python utils/generate_test.py "Hello, World!"

Вывод:
text

f348cdc9c9d75108cf2fca4951640000

Онлайн (если Python отсутствует)
Откройте онлайн-компилятор Python, вставьте скрипт:
python

import zlib
text = "Ваш текст"
print(zlib.compress(text.encode('utf-8'), wbits=-15).hex())

Скопируйте полученную hex-строку.
2. Распакуйте hex обратно в текст

Выполните в корне проекта:
bash

cabal run deflate-test -- <hex-строка>

Например:
bash

cabal run deflate-test -- f348cdc9c9d75108cf2fca4951640000

Вы должны увидеть исходный текст.
Структура проекта

    src/Data/BitStream.hs – побитовое чтение (LSB first)

    src/Data/Huffman.hs – построение канонических деревьев Хаффмана, декодирование символов, чтение длин

    src/Codec/Deflate/GlobalTypes.hs – константы (таблицы длин и расстояний) и фиксированные деревья Хаффмана

    src/Codec/Deflate/Decoder.hs – обработка блоков DEFLATE (stored, fixed, dynamic) и LZ77

    src/Codec/Deflate.hs – публичная функция decompress

    app/Main.hs – исполняемая утилита deflate-test

    utils/generate_test.py – генератор сжатых DEFLATE-потоков из произвольного текста

Примечания

    Библиотека реализует только «чистый» DEFLATE (без zlib/gzip обёрток). Для работы с .gz или .zlib нужно предварительно снять обёртки.

    Проверка целостности stored-блоков (NLEN = ~LEN) выполнена строго по RFC 1951.

    Код снабжён подробными комментариями на русском языке.

Авторы

    Pristalov R. & Tsedenov A.
    МФТИ, 2026
