; named shell_.asm to avoid infinite include loop.
.equ	RAMSTART	0x4000
; kernel ram is well under 0x100 bytes. We're giving us 0x200 bytes so that we
; never worry about the stack.
.equ	KERNEL_RAMEND	0x4200
.equ	USERCODE	KERNEL_RAMEND
.equ	STDIO_PORT	0x00
.equ	FS_DATA_PORT	0x01
.equ	FS_ADDR_PORT	0x02

	jp	init

; *** JUMP TABLE ***
	jp	strncmp
	jp	addDE
	jp	addHL
	jp	upcase
	jp	unsetZ
	jp	intoDE
	jp	intoHL
	jp	writeHLinDE
	jp	findchar
	jp	parseHex
	jp	parseHexPair
	jp	blkSel
	jp	blkSet
	jp	fsFindFN
	jp	fsOpen
	jp	fsGetB
	jp	fsPutB
	jp	fsSetSize
	jp	cpHLDE
	jp	parseArgs
	jp	printstr
	jp	_blkGetB
	jp	_blkPutB
	jp	_blkSeek
	jp	_blkTell
	jp	printcrlf
	jp	stdioPutC
	jp	stdioReadLine

.inc "core.asm"
.inc "err.h"
.inc "parse.asm"

.equ	BLOCKDEV_RAMSTART	RAMSTART
.equ	BLOCKDEV_COUNT		4
.inc "blockdev.asm"
; List of devices
.dw	fsdevGetB, fsdevPutB
.dw	stdoutGetB, stdoutPutB
.dw	stdinGetB, stdinPutB
.dw	mmapGetB, mmapPutB


.equ	MMAP_START	0xe000
.inc "mmap.asm"

.equ	STDIO_RAMSTART	BLOCKDEV_RAMEND
.equ	STDIO_GETC	emulGetC
.equ	STDIO_PUTC	emulPutC
.inc "stdio.asm"

.equ	FS_RAMSTART	STDIO_RAMEND
.equ	FS_HANDLE_COUNT	2
.inc "fs.asm"

.equ	SHELL_RAMSTART		FS_RAMEND
.equ	SHELL_EXTRA_CMD_COUNT	9
.inc "shell.asm"
.dw	blkBselCmd, blkSeekCmd, blkLoadCmd, blkSaveCmd
.dw	fsOnCmd, flsCmd, fnewCmd, fdelCmd, fopnCmd

.inc "blockdev_cmds.asm"
.inc "fs_cmds.asm"

.equ	PGM_RAMSTART		SHELL_RAMEND
.equ	PGM_CODEADDR		USERCODE
.inc "pgm.asm"

;.out	PGM_RAMEND

init:
	di
	; setup stack
	ld	hl, KERNEL_RAMEND
	ld	sp, hl
	call	fsInit
	ld	a, 0	; select fsdev
	ld	de, BLOCKDEV_SEL
	call	blkSel
	call	fsOn
	call	shellInit
	ld	hl, pgmShellHook
	ld	(SHELL_CMDHOOK), hl
	jp	shellLoop

emulGetC:
	; Blocks until a char is returned
	in	a, (STDIO_PORT)
	cp	a		; ensure Z
	ret

emulPutC:
	out	(STDIO_PORT), a
	ret

fsdevGetB:
	ld	a, e
	out	(FS_ADDR_PORT), a
	ld	a, h
	out	(FS_ADDR_PORT), a
	ld	a, l
	out	(FS_ADDR_PORT), a
	in	a, (FS_ADDR_PORT)
	or	a
	ret	nz
	in	a, (FS_DATA_PORT)
	cp	a		; ensure Z
	ret

fsdevPutB:
	push	af
	ld	a, e
	out	(FS_ADDR_PORT), a
	ld	a, h
	out	(FS_ADDR_PORT), a
	ld	a, l
	out	(FS_ADDR_PORT), a
	in	a, (FS_ADDR_PORT)
	cp	2		; only A > 1 means error
	jr	nc, .error	; A >= 2
	pop	af
	out	(FS_DATA_PORT), a
	cp	a		; ensure Z
	ret
.error:
	pop	af
	jp	unsetZ		; returns

.equ	STDOUT_HANDLE	FS_HANDLES

stdoutGetB:
	ld	ix, STDOUT_HANDLE
	jp	fsGetB

stdoutPutB:
	ld	ix, STDOUT_HANDLE
	jp	fsPutB

.equ	STDIN_HANDLE	FS_HANDLES+FS_HANDLE_SIZE

stdinGetB:
	ld	ix, STDIN_HANDLE
	jp	fsGetB

stdinPutB:
	ld	ix, STDIN_HANDLE
	jp	fsPutB

