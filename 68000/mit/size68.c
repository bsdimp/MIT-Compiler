#include <stdio.h>
#include <b.out.h>

/*
	size68	[-hl]	<file1> ... <filen>	Print sizes of segments.
	-h	print in hex format
	-l	print long format
 */


/* type and structure definitions */

typedef struct name_seg *nlink;

struct name_seg
{
	char *nname;	/* pointer to name */
	nlink nnext;	/* next name in list */
};


/* global variables */

int argnum;		/* number of current argument being processed */
nlink namelist = NULL;	/* list of filenames to process */
char *filename;		/* input file name */
FILE *infile;		/* id of input file */
char hflag = 0;		/* print in hex */
char lflag = 0;		/* print long form */
char nflag = 0;		/* print names of files */
struct bhdr filhdr;	/* header of input file */

/* Internal functions */

char *nextname();


/* Error Messages */

char *e1 = "filename required following -%c option";
char *e2 = "unrecognized option: %c";
char *e3 = "file %s not found";
char *e4 = "unrecognized magic number %O";
char *e5 = "unrecognized type %o on symbol %s";
char *e6 = "could not reopen pipe as stdout";
char *e7 = "could not reopen pipe as stdin";
char *e8 = "could not exec %s";
char *e9 = "file %s format error, unexpected eof";
char *e10 = "pipe failed";
char *e11 = "dup failed or returned wrong value";
char *e12 = "fork failed";
char *e13 = "read error on file %s";
/*************************************************************************
	main -	process arguments, call major loop and go away
 *************************************************************************/

main(argc, argv)
int argc;
char *argv[];
{
	procargs(argc, argv);
	startup();
	while((filename = nextname()) != NULL) size();
	cleanup();
	exit(0);
}



/*************************************************************************
	procargs - process command arguments
 *************************************************************************/

procargs(argc, argv)
int argc;
char *argv[];
{
	if (argc > 2)
		nflag = 1;
	for (argnum = 1; argnum < argc; argnum++) {
		if (argv[argnum][0] == '-' )
			procflags(&argv[argnum][1], argc, argv);
		else newname(argv[argnum]);
	}
}


/*************************************************************************
	procflags - process flags
 *************************************************************************/

procflags(flagptr, argc, argv)
char *flagptr;
int argc;
char *argv[];
{
	char c;
	while (c = *flagptr++) switch(c)
	{
	case 'h':	hflag = 1; break;
	case 'l':	lflag = 1; break;
	case 'n':	nflag = 1; break;
	default:	error(e2, c);
	}
}

/*************************************************************************
	error - type a message on error stream
 *************************************************************************/

/*VARARGS1*/
error(fmt, a1, a2, a3, a4, a5)
char *fmt;
{
	fprintf(stderr, "size68: ");
	fprintf(stderr, fmt, a1, a2, a3, a4, a5);
	fprintf(stderr, "\n");
}


/*************************************************************************
	fatal - type an error message and abort
 *************************************************************************/

/*VARARGS1*/
fatal(fmt, a1, a2, a3, a4, a5)
char *fmt;
{
	error(fmt, a1, a2, a3, a4, a5);
	exit(1);
}
/*************************************************************************
  startup -	Fork off a trailing process to sort symbols.
 *************************************************************************/

startup()
{
}



/*************************************************************************
	cleanup	- 
 *************************************************************************/

cleanup()
{
}


/*************************************************************************
  newname -	Attach a new name to the list of names in name list.
 *************************************************************************/

newname(name)
char *name;
{	nlink np1, np2;
	np1 = (nlink)malloc(sizeof(*np1));
	np1->nname = name;
	np1->nnext = NULL;
	if (namelist == NULL) namelist = np1;
	else
	{	np2 = namelist;
		while(np2->nnext != NULL) np2 = np2->nnext;
		np2->nnext = np1;
	}
}


/*************************************************************************
  nextname - 	Return the next name from the list of names being processed.
 *************************************************************************/

char *nextname()
{
	nlink np;
	if (namelist == NULL) return(NULL);
	np = namelist;
	namelist = np->nnext;
	return(np->nname);
}
/*************************************************************************
  size -	Print segment sizes
 *************************************************************************/

size()
{
	long t;

	if ((infile = fopen(filename, "r")) == NULL)
	{
		error(e3, filename);
		return;
	}
/*	fread(&filhdr, sizeof filhdr, 1, infile);	*/
	get68(infile, &filhdr.fmagic, sizeof(filhdr.fmagic));
	get68(infile, &filhdr.tsize, sizeof(filhdr.tsize));
	get68(infile, &filhdr.dsize, sizeof(filhdr.dsize));
	get68(infile, &filhdr.bsize, sizeof(filhdr.bsize));
	get68(infile, &filhdr.ssize, sizeof(filhdr.ssize));
	get68(infile, &filhdr.rtsize, sizeof(filhdr.rtsize));
	get68(infile, &filhdr.rdsize, sizeof(filhdr.rdsize));
	get68(infile, &filhdr.entry, sizeof(filhdr.entry));
	switch((int)filhdr.fmagic)
	{
	case OMAGIC:
	case FMAGIC:
	case NMAGIC:
	case IMAGIC:
		break;
	default:
		error(e4, filhdr.fmagic);
		fclose(infile);
		return;
	}
	t = filhdr.tsize + filhdr.dsize + filhdr.bsize;
	if (nflag)
	{
		printf("%s:\n", filename);
		if (lflag)
			printf("\n");
	}
	if (hflag)
	{
		if (lflag)
		{
			printf("fmagic:\t0%O\n", filhdr.fmagic);
			printf("tsize:\t0x%X\n", filhdr.tsize);
			printf("dsize:\t0x%X\n", filhdr.dsize);
			printf("bsize:\t0x%X\n", filhdr.bsize);
			printf("ssize:\t0x%X\n", filhdr.ssize);
			printf("rtsize:\t0x%X\n", filhdr.rtsize);
			printf("rdsize:\t0x%X\n", filhdr.rdsize);
			printf("entry:\t0x%X\n", filhdr.entry);
		}
		else
		{
			printf("TSIZE\tDSIZE\tBSIZE\tTOTAL\n");
			printf("0x%X\t0x%X\t0x%X\t0x%X (%D decimal)\n",
				filhdr.tsize, filhdr.dsize, filhdr.bsize,
				t, t);
		}
	}
	else
	{
		if (lflag)
		{
			printf("fmagic:\t0%O\n", filhdr.fmagic);
			printf("tsize:\t%D\n", filhdr.tsize);
			printf("dsize:\t%D\n", filhdr.dsize);
			printf("bsize:\t%D\n", filhdr.bsize);
			printf("ssize:\t%D\n", filhdr.ssize);
			printf("rtsize:\t%D\n", filhdr.rtsize);
			printf("rdsize:\t%D\n", filhdr.rdsize);
			printf("entry:\t0%O\n", filhdr.entry);
		}
		else
		{
			printf("TSIZE\tDSIZE\tBSIZE\tTOTAL\n");
			printf("%D\t%D\t%D\t%D\n",
				filhdr.tsize, filhdr.dsize, filhdr.bsize, t);
		}
	}
	fclose(infile);
}

get68(file, p, c)
register FILE	*file;
register char	*p;
register c;
{
	if(c == 2) {
		*(short *)p = getc(file);
		*(short *)p = *(short *)p << 8 | getc(file);
	}
	else {
		*(long *)p = getc(file);
		*(long *)p = *(long *)p << 8 | getc(file);
		*(long *)p = *(long *)p << 8 | getc(file);
		*(long *)p = *(long *)p << 8 | getc(file);
	}

	if (feof(file)) fatal(e9, filename);
	if (ferror(file)) fatal(e13, filename);
}
