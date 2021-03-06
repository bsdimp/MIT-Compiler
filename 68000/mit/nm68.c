#include <stdio.h>
#include <b.out.h>

/*
 *	nm68 - print symbol table of .b file
 */

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
struct bhdr filhdr;	/* header of input file */
char cflag = 0;		/* list only C-style symbols: those beginning with _ */
char gflag = 0;		/* print only external (global) symbols */
char nflag = 0;		/* sort by value instead of name */
char pflag = 0;		/* don't sort */
char rflag = 0;		/* sort in reverse order */
char uflag = 0;		/* print only undefined symbols */
char hflag = 0;		/* print in hex rather than octal */
long offset = 0;
#ifndef vax
char *sortname = "/bin/sort";	/* name of command used to sort */
#else
char *sortname = "/usr/bin/sort";
#endif

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
	while((filename = nextname()) != NULL) nm();
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
	case 'c':	cflag++; break;
	case 'g':	gflag++; break;
	case 'n':	nflag++; break;
	case 'p':	pflag++; break;
	case 'r':	rflag++; break;
	case 'u':	uflag++; break;	
	case 'h':	hflag++; break;
	case 'o':	offset = atoi(flagptr); return;
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
	fprintf(stderr, "nm68: ");
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
	if (pflag == 0)
	{
		char *option1, *option2;	/* options to sort */
		option1 = (nflag ? "+0" : "+2");	/* value|id sort ? */
		option2 = (rflag ? "-r" : 0);		/* reverse order? */
		pipeline(sortname, sortname, "-t ", option1, option2, 0);
	}
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
  pipeline -	Connect a child process stdout via a pipe.
 *************************************************************************/

/* VARARGS */
pipeline(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9)
{
	int child;			/* proc id of child process */
	int fildes[2];
	
	if (pipe(fildes) < 0) fatal(e10);
	if ((child = fork()) != 0)	/* i am parent */
	{
		if (child < 0) fatal(e12);
		close(0);
		if (dup(fildes[0]) != 0) fatal(e11);
		close(fildes[0]);
		close(fildes[1]);
		execl(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9);
		fatal(e8);
	}
	else		/* i am child */
	{
		close(1);
		if (dup(fildes[1]) != 1) fatal(e11);
		close(fildes[0]);
		close(fildes[1]);
	}
}
/*************************************************************************
  nm -	Print symbols
 *************************************************************************/

nm()
{
	struct sym s;
	char type;
	long pos;
	char symbuf[SYMLENGTH];
	register char *sp;
	register int c;

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
		return;
	}
	fseek(infile, (long)(SYMPOS), 0);
	for(pos = 0; pos < filhdr.ssize; pos += sizeof(s)+strlen(symbuf)+1)
	{
/*		fread(&s, sizeof s, 1, infile);	*/
		get68(infile, &s.stype, sizeof(s.stype));
		get68(infile, &s.svalue, sizeof(s.svalue));
		for(sp = symbuf; sp < &symbuf[SYMLENGTH - 1]; sp++)
		{
			if ((c = getc(infile)) == EOF)
			{
				error(e9, filename);
				return;
			}
			if (c == 0) break;
			*sp = c;
		}
		*sp = 0;	/* make asciz */
		if (cflag)
		{
			if (symbuf[0] == '~' || symbuf[0] == '_')
			{
				register char *cp1 = &symbuf[0];
				register char *cp2 = &symbuf[1];
				while(*cp1++ = *cp2++);
			}
			else continue;
		}
		switch(s.stype & (037<<8))
		{
		case UNDEF:	type = s.stype & EXTERN ? 'C' : 'U';
				break;
		case ABS:	type = 'A'; break;
		case TEXT:	type = 'T'; break;
		case DATA:	type = 'D'; break;
		case BSS:	type = 'B'; break;
		default:	error(e5, s.stype, symbuf);
		}
		if (gflag && (s.stype & EXTERN) == 0) continue;
		if (uflag && type != 'U') continue;
		s.svalue += offset;
		if ((s.stype & EXTERN) == 0) type |= 040;
		if (hflag)
			printf("0x%08X %c %s\n", (long)s.svalue, type, symbuf);
		else printf("%011O %c %s\n", (long)s.svalue, type, symbuf);
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
