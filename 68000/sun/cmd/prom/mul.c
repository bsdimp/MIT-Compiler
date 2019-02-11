/*			Multiplication Routines
		  (Stopgap till the compiler is fixed.)
				V.R. Pratt
 */

#define MUL

lmul(x,y) int x,y;
{asm("	movw	a6@(10.),d0");
 asm("	muls	a6@(14.),d0");
}

almul(px,y) int *px,y;
{asm("	movl	a6@(8.),a0");
 asm("	movl	a0@,d0");
 asm("	muls	a6@(14.),d0");
 asm("	movl	d0,a0@");
}

ldiv(x,y) int x,y;
{asm("	movl	a6@(8.),d0");
 asm("	divs	a6@(14.),d0");
 asm("	extl	d0");
}

aldiv(px,y) int *px,y;
{asm("	movl	a6@(8.),a0");
 asm("	movl	a0@,d0");
 asm("	divs	a6@(14.),d0");
 asm("	extl	d0");
 asm("	movl	d0,a0@");
}

lrem(x,y) int x,y;
{asm("	movl	a6@(8.),d0");
 asm("	divs	a6@(14.),d0");
 asm("	asrl	#8.,d0");
 asm("	asrl	#8.,d0");
}

alrem(px,y) int *px,y;
{asm("	movl	a6@(8.),a0");
 asm("	movl	a0@,d0");
 asm("	divs	a6@(14.),d0");
 asm("	swap	d0");
 asm("	extl	d0");
 asm("	movl	d0,a0@");
}

ulmul(x,y) int x,y;
{asm("	movw	a6@(10.),d0");
 asm("	mulu	a6@(14.),d0");
}

aulmul(px,y) int *px,y;
{asm("	movl	a6@(8.),a0");
 asm("	movl	a0@,d0");
 asm("	mulu	a6@(14.),d0");
 asm("	movl	d0,a0@");
}

uldiv(x,y) int x,y;
{asm("	movl	a6@(8.),d0");
 asm("	divu	a6@(14.),d0");
 asm("	extl	d0");
}

auldiv(px,y) int *px,y;
{asm("	movl	a6@(8.),a0");
 asm("	movl	a0@,d0");
 asm("	divu	a6@(14.),d0");
 asm("	extl	d0");
 asm("	movl	d0,a0@");
}

ulrem(x,y) int x,y;
{asm("	movl	a6@(8.),d0");
 asm("	divu	a6@(14.),d0");
 asm("	asrl	#8.,d0");
 asm("	asrl	#8.,d0");
}

aulrem(px,y) int *px,y;
{asm("	movl	a6@(8.),a0");
 asm("	movl	a0@,d0");
 asm("	divu	a6@(14.),d0");
 asm("	swap	d0");
 asm("	extl	d0");
 asm("	movl	d0,a0@");
}


