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


drvinit	; Driver initialization
	pea	text.init(pc)
	gemdos	Cconws,6

	; Initialize the pun_info structure
	lea	pun(pc),a0              ; a0 = local pun table

	move.l	pun.p_cookptr(a0),d0    ; Adjust p_cookptr
	add.l	a0,d0                   ;
	move.l	d0,pun.p_cookptr(a0)    ;

	lea	pun_ptr.w,a1            ;
	move.l	a0,(a1)                 ; Install the main pun table

	ifgt	maxsecsize-$200

	; Initialize big buffers in bufl

	lea	bss+bcb(pc),a0          ; a0 = pointer to the current BCB struct
	lea	bss+bcbbufr(pc),a1      ; a1 = pointer to the current buffer

	bsr.b	.bufini                 ; Initialize the first buffer list

	lea	bufl.w,a2               ; Store the first buffer list in bufl
	move.l	a0,(a2)                 ;

	lea	bcb...*2(a0),a0         ; a0 = pointer to the second BCB struct
	lea	maxsecsize(a1),a1       ; a1 = pointer to the 3rd buffer

	bsr.b	.bufini                 ; Initialize the second buffer list

	lea	(bufl+4).w,a2           ; Store the second buffer list in bufl+4
	move.l	a0,(a2)                 ;

	bra.b	.bufend                 ; Skip the subroutine

.bufini	; Initialize a linked list of 2 BCB buffers
	; Input:
	;  a0: pointer to the BCB struct
	;  a1: pointer to the actual buffers
	;  maxsecsize: constant defining the maximum sector size
	; Output:
	;  a0: untouched
	;  a1: pointer to the 2nd buffer

	lea	bcb...(a0),a2           ; a2 = Pointer to the second buffer

	move.l	a2,(a0)                 ; Link the first buffer to the second
	clr.l	(a2)                    ; Terminate the linked list

	move.w	#-1,bcb.bufdrv(a0)      ; Set Drive# to -1
	move.w	#-1,bcb.bufdrv(a2)      ;

	move.l	a1,bcb.bufr(a0)         ; Pointer to the 1st data buffer
	lea	maxsecsize(a1),a1       ; a1 = pointer to the 2nd buffer
	move.l	a1,bcb.bufr(a2)         ; Pointer to the 2nd data buffer
	rts
.bufend

	endif

	hkinst	getbpb                  ; Let's thrash that poor system
	hkinst	rwabs                   ; Install hooks
	hkinst	mediach                 ;

	pea	text.scan(pc)
	gemdos	Cconws,6

	bsr.w	scan                    ; Scan devices and mount them

	; Set boot drive

	moveq	#2,d1
	bsr.w	getpart
	cmp.b	#$ff,d7
	beq.b	.nobdrv

	move.w	d1,bootdev.w            ; Write boot drive to C:

	move.w	d1,-(sp)                ; Set current drive to C:
	gemdos	Dsetdrv                 ;

	move.w	'\'*$100,-(sp)          ; Set current path to \
	pea	(sp)                    ;
	gemdos	Dsetpath,12             ;

.nobdrv
	; Display partitions
	bsr.w	prtpart

	pea	text.started(pc)
	gemdos	Cconws,6

	move.b	#$e0,d7                 ; Don't boot other drives
	rts

; Hook declarations
	hook	getbpb
	hook	rwabs
	hook	mediach

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm