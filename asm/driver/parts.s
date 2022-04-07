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
; Partition functions


scan	; Scan devices and partitions, and mount everything
	; Input:
	;  none
	; Output:
	;  Updates internal memory structures

	lea	devmask(pc),a0          ; Clear previous devmask
	clr.w	(a0)                    ;

	move.w	d7,-(sp)
	clr.b	d7                      ; Start at first ACSI drive

.scan	bsr.w	blk.tst                 ; Low timeout device test
	tst.w	d0                      ;
	bne.b	.next                   ; If timed out, scan next device

	moveq	#0,d0                   ; Update the detected device mask
	move.b	d7,d0                   ;
	rol.b	#3,d0                   ;
	lea	devmask(pc),a0          ;
	bset	d0,1(a0)                ;

	bsr.w	mount                   ; Mount the drive

.next	add.b	#$20,d7
	bne.b	.scan

	; We are done
	move.w	(sp)+,d7
	rts

getpun	; Compute pun and drive index. Allows using extended pun table
	; Input:
	;  d1.w: Drive number (C: = 2, D: = 3, ...)
	; Output:
	;  d0.w: Offset in the pun table
	;  d1.w: Drive number (kept intact)
	;  a0: Pointer to the pun table
	;  other registers unmodified

	move.w	d1,d0                   ; d0 = pun offset
	cmp.w	#16,d0                  ;
	bge.b	.punext                 ;

	move.l	pun_ptr.w,a0            ; Load the regular pun table
	rts

.punext	lea	punext(pc),a0           ; Drive number >= 16: use local pun
	sub.w	#16,d0                  ;

	rts

getpart	; Query the ACSI id and partition offset from pun
	; Input:
	;  d1.w: Drive number (C: = 2, D: = 3, ...)
	; Output:
	;  d1.w: Drive number (kept intact)
	;  d2.l: Partition offset
	;  d7.b: ACSI id or $ff if failed

	bsr.b	getpun                  ; Load the pun table

	move.b	pun.pun(a0,d0),d7       ; Read flags

	btst	#7,d7                   ; Bit 7 = Not managed
	bne.b	.nodrv                  ;

	lsl.b	#5,d7                   ; Convert to ACSI id

	lsl.w	#2,d0                   ; Load partition start sector
	move.l	pun.part_start(a0,d0),d2;

	rts

.nodrv	move.b	#$ff,d7                 ;
	rts

remount	; Remount all devices
	move.w	d7,-(sp)

	clr.b	d7                      ; Start at first id

.check	moveq	#0,d0                   ; Check if the device is present
	move.b	d7,d0                   ;
	rol.b	#3,d0                   ;
	lea	devmask(pc),a0          ;
	btst	d0,1(a0)                ;
	beq.b	.next                   ;

	bsr.w	mount                   ;

.next	add.b	#$20,d7                 ; Point d7 at next device
	beq.b	.check                  ;
	
	move.w	(sp)+,d7
	rts

mount	; Mount ACSI device
	; Input:
	;  d7.b: ACSI id

	; Unmount device
	move.b	d7,d0                   ; d0 = pun formatted drive id
	lsr.b	#5,d0                   ;
	bset	#6,d0                   ;

	move.l	pun_ptr.w,a0            ; Remove the device from the pun table
	bsr.w	.unpun                  ;

	lea	punext(pc),a0           ; Remove the device from the ext pun
	bsr.w	.unpun                  ;

	movem.l	d4-d5,-(sp)             ; Save extra registers

	bsr.w	blk.cap                 ; Get device size
	tst.l	d0                      ;
	beq.b	.dummy                  ;

	move.l	d0,d4                   ; d4 = logical drive size
	moveq	#0,d5                   ; d5 = logical drive offset

	bsr.b	mntdev                  ; Detect and mount what's in this device
	movem.l	(sp)+,d4-d5             ;
	rts

.dummy	moveq	#-1,d1                  ;
	moveq	#-1,d5                  ; No media: create a dummy drive letter
	bsr.w	setdrv                  ;

	rts

.unpun	; Remove from the pun table
	; Input:
	;  a0: pun table address
	;  d0.b: Drive id in pun format
	; Output:
	;  d0.b: unchanged

	moveq	#15,d1
.uploop
	cmp.b	pun.pun(a0,d1),d0
	bne.b	.upnext

	; Drive was mounted on this device: unmount
	subq.w	#1,pun.puns(a0)
	sf	pun.pun(a0,d1)

.upnext	dbra	d1,.uploop
	rts

mntdev	; Mount a block device or a partition
	; Input:
	;  d4.l: Partition/device size
	;  d5.l: Partition/device offset
	;  d7.b: ACSI id

	move.l	d5,d2                   ; Read boot sector
	moveq	#1,d0                   ;
	lea	bss+buf(pc),a0          ; Read into the local buffer
	move.l	a0,d1                   ;
	bsr.w	blk.rd                  ;
	tst.b	d0                      ;
	bne.w	.end                    ;

	lea	bss+buf(pc),a0          ;
	bsr.w	isfatfs                 ; Check if it contains a FAT filesystem
	tst.l	d0                      ;
	beq.b	.nfat                   ;
	; The device is a FAT partition. Mount it
	moveq	#-1,d1                  ; Choose the next available drive
	bsr.w	setdrv                  ; Associate to the drive letter
	bra.b	.end
.nfat

	lea	bss+buf(pc),a0          ;
	bsr.w	ismbr                   ; Check if it contains a partition table
	tst.l	d0                      ;
	beq.w	.nmbr                   ;
	; The device is a MBR partition table. Iterate its partitions.
	lea	bss+buf(pc),a0          ;
	bsr.w	mntmbr
.nmbr

.end	rts

mntmbr	; Mount all partitions in a MBR partition table.
	; ismbr must have been called before to check data format.
	; Note: this totally ignores the partition type value.
	; Input:
	;  d4.l: Partition/device size
	;  d5.l: Partition/device offset
	;  d7.b: ACSI id
	;  a0: pointer to the boot sector data
	; Output:
	;  nothing

	movem.l	d4-d5,-(sp)             ; Store current partition pointer

	moveq	#3,d1                   ; Partition counter

	lea	-4*2*4(sp),sp           ; Store partition pointers on the stack
	lea	(sp),a1                 ;

	lea	mtbl.parts(a0),a0       ; Point at partition table

.read	move.l	mpart.start(a0),d2      ; Read partition start sector
	rol.w	#8,d2                   ;
	swap	d2                      ;
	rol.w	#8,d2                   ;
	add.l	d5,d2                   ; Compute the physical offset
	move.l	d2,(a1)+                ; Store on the stack

	move.l	mpart.size(a0),d0       ; Read partition size
	rol.w	#8,d0                   ;
	swap	d0                      ;
	rol.w	#8,d0                   ;
	move.l	d0,(a1)+                ; Store on the stack

	lea	mpart...(a0),a0         ; Point at the next partition
	dbra	d1,.read                ;

	; Try to mount the 4 partitions

	moveq	#3,d1                   ; Partition counter

.mnt	move.l	(sp)+,d5                ; Read partition offset
	move.l	(sp)+,d4                ; Read partition size
	beq.b	.next                   ; 0 = not defined
	move.w	d1,-(sp)                ;
	bsr.w	mntdev                  ; Mount whatever we detect in it
	move.w	(sp)+,d1                ;
.next	dbra	d1,.mnt                 ;

	movem.l	(sp)+,d4-d5             ; Restore current partition pointer

	rts

setdrv	; Associate a partition to a mounted drive letter
	; Input:
	;  d1.w: Drive letter or -1 for dynamic allocation
	;  d5.l: Partition start sector
	;  d7.b: ACSI id
	; Output:
	;  d1.w: Effective drive letter or -1 if failed

	move.l	pun_ptr.w,a2            ; a2 = pun table

	tst.w	d1
	bpl.w	.doit

	move.w	#2,d1                   ; Start at C:

.isfree	btst	#7,pun.pun(a2,d1)       ; Check if the drive letter is free
	bne.b	.doit                   ;

	addq.w	#1,d1                   ; Check next partition
	cmp.w	#16,d1                  ; Stop at P:
	blt.b	.isfree

	; Search in the extended pun table
	lea	punext(pc),a2           ; Start at Q:
	moveq	#0,d1                   ;

.isxf	btst	#7,pun.pun(a2,d1)       ; Check if the drive letter is free
	bne.b	.doit                   ;

	addq.w	#1,d1                   ; Check next partition
	cmp.w	#10,d1                  ; Stop at Z:
	blt.b	.isxf

	bra.w	.fail

.doit	; Mount the partition on the drive set in d1
	moveq	#1,d0                   ; d0 = drive mask
	lsl.w	d1,d0                   ;

	; Update drvbits
	lea	drvbits.w,a0            ;
	or.l	d0,(a0)                 ;

	; Set media change flag
	lea	mchmask(pc),a0          ;
	or.l	d0,(a0)                 ;

	; Update pun
	move.b	d7,d0                   ; ACSI id
	rol.b	#3,d0                   ;
	bset	#6,d0                   ; Removable flag
	move.b	d0,pun.pun(a2,d1)       ; Set flags

	addq.w	#1,pun.puns(a2)         ; Add one drive

	move.w	d1,d0                   ;
	lsl.w	#2,d0                   ;
	move.l	d5,pun.part_start(a2,d0); Set partition offset

	rts

.fail	moveq	#-1,d1
	rts

ismbr	; Tries to detect if this is a valid MBR partition table
	; There is no real clear 100% foolproof way to do that
	; Some heuristics will be applied.
	; Input:
	;  d4.l: Partition/device size
	;  d5.l: Partition/device offset
	;  a0: pointer to the boot sector data
	; Output:
	;  d0.l: Device capacity if it is a valid MBR, 0 otherwise

	; Check MBR signature
	cmp.w	#$55aa,mtbl.sig(a0)
	bne.b	.no

	; Check if at least 1 partition is defined
	moveq	#3,d2                   ; d2 = partition iterator counter
	lea	mtbl.parts(a0),a1       ; a1 = partition entry address
.ckepty	tst.b	mpart.type(a1)          ; Test partition type
	bne.b	.nempty                 ; Jump out if found at least one
.nxepty	lea	mpart...(a1),a1         ; Next partition
	dbra	d2,.ckepty              ;
	bra.w	.no                     ; No partition !
.nempty

	moveq	#3,d2                   ; d2 = partition iterator counter
	lea	mtbl.parts(a0),a1       ; a1 = partition entry address

	; Check if this partition entry makes sense
.ckpart	moveq	#$7f,d1                 ; mpart.status must be $00 or $80
	and.b	mpart.status(a1),d1     ;
	bne.b	.no                     ;

	tst.b	mpart.type(a1)          ; Check for an empty partition
	bne.b	.defind                 ;
	tst.l	mpart.start(a1)         ; Empty partitions have 0 values
	bne.b	.no                     ;
	tst.l	mpart.size(a1)          ;
	bne.b	.no                     ;
	bra.b	.nxpart                 ; Valid empty entry

.defind	move.l	mpart.start(a1),d1      ; Read partition start sector
	beq.b	.no                     ; Cannot start at 0 for a defined part
	rol.w	#8,d1                   ;
	swap	d1                      ;
	rol.w	#8,d1                   ;

	cmp.l	d1,d4                   ; Cannot start outside the device
	ble.b	.no                     ; XXX not sure if ble is correct

	move.l	mpart.size(a1),d0       ; Read partition size
	beq.b	.no                     ; Cannot be 0 for a defined part
	rol.w	#8,d0                   ;
	swap	d0                      ;
	rol.w	#8,d0                   ;

	add.l	d0,d1                   ; d1 = start+size

	cmp.l	d1,d4                   ; Cannot end outside the device
	blt.b	.no                     ; XXX not sure if blt is correct

.nxpart	lea	mpart...(a1),a1         ; Next partition
	dbra	d2,.ckpart              ;

	; This is a valid MBR. Return the size in d0.
	move.l	d4,d0
	rts

.no	moveq	#0,d0
	rts

isfatfs	; Detects whether this is a valid FAT boot sector
	; There is no real clear 100% foolproof way to do that
	; Some heuristics will be applied.
	; Input:
	;  d4.l: Partition/device size
	;  d5.l: Partition/device offset
	;  a0: pointer to the boot sector data
	; Output:
	;  d0.l: Filesystem size in sectors if it is a valid FAT, 0 otherwise.

	cmp.b	#$f0,fat.media(a0)      ; Check media type
	blt.w	.no

	tst.b	fat.bps(a0)             ; Check that we have 512 bytes sectors
	bne.w	.no
	cmp.b	#2,fat.bps+1(a0)
	bne.w	.no

	move.b	fat.spc(a0),d1          ; Check sectors per cluster
	beq.w	.no                     ; It can't be 0
	cmp.b	#64,d1                  ; It can't be more than 64
	bhi.w	.no                     ;
	move.b	d1,d2                   ; It must be a power of 2
	subq.b	#1,d2                   ;
	and.b	d1,d2                   ;
	bne.b	.no                     ;

	moveq	#0,d1                   ; Clear MSB
	move.b	fat.nsects+1(a0),d1     ;
	lsl.w	#8,d1                   ;
	move.b	fat.nsects(a0),d1       ; d1 = fat.nsects

	tst.w	d1
	bne.b	.nsecok                 ; If fat.nsects == 0
	move.l	fat.hsects(a0),d1       ; Use fat.hsects
	rol.w	#8,d1                   ;
	swap	d1                      ;
	rol.w	#8,d1                   ; d1 = fat.hsects
.nsecok
	cmp.l	d1,d4                   ; Check that the filesystem does not
	blt.b	.no                     ; go beyond the size of its container XXX is blt correct ?

	move.l	d1,d0                   ; Return the real size of the filesystem

	; This looks like a proper FAT to me.
	rts

.no	moveq	#0,d0
	rts

; vim: ff=dos ts=8 sw=8 sts=8 noet colorcolumn=8,41,81 ft=asm
