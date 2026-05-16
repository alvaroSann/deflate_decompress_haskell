#!/usr/bin/env python3
"""
Генератор сжатого DEFLATE-потока (raw) из произвольной строки.
Запуск: python utils/generate_test.py "Ваш текст"
"""

import sys
import zlib

if len(sys.argv) < 2:
    print("Использование: python generate_test.py <текст>")
    sys.exit(1)

text = sys.argv[1]
data = text.encode('utf-8')
# wbits=-15 означает raw DEFLATE без zlib-заголовка
compressed = zlib.compress(data, wbits=-15)
print(compressed.hex())
