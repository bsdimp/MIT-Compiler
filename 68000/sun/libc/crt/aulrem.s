|J. Test	1/81
|addressed unsigned long remainder: *dividend = *dividend % divisor

	.globl	aulrem
	.text

aulrem:	link	a6,#0
	moveml	#/3000,sp@-	|need d2,d3 registers
	movl	a6@(8.),a0	|a0 = dividend pointer
	movl	a0@,d0		|d0 = dividend
	movl	d0,d2		|save dividend
	movl	a6@(12.),d1	|divisor

	cmpl	#/10000,d1	|divisor < 2 ** 16?
	bge	1$		|no, divisor must be < 2 ** 16
	clrw	d0		|d0 =
	swap	d0		|   dividend high
	divu	d1,d0		|yes, divide
	movw	d2,d0		|d0 = remainder high + quotient low
	divu	d1,d0		|divide
	clrw	d0		|d0 = 
	swap	d0		|   remainder
	bra	4$		|return

1$:	movl	d1,d3		|save divisor
2$:	asrl	#/1,d0		|shift dividend
	asrl	#/1,d1		|shift divisor
	andl	#/7FFFFFFF,d0	|assure positive
	andl	#/7FFFFFFF,d1	|  sign bit
	cmpl	#/10000,d1	|divisor < 2 ** 16?
	bge	2$		|no, continue shift
	divu	d1,d0		|yes, divide
	andl	#/FFFF,d0	|erase remainder
	movl	d0,sp@-		|call ulmul with quotient
	movl	d3,sp@-		|  and saved divisor on stack
	jsr	ulmul		|  as arguments
	addql	#/8,sp		|restore sp
	cmpl	d0,d2		|original dividend >= lmul result?
	jge	3$		|yes, quotient should be correct
	subl	d3,d0		|no, fixup 
3$:	subl	d2,d0		|calculate
	negl	d0		|  remainder

4$:	movl	d0,a0@		|store result through pointer
	moveml	sp@+,#/C	|restore registers
	unlk	a6
	rts
