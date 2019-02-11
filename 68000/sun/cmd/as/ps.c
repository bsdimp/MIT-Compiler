#include "mical.h"
#ifndef Stanford
#include <a.out.h>
#else Stanford
#include "b.out.h"
#endif Stanford

struct csect *Text_csect,*Data_csect,*Bss_csect;
#ifndef Stanford
struct exec filhdr;
#else Stanford
struct bhdr filhdr;
#endif Stanford
char	Ignore;	/* if nonzero, ignore code,e.g. unsatified conditional block */

/* Pseudo() is called from the main loop to process assembler directives. If
	finds a pseudo-op, it returns FALSE, to discontinue processing
	on the current line. Otherwise, it returns TRUE.

	It also detects direct assignment statements.

	If the assembler is in Ignore mode, i.e. processing lines in an 
unsatisfied conditional block, then Pseudo will list the line. Each of the
separate directive handlers, e.g. Byte(), is responsible for listing the
line if it is called. */

Pseudo() {
	char String[MNEM_MAX+1];	/* storage for the mnemonic */
	register char *S;		/* what we'll work with */
	int 	Save;			/* temp storage for Position */
	extern char O_debug;
	char	D;

	D = O_debug;
	S = String;			/* load the register */
	Save = Position;		/* Save the current position */
	if (Get_Token(S) == FALSE)	/* Pick up next token, */
		return(TRUE);		/* if not there, return */
	Lower(S);			/* Convert token to lower case */

	if (S[0] != '.') { 		/* If not start with '.', ignore it */
		Position = Save; return(TRUE); }

	if (seq(S,".end")) End();
	else if (Ignore) Print_Line(P_NONE);
		
	else if (seq(S,".long"))
	{
		if (Dot & 1) Prog_Error(E_ODDADDR);
		ByteWord(4);
	}
	else if (seq(S,".word"))
	{
		if (Dot & 1) Prog_Error(E_ODDADDR);
		ByteWord(2);
	}
	else if (seq(S,".byte"))  ByteWord(1);
	else if (seq(S,".macro")) Define_Macro();
	else if (seq(S,".rept"))  Rept();
	else if (seq(S,".ascii")) Asciiz(0);
	else if (seq(S,".asciz")) Asciiz(1);
	else if (seq(S,".blkb"))  Blkbw(1);
	else if (seq(S,".blkw"))  Blkbw(2);
	else if (seq(S,".blkl"))  Blkbw(4);
	else if (seq(S,".list"))  NList(TRUE);
	else if (seq(S,".nlist")) NList(FALSE);
	else if (seq(S,".insrt")) Insrt();
	else if (seq(S,".text")) { New_Csect(Text_csect); Print_Line(P_NONE); }
	else if (seq(S,".data")) { New_Csect(Data_csect); Print_Line(P_NONE); }
	else if (seq(S,".bss"))  { New_Csect(Bss_csect); Print_Line(P_NONE); }
	else if (seq(S,".globl")) Globl();
	else if (seq(S,".comm")) Comm();
	else if (seq(S,".radix")) Radix();
	else if (seq(S,".typef")) EPrintf('T');
	else if (seq(S,".printf")) EPrintf('P');
	else if (seq(S,".error")) EPrintf('E');
	else if (seq(S,".page")) Page();
	else if (seq(S,".defrs")) Defrs();
	else if (seq(S,".even")) Even();
	else { Position = Save; return(TRUE); };
	return(FALSE);
}




/* End()-- .end handler

	Preconditions:	Position is just after ".end".
	Side Effects:	Temp_file is closed and switched to source file;
			Per-pass variables are initialized; Header for .rel
			file is generated. On pass two, descriptions of errors
			are printed, along with symbol table, (at end of listing)
			and Done flag is set. Entry point is determined.
*/

struct sym_bkt	Entry_point ;	/* Entry point of assembly program, optional */
char	EntryFlag = 0;		/* non-zero if entry point is specified */
char	Done ;		/* when 1, assembly complete */

End(){
	extern FILE *Source_stack[];
	extern int	Ss_top;
	extern char	O_symtab,O_debug,O_global;	/* Set in init.c */
	extern FILE *Temp_file;
	extern char	Temp_name[];
	extern struct csect Csects[];
	extern int	Csect_load;	/* next available csect in Csects[] */
	register int i;
	register struct csect *p;

	Print_Line(P_LC);			/* Whichever pass, print the line */
/* Pass 2 */
		if (O_debug >2) printf("\n   End: Position=%d, ",Position);
	if (Pass > 1) {				/* On the second pass, */
		Error_Describe();		/* Print error descriptions, */
		if (O_debug == 0) unlink(Temp_name);	/* if not debugging, remove temporary file */
		if (O_symtab) Pr_Sym_Tab();	/* Print symbol table, */
		Fix_Rel();			/* patch up object file */
		Done = 1;			/* stop assembler */
		return; }

/* Pass 1 */
	fclose(Temp_file);
	if ((Temp_file = fopen(Temp_name, "r")) == NULL)
		Sys_Error("Cannot reopen temporary file %s", Temp_name);

	for(; Ss_top>=0; Ss_top--)		/* By clearing source stack */
		fclose(Source_stack[Ss_top]);
	Push_Source(Temp_file);

/* Pick up entry point */
	if (Num_Operands() > 0 && Get_Operand(&Operand)) {
		Entry_point.value_s = Operand.value_o;
		EntryFlag = 1;
	}

	sdi_resolve();	/* resolve span dependent instructions */

	for (p = &Csects[0], i=0; i < Csect_load; i++, p++)
		p->len_cs += sdi_inc(p, p->len_cs);

/* Will need to remove following if Pratt's algorithm for locating
instructions is to work. */
	tsize = (Text_csect->len_cs + 3) & ~3;	/* make long aligned */
	dsize = (Data_csect->len_cs + 3) & ~3;
	bsize = (Bss_csect->len_cs + 3) & ~3;

	Sym_Fix();	/* relocate and globalize */
	sdi_free();	/* release sdi blocks */
	Rel_Header();	/* Initialize output stuff */
	Start_Pass();	/* Init per-pass variables */
	return;
}

/* Ehead()     handles end of header file
	The header file consists of source statements that are executed before 
	every program, and is included in the source descriptor file for the
	machine. When end_of_file is reached on this file, this program is
	called.

	Assumptions:	Pass is 0, that is, the header file.
	Side_effects:	Starts pass 1 by calling Start_Pass; Aborts if any
			assembly errors in descriptor file 
*/

Ehead(){
	extern int Errors;			/* count of errors in this pass */

	if (Errors) Sys_Error("%d errors in descriptor file\n",Errors);
	Perm();		/* make all symbols permanent */
	Start_Pass();
}


/* Initialize per-pass variables */

Start_Pass() {
	extern int Errors,Warnings,Err_load,Line_no;
	extern struct sym_bkt *Last_symbol;	/* ptr to last defined sym */
	extern struct sym_bkt *Dot_bkt;		/* ptr to sym_bkt for Dot */
	extern char O_debug;
	extern struct csect Csects[];
	extern int Csect_load;
	register int i;


	Line_no = 0;
	Errors = 0;
	Warnings = 0;
	Err_load = 0;
	Pass++;
	if (Pass != 2) for (i=0; i<Csect_load; i++) Csects[i].dot_cs = 0;
	else
	{
		Text_csect->dot_cs = 0;
		Data_csect->dot_cs = tsize;
		Bss_csect->dot_cs = tsize + dsize;
	}
	Last_symbol = Dot_bkt;	/*ONLY defined symbol at the start of a pass */
	New_Csect(&Csects[0]);	/* start in text segment */
	if (O_debug > 2) printf("\n   Start_Pass: Pass=%d\n",Pass);
}

/* Defrs(): DEFine Register Symbol.
 *	This routine is called in the header code to define those symbols 
 * that represent registers, accumulators, etc. on the machine. These
 * symbols have the S_REG flag set as an attribute, so that an error is
 * generated when their value is attempted to be changed.
 *	Syntax is:
 *	.defrs  <name>,<value>[,<name>,<value>]...
 */
Defrs() {
	char 	S[STR_MAX];	/* working string */
	register struct sym_bkt *sbp;
	struct sym_bkt *Lookup();

	while(Get_Token(S)) {		/* Pick up the name of the symbol */
		sbp = Lookup(S);	/* Make a sym_bkt for it */
		Non_Blank();		/* find the ',' */
		if (Line[Position] == ',') Position++;		/* move past it */
		if ((Get_Operand(&Operand) == 0) || Operand.sym_o ) {	/* Evaluate the expression, must be absolute */
									/* This moves Position past second ',' */
			Prog_Error(E_OPERAND);
			break; }
		sbp->value_s = Operand.value_o;			/* Load the sym_bkt */
		sbp->csect_s = 0;
		sbp->attr_s = S_DEC | S_DEF | S_REG;
	}
	Print_Line(P_NONE);
	return;
}

/* #define CMD_LCS 27 */

/* Equals() is called from Label() to evaluate the operand field of a direct
	assignment statement and then to assign this value to the symbols on
	the left side of the '='. The array Label_list is a list of ptrs to 
	the sym_bkt structures of each variable that is to be assigned. 
*/

Equals() {
	register int i,Got;	/* Got is TRUE if the operand field has been evaluated */
	register struct sym_bkt *sbp;
	extern struct sym_bkt *Label_list[];	/* ptrs to the symbols on the left side */
	extern int Label_count;		/* num of symbols on left side */
/*	extern char Cmd_buffer[];		/* buffer of commands for the current text block of .rel file */
	extern struct csect *Cur_csect;	/* ptr the the current csect */
	extern int E_pass1;		/* if nonzero on pass1, causes non-ignored error */
	extern struct sym_bkt *Dot_bkt;	/* ptr to symbol bucket for dot */

	Got = 0;			/* haven't read operand yet */
	for(i=0;i<Label_count; i++) {	/* For each symbol to be defined, */
		sbp = Label_list[i];	/* pick up the ptr to it */
		if (Label_list[i] == Dot_bkt) {	/* Treat the ". = " statement specially */
			if (Got == 0) {		/* Pick up the operand if we haven't already */
				if (Get_Operand(&Operand) == FALSE) {			/* if any error, */
					E_pass1 = E_OPERAND; break; }	/* Cause an error in pass 1 */
				Got++; }
			/* Make sure expression is in current csect, or is absolute */
			if (Operand.sym_o && Operand.sym_o->csect_s != Cur_csect) {
				E_pass1 = E_OPERAND; break; }
			Dot = Operand.value_o;			/* assign location counter */
			}
		else {		/* If it's not a .= statement, */
			if ((Got++ == 0) && (Get_Operand(&Operand) == FALSE)) break;	/* Evaluate the operand */
			sbp->value_s = Operand.value_o;	/* Load value of expression into symbol */
			sbp->csect_s = Operand.sym_o? Operand.sym_o->csect_s:0;
			if (sbp->attr_s & S_LABEL) Prog_Error(E_EQUALS);
			else sbp->attr_s = Operand.sym_o ? (Operand.sym_o->attr_s&~(S_LABEL|S_PERM)): (S_DEC|S_DEF);
		}
	}
	Print_Line(P_NONE);
	return;
}
/*
 * .even handler
 */
Even()
{
	if (Dot&1) {
		Dot++;
		Code[0] = 0;
		Put_Text(Code,1);
	}
	Print_Line(P_LC);
}

