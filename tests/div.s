	.text
	.global main
main:
	mv	x31, ra

	li	x1, -74
	li	x2, -7
  div x3, x1, x2
  rem x6, x1, x2
  divu x5, x1, x2
  remu x7, x1, x2
  
  li	x1, -74
	li	x2, 7
  div x3, x1, x2
  rem x6, x1, x2
  divu x5, x1, x2
  remu x7, x1, x2

  li	x1, 74
	li	x2, -7
  div x3, x1, x2
  rem x6, x1, x2
  divu x5, x1, x2
  remu x7, x1, x2

  li	x1, 74
	li	x2, 7
  div x3, x1, x2
  rem x6, x1, x2
  divu x5, x1, x2
  remu x7, x1, x2

  # reverse
  li	x2, -74
	li	x1, -7
  div x3, x1, x2
  rem x6, x1, x2
  divu x5, x1, x2
  remu x7, x1, x2
  
  li	x2, -74
	li	x1, 7
  div x3, x1, x2
  rem x6, x1, x2
  divu x5, x1, x2
  remu x7, x1, x2

  li	x2, 74
	li	x1, -7
  div x3, x1, x2
  rem x6, x1, x2
  divu x5, x1, x2
  remu x7, x1, x2

  li	x2, 74
	li	x1, 7
  div x3, x1, x2
  rem x6, x1, x2
  divu x5, x1, x2
  remu x7, x1, x2

  li x4, 8

	mv	a0, zero
	mv	ra, x31
	ret
