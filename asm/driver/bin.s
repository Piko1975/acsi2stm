; ACSI2STM Atari hard drive emulator
; Copyright (C) 2019-2022 by Jean-Matthieu Coulon

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.

; ACSI2STM integrated driver
; Binary payload loaded by the overlay or the boot sector (drvboot)

	org	0

	incdir	..\inc\
	include	acsi2stm.i
	include	tos.i
	include	atari.i
	include	structs.i
	include	hook.i

	dc.l	memend                  ;
	dc.b	'ACSI2STM OVERLAY'      ; Used to check that DMA worked

boot
	include	init.s
	even
	include	parts.s
	even
	include	blkdev.s
	even
	include	acsicmd.s
	even
	include	acsierr.s
	even
rodata
	include	rodata.s
	even
data
	include	data.s
dataend
	; Align payload to 16 bytes boundary for DMA transfers
	ifne	dataend&$f
	ds.b	$10-(dataend&$f)
	endif
bss
	include	bss.s

memend	equ	bss+bss...

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
