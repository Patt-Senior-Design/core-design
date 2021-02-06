	.macro pfd rd:req, rs1:req, rs2:req
	.4byte	0x0000002b | (\rd << 7) | (\rs1 << 15) | (\rs2 << 20)
	.endm

	.text
	.global main
main:
  mv x31, ra

	li x3, 544
	pfd 5, 3, 0 
	li	x4, 0xff00aa55

	mv	a0, zero
	mv	ra, x31
	ret
