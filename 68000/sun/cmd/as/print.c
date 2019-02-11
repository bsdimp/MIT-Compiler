#include "mical.h"
char *print = "~|^`s.print.c R1.5 on 1/22/80";

extern int *WCode;
extern FILE *listout;
/*	Print_Line, Print_No ;

	Print_Line() prints the current line to the appropriate file, depending on the pass.
		Pass 0:	(Descriptor file code) Nothing is printed;
		Pass 1:	The current error code and the source line is printed into the temproary file, for subsequent
			input to pass 2;
		Pass 2:	A regular assembly listing line is generated and printed into the standard output.
	Possible 'option's are:
		P_NONE:	List only the line number, error code (if any), and the source line.
		P_LC:	Same as P_NONE, but list value of location counter also.
		P_ALL:	Same as P_LC, but list the binary code generated as well.
	On pass 2, if the command line flag 'O_list' is zero (meaning no listing requested), then the line number 
	and error code of illegal statements is printed to the standard output.
*/

/* parameters to Print_No() */
#define ZS	0
#define ZP	1


/* External listing parameters */
int	L_radix = 16;		/* Radix for numbers in listing. Default is octal */
int	L_ndigits = 2;		/* Number of digits to express one byte in L_radix */

/* Listing option flags; set by .LIST and .NLIST directives */

struct {
	char	any_lf;		/* master switch. If 0, no listing at all is done */
	char	bin_lf;		/* binary code field of listing line */
	char	bex_lf;		/* binary extensions (e.g. from .word) */
	char	md_lf;		/* macro definitions */
	char	mc_lf;		/* macro calls */
	char	me_lf;		/* macro expansions */
	char	cnd_lf;		/* unsatisfied conditional blocks */
	char	ld_lf;		/* listing directives */
} Lflags =
	{ 1,1,1,1,1,1,1,0 } ;




Print_Line(option){
	register int i;		/* gen index */
	int fsave;
	extern FLAG	Ignore,		/* True if in unsatisfied conditional block, false otherwise */
			Expanding;	/* True if expanding a macro */
	extern int	Pass,		/* Pass number, obviously */
			Line_no,	/* Line number in source file */
			Code_length,	/* Number of bytes generated on this instruction */
			E_pass1,	/* Error code for pass 1 */
			Err_code;	/* Error code generated for current statement, valid only in pass 2 */
	extern char	Rel_mark,	/* (') if relocatable address generated, (<blank>) if not */
			E_warn,		/* (W) if current error is only a warning */
			O_print,
			O_list;		/* command line option, 1 if listing requested, 0 otherwise */
	extern FILE *Temp_file;	/* iobuf for intermediate file */
	extern char *lastc();

	if (Pass == 0) {	/* If in header file (pre-assembly code) */
		if (Err_code) Print_Error();	/* if error, print a msg on error output device */
		return;				/* otherwise, don't list anything */	}


	if (Pass == 1) {	/* On pass 1, create a line in the temporary file */
		putc(E_pass1,Temp_file);	/* put out error code in binary form */
		putc(Expanding?'*':' ',Temp_file);	/* put out * if macro expansion, blank otherwise */
		fputs(Line,Temp_file);		/* and put out source line */
		return; }
	if (O_list == 0 ) {	/* if no listing wanted , give him one anyway it there's an error */
		if (Err_code) Print_Error();	
		return; }


	if (Lflags.cnd_lf == 0 && Ignore) return;	/* if unsatisfied cond blocks not listed, don't */

	/* Check listing flags if line is to be listed. If there's an error,
		block is listed regardless of the flags. */
	if (Err_code == 0) 
		if (    (Lflags.any_lf == false) ||		/* .NLIST in effect */
			(Expanding && (Lflags.me_lf == false))	/* Macro expansion */
		   ) return;

/*
 *	Print listing line for pass 2; There are six fields: Line number, Expanding Flag, Location counter, Code, Error, and Source. 
	Each field is separated with 3 blanks; within a field, individual numbers are separated by one blank, 
	except for the Source field.

	Any changes made in the listing line format should be reflected in the routine
Extend() in the file ps1.c, which does the listing for binary extension instructions (e.g. .WORD).
 *
 */

  /* Line number and expanding flag */
	fprintf(listout, "%4d%c   ",Line_no,Expanding?'*':' ');		/* Print line number for all options */


  /* Location counter */
	if (option == P_NONE) Space_(3*L_ndigits+3);
	else {
		Print_No((Dot>>24)&0177,L_radix,L_ndigits,ZP);
		Space_(1);
		Print_No(Dot&0xFFFF,L_radix,2*L_ndigits,ZP);
		Space_(2); }
  /* Code */
	if (option == P_ALL && Lflags.bin_lf) {	/* If binary code listing desired */
	    for(i=0;i<CODE_MAX/2;i++)		/* For each possible word of generated code */
		if (i >= Code_length/2) Space_(2*L_ndigits+2);	/* Skip enough space if it wasn't actually generated */
		else {						/* If it was, print it out. */
			Print_No(0XFFFFL&((long)WCode[i]),L_radix,2*L_ndigits,ZP);
/*			if (i == Rel_byte_no) putc(Rel_mark, listout);	/* If this could be the low byte of a */
									/* relocatable address, mark it */
			/* else */ Space_(2); }				/* otherwise skip a space */
	} else Space_((CODE_MAX/2)*(2*L_ndigits+2));	/* If we don't want code listed, skip enough space for it */
  /* Error */
	Space_(2);					/* separate from other fields */
	if (Err_code) Print_No((long)Err_code,10,2,ZS);	/* if any error, print it's code */
	else Space_(2);					/* otherwise skip the field */
	putc(E_warn, listout);				/* put out 'W' if its a warning */
	Space_(2);					/* separate fields */
  /* Source line */
	fputs(Line, listout);				/* Nothing hard about that */

	/* if Line ends with form-feed, supply carriage return */
	if (*lastc(Line) == '\014') putc('\015', listout);
	return;
}


/* Space_(Numspaces) just puts 'Numspaces' blanks out */
Space_(Numspaces)
register int Numspaces;
{
	register int i;
	for(i=0;i<Numspaces;i++) putc(' ',listout);
}


/* Print_No(val,radix,width,z) :
	Argument	Explanation
	value:		number to be printed;
	radix:		8,10, or 16 for octal, decimal, or hexadecimal notation respictively;
	width:		field width--number is placed right-justified with left padding of blanks or zeroes;
	zflag:		ZP for zero left padding, ZS for blank (zero-suppress) padding;
 
	It treats 'value' as a 16 bit unsigned integer 
*/
Print_No(val,radix,width,zflag)
 long val;
 {
	register char 	Buf[16];
	register int	bl,T;

	bl = 15;			/* load buffer from the end */
	val &= 0177777L;		/* mask to 16 bits */
	do {				/* do...while so that a value of zero gets printed */
		T = val % radix;		/* get value of digit */
		if (val<0) T += radix;
		Buf[bl] = (T<10) ? (T+'0') : (T+'A'-10);	/* load ascii value of digit */
 		val = val / radix;		/* set up for next digit */
		--bl; --width; }
	while (val>0 && width>0 && bl >= 0) ;	/* we've got all of the digits */
	for(; width>0 && bl>=0; (--bl, --width))	/* left pad with zeroes or blanks */
		Buf[bl] = zflag ? '0' : ' ';
	for(bl++; bl<16; bl++) putc(Buf[bl],listout);		/* and print the buffer */
}

/* NList() -- implements .list, .nlist directives.

Listing options are noted in a Listing Flag table: Lflags, defined above. Entries are 1 if option is listed, 0 if not.

These flags are checked in the various routines that call Print_Line, and in
Print_Line itself.

This routine merely processes a .list or .nlist directive, which sets/resets the various listing flags.
The argument Which is 1 for .list directives, 0 for .nlist. Nlist() is called
from Pseudo(), in ps.c.
*/


NList(Which)
FLAG Which;
{
	char	S[STR_MAX];	/* utility char string */
	FLAG	args_there;	/* set if any arguments to .list/.nlist */
	extern  Lower();	/* convert to lower case function */

	if (Pass == 1) {	/* On pass 1, just copy line to temp file */
		Print_Line(P_NONE);
		return; }

	if (Lflags.ld_lf) Print_Line(P_NONE);	/* if listing directives are listed, then do so */
	
	/* Loop through the arguments, setting the appropriate listing flags */
	/*  If no arguments, set master switch */
	args_there = false;
	while (Get_Token(S)) {	/* pickup next argument */
		Lower(S);	/* convert to lower case */
		args_there = true;
		if (seq(S,"bin")) Lflags.bin_lf = Which;
		else if (seq(S,"bex")) Lflags.bex_lf = Which;
		else if (seq(S,"md"))  Lflags.md_lf = Which;
		else if (seq(S,"mc"))  Lflags.mc_lf = Which;
		else if (seq(S,"me"))  Lflags.me_lf = Which;
		else if (seq(S,"cnd")) Lflags.cnd_lf = Which;
		else if (seq(S,"ld"))  Lflags.ld_lf = Which;
		else Prog_Warning(E_ARGUMENT);			/* invalid argument */
		Non_Blank(); if (Line[Position]==',') Position++; /* skip comma */
	}
	if (args_there == false) Lflags.any_lf = Which;		/* if no args, then master switch set */
	return;
}

