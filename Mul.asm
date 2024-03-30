.text
j main

### Read a double from keyboard
### Input  : None
### Output : $v1 -> upper 32 bits of the double
###	     $v0 -> lower 32 bits of the double
readDouble:
   addi $v0, $zero, 7
   syscall
   mfc1.d $v0, $f0
   jr $ra

### Print a double to screen
### Input  : $a1 -> upper 32 bits of the double
###	     $a0 -> lower 32 bits of the double
### Output : None
writeDouble:
   mtc1.d $a0, $f12
   addi $v0, $zero, 3
   syscall
   jr $ra
   
### Extract the sign bit of the double
### Input  : $a1 -> upper 32 bits of the double
###	     $a0 -> lower 32 bits of the double
### Output : $v0 -> 1 if the double is negative, 0 otherwise
### Guarantees : Does not alter $a0 and $a1
extractSign:
   srl $v0, $a1, 31
   jr $ra

### Extract the biased exponent field of the double
### Input  : $a1 -> upper 32 bits of the double
###	     $a0 -> lower 32 bits of the double
### Output : $v0 -> the biased exponent field of the double
### Guarantees : Does not alter $a0 and $a1
extractBiasedExponent:
   lui $t0, 0x7FF0		# bit mask 0x7FF0 0000
   and $v0, $a1, $t0
   srl $v0, $v0, 20
   jr $ra

### Extract the fraction field of the double
### Input  : $a1 -> upper 32 bits of the double
###	     $a0 -> lower 32 bits of the double
### Output : $v1 -> the upper 20 bits of the fraction
###	     $v0 -> the lower 32 bits of the fraction
### Guarantees : Does not alter $a0 and $a1
extractFraction:
   lui $t0, 0x000F
   ori $t0, $t0, 0xFFFF		# bit mask 0x000F FFFF
   and $v1, $a1, $t0
   or $v0, $a0, $zero
   jr $ra
   
### Shift left logical the bits across 2 registers
### Input  : $a0 -> the "left" register
###	     $a1 -> the "right" register
### Output : $v0 -> the "left" register after shifted left
###          $v1 -> the "right" register after shifted left
### Guarantees: Does not alter any registers except for $v0, $v1
shiftLeft2Registers:
   sll $v0, $a0, 1
   srl $v1, $a1, 31
   addu $v0, $v0, $v1
   sll $v1, $a1, 1
   jr $ra
   
### Shift right logical the bits across 2 registers
### Input  : $a0 -> the "left" register
###	     $a1 -> the "right" register
### Output : $v0 -> the "left" register after shifted right
###	     $v1 -> the "right" register after shifted right
### Guarantees: Does not alter any registers except for $v0, $v1
shiftRight2Registers:
   srl $v1, $a1, 1
   sll $v0, $a0, 31
   or $v1, $v0, $v1
   srl $v0, $a0, 1
   jr $ra

### Add two registers and also returns a carry bit from the 32nd bit
### Input  : $a0 -> the first register
###          $a1 -> the second register
### Output : $v0 -> the sum of the two registers
###        : $v1 -> 1 if the sum overflow, 0 otherwise
### Guarantees: Does not alter any registers except for $v0, $v1
addUnsignedWithCarry:
   addu $v0, $a0, $a1		# $v0 = 32 lower bits of sum
   nor $v1, $a0, $zero		# flip all bits of $a0
   sltu $v1, $v1, $a1		# $v1 = 1 if $a0 + $a1 > 0xFFFF FFFF
   jr $ra

### Multiply two double-precision floating point number stored in general-purpose registers
### Input  : $a1 -> upper 32 bits of the first double
###	     $a0 -> lower 32 bits of the first double
###	     $a3 -> upper 32 bits of the second double
###	     $a2 -> lower 32 bits of the second double
### Output : $v1 -> upper 32 bits of the resulting double
###	     $v0 -> lower 32 bits of the resulting double
### Assumptions: The two double are not NaNs, Infinities or denormalized numbers
multiply:
   STEP1_SAVE_STATES:
   ## saving return address and registers' states
   addi $sp, $sp, -36
   sw $ra, 0($sp)
    
   sw $s0, 4($sp)
   sw $s1, 8($sp)
   sw $s2, 12($sp)
   sw $s3, 16($sp)
   sw $s4, 20($sp)
   sw $s5, 24($sp)
   sw $s6, 28($sp)
   sw $s7, 32($sp)
   
   STEP2_FIELD_ETRACTION:
   ## extracting fields of the multiplicand (first double)
   jal extractSign			# note: does not alter $a0 and $a1
   add $s0, $v0, $zero			# s0 <- sign of the multiplicand
   
   jal extractBiasedExponent		# note: does not alter $a0 and $a1
   add $s1, $v0, $zero			# s1 <- biased exponent of the multiplicand
   
   jal extractFraction			# note: does not alter $a0 and $a1
   add $s3, $v1, $zero			# s3 <- the 20 upper bits of the multiplicand's fraction
   add $s2, $v0, $zero			# s2 <- the 32 lower bits of the multiplicand's fraction 
   
   ## extracting fields of the multiplier (second double)
   add $a1, $a3, $zero
   add $a0, $a2, $zero
   
   jal extractSign			# note: does not alter $a0 and $a1
   add $s4, $v0, $zero			# $s4 <- sign of the multiplier
   
   jal extractBiasedExponent		# note: does not alter $a0 and $a1
   add $s5, $v0, $zero			# $s5 <- biased exponent of the multiplier
   
   jal extractFraction			# note: does not alter $a0 and $a1
   add $s7, $v1, $zero			# $s7 <- the 20 upper bits of the multiplier's fraction
   add $s6, $v0, $zero			# $s6 <- the 32 lower bits of the multiplier's fraction 
   
   ## Zero checking + Add 1.0
   lui $t0, 0x0010			# bit mask 0x0010 0000
   
   or $t1, $s3, $s2
   or $t1, $t1, $s1			# $t1 = 0 if the multiplicand is 0
   
   or $t2, $s7, $s6
   or $t2, $t2, $s5			# $t2 = 0 if the multiplier is 0
   
   bne $t1, $zero, NOT_0_MULTIPLICAND
      ### set to 0
      add $s1, $zero, $zero
      add $s2, $zero, $zero
      add $s3, $zero, $zero		
      j STEP7_SIGN_BIT  		# set sign bit and return 
   NOT_0_MULTIPLICAND:
   or $s3, $s3, $t0			# set the 21st bit to 1 if the multiplicand is not zero
   
   bne $t2, $zero, NOT_0_MULTIPLIER
      ### set to 0
      add $s1, $zero, $zero
      add $s2, $zero, $zero
      add $s3, $zero, $zero
      j STEP7_SIGN_BIT			# set sign bit and return
   NOT_0_MULTIPLIER:
   or $s7, $s7, $t0			# set the 21st bit to 1 if the multiplier is not zero
   
   STEP3_BIASED_EXPONENT:
   ## calculating the biased exponent of the result
   add $s1, $s1, $s5			# s1 <- nonbiased exponent
   subiu $s1, $s1, 0x03FF		# s1 <- biased exponent

   STEP4_FRACTION:
   ## multiplying the two fractions
   multu $s2, $s6
   mflo $t0					# lower 32 bit of the product (0 - 31)
   mfhi $t1
   
   multu $s2, $s7
   mflo $t2
   mfhi $t3
   
   multu $s3, $s6
   mflo $t4
   mfhi $t5
   
   multu $s3, $s7
   mflo $t6
   mfhi $t7
   
   # calculate next 32 bits of the product (32 - 63)
   add $a0, $t1, $zero
   add $a1, $t2, $zero
   jal addUnsignedWithCarry			# note: does not alter any registers except for $v0, $v1
   add $t2, $v1, $zero
   
   add $a0, $v0, $zero
   add $a1, $t4, $zero
   jal addUnsignedWithCarry			# note: does not alter any registers except for $v0, $v1
   add $t2, $t2, $v1				# carry from the current 32 bits
   
   add $t1, $v0, $zero				# next 32 bits of the product
   
   # calculate next 32 bits of the product (64 - 95)
   add $a0, $t2, $zero
   add $a1, $t3, $zero
   jal addUnsignedWithCarry			# note: does not alter any registers except for $v0, $v1
   add $t3, $v1, $zero
   
   add $a0, $v0, $zero
   add $a1, $t5, $zero
   jal addUnsignedWithCarry			# note: does not alter any registers except for $v0, $v1
   add $t3, $v1, $t3
   
   add $a0, $v0, $zero
   add $a1, $t6, $zero
   jal addUnsignedWithCarry			# note: does not alter any registers except for $v0, $v1
   add $t3, $v1, $t3				# carry from the current 32 bits
   
   add $t2, $v0, $zero				# next 32 bits of the product

   # calculate next 32 bits of the product (96 - 127)
   add $t3, $t3, $t7				# no overflow should happen here!
   						# last 32 bits of the product
   
   # $t0 -> 0-31
   # $t1 -> 32-63
   # $t2 -> 64-95
   # $t3 -> 96-127
   
   STEP5_ROUND_NORMALIZE:
   ## Rounding and normalize
   ori $t4, $zero, 0x0200			# bit mask 0x0000 0200
   and $t4, $t3, $t4				# $t4 = 0 if the product doesn't need normalizing, != 0 otherwise
   
   beq $t4, $zero, NOT_NORMALIZE
      sll $s3, $t3, 11
      srl $t4, $t2, 21
      or $s3, $s3, $t4
      
      sll $s2, $t2, 11
      srl $t4, $t1, 21
      or $s2, $s2, $t4   
      
      addiu $s1, $s1, 1 
      j EXIT_NORMALIZE
   NOT_NORMALIZE:
      sll $s3, $t3, 12
      srl $t4, $t2, 20
      or $s3, $s3, $t4
      
      sll $s2, $t2, 12
      srl $t4, $t1, 20
      or $s2, $s2, $t4
   EXIT_NORMALIZE:
   
   STEP6_UNDERFLOW_OVERFLOW:
   ## overflow/underflow checking
   slti $t0, $s1, 0x07FF
   bne $t0, $zero, EXIT_OVERRFLOW_CHECK
      ### set to infinity
      ori $s1, $zero, 0x07FF
      add $s2, $zero, $zero
      add $s3, $zero, $zero
   EXIT_OVERRFLOW_CHECK:
   
   slti $t0, $s1, 0
   beq $t0, $zero, EXIT_UNDERFLOW_CHECK
      ### set to zero
      add $s1, $zero, $zero
      add $s2, $zero, $zero
      add $s3, $zero, $zero
   EXIT_UNDERFLOW_CHECK:
   
   STEP7_SIGN_BIT:
   ## determining the sign bit of the result
   xor $s0, $s0, $s4
   
   STEP8_FIELD_COMBINE:
   ## combining the field
   ### Fraction field
   or $v0, $s2, $zero
   
   lui $t0, 0x000F
   ori $t0, $t0, 0xFFFF
   and $s3, $s3, $t0 
   or $v1, $s3, $zero
   
   ### Exponent field
   sll $s1, $s1, 20
   or $v1, $v1, $s1
   
   ### Sign field
   sll $s0, $s0, 31
   or $v1, $v1, $s0
   
   STEP9_RETRIEVE_STATES:
   ## retrieving return address and registers' states
   lw $ra, 0($sp)
   
   lw $s0, 4($sp)
   lw $s1, 8($sp)
   lw $s2, 12($sp)
   lw $s3, 16($sp)
   lw $s4, 20($sp)
   lw $s5, 24($sp)
   lw $s6, 28($sp)
   lw $s7, 32($sp)
   
   addi $sp, $sp, 36

   jr $ra

main:
   jal readDouble
   move $s1, $v1
   move $s0, $v0
   
   jal readDouble
   move $s3, $v1
   move $s2, $v0
   
   move $a1, $s1
   move $a0, $s0
   
   move $a3, $s3
   move $a2, $s2
   
   jal multiply
   
   move $a1, $v1
   move $a0, $v0
 
   jal writeDouble
