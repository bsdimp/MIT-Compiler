foo()
  {	register int i;

	if (i) {
	  asm("	movl	d0,d1");
	  return;
	}

	asm("	movl	d1,d0");
	asm("	movl	d2,d3");
}
