/*
 * arch/alpha/boot/head.S
 *
 * initial bootloader stuff..
 */

#include "pal.h"

#include <config.h>

	.set noreorder
	.globl	__start
	.ent	__start
__start:
	.prologue 0
	bis	$31,$31,$31
	br	1f
	/* room for the initial PCB, which comes here */
	.quad	0,0,0,0,0,0,0,0
1:	br	$27,2f
2:	ldgp	$29,0($27)
	bsr     $26,main_       !samegp
	call_pal PAL_halt
	.end __start

	/* these must appear within first 512 bytes: */
	.align 3
	.quad	ABOOT_MAGIC
config_file_partition:
	.globl	config_file_partition
	.quad	CONFIG_FILE_PARTITION
raw_initrd_size:
	.globl	raw_initrd_size
	.quad	0

	.align 3
	.globl wrent
	.ent wrent
wrent:
	.prologue 0
	call_pal PAL_wrent
	ret ($26)
	.end wrent

	.align 3
	.globl wrkgp
	.ent wrkgp
wrkgp:
	.prologue 0
	call_pal PAL_wrkgp
	ret ($26)
	.end wrkgp

	.align 3
	.globl tbi
	.ent tbi
tbi:
	.prologue 0
        call_pal PAL_tbi
        ret     ($26)
        .end tbi

	.align 3
	.globl switch_to_osf_pal
	.ent switch_to_osf_pal
switch_to_osf_pal:
	.prologue 0
	subq	$30,128,$30
	stq	$26,0($30)
	stq	$1,8($30)	# regs clobbered by swppal
	stq	$2,16($30)
	stq	$3,24($30)
	stq	$4,32($30)
	stq	$5,40($30)
	stq	$6,48($30)
	stq	$7,56($30)
	stq	$8,64($30)
	stq	$9,72($30)
	stq	$10,80($30)
	stq	$11,88($30)
	stq	$12,96($30)
	stq	$13,104($30)
	stq	$14,112($30)
	stq	$15,120($30)

	stq	$30,0($17)	/* save KSP in PCB (a1) */

	bis	$30,$30,$20	/* a4 = KSP */
	br	$17,__do_swppal

	ldq	$26,0($30)
	ldq	$1,8($30)
	ldq	$2,16($30)
	ldq	$3,24($30)
	ldq	$4,32($30)
	ldq	$5,40($30)
	ldq	$6,48($30)
	ldq	$7,56($30)
	ldq	$8,64($30)
	ldq	$9,72($30)
	ldq	$10,80($30)
	ldq	$11,88($30)
	ldq	$12,96($30)
	ldq	$13,104($30)
	ldq	$14,112($30)
	ldq	$15,120($30)
	addq	$30,128,$30
	ret ($26)

__do_swppal:
	call_pal PAL_swppal
	.end	switch_to_osf_pal

	.align 3
	.globl dispatch
	.ent dispatch
dispatch:
	.prologue 0
	subq	$30,80,$30
	stq	$26,0($30)
	stq	$29,8($30)

	stq	$8,16($30)	/* OpenVMS save regs */
	stq	$9,24($30)
	stq	$10,32($30)
	stq	$11,40($30)
	stq	$12,48($30)
	stq	$13,56($30)
	stq	$14,64($30)
	stq	$15,72($30)

	lda	$1,0x10000000		/* hwrpb */
	ldq	$2,0xc0($1)		/* crb offset */
	addq	$2,$1,$2		/* crb */
	ldq	$27,0($2)		/* dispatch procedure value */

	ldq	$2,8($27)		/* dispatch call address */
	jsr	$26,($2)		/* call it (weird VMS call seq) */

	ldq	$26,0($30)
	ldq	$29,8($30)

	ldq	$8,16($30)
	ldq	$9,24($30)
	ldq	$10,32($30)
	ldq	$11,40($30)
	ldq	$12,48($30)
	ldq	$13,56($30)
	ldq	$14,64($30)
	ldq	$15,72($30)

	addq	$30,80,$30
	ret	$31,($26)
.end    dispatch


	.align 3
	.globl halt
	.ent halt
halt:
	.prologue 0
	call_pal PAL_halt
	.end halt

	.ent run_kernel
	.globl run_kernel
run_kernel:
	.prologue 0
	mov	$16,$27
	mov	$17,$30
	jmp	$31,($27)
	.end run_kernel

.section .note.GNU-stack, "", @progbits
