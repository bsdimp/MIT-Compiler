/* 			68000 Disassembler
 *    			    V.R. Pratt
 *    			    Jan., 1981
 */

#include "ddt.h"

#define NOARGS 6		/* maximum number of opcode arguments */
#define NEARGS 3		/* maximum number of eff.adr. arguments */

/* Symbols external to dasmsub 
 */

char legal;					/* keeps track of *'s */

/* Symbols global to dasmsub but not external.
 */

static long opargs[NOARGS], 			/* where to put opcode args */
     eargs[NEARGS]; 				/* where to put ea args */
static int  argno;				/* global pointer into args */
static int nwords;				/* words in instruction */
static unsigned short *mpc, 			/* main program counter */
      	       *spc;				/* start pc */

static char longflag;				/* 1 -> long */
static char sym;				/* 1 -> symbolic addresses */
static char sizmod;				/* 1 -> one-bit size field */

/* Some general routines.
 *
 * We don't actually talk to the outside world directly. Output is dumped
 * dumped into one of two global buffers and we leave it up to the caller
 * to decide what is to be done with it.
 */

struct cbuffr bfr1, bfr2;		/* the two buffers */
struct cbuffr *cbfp;			/* pointer to active one */

/* As characters are placed in the output buffer, we keep track of the
 * column position and watch out for the special character '*'. This is
 * indication that we have just attempted to disassemble an illegal
 * instruction and the global flag "legal" is cleared.
 */

dasmput(c)
register char c;
{
register int lcol = cbfp->col;

    if ( c != '\t' ) lcol++;
    else lcol = ( ( lcol + 8 ) / 8 ) * 8;
    if ((cbfp->buf[cbfp->pnt++] = c) == '*') legal = 0;
    cbfp->col = lcol;
}

/* The usual routines for numeric conversion.
 *
 * First, an external routine to output a number in some radix.
 */

extern void numout();			/* type a number in current radix */

/* Convert a long to it's ascii hex representation regardless of the
 * "current radix".
 */

static
hex(n)
register unsigned long n;
{
    if ( n > 15 ) hex( n >> 4 );
    n &= 15;
    dasmput((char)( n + ( n>9 ? '7': '0')));
}

/* Convert an integer to it's ascii hex representation in exactly four
 * digits. Insert leading zeroes if required.
 */

static
whex(n)
register unsigned int n;
{
register int i;
register char c;

    for( i = 12; i >= 0; i -= 4)
    {
	c = n>>i & 15;
	dasmput( c + ( c>9? '7': '0'));
    }
}

/* This is a compact disassembler intended for use in the 68000 design
 * module.
 *
 * Principles of Operation
 * 
 * The disassembler has the following components.
 * 
 * 1.  A list of instruction patterns and their assembler forms,
 * each serving as the head of a function definition.
 * 
 * 2.  A list of effective addresses and their assembler forms, each serving
 * as the body of a function definition.
 * 
 * 3.  A function to locate the first entry in the appropriate list matching 
 * a given instruction or effective address, serving as the
 * function-identification component of an eval.
 * 
 * 4.  A function to bind the actual parameters in the instruction or
 * effective address to the formal parameters in the function head.
 * 
 * 5.  A function to substitute the formal parameters into the function body.
 * 
 * 
 * Lists
 * 
 * The two lists are machine readable forms of those given in /usr/pratt/ins68
 * (see /usr/pratt/ins.f for the format of this file).  In the machine
 * readable form each entry has the following structure.
 */

typedef struct Entry
       {char length;
	char modifier;
	unsigned short mask;
	unsigned short pattern;
       } *entry;

/* Following each entry is a character string, considered part of the entry.
 * The entries are concatenated to form a table.  The entry boundaries are
 * determined only by the length member, the tables being intended to be
 * searched forwards linearly.  Entries are aligned on word boundaries.
 * 
 * The length of an entry is the number of bytes in the entry, which may be
 * odd in which case the following entry is one byte further along than
 * indicated by length.
 * 
 * Fparams is an array of 6 formal parameters, each an unsigned nybble (4-bit
 * integer) encoding the type of that parameter.
 *
 * The mask and the pattern together are used to tell whether an item such
 * as an opcode matches entry e, by the test:
 */

#define match(item,ent) ((item ^ ent->pattern) & ent->mask) == 0

/* Match is used by the locate routine, which locates the first entry in the
 * given table matching the given code.
 */

static entry
locate(code,tab) register code; register entry tab;
{
    while (1)				/* guaranteed to find something */
    {
	if (match(code,tab)) break;
	tab = (entry)((long)tab + tab->length + 1 & -2);/* go to next entry */
    }
    return(tab);
}

/* The mask and pattern are also used to extract the arguments from an item 
 * such as an opcode or an effective address.  These are extracted 
 * right-to-left from the item by the function bind and stored in 
 * in successive locations of the area args supplied to bind.
 */

#define shft	{item >>= 1; pattern >>= 1; mask >>= 1;}

static
bind(item,pattern,mask,args)
register short unsigned item, pattern, mask;
long args[];
{
    while (1)					/* loop per argument */
    {
	while (mask&1) shft;			/* skip masked part */
	if (!pattern) break;			/* stopping cond. */
	args[argno++] = (long)(char)(item&(pattern ^ pattern-1)); /* bind */
	while (!(pattern&1)) shft;  shft;	/* skip field */
    }
}

static
bindmod(m,args) register char m;		/* bind modifier */
		register long args[];		/* bind arg */
{
/*n*/	if (m&1 && (!(m&2) || !longflag)) args[argno++] = (short) getwpc((short*)mpc++);
/*i*/	if (m&2 && (!(m&1) || longflag)) {args[argno++] = getlpc((long*)mpc++); mpc++;}
/*g*/   if (m&8) {
		args[argno++] = (unsigned)getwpc(mpc)>>8;
		args[argno++] = getbpc((char *)mpc++ + 1);
	}
/*l*/	if (m&16) longflag = 1;
/*p*/	if (m&32) sym = 1;
/*t*/	if (m&64) sizmod = 1;
/*u*/	if (m&128) args[argno++] = getwpc(mpc++);
}

/* Symbols are dealt with as follows:
 *
 * Output a symbol's name.
 */

static
putsymbol(c) register char *c; 
{
register int i=MAXSYMLEN;

    while (*c != ' ' && *c != '\0' && i--) dasmput(*c++);
}

/* Given a long value "n", and pointer to a symbol table definition,
 * find the symbol entry whose value is 'closest' to "n".
 */
struct sym *
dasmsymbol(n, table)
register long n;
symtabdef *table;
{
register struct sym *current, *best;
register long bestvalue = 0;

#ifdef DM
    for (current = table->start; current < table->limit; current++)
#else
    for (current = table->start; 
	 current < table->limit; 
	 current = (struct sym *)((int)(current+1) + current->slength + ADJ))
#endif DM
	if (bestvalue < current->svalue  &&  current->svalue <= n)
	{
	    best = current;
	    bestvalue = current->svalue;
	}
    return(bestvalue && n - bestvalue < 1000? best: 0);
}

/* Given a value "v", look for a symbol whose value is 'closest' to "v".
 * If one is found, output the name of that symbol, otherwise, output the
 * numeric value of "v" in the current radix.
 */
struct sym *dasmsymbolic(v, table)
register long v;
symtabdef *table;
{
register struct sym *e = dasmsymbol(v, table);
    if (e)
    {
	putsymbol(e+1); 
	if (e->svalue < v) 
	{
	    dasmput('+');
	    numout(v - e->svalue);
	}
    }
    else numout(v);
    return( e );
 }

/* Given a long "y", return it's bit reversal.
 */
static long
rev(y)
long y;
{
register long z=0;
register n=16;
    while (n--)
    {
	z = z<<1|(y&1);
	y>>=1;
    }
    return(z);
}


/* The tables of opcodes and eacodes (for effective addresses) are kept on
 * separate files ops68.c and ea68.c.
 */

static unsigned char
optab[] = {
#ifdef MC68000
#include "ops68.c"
#else ndef MC68000
#include "vops68.c"
#endif MC68000
};

static unsigned char
eatab[] = {
#ifdef MC68000
#include "ea68.c"
#else ndef MC68000
#include "vea68.c"
#endif MC68000
};

/* The heart of this file is instr(), which returns the assembler form
 * of the instruction presently pointed to by mpc.  As a side effect it 
 * advances mpc to the word following the instruction.
 */

static
instr()						/* process next instruction */
{
    sizmod = 0;					/* assume two-bit size field */
    longflag = 0;				/* assume short data */
    legal = 1;					/* innocent till proved g'ty */
    sym = 0;					/* assume nonsymbolic data */
    spc = mpc;					/* remember mpc */
    if( getwpc(mpc) )				/* if word at pc isn't 0 */
	translate( getwpc(mpc++),optab,opargs);	/* translate opcode */
    else
	legal = 0;				/* assume data */
    if (!legal) {
	mpc = spc+1;				/* assume one word */
}
 }

/* The function translate(item,tab,args) translates item, which is either
 * an opcode or an effective address, using the appropriate table tab, either
 * optab or eatab, using args as the base address of the stack of
 * arguments extracted from the item in the course of translation, by the
 * binding mechanisms.
 */

static
translate(item,tab,args)
unsigned short item;
char *tab;
long args[];
{
    entry ent = locate(item,tab);		/* locate entry for opcode */
    argno = 0;					/* where to store args */
    bind(item,ent->pattern,ent->mask,args);	/* bind item arguments */
    bindmod(ent->modifier,args);		/* bind modifier arguments */
    subst((long)ent+6,(long)ent+ent->length,args);	/* substitute args */
}

/* The function subst takes a pair of pointers pointing to the two ends of
 * a string whose free variables are to be instantiated, and a pointer to
 * a stack of arguments to be bound to those variables.
 */

static
subst(cod,lim,args)
char *cod, *lim;
long args[];
{
    while (cod<lim)				/* substitute up to lim */
    if (*cod >= 0) dasmput(*cod++);		/* copy the char directly */
    else					/* execute the command *cod */
    {
	register long v = args[(*cod >> 4) & 7];/* get value v */
	char *siz = "bwl*";
	char *cc  = "rasrhilscccsneeqvcvsplmigeltgtle";/* condition codes */
	char r = 'a';
	switch (*cod++ & 15)
/*k*/	{case 0:  if (v<128) r += 3;
		  dasmput(r);
		  dasmput('0'+((v>>4)&7));
		  dasmput(':');
		  dasmput(v&8? 'l': 'w');
		  break;
/*d*/	 case 1:  r += 3;		/* do a->d conversion */
/*a*/	 case 2:  dasmput(r);
		  dasmput('0'+(v&7));
		  break;
/*E*/	 case 3:  v = ((v&7)<<3)|(v>>3);
/*e*/	 case 4:  translate((short)v,eatab,eargs); 
		  break;
/*s*/	 case 5:  v+=sizmod; dasmput(siz[v]); 
		  if (v==2) longflag = 1;
		  break;
/*v*/	 case 6:  if (v == 0) v = 8;
/*n*/	 case 7:  if (v<0) {
			dasmput('-'); 
		  	numout((long)-v);
		  	break;
		  }
/*u*/	 case 8:  dasmsymbolic((long)v, USRSYMS); 
		  break;
/*y*/	 case 9:  v = rev((long)v);
/*x*/	 case 10: hex((long)(v&0xffff)); break;
/*m*/	 case 11: if (v) cod += *cod; else cod++; break;
/*f*/	 case 12: while (v--) while (*cod++ != ',');
		  while (*cod != ',' && *cod != ')') dasmput(*cod++); 
		  while (*cod++ != ')'); break;
/*c*/	 case 13: dasmput(cc[v*2]); dasmput(cc[v*2+1]); break;
/*r*/	 case 14: dasmsymbolic((long)spc+2+v, USRSYMS); break;
	}
    }
}

/* Finally, the main entry point to this collection of routines.
 * Given a word address, we interpret the word(s) at that address
 * as a 68000 instruction and disassemble them putting the disassembled
 * "source" text in one output buffer, and the hex ascii representation
 * in another. The number of words disassembled is returned.
 */
int dasm(address)
unsigned short *address;
{
     mpc = address;
     bfr1.pnt = bfr2.pnt = 0;
     bfr1.col = bfr2.col = 1;
     cbfp = &bfr1;			/* start off in first buffer */
     dasmsymbolic((long)mpc, USRSYMS);
     if (cbfp->col <= 8) dasmput('\t'); dasmput('\t');
     instr();				/* dis-assemble the instruction */
     dasmput('\0');
     cbfp = &bfr2;			/* switch to second for hex */
     hex((long)spc);			/* address in hex */
     dasmput('\t');
     do {
	whex( getwpc(spc++) );
	dasmput(' ');
	} while (spc < mpc);
     while (cbfp->col < 32) dasmput('\t');
     dasmput('\0');
     return((int) (mpc - address) );
}
