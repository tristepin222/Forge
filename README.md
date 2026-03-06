# Forge
Imperium compiler bootstrap

### install nasm

just be sure that apt is up to date

```
sudo apt update
```

then type

```
sudo apt install nasm build-essential
```

this will install nasm, nasm is only useful to build on x86-64 architecture processors, it cannot build for arm and thumb

### building the compiler
any linux distro will do, for windows install wsl, and then you can run these commands

```
nasm -f elf64 compiler.asm -o compiler.o
ld -o compiler compiler.o
./compiler
```

this will create a bunch of files, but the most important is program.asm

### building the program

when program.asm is created, it should have assembly in it, so again, you'll have to run these commands

```
nasm -f elf64 program.asm -o program.o
ld -o program program.o
./program
```

and it should beautifully output hello, world
