	.text
	.global main
main:
	li	a0, 128
	li	a1, 0x20000000
	li	a2, 0x20010000
	li	a3, 0x20020000

loop:	lw	t0, 0(a1)
	addi	a1, a1, 4

	lw	t1, 0(a2)
	addi	a2, a2, 4

	add	t2, t0, t1

	sw	t2, 0(a3)
	addi	a3, a3, 4

	addi	a0, a0, -1
	bgtz	a0, loop

	ret
