#include <stdio.h>
#include "b.out.h"

/*
	rl68 -	Print relocation commands
 */

#define NSYM	1000	/* number of symbols */


/* type and structure definitions */

struct symbol
{
	struct sym s;
	char *sname;
	int snlength;
};

typedef struct symbol *symp;

typedef struct name_seg *nlink;

struct name_seg
{
	char *nname;	/* pointer to name */
	nlink nnext;	/* next name in list */
};


/* global variables */

struct symbol symtab[NSYM];
int nextsym = 0;	/* next free slot in symbol table */
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
char *sortname = "/bin/sort";	/* name of command used to sort */

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
char *e13 = "symbol table overflow";
/*************************************************************************
	main -	process arguments, call major loop and go away
 *************************************************************************/

main(argc, argv)
int argc;
char *argv[];
{
	procargs(argc, argv);
	startup();
	while((filename = nextname()) != NULL)
	{
		if ((infile = fopen(filename, "r")) == NULL)
		{
			error(e3, filename);
			continue;
		}
		fread(&filhdr, sizeof filhdr, 1, infile);
		switch((int)filhdr.fmagic)
		{
		case FMAGIC:
		case NMAGIC:
			break;
		default:
			error(e4, filhdr.fmagic);
			continue;
		}
		getsyms();
		printcmds();
		fclose(infile);
	}
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
	fprintf(stderr, "rl68: ");
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
	getsyms -	Read in the symbol table.
 *************************************************************************/

getsyms()
{
	struct sym s;
	char type;
	long pos;
	char symbuf[SYMLENGTH];
	struct symbol *sp;
	register char *scp;
	register int c;
	int slength;

	fseek(infile, (long)(SYMPOS), 0);
	for(pos = 0; pos < filhdr.ssize; pos += sizeof(sp->s) + slength + 1)
	{
		if (nextsym >= NSYM) error(e13);
		sp = &symtab[nextsym++];
		fread(&sp->s, sizeof sp->s, 1, infile);
		if (feof(infile)) error(e9, filename);
		slength = 0;
		for(scp = symbuf; scp < &symbuf[SYMLENGTH - 1]; scp++)
		{
			if ((c = getc(infile)) == EOF)
			{
				error(e9, filename);
				return;
			}
			if (c == 0) break;
			*scp = c;
			slength++;
		}
		*scp = 0;	/* make asciz */
		sp->snlength = slength;
		sp->sname = (char*)calloc(1, slength+1);
		strcat(sp->sname, symbuf);
	}
}
/*************************************************************************
  printcmds -	Print relocation commands.
 *************************************************************************/

printcmds()
{
	long size;
	struct reloc rcmd;

	fseek(infile, RTEXTPOS, 0);
	for (size = 0; size < filhdr.rtsize; size += sizeof(rcmd)) cmd('T');
	fseek(infile, RDATAPOS, 0);
	for (size = 0; size < filhdr.rdsize; size += sizeof(rcmd)) cmd('D');
}


/*************************************************************************
  cmd -		Read and print one command.
 *************************************************************************/

cmd(area)
int area;
{
	struct reloc rcmd;
	char seg, size;
	char *sym;
	char idbuf[100];

	fread(&rcmd, sizeof(rcmd), 1, infile);
	if (feof(infile)) error(e9, filename);
	if (ferror(infile)) error(e9, filename);
	seg = "TDBE"[rcmd.rsegment];
	size = "BWL?"[rcmd.rsize];
	if (seg == 'E')
	{
		if (rcmd.rsymbol >= 0 && rcmd.rsymbol < nextsym)
			sym = symtab[rcmd.rsymbol].sname;
		else
		{
			sprintf(idbuf,"??????? bad symbol id %d",rcmd.rsymbol);
			sym = idbuf;
		}
		printf("%c %c %c %011O %s\n",area,seg,size,rcmd.rpos,sym);
	}
	else printf("%c %c %c %011O\n", area, seg, size, rcmd.rpos);
}

