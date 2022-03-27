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
; Getbpb handler

; BPB *Getbpb ( int16_t dev );

		rsreset
		rs.l	1
getbpb.dev	rs.w	1

	move.w	getbpb.dev(sp),d1	; d1 = current device

	move.w	d7,-(sp)

	bsr.w	getpart                 ; Get device from pun
	cmp.b	#$ff,d7                 ;
	bne.w	.own                    ;

	move.w	(sp)+,d7                ; Restore d7
	hkchain	getbpb                  ; Chain call to BIOS

.own	
	cmp.l	#$ffffffff,d2           ; Test if no medium
	bne.b	.hasmed                 ;

	bsr.w	remount                 ; Try to remount the drive

	moveq	#0,d0                   ; Return an error
	move.w	(sp)+,d7                ; Restore d7
	rts

.hasmed	lea	mchmask(pc),a0          ; Clear media change flag
	move.l	(a0),d0                 ;
	bclr	d1,d0                   ;
	move.l	d0,(a0)                 ;

	lea	bss+buf(pc),a0          ; Read partition header
	move.l	a0,d1                   ;
	moveq	#1,d0                   ;
	bsr.w	blk.rd                  ;

	tst.b	d0                      ; Check for error
	beq.b	.nerr                   ;
	moveq	#0,d0                   ;
	rts
.nerr

	; Compute BPB (code inspired from emuTOS)

	lea	bss+buf(pc),a0          ; a0 = Partition header
	lea	bss+bpb(pc),a1          ; a1 = BPB address

	move.w	#$200,(a1)+             ; d0 = bpb.recsiz = 512 (hardcoded)

	clr.b	(a1)+                   ;
	move.b	fat.spc(a0),d0          ;
	move.b	d0,(a1)+                ; bpb.clsiz = fat.spc

	lsl.b	#1,d0                   ; assumes recsiz == $200
	move.b	d0,(a1)+                ;
	clr.b	(a1)+                   ; bpb.clsizb = bpb.clsiz * 512

	moveq	#0,d0                   ; Clear d0 MSB

	move.b	fat.ndirs+1(a0),d0      ;
	lsl.w	#8,d0                   ;
	move.b	fat.ndirs(a0),d0        ;
	add.w	#$f,d0                  ;
	lsr.w	#4,d0                   ;
	move.w	d0,(a1)+                ; d0 = bpb.rdlen = (fat.ndirs + 15) / 16

	move.w	fat.spf(a0),d1          ;
	rol.w	#8,d1                   ;
	move.w	d1,(a1)+                ; d1 = bpb.fsiz = fat.spf

	move.w	fat.res(a0),d2          ; d2 = fat.res
	rol.w	#8,d2                   ;
	beq.b	.onefat                 ;
.nres	cmp.b	#2,fat.nfats(a0)        ; Are there 2 FATs ?
	blt.b	.onefat                 ;
	add.w	d1,d2                   ; d2 = fat.res + fat.spf
.onefat move.w	d2,(a1)+                ; bpb.fatrec

	add.w	d2,d0                   ; bpb.datrec =
	add.w	d1,d0                   ;  bpb.fatrec + bpb.fsiz + bpb.rdlen
	move.w	d0,(a1)+                ; d0 = bpb.datrec

	moveq	#0,d1                   ; Clear MSB
	move.b	fat.nsects+1(a0),d1     ;
	lsl.w	#8,d1                   ;
	move.b	fat.nsects(a0),d1       ; d1 = fat.nsects

	tst	d1                      ; 
	bne.b	.nsecok                 ; If fat.nsects == 0
	move.l	fat.hsects(a0),d1       ; Use fat.hsects
	rol.w	#8,d1                   ;
	swap	d1                      ;
	rol.w	#8,d1                   ; d1 = fat.hsects
.nsecok
	sub.l	d0,d1                   ; bpb.numcl =
	move.b	fat.spc(a0),d0          ;  (fat.nsects - bpb.datrec) / fat.spc
.clsdiv	lsr.b	#1,d0                   ;
	beq.b	.numcl                  ;
	lsr.l	#1,d1                   ;
	bra.b	.clsdiv                 ;
.numcl
	move.w	d1,(a1)+                ; bpb.numcl

	cmp.w	#4084,d1                ; A FAT with more than 4084 clusters
	bpl.b	.fat12                  ; is FAT16.
	move.w	#1,(a1)+                ;
	bra.b	.bpbok                  ;
.fat12	clr.w	(a1)+                   ; bpb.bflags
.bpbok
	lea	bss+bpb(pc),a0          ; a0 = BPB address
	move.l	a0,d0                   ; Return BPB address
	move.w	(sp)+,d7                ; Restore d7
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm