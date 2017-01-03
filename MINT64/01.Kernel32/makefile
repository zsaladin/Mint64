all: VirtualOS.bin

VirtualOS.bin: Source/VirtualOS.asm
	nasm -o VirtualOS.bin Source/VirtualOS.asm

clean:
	rm -f VirtualOS.bin