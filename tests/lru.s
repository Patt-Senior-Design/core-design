	.text
	.global main
main:
	li	t0, 0x20010000
	li	t1, 0x00008000
	li	t2, 0x28000000
	li	t3, 0xdecafbad

1:	sw	t3, 0(t0)
	sw	t0, 4(t0)
	add	t0, t0, t1
	blt	t0, t2, 1b

	li	t0, 0x20010000

1:	lw	t3, 0(t0)
	lw	t3, 4(t0)
	add	t0, t0, t1
	blt	t0, t2, 1b

	li	t0, 0x20010000
	li	t3, 0xabcdabcd

1:	sw	t3, 0(t0)
	add	t0, t0, t1
	blt	t0, t2, 1b

	li	t0, 0x20010000

1:	lw	t3, 0(t0)
	add	t0, t0, t1
	blt	t0, t2, 1b

	mv	a0, zero
	ret
