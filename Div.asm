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
###	     $v1 -> the "right" register after shifted left
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

### Divide two double-precision floating point number stored in general-purpose registers
### More specifically, divide the first double by the second double
### Input  : $a1 -> upper 32 bits of the first double
###	     $a0 -> lower 32 bits of the first double
###	     $a3 -> upper 32 bits of the second double
###	     $a2 -> lower 32 bits of the second double
### Output : $v1 -> upper 32 bits of the resulting double
###	     $v0 -> lower 32 bits of the resulting double
### Assumptions: The two double are not NaNs, Infinities or denormalized numbers
divide:
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
   ## extracting fields of the dividend (first double)
   jal extractSign			# note: does not alter $a0 and $a1
   add $s0, $v0, $zero			# s0 <- sign of the dividend
   
   jal extractBiasedExponent		# note: does not alter $a0 and $a1
   add $s1, $v0, $zero			# s1 <- biased exponent of the dividend
   
   jal extractFraction			# note: does not alter $a0 and $a1
   add $s3, $v1, $zero			# s3 <- the 20 upper bits of the dividend's fraction
   add $s2, $v0, $zero			# s2 <- the 32 lower bits of the dividend's fraction 
   
   
   
   ## extracting fields of the divisor (second double)
   add $a1, $a3, $zero
   add $a0, $a2, $zero
   
   jal extractSign			# note: does not alter $a0 and $a1
   add $s4, $v0, $zero			# $s4 <- sign of the divisor
   
   jal extractBiasedExponent		# note: does not alter $a0 and $a1
   add $s5, $v0, $zero			# $s5 <- biased exponent of the divisor
   
   jal extractFraction			# note: does not alter $a0 and $a1
   add $s7, $v1, $zero			# $s7 <- the 20 upper bits of the divisor's fraction
   add $s6, $v0, $zero			# $s6 <- the 32 lower bits of the divisor's fraction 
   
   ## Zero checking + Add 1.0
   lui $t0, 0x0010			# bit mask 0x0010 0000
   
   or $t1, $s3, $s2
   or $t1, $t1, $s1			# $t1 = 0 if the dividend is 0
   
   or $t2, $s7, $s6
   or $t2, $t2, $s5			# $t2 = 0 if the divisor is 0
   
   or $t3, $t1, $t2			# $t3 = 0 if both the divisor and dividend are 0
   
   bne $t3, $zero, NOT_0_DIV_0
      ### 0/0 - set to NaN
      ori $s1, $zero, 0x07FF
      addi $s2, $zero, 0xFFFF
      add $s3, $zero, $zero
      j STEP8_FIELD_COMBINE		# return
   NOT_0_DIV_0:
  
   bne $t1, $zero, NOT_0_DIVIDED
      ### set to 0
      add $s1, $zero, $zero
      add $s2, $zero, $zero
      add $s3, $zero, $zero		
      j STEP7_SIGN_BIT  		# set sign bit and return 
   NOT_0_DIVIDED:
   or $s3, $s3, $t0			# set the 21st bit to 1 if the dividend is not zero
   
   bne $t2, $zero, NOT_DIV_BY_0
      ### divide by zero - set to infinity
      ori $s1, $zero, 0x07FF
      add $s2, $zero, $zero
      add $s3, $zero, $zero
      j STEP7_SIGN_BIT			# set sign bit and return
   NOT_DIV_BY_0:
   or $s7, $s7, $t0			# set the 21st bit to 1 if the divisor is not zero
   
   STEP3_BIASED_EXPONENT:
   ## calculating the biased exponent of the result
   sub $s1, $s1, $s5			# s1 <- nonbiased exponent
   addiu $s1, $s1, 0x03FF		# s1 <- biased exponent
   
   STEP4_FRACTION:
   ## dividing the two fractions
   add $t0, $zero, $zero		# loop counter
   addi $t1, $zero, 53			# loop times
   
   add $t3, $zero, $zero		# used to store the 20 upper bits of the result's fraction, also accounts for the bit before the decimal point (bit 21)
   add $t2, $zero, $zero		# used to store the 32 lower bits of the result's fraction
   
   lui $t4, 0x0010			# bit mask 0x0010 0000
   
   DIVIDE_LOOP:
   	### Check if the dividend is smaller than the divisor
   	sltu $t5, $s3, $s7
   	
   	sltu $t6, $s7, $s3		
   	or $t6, $t6, $t5		# $t6 <- 0 if $s3 == $s7, 1 otherwise
   	xori $t6, $t6, 0x0001		# $t6 <- 1 if $s3 == $s7, 0 otherwise
   	
   	sltu $t7, $s2, $s6
   	and $t6, $t6, $t7
   	
   	or $t5, $t5, $t6		# $t5 = 1 if the dividend is smaller than the divisor
   	
   	### exit on the 54th iteration
   	### $t5 would be the guard bit on exit
   	beq $t0, $t1, DIVIDE_EXIT
   	
   	### Skip if the dividend is smaller
   	bne $t5, $zero, EXIT_SET_BIT
   	   ### Subtract dividend from the divisor
   	   sltu $t5, $s2, $s6
   	   subu $s2, $s2, $s6
   	   subu $s3, $s3, $s7
   	   subu $s3, $s3, $t5
   	   
   	   ### Set the bits of the result
   	   sltiu $t5, $t0, 21		# from the 22nd iteration, set the bits of $t2
   	   beq $t5, $zero, UPDATE_LOWER
   	   	or $t3, $t3, $t4
   	   	j EXIT_SET_BIT
   	   UPDATE_LOWER:
   	   	or $t2, $t2, $t4
   	EXIT_SET_BIT:
   	
   	### shifting left the bits of the dividend
   	add $a0, $s3, $zero
   	add $a1, $s2, $zero
   	jal shiftLeft2Registers		# Note: does not alter any registers except for $v0, $v1
   	add $s3, $v0, $zero
   	add $s2, $v1, $zero
   	
   	### Circularly shifting right bit mask
   	srl $t4, $t4, 1
   	bne $t4, $zero, EXIT_UPDATE_MASK
   	   lui $t4, 0x8000		# refresh mask to 0x8000 0000
   	EXIT_UPDATE_MASK:
   	
   	addi $t0, $t0, 1
   	j DIVIDE_LOOP
   	
   DIVIDE_EXIT:
  
   add $s3, $t3, $zero			# storing the upper 20 bits of the fraction, also accounting for the bit before the decimal point (bit 21)
   add $s2, $t2, $zero			# storing the lower 32 bits of the fraction
   
   STEP5_ROUND_NORMALIZE:
   ## Rounding and normalize
   
   # $t5 now acts like the guard bit
   srl $t4, $s3, 20			# $t4 = 1 if the number is normalized
   bne $t4, $zero, EXIT_NORMALIZE
      ### shift left the fraction of the result
      add $a0, $s3, $zero
      add $a1, $s2, $zero
      jal shiftLeft2Registers		# Note: does not alter any registers except for $v0, $v1
      add $s3, $v0, $zero
      add $s2, $v1, $zero
      
      addu $s2, $s2, $t5		# add the sticky bit to the fraction of the result
      
      addiu $s1, $s1, -1 		# decrement the exponent of the result
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
   
   jal divide
   
   move $a1, $v1
   move $a0, $v0
 
   jal writeDouble
  
