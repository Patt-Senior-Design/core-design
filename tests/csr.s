	.text
  .global main
main:
  mv x31, ra

	li	x1, -1
  li  x2, -743
	mulh	x3, x1, x2
  ;
  csrrs x4, mcycle, x2
  ;
  li x5, 100
  li x5, 101
  ;
  csrrc x4, minstret, x1
  ;
  li x5, 200
  li x5, 201
  ;
  csrrw x7, minstret,  x0
  ;
  mv a0, zero
  mv ra, x31
  ret
