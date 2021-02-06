	.macro pfd rd:req, rs1:req, rs2:req
	.4byte	0x0000002b | (\rd << 7) | (\rs1 << 15) | (\rs2 << 20)
	.endm

	.text
	.global main
main:
	li x3, 544
	pfd 6, 3, 0 
	li	x4, 0xff00aa55
	xor	a0, x3, x4
	ret
