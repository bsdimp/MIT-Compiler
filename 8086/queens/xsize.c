static	char *sccsid = "@(#)size.c	4.3 (Berkeley) 7/2/81";
/*
 * size
 */

#include	<stdio.h>
#include 	<a.out.h>

/* the following defines added by Bill O'Farrell */
#define BMAGIC 017353 /* == 0x1eeb == 8086 jmp over 0x20 byte unix header */

#define	BN_BADMAG(x) \
    (((x).a_magic)!=OMAGIC && ((x).a_magic)!=NMAGIC && ((x).a_magic)!=ZMAGIC \
&& ((x).a_magic)!=BMAGIC)

int	header;

main(argc, argv)
char **argv;
{
	struct exec buf;
	long sum;
	int gorp,i;
	FILE *f;

	if (argc==1) {
		*argv = "a.out";
		argc++;
		--argv;
	}
	gorp = argc;
	while(--argc) {
		++argv;
		if ((f = fopen(*argv, "r"))==NULL) {
			printf("size: %s not found\n", *argv);
			continue;
		}
		if (fread((char *)&buf, sizeof(buf), 1, f) != 1 ||
		    BN_BADMAG(buf)) {
			printf("size: %s not an object file\n", *argv);
			fclose(f);
			continue;
		}
		if (header == 0) {
			printf("text\tdata\tbss\tdec\thex\n");
			header = 1;
		}
		printf("%x\t%x\t%x\t", buf.a_text,buf.a_data,buf.a_bss);
		sum = (long) buf.a_text + (long) buf.a_data + (long) buf.a_bss;
		printf("%ld\t%lx", sum, sum);
		if (gorp>2)
			printf("\t%s", *argv);
		printf("\n");
		fclose(f);
	}
}
