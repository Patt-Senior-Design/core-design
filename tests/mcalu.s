	.text
	.global main
main:
	# t0: op1 pointer
	# t1: op2 pointer
	# t2: end of value array
	la	t0, values
	mv	t1, t0
	lw	t2, 0(t0)
	slli	t2, t2, 2
	add	t2, t0, t2
loop:
	# fetch op1, op2
	lw	t3, 4(t0)
	lw	t4, 4(t1)
	# multiply insns
	mul	a0, t3, t4
	mulh	a0, t3, t4
	mulhsu	a0, t3, t4
	mulhu	a0, t3, t4
	# skip divide insns if op2 == 0
	beqz	t4, 1f

	# divide insns
	div	a0, t3, t4
	divu	a0, t3, t4
	rem	a0, t3, t4
	remu	a0, t3, t4

1:	# increment op2 pointer
	addi	t1, t1, 4
	bne	t1, t2, loop

	# op2 pointer at end of value array, reset
	la	t1, values
	# increment op1 pointer
	addi	t0, t0, 4
	bne	t0, t2, loop

	# op1 pointer at end of array, we are done
	mv	a0, zero
	ret

values:
	.word	14 # length of array
	.word	0x00000000
	.word	0xffffffff
	.word	0xffff0000
	.word	0x0000ffff
	.word	0xfffffffe
	.word	0x00000001
	.word	0xdecafbad
	.word	0xa5a5a5a5
	.word	0x5a5a5a5a
	.word	0xabcdabcd
	.word	0x80000000
	.word	0x7fffffff
	.word	0xcccccccc
	.word	0x0f0f0f0f
