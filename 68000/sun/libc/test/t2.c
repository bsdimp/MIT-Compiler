main()
{

	double a,b;
	int c;
	
	c = 2;
	a = c;
	c = a;
	printf("fix(a) = %x\n",c);
	f(&a);
	b = a+a;
	c = b;
	printf("fix(b) = %x\n",c);
	f(&b);
	b = a*a;
	c = b;
	printf("fix(b) = %x\n",c);
	f(&b);
}

f(x) long *x;
{printf("hi = %x, lo = %x\n", x[0], x[1]);}
