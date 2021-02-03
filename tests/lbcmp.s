	.macro lbcmp rd:req, rs2:req, rs1:req
	.4byte	0x0000300b | (\rd << 7) | (\rs1 << 15) | (\rs2 << 20)
	.endm

	.text
	.global main
main:
	la	x3, values
	lbcmp	3, 0, 3
	li	x4, 0xff00aa55
	xor	a0, x3, x4
	ret

	.balign 8
values:
	.8byte	0xff00ff00ff00ff00
	.8byte	0x00ff00ff00ff00ff
	.8byte	0xffffffffffffffff
	.8byte	0x0000000000000000
