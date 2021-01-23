	.text
	.global _start
	.global _vector_table
	.global _exit

_start:
	# initialize trap vector
	# TODO: uncomment once we have CSRs and exceptions
	# la	t0, _vector_table
	# csrw	mtvec, t0

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
