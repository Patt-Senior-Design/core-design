	.macro pcr rd:req, rs1:req, rs2:req
	.4byte	0x0000102b | (\rd << 7) | (\rs1 << 15) | (\rs2 << 20)
	.endm

	.text
	.global main
main:
  mv x31, ra

  li x3, 546
	pcr 5, 3, 0 
	li	x4, 0xff00aa55

	mv	a0, zero
	mv	ra, x31
	ret
