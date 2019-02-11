struct intern {
	short sign;
	short expt;
	long manh;
	long manl;
	};
extern struct intern afloat;
extern struct intern bfloat;

printern(x)
struct intern *x;
{
	if (x->sign) printf("- ");
	printf("expt = %x manh = %x manl = %x\n",
		x->expt, x->manh, x->manl);
}

main()
{

	double a,b;
	int c;
	
/*
	a = 2.0;
	b = -2.0;
*/
	c = 2;
	a = c;
	printern(&afloat);
	printern(&bfloat);
	f(&a);
	b = a+a;
	printern(&afloat);
	printern(&bfloat);
	f(&b);
	b = a*a;
	printern(&afloat);
	printern(&bfloat);
	f(&b);
	c = a;
	printern(&afloat);
	printern(&bfloat);
	printf("fix(2.0) = %x\n",c);
}

f(x) long *x;
{printf("hi = %x, lo = %x\n", x[0], x[1]);}
