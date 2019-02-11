	.data
	.even
	.globl	envp
envp:
	.data
	.long	.L12
	.long	.L13
	.long	.L14
	.long	.L15
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.long	0
	.text
	.globl	getenv
getenv:
	link	a6,#-_F1
	moveml	#_S1,a6@(-_F1)
| A1 = 12
	movl	#envp,a6@(-4)
	jra	.L20
.L20001:
	movl	a6@(-4),a0
	movl	a0@,sp@-
	movl	a6@(8),sp@-
	jbsr	strpref
	addql	#8,sp
	tstl	d0
	jne	.L18
	movl	a6@(8),sp@-
	jbsr	strlen
	addql	#4,sp
	movl	a6@(-4),a0
	movl	a0@,d1
	addl	d0,d1
	addql	#1,d1
	movl	d1,d0
	jra	.L17
.L18:
	addql	#4,a6@(-4)
.L20:
	tstl	a6@(-4)
	jne	.L20001
	clrl	d0
.L17:
	unlk	a6
	rts
_F1 = 4
_S1 = 0
| M1 = 8
	.text
	.globl	strpref
strpref:
	link	a6,#-_F2
	moveml	#_S2,a6@(-_F2)
| A2 = 16
.L25:
	movl	a6@(8),a0
	tstb	a0@
	jeq	.L26
	movl	a0,d0
	addql	#1,a6@(8)
	movl	d0,a0
	movb	a0@,d0
	movl	a6@(12),d1
	addql	#1,a6@(12)
	movl	d1,a0
	movb	a0@,d1
	cmpb	d1,d0
	jeq	.L25
	moveq	#1,d0
	jra	.L24
.L26:
	clrl	d0
.L24:
	unlk	a6
	rts
_F2 = 0
_S2 = 0
| M2 = 0
	.data
.L12:
	.byte	80,65,84,72,61,47,117,115
	.byte	114,47,115,117,110,47,98,111
	.byte	111,116,102,105,108,101,0
.L13:
	.byte	72,79,77,69,61,47,109,110
	.byte	116,47,103,117,101,115,116,0
.L14:
	.byte	84,69,82,77,61,115,117,110
	.byte	0
.L15:
	.byte	85,83,69,82,61,103,117,101
	.byte	115,116,0
