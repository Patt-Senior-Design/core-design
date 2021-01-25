	.text
	.global _start
	.global _vector_table

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

	# initialize trap vector
	# TODO: uncomment once we have CSRs and exceptions
	# la	t0, _vector_table
	# csrw	mtvec, t0

	# initialize counters
	# csrw	mcycleh, zero
	# csrw	mcycle, zero
	# csrw	minstreth, zero
	# csrw	minstret, zero

	# copy data into ram
	la	t0, _etext
	la	t1, _sdata
	la	t2, _edata
fill_ram:
	beq	t1, t2, ram_full
	lw	t3, 0(t0)
	sw	t3, 0(t1)
	addi	t0, t0, 4
	addi	t1, t1, 4
	j	fill_ram

ram_full:
	# clear bss
	la	t0, _edata
	la	t1, _end
zero_bss:
	beq	t0, t1, bss_cleared
	sw	zero, 0(t0)
	addi	t0, t0, 4
	j	zero_bss

bss_cleared:
	# launch program
	la	sp, _stack-4
	sw	zero, 0(sp)
	call	main

	# halt
	sll	t0, a0, 1 # return value of main << 1
	ori	t0, t0, 1 # set the low bit (signals to HTIF to exit)
	la	t1, tohost
	sw	t0, 0(t1)
	ebreak # pauses spike while it shuts down which gets rid of extraneous trace output

done:	j	done # if all else fails...

_vector_table:
	.word	0 # TODO: exception handlers
