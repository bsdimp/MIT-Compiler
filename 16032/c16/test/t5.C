main()
{
	int	foo;
	struct { long x,y; } Z;
	char	g[34000];
	struct { long x,y; } z;
	main(&Z);
	main(&z);
}
