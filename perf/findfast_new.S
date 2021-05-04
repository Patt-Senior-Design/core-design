	.macro lbcmp rd:req, rs2:req, rs1:req
	.4byte	0x0000300b | (\rd << 7) | (\rs1 << 15) | (\rs2 << 20)
	.endm
	.macro pfd rd:req, rs1:req, rs2:req
	.4byte	0x0000002b | (\rd << 7) | (\rs1 << 15) | (\rs2 << 20)
	.endm
	.macro pcr rd:req, rs1:req, rs2:req
	.4byte	0x0000102b | (\rd << 7) | (\rs1 << 15) | (\rs2 << 20)
	.endm
findNode:
	addi	sp,sp,-32
	sw	s2,16(sp)
	mv	s2,a0
	mv	a0,a1
	sw	ra,28(sp)
	sw	s0,24(sp)
	sw	s1,20(sp)
	sw	s3,12(sp)
	sw	s4,8(sp)
	mv	s3,a1
	call	hash_fn
	lw	s1,8(s2)
	li	a3,0
	mv	s0,a0
	mv	a2,s1
	mv	s4,a1
	call	__umoddi3 # a0 = hashIdx
	lw	a2,4(s2)    # s2 = &set, a2 = &mdata
	add	a3,a2,a0    # a3 = &mdata[hashIdx]

  lw a7, 0(s2)    # a7 = &arr
### NEW ADDITIONS ###
  # s1 = capacity, s0 = lo32-hash, s3 = val, s2 = &set, s4 = hi-hash (unused)
  # a0 = hashIdx, a1 = first-empty, a2 = &mdata, a3 = &mdata[hashIdx], a4 = hash-to-find, a7 = &arr

  andi a5, a0, 31   # a5: offset
  li a1, 1
  sll a1, a1, a5 
  add a5, a1, -1   # a5: mask for offset

  srli a0, a0, 5
  slli a0, a0, 5   # a0: align hashIdx to 32-byte

  srli a4, s0, 20   # hash >> PHASH
  andi a4, a4, 127
  ori a4, a4, 128   # a4 = hash to find

.OLOOP:
  add a3, a2, a0    # get next mdata[hashIdx] aligned location
  lbcmp 11, 0, 13   # search for empty slot
  lbcmp 16, 14, 13  # search for value
  pfd 11, 11, 15     # find first empty: a0=empty-idx

.ILOOP:
  pfd 8, 16, 15     # find and clear first match; s0=found-idx, a6=vec, a5=mask
  pcr 16, 16, 15     
  
  bgtu s0, a1,.NOTFOUND 
  beq s0, a1,.NEXTSET

  ## CHECK ELEMENTS : s0 = hash_off in block ##
  add s2, a0, s0    # s2 = hash_off from base in words
  slli s2, s2, 2    # s2 = hash_off from base in bytes
  add s2, a7, s2    # s2 = &arr[matching_hash]
  lw s2, 0(s2)      
  beq s2, s3,.FOUND   
  j .ILOOP

.NEXTSET:
  addi a0, a0, 32
  mv a5, zero       # No masking after first iteration
  remu a0, a0, s1   # hashIdx = (hashIdx + 32) % cap
  j .OLOOP

###              ###
.NOTFOUND:               # RETURN STUFF
  lw	ra,28(sp)
	lw	s0,24(sp)
	lw	s1,20(sp)
	lw	s2,16(sp)
	lw	s3,12(sp)
	lw	s4,8(sp)
	li	a0,0
	addi	sp,sp,32
	jr	ra
.FOUND:
	lw	ra,28(sp)
	lw	s0,24(sp)
	lw	s1,20(sp)
	lw	s2,16(sp)
	lw	s3,12(sp)
	lw	s4,8(sp)
	li	a0,1
	addi	sp,sp,32
	jr	ra
.FSTR:
  .string "Found\n"
.NFSTR:
  .string "Not Found\n"
