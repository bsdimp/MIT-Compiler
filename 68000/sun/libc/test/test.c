main()
{
	float a,b,c,d,e,f;
	int i,j;

	a = 1.5;
	b = a/1.5;
	c = b*1.5;
	d = a - 1.5;
	e = d + 1.5;

	j = 2;
	f = j;
	
	i = f;

	printf("a (should be 1.5) %f\n",a);
	printf("b (should be 1.0) %f\n",b);
	printf("c (should be 1.5) %f\n",c);
	printf("d (should be 0.0) %f\n",d);
	printf("e (should be 1.5) %f\n",e);
	printf("f (should be 2.0) %f\n",f);
	printf("i (should be 2) %d\n",i);

	printf("now in hex:\n");

	printf("a (should be 1.5) %x\n",a);
	printf("b (should be 1.0) %x\n",b);
	printf("c (should be 1.5) %x\n",c);
	printf("d (should be 0.0) %x\n",d);
	printf("e (should be 1.5) %x\n",e);
	printf("f (should be 2.0) %x\n",f);
}
