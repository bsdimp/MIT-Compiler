#include "mical.h"
char *ps1 = "~|^`s.ps1.c R1.9 on 12/18/79";

/*
 *	mical assembler-- .byte, .word, .long, .ascii, and .asciz handlers 
 *
 */


/* Print_No zero-suppress and zero-pad flags */
#define	ZS	0
#define	ZP	1

/* Extend()'s flush flag */
#define NOFLUSH	0
#define	FLUSH	1


/* initialized static variables for Extend() */
long Ext_buf[CODE_MAX];	/* the buffer for values */
char Ext_mark[CODE_MAX];	/* the buffer for corresponding Rel_mark */
int Ext_load = 0;		/* num of values in Ext_buf */
char Extension = 0;	/* 1 if first listing line printed already */
int Ext_nbytes = 0;	/* set by the calling routine, number of bytes to print for each value */

/* ByteWord(Which):	Which is 1 if a .BYTE was found by Pseudo(), and
			2 if a .WORD was found, 4 is .LONG was found
*/

struct {
	char	any_lf;		/* master switch. If 0, no listing is done */
	char	bin_lf;		/* binary code field of listing line */
	char	bex_lf;		/* binary extensions (e.g. from .word) */
	char	md_lf;		/* macro definitions */
	char	mc_lf;		/* macro calls */
	char	me_lf;		/* macro expansions */
	char	cnd_lf;		/* unsatisfied conditional blocks */
	char	ld_lf;		/* listing directives */
} Lflags ;

/* ByteWord -	Generate Constant Data */
ByteWord(Which)
register int Which;
{
	register int i;
	int Num;		/* number of bytes/words to pick up */
	
	extern char	O_list,		/* flag, 1 if listing requested */
			Code[];		/* generated code used by Put_Rel */
	extern int	Err_code;
	int *WCode = (int *)&Code[0];

	Ext_nbytes = Which==1?1:2;
	Num = Num_Operands();
	for (i = 0; i < Num; i++)		/* for each byte/word, */
	{
		Get_Operand(&Operand);
		if (Operand.type_o != t_normal) {
			Operand.sym_o = 0;
			Operand.type_o = t_normal;
			Operand.value_o = 0;
			Prog_Error(E_OPERAND);
		} else {
			if (Operand.sym_o)
				Put_Rel(&Operand, Which==1?B:Which==2?W:L, Dot+i*Which);
		}
		if (Which == 4) {
			WCode[0] = Operand.value_o >> 16;
			WCode[1] = Operand.value_o;
		} else
			WCode[0] = Operand.value_o;
		if (Which == 1)
			Put_Text(WCode, Which);
		else
			Put_Words(WCode, Which);
		if (Pass == 2 && O_list)
		{
			if (Which == 4)
			{
				Extend(Operand.value_o >> 16, NOFLUSH);
				Extend(Operand.value_o & 0xFFFF, NOFLUSH);
			}
			else Extend(Operand.value_o,NOFLUSH);
		}
	}
	if (Pass == 1) Print_Line(P_NONE);	/* copy line to temp */
	else if (O_list) Extend(0L,FLUSH);	/* list all of the values */
	else if (Err_code) Print_Error();	/* tell him about the error */
	BC = Num*Which;				/* increment byte count */
}

/*
 * Asciiz(Z):	called from Pseudo() with Z=0 for .ASCII and Z=1 for .ASCIZ 
 *
 *	Format of statement:
 *		.ASCII	"<chars>"
 *	where <chars> may include special escaped chars (see Grab_Char() )
 */

Asciiz(Z)
int Z;
{
	register int C;			/* the current character */
	register int count;		/* num of chars in string */
	register char delim;		/* string delimiter */
	extern int Code_length;		/* num of bytes of generated code */
	extern FLAG O_list;		/* listing flag */
	extern int	Err_code;	/* error code */

	Non_Blank();			/* first non-blank is delimiter */
	delim = Line[Position];
	if (Line_Delim(delim)){		/* no string, so nothing to do */
		Print_Line(P_LC);
		return; }

	Position++;			/* move up to first char */

	Code_length = Ext_nbytes = 1;	/* handling one-byte animals */
		/* changed to allow | in the middle of user strings -- JEA 5/5/81 */
	for(count=0;
	    ((Line[Position]=='|') || !Line_Delim(Line[Position])) 
					&& (C= Grab_Char()) > 0 && C!= delim;
	    count++)
		 LoadChar(C);	/* Handle the string proper */
	if (C != delim) Prog_Error(E_STRING);
	if (Z && C>0) { LoadChar(0); count++; }	/* do final zero if needed */
	if (Pass == 1) Print_Line(P_NONE);
	else if (O_list) Extend(0L,FLUSH);	/* flush the listing line */
	else if (Err_code) Print_Error();
	BC = count;			/* and increment Dot */
	return;
}

/* routine to load a char into the .rel file and list it */
LoadChar(C)
register int C; {
	extern char O_list;		/* 1 if listing wanted */

	Code[0] = C;			/* move char into code buffer, so */
	Put_Text(Code,1);
	if (Pass == 2 && O_list) Extend ((long)C,NOFLUSH);
}

/* Extend(Value,Fflag):
 * 	lists the current line, and any extensions for binary code.
 *	A buffer is kept of values to be listed in the code portion of the
 * listing line. When this buffer is full, the current line (or extension) is
 * printed out.
 *	Fflag, the flush flag, is 1 when this buffer is to be flushed, and
 * the last listing line is to be printed. Fflag should be zero otherwise.
 */


Extend(Value,Fflag)
long Value; int Fflag;
{
	register int i;
	extern FILE *listout;		/* file id of listing file */
	extern int 	L_radix,	/* listing radix, for Print_No() */
			L_ndigits,	/* also for Print_No() */
			Line_no,	/* current line number */
			Err_code;	/* current error code */
	extern char	Rel_mark,	/* ' if operand value is relocatable */
			E_warn;		/* W if current error is warning */
	extern FLAG	Expanding;	/* macro expansion flag */

	if (Lflags.any_lf == false) return;			/* if in .nlist mode, no listing at all */
	if (Fflag || (Ext_load * Ext_nbytes) >= CODE_MAX) {	/* If we need to flush the buffer, */
		if (Extension == 0) {			/* Check if this is the first listing line, */
			fprintf(listout, "%4d%c   ",Line_no,Expanding?'*':' ');	/* and if so, give him line number and Dot */
			Print_No((Dot>>24)&0177,L_radix,L_ndigits,ZP);
			Space_(1);
			Print_No(Dot,L_radix,2*L_ndigits,ZP);
			Space_(2); }
		else Space_(3*L_ndigits+11);		/* if it's an extension, skip Line number and Dot listing fields */
		if (Extension && (Lflags.bex_lf == false)) return; /* if binary extension disabled, skip it */
		for (i=0; i < Ext_load; i++) {		/* List the binary code */
			Print_No(Ext_buf[i], L_radix, Ext_nbytes * L_ndigits, ZP);	/* as words or bytes */
			putc(Ext_mark[i], listout);
			if (Ext_nbytes == 2) putc(' ', listout);
			else if (Ext_nbytes == 4) fprintf(listout, "    ");
		}
		for(i= Ext_load*Ext_nbytes; i < CODE_MAX; i++) Space_(L_ndigits+1);	/* skip to end of code field */
		Space_(2);			/* skip to error field */
		if (Err_code) Print_No((long)Err_code,10,2,ZS); 	/* and print error code, if any */
		else Space_(2);
		putc(E_warn, listout); Space_(2);
		if (Extension == 0) {		/* if this is the first line, */
			Extension++;		/* the next one's an extension */
			fprintf(listout, "%s",Line); }	/* List the source line */
		else putc('\n', listout);		/* if it's already an extension, just end the line */
		Ext_load = 0;
		Err_code = 0;			/* since we just printed it */
	}

	if (Fflag == 0)			/* if we're not flushing, load the value into buffer */
	 {  Ext_buf[Ext_load] = Value;
	    Ext_mark[Ext_load++] = Rel_mark;
	 };
	if (Fflag) {				/* if this was our last call for the current source line, */
		Extension = 0;			/* reset the static variables */
		Ext_nbytes = 0; }
	return;
}

