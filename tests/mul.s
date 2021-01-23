	.text
	.global main
main:
	mv	x31, ra

	li	x1, -9
	li	x2, -7
	mulh	x4, x2, x1
	mulhu	x5, x2, x1
	mulhsu	x6, x2, x1

	mv	a0, zero
	mv	ra, x31
	ret
