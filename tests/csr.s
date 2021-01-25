	.text
  .global main
main:
  mv x31, ra

	li	x1, -1
  li  x2, -743
	mulh	x3, x1, x2
  ;
  csrrw x4, mcycle, x0
  ;
  li x5, 100
  li x5, 101
  ;
  csrrs x4, minstret, x2
  ;
  li x5, 100
  li x5, 101

  mv a0, zero
  mv ra, x31
  ret
