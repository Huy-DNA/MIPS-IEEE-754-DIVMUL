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
###			 $a1 -> the "right" register
### Output : $v0 -> the "left" register after shifted left
###			 $v1 -> the "right" register after shifted left
### Guarantees: Does not alter any registers except for $v0, $v1
shiftLeft2Registers:
   sll $v0, $a0, 1
   srl $v1, $a1, 31
   addu $v0, $v0, $v1
   sll $v1, $a1, 1
   jr $ra
   
### Shift right logical the bits across 2 registers
### Input  : $a0 -> the "left" register
###			 $a1 -> the "right" register
### Output : $v0 -> the "left" register after shifted right
###			 $v1 -> the "right" register after shifted right
### Guarantees: Does not alter any registers except for $v0, $v1
shiftRight2Registers:
   srl $v1, $a1, 1
   sll $v0, $a0, 31
   or $v1, $v0, $v1
   srl $v0, $a0, 1
   jr $ra
