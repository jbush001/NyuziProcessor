#!/bin/bash

../../bin/simulator -m gdb $1.hex &
/usr/local/llvm-nyuzi/bin/lldb --arch nyuzi $1.elf -o "gdb-remote 8000"
