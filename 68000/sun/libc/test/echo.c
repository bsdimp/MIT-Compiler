putchar(c) char c; {emt_putchar(c);}

getchar() {return(emt_getchar());}

char response[100];

main()
{
	int i;
	char c;
	
	for (i = 0; i < 10; i++) {
		printf("Echo on -- enter a char: ");
		c = getchar();
		printf("Got '%c'\n",c);
		setecho(0);

		printf("Echo off -- enter a char: ");
		c = getchar();
		printf("Got '%c'\n",c);
		setecho(1);
		
	}

	for (;;) {
		printf("Echo on -- enter a line: ");
		gets(response);
		printf("Got '%s'\n",response);
		setecho(0);

		printf("Echo off -- enter a line: ");
		gets(response);
		printf("Got '%s'\n",response);
		setecho(1);
	}
}

