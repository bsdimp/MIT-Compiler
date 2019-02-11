#include "mical.h"
char *ps2 = "~|^`s.ps2.c R1.4 on 12/13/79";
/*
 *
 *	Handlers for pseudo-ops--
 *
 *		.BLKB, .BLKW, .BLKL
 *		.CSECT, .ASECT
 *		.RADIX
 */

/* size of radix_tab */
#define RTSIZE	8


struct csect Csects[CSECT_MAX] =
{
		".text",0,0,0,R_ISPC|R_PURE,	/* text csect */
		".data",0,0,0,0,		/* data csect */
		".bss",0,0,0,0			/* uninitialized csect */
} ;
int Csect_load = 4;			/* Next available csect in Csects[] */
struct csect	*Cur_csect = &(Csects[0]);	/* ptr to current csect */
struct csect	*Text_csect = &(Csects[0]);
struct csect	*Data_csect = &(Csects[1]);
struct csect	*Bss_csect = &(Csects[2]);

extern char *Store_String();
extern struct sym_bkt *Lookup();

/* Blkbw(Which)--	.blkb, .blkw, .blkl handler
 *
 *	Which is 1 for .blkb, 2 for .blkw, 4 for .blkl
 *	Reads an operand specifying the number of bytes/words to reserve space
 *      for, and moves the location counter past this block.
 */

Blkbw(Which)
register int Which;
{
	register int 	Num;
	extern int 	E_pass1;	/* for errors in pass 1 */
	long int	fill = 0;
	register int	i;

	if (Get_Operand(&Operand) && (Operand.sym_o == 0)
	    && ((Num = Operand.value_o) >= 0))
		BC = Num * Which;	/* this many bytes */
	else Prog_Error(E_pass1 = E_CONSTANT);
	for (i=0; i<Num; i++)		/* have to output filler bytes */
		Put_Text((char *)&fill, Which);
	Print_Line(P_LC);
}

/*
 *
 *	Csect()-- .csect handler
 *
 *	Format:		.csect	[<name>] [[,<attr>],<attr>]
 *	<name> is any legal symbol name, <attr> is either EXT or ABS, for
 * external and absolute attributes.
 * 	if <name> is absent the default (unnamed) csect is entered.
 *
 */
Csect()
{
	register struct csect	*csp;
	register int		i;
	register char		S[STR_MAX];
	FLAG			Defining,	/* when csect being entered for first time */
				Warn;		/* when he uses illegal attributes */
	extern struct csect	Csects[],	/* collection of csects */
				*Cur_csect;
	extern int		Csect_load;	/* next available csect in Csects[] */
	Defining = Warn = FALSE;
	if (((i = Get_Token(S)) == 0) && (Line_Delim(Line[Position]) == false))
		Prog_Error(E_SYMBOL);
	else {
		if (i == 0)
			csp = &Csects[0];
		else {
			for (i=0; i< Csect_load; i++)
			    if (seq(Csects[i].name_cs,S)) break;
			csp = &(Csects[i]);
			if (i == Csect_load) {	/* Make a new csect */
				Defining = TRUE;
				Csect_load++;
				csp->name_cs = Store_String(S);
				csp->len_cs = csp->id_cs = csp->attr_cs = csp->dot_cs = 0; }
			Non_Blank();
			do {
				if (Line[Position] == ',') Position++;
				if (Get_Token(S) == 0) {
				    if (Line_Delim(Line[Position]) == 0) Warn = TRUE;
				    break; }
				Lower(S);
				if (seq(S,"abs"))
				    if ((Defining == FALSE) && ((csp->attr_cs & R_ABS) == 0))
					Warn = TRUE;	/* redeclared attribute */
				    else csp->attr_cs |= R_ABS;
				else if (seq(S,"ext"))
				    if ((Defining == FALSE) && (( csp->attr_cs & R_EXT) == 0))
					Warn = TRUE;
				    else csp->attr_cs |= R_EXT;
				else Warn = TRUE;
				Non_Blank();
			    } while (Line[Position] == ',');
	
			if (Warn) Prog_Warning(E_ATTRIBUTE);
		}
		New_Csect(csp);		/* move to new csect */
	    }
	Print_Line(P_NONE);
}
/* New_Csect(csp)
 *	Input:	argument csp is a ptr to csect structure
 *	Side effects:	1. "The current csect" is made to be *csp.
 *			2. A symbol with the same name as the new csect is created, with the value of zero in that csect
 *			3. The appropriate command for the .rel file is loaded on pass 2.
 *	Called From:	Csect()
 */
New_Csect(csp)
register struct csect *csp;
{
	register struct sym_bkt *sbp;	/* for defining new symbol */
	extern struct csect *Cur_csect;	/* ptr to current csect */
	extern struct sym_bkt	*Last_symbol;	/* used for local symbols */
	extern struct sym_bkt	*Dot_bkt;	/* sym_bkt for location counter */
	
	Cur_csect = csp;
	Dot = csp->dot_cs;
	Dot_bkt->csect_s = Cur_csect;	/* update dot's csect. Dot_bkt->value_s will be updated in the main loop */

	sbp = Lookup(csp->name_cs);
	sbp->attr_s |= S_DEC | S_DEF | S_LOCAL;	/* local attribute so it won't be listed in symbol table */
	sbp->csect_s = Cur_csect;
	sbp->value_s = 0;
	Last_symbol = sbp;

}
/*
 *	Radix()--	.radix handler
 *
 *	Format:		.radix	{in,out}, <radixname>
 *		"in" refers to the default radix for numbers in source statements
 *	"out" refers to the radix of the LC and Code fields on the output listing.
 *		<radixname> is one of the following strings:
 *	'2','8','10','16','binary','octal','decimal', or 'hex'.
 */

struct rt_entry {
	char	*name_r;		/* name of radix */
	int	value_r, cpb_r;	/* value and chars per byte */
} radix_tab[RTSIZE] =
       {"octal", 8, 3,
	"8", 8, 3,	
	"decimal", 10, 3,
	"10", 10, 3,
	"hex", 16, 2,
	"16", 16, 2,
	"binary", 2, 8,
	"2", 2, 8  
       };

Radix() {
	register int i;
	register char S[STR_MAX];
	register int rad;
	FLAG	Got,In,Error;
	extern int In_radix,L_ndigits,L_radix;

	if (Get_Token(S)== 0) Error++;
	else {
		Lower(S);
		Got = FALSE;
		In = FALSE;
		if (seq(S,"out")) In = FALSE;
		else  if (seq(S,"in")) In = TRUE;
		else Got = TRUE;			/* got the radix */
		Error = 0;
		Non_Blank();
		if (Line[Position] == ',') Position++;
		if (Got || Get_Token(S)) {		/* pick up radixname, if we don't have it yet); */
			for (i=0; i<RTSIZE; i++) 
			    if (seq(radix_tab[i].name_r,S)) {
				rad = radix_tab[i].value_r;
				if (In) { In_radix = rad; break; }
				else {
				    L_radix = rad;
				    L_ndigits = radix_tab[i].cpb_r;
				    break; }
			    }
			if (i>=RTSIZE) Error++;
		}
	}
	if (Error) Prog_Error(E_OPERAND);
	Print_Line(P_NONE);
	return;
}

/* Insrt()-	.insrt handler
 *	source line is:		.insrt	/<filename>/
 *
 * where / means any character and <filename> is a valid UNIX filename.
 * 	Side Effects: opens filename for reading and pushes an io-buffer for
 * it onto Source_stack. This causes input to the assembler to come from the
 * indicated file. Upon eof, input resumes from the previous input file.
 *	.insrt's can be nested to a depth of SSTACK_MAX files.
 */

Insrt() {

	register char 	C;
	extern	int E_pass1;
	char		filename[STR_MAX], delim;
	FILE	 	*iop;
	FLAG		eflag = false;
	int		i;

	if (Pass == 2) {
		Print_Line(P_NONE);
		return;
	}

					/* Pick up name of file */
	Non_Blank();			/* locate delimiter character of string containing filename */
	delim = Line[Position];
	if (Line_Delim(delim)) eflag = true;		/* no filename specified */
	else {
		Position++;				/* move past delimiter */
		for (i=0; (C=Grab_Char()) > 0 && C != delim && i < STR_MAX-1 && !Line_Delim(C); i++)
			filename[i] = C;		/* pick up string */
		if (C != delim) Prog_Error(E_pass1 = E_STRING);	/* invalid string representation */
		else {
		    filename[i] = 0;			/* end of filename */
		    Position++;				/* move past closing delimiter */
		    if ((iop = fopen(filename,"r")) !=NULL) Push_Source(iop);
		    else eflag = true;
		}
	}

	if (eflag) Prog_Error(E_pass1 = E_FILE);
	Print_Line(P_LC);
	return;
}


Page()
{
	extern int Line_no;
	extern FILE *listout;
	extern int O_list;

	Line_no--;
	if (Pass == 1) {
		Print_Line(P_NONE);
		return; }

	if (O_list) fprintf(listout, "\014\n");
}

