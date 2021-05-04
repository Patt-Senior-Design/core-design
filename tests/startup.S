/* Copyright (c) 2017  SiFive Inc. All rights reserved.

   This copyrighted material is made available to anyone wishing to use,
   modify, copy, or redistribute it subject to the terms and conditions
   of the FreeBSD License.   This program is distributed in the hope that
   it will be useful, but WITHOUT ANY WARRANTY expressed or implied,
   including the implied warranties of MERCHANTABILITY or FITNESS FOR
   A PARTICULAR PURPOSE.  A copy of this license is available at
   http://www.opensource.org/licenses.
*/

#include "newlib.h"

#=========================================================================
# crt0.S : Entry point for RISC-V user programs
#=========================================================================

	.section .init
	.global _start
	.type _start, @function
_start:
	# zero registers
	mv	x1, zero
	mv	x2, zero
	mv	x3, zero
	mv	x4, zero
	mv	x5, zero
	mv	x6, zero
	mv	x7, zero
	mv	x8, zero
	mv	x9, zero
	mv	x10, zero
	mv	x11, zero
	mv	x12, zero
	mv	x13, zero
	mv	x14, zero
	mv	x15, zero
	mv	x16, zero
	mv	x17, zero
	mv	x18, zero
	mv	x19, zero
	mv	x20, zero
	mv	x21, zero
	mv	x22, zero
	mv	x23, zero
	mv	x24, zero
	mv	x25, zero
	mv	x26, zero
	mv	x27, zero
	mv	x28, zero
	mv	x29, zero
	mv	x30, zero
	mv	x31, zero

	# Initialize stack
	la	sp, _stack-8
	sw	zero, 0(sp)

	# Initialize global pointer
	.option push
	.option norelax
1:	auipc	gp, %pcrel_hi(__global_pointer$)
	addi	gp, gp, %pcrel_lo(1b)
	.option pop

	# Initialize the data segment
	la	a0, _sdata
	la	a1, _etext
	la	a2, _edata
	sub	a2, a2, a0
	call	memcpy

	# Clear the bss segment
	la	a0, _edata
	la	a2, _end
	sub	a2, a2, a0
	li	a1, 0
	call	memset
#ifdef _LITE_EXIT
	# Make reference to atexit weak to avoid unconditionally pulling in
	# support code.  Refer to comments in __atexit.c for more details.
	.weak atexit
	la	a0, atexit
	beqz	a0, .Lweak_atexit
	.weak __libc_fini_array
#endif

	la	a0, __libc_fini_array   # Register global termination functions
	call	atexit                  #  to be called upon exit
#ifdef _LITE_EXIT
.Lweak_atexit:
#endif
	call	__libc_init_array       # Run global initialization functions

	# Save sp/fp/gp in case main doesn't save them
	la	t0, _saved_regs
	sw	sp, 0(t0)
	sw	fp, 4(t0)
	sw	gp, 8(t0)

	lw	a0, 0(sp)                  # a0 = argc
	addi	a1, sp, __SIZEOF_POINTER__ # a1 = argv
	li	a2, 0                      # a2 = envp = NULL
	call	main

	# Restore sp/fp/gp
	.option push
	.option norelax
1:	auipc	t0, %pcrel_hi(_saved_regs)
	addi	t0, t0, %pcrel_lo(1b)
	.option pop
	lw	sp, 0(t0)
	lw	fp, 4(t0)
	lw	gp, 8(t0)

	tail	exit
	.size _start, .-_start

	.section .bss
	.align 4
_saved_regs:
	.word	0, 0, 0
