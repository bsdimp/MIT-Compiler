main()
{
	float a,b,c,d,e,f;
	int i,j;

	j = 2;
	f = j;

	a = j;
	b = a/j;
	c = b*j;
	d = a - j;
	e = d + j;
	
	i = f;

	printf("a (should be 2.0) %f\n",a);
	printf("b (should be 1.0) %f\n",b);
	printf("c (should be 2.0) %f\n",c);
	printf("d (should be 0.0) %f\n",d);
	printf("e (should be 2.0) %f\n",e);
	printf("f (should be 2.0) %f\n",f);
	printf("i (should be 2) %d\n",i);

	printf("now in hex:\n");

	printf("a (should be 2.0) %x\n",a);
	printf("b (should be 1.0) %x\n",b);
	printf("c (should be 2.0) %x\n",c);
	printf("d (should be 0.0) %x\n",d);
	printf("e (should be 2.0) %x\n",e);
	printf("f (should be 2.0) %x\n",f);
}
