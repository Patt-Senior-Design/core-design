	.text
	.global main
main:
	li	s0, 0
	li	s1, 0
	beq	s0, s0, start	# 0

error:
	li	a0, 1		# 1
	ret			# 2

start:	addi	s1, s1, 10	# 3
	blt	s0, s1, label1	# 4
	beq	x0, x0, error	# 5

label2:	addi	s1, s1, -20	# 6
	bltu	s0, s1, end	# 7
	beq	x0, x0, error	# 8

label1:	addi	s0, s0, 20	# 9
	blt	s1, s0, label2	# 10
	beq	x0, x0, error	# 11

end:	mv	a0, zero	# 12
	ret

	# 0, 3, 4, 9, 10, 6, 7, 12
