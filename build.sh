#!/bin/bash

set -e

mkdir -p output

echo "Compiling compiler..."
nasm -f elf64 compiler.asm -o output/compiler.o
ld output/compiler.o -o output/compiler

echo "Running compiler..."
./output/compiler

echo "Compiling generated program..."
nasm -f elf64 output/program.asm -o output/program.o
ld output/program.o -o output/program

echo "Running program..."
./output/program
