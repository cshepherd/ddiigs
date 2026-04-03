#!/usr/bin/env python3
import sys

if len(sys.argv) < 3:
    print(f"Usage: {sys.argv[0]} <input> <output>")
    sys.exit(1)

data = open(sys.argv[1], "rb").read()
stripped = bytes(b & 0x7F for b in data)
translated = stripped.replace(b"\r", b"\n")
open(sys.argv[2], "wb").write(translated)
