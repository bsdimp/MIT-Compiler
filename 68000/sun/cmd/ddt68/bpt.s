| This file is the low level interface to ddt. It saves registers and passes
| control to ddt.
	.text
	.globl ddtinit			|initial entry point
	.globl ddtbpt			|trap #14 vector
	.globl ddtbrk			|C-level trap routine
	.globl ddttrct			|trace vector
	.globl ddttrace			|C-level trace routine
	.globl ddtosr			|old status register
	.globl ddtopc			|old program counter
	.globl ddtsvregs		|saved gp regs

| Here from a ddtinit() call, normally from crtsun.s
| Must already be in system state

ddtinit:
	addql	#2,sp@			|anticipate following subql #2,sp@
	movw	sr,sp@-			|push status register on stack

| here on a breakpoint trap

ddtbpt:
	movw	#0x2600,sr		| mask off interrupts < 7
	movw	sp@+,ddtosr		|old status register
	subql	#2.,sp@			|point back to bp instruction
	movl	sp@+,ddtopc		|old program counter
	moveml	#/FFFF,ddtsvregs	|save registers
	btst	#5,ddtosr		|see if user state
	bne	callddt			|no
	movl	usp,a0			|yes, get user's sp
	movl	a0,ddtsvregs+60		|and save it
callddt:
	jsr	ddtbrk			|call ddt
traprt:	btst	#5,ddtosr		|again see if user state
	bne	restor
	movl	ddtsvregs+60,a0		|get user sp
	movl	a0,usp			|and restore it to usp
restor:	moveml	ddtsvregs,#/FFFF	|restore registers
	movl	ddtopc,sp@-		|push pc on the stack
	movw	ddtosr,sp@-		|push sr on the stack
	rte				|execute broken instruction
ddttrct:
	movw	#0x2600,sr		| mask off interrupts < 7
	movw	sp@+,ddtosr		|save status register
	movl	sp@+,ddtopc		|save pc
	moveml	#/FFFF,ddtsvregs	|save registers
	btst	#5,ddtosr		|see if user state
	bne	calltr			|no
	movl	usp,a0			|yes, get user's sp
	movl	a0,ddtsvregs+60		|and save it
calltr:	jsr	ddttrace		|call tracer
	bra	traprt
