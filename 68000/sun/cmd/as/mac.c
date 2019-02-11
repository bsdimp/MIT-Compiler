#
#include "mical.h"
#include "mac.h"
char *mac = "~|^`s.mac.c R1.2 on 12/5/79";

/* macro bucket states */
#define	DEFINING	1
#define	EXPANDING	2

/* macro token types */
#define SPACE	0
#define TIK	1
#define EOL	2
#define WORD	3
#define	ARG	4
#define NIL	5

/* arguments to Load_Macro */
#define MACRO	0
#define REPT	1



/****************************************************************************
 *									    *
 *  MICAL Assembler -- Macro Implementation				    *
 *									    *
 * 	The overall purpose of the following procedures is explained in     *
 * mac.h.								    *
 *									    *
 ****************************************************************************/


/*
 * External Variables 
 */
FLAG	Expanding = FALSE;	/* TRUE when expanding a macro, FALSE otherwise */

int	Top_of_M_stack = -1;	/* initialize macro call stack ptr */

extern char *Store_String();
extern struct sym_bkt *Lookup();

/* Define_Macro()
	This is called by Pseudo() (ps.c) when a .macro pseudo-op is recognized
on the source line. It allocates a macro bucket for the macro, and places it
on the macro table, which is organized in a hashed, chained method as is the
assembler's normal symbol table.
	Define_Macro processes the remainder of the .macro line, reading in the
formal arguments of the macro, loading pertinent information into the external
structure, M_defining.
	Finally, it puts the assembler into macro defining mode by  calling
Load_Macro.

	All of the above is done on pass 1. On pass 2, the assembler 
merely prints the text of the macro definition.

*/

/* Macro hash table, each entry is the head of a linked list of macro buckets.
   This structure is initialized by the routine Init_Macro(), which is called
   by the assembler's initialization routine Init();
*/ 

struct M_bkt	*Mac_hash_tab[HASH_MAX];
Init_Macro(){
	register int i;
	for (i=0; i<HASH_MAX; i++) Mac_hash_tab[i] = 0;
}


/* typ_mask is an array of mask bits. The name "typ_mask" is used to share
this structure with the "typ_mask" array of sym.c, where the array is defined */
int	typ_mask[16] = { 01, 02, 04, 010, 020, 040, 0100, 0200, 0400,
		 01000, 02000, 04000, 010000, 020000, 040000, 0100000 };

struct {			/* Listing flags */
	char	any_lf;		/* master switch. If 0, no listing at all is done */
	char	bin_lf;		/* binary code field of listing line */
	char	bex_lf;		/* binary extensions (e.g. from .word) */
	char	md_lf;		/* macro definitions */
	char	mc_lf;		/* macro calls */
	char	me_lf;		/* macro expansions */
	char	cnd_lf;		/* unsatisfied conditional blocks */
	char	ld_lf;		/* listing directives */
} Lflags ;

Define_Macro(){
	char		S[STR_MAX];
	register char	*cp;
	register 
	struct	M_bkt	*mdp;
	int		save;	/* index of chain in Mac_hash_tab of macro name */
	register int	load;	/* next available character in M_defining.buff[] */
	int		count;	/* number of formal arguments to the macro */

	extern int 	E_pass1;	/* error code for errors detected in pass 1 */

/* Pass2: list the current (.macro) line, and call Print_Macro to list the
   rest of the macro definition */
	if (Pass == 2) {
		if (Lflags.md_lf) {		/* if macro definitions listed, do it */
			Print_Line(P_NONE);
			Print_Macro(); }
		return; }

/* Pass1: */

/* Get the name of the macro */
	if (Get_Token(S) == 0) Prog_Error(E_pass1 = E_MACRO);
	else {

	/* Create a macro bucket for this macro, and enter it in the macro 
	   symbol table */
		mdp = (struct M_bkt *)malloc(sizeof _M_bkt);
		mdp->name_m = Store_String(S);
		mdp->next_m = Mac_hash_tab[save = Hash(S)];
		mdp->text_m = 0;
		mdp->state_m = DEFINING;
		mdp->ACS_m = 0;
		Mac_hash_tab[save] = mdp;

	/* Load the M_defining structure */
		M_defining.bkt_md = mdp;
		M_defining.nargs_md = 0;
		load = 0;
		for (count = 0; count < MARGS_MAX; count++) {	/* load formal macro arguments */
			Non_Blank();
			if (Line[Position] == ',') Position++;
			Non_Blank();
			if (Line[Position] == '?') {		/* Check for automatically created symbol */
				mdp->ACS_m |= typ_mask[count];
				Position++; }

			if (Get_Token(S) == 0) break;		/* Get the formal argument */
			M_defining.args_md[count] = & (M_defining.buff_md[load]);	/* load it into M_defining */
			for (cp = S; *cp && load < MARGCHAR_MAX-1; cp++,load++)
				M_defining.buff_md[load] = *cp;
			M_defining.buff_md[load++] = 0;

			if (load >= MARGCHAR_MAX) {
				Prog_Warning(E_MLENGTH);
				break; }
			
		}
		M_defining.nargs_md = count;		/* count of number of arguments */
		mdp->state_m = 0;

	/* macro args have been read, make sure we're at end of line */
		if (Line_Delim(Line[Position]) == false) Prog_Error(E_pass1 = E_MACARG);
	}

/* List the .macro line */
	Print_Line(P_NONE);

/* Load the rest of the macro definition */
	Load_Macro(mdp,MACRO);		/* call from Define_Macro */
	return;
}


/* MLHold is a buffer to hold a line of the macro as it is scanned for 
macro arguments */
char MLHold[LINE_MAX] = 0;


/* Load_Macro
	This is called on pass 1 to store the text of the macro currently 
being defined.
	arguments:	mdp, a ptr to the macro bucket for the macro.
			caller, a flag that is the constant MACRO if we are
				called from Define_Macro and the constant REPT
				if we're called from Rept().	
	returns:	nothing;
	Side Effects:	The text_m component of the macro's bucket becomes
			the head of a linked list of M_line's, where the Nth
			M_line points to the Nth line of the macro.
*/

Load_Macro(mdp,caller)
struct M_bkt *mdp;
int caller;
{
	char		S[STR_MAX];	/* all-purpose char string */
	struct M_line	*Cur_mline;	/* current macro line */
	int		Nested;		/* depth of .macro definitions */
	int		Last,This;	/* Macro token types */
	extern int 	E_pass1;	/* error code for errors detected in pass 1 */
	struct M_line *Load_Arg(),
		      *Load_String();

	Cur_mline = mdp->text_m = (struct M_line *)malloc(sizeof _M_line);	/* allocate initial M_line */
	Nested = 0;
	MLHold[0] = 0;			/* initialize line buffer for Load_String */

	while(1) {	/* For the duration of the macro definition, */
		Read_Line();		/* read the next source line */
		if (Get_Token(S)) 	/* does a valid token begin the line? */
			if (seq(S,".macro") ||	/* Yes, check for macro definition delimiters */
				seq(S,".rept"))
				 Nested++; 	/* if starting a nested macro definition, incr depth count */
			else if ((seq(S,".endm")|| seq(S,".endr"))	/* if ending a macro definition, */
				&& (--Nested) < 0) {			/* decrement depth count */
					Print_Line(P_NONE);		/* list the .endm statement */
					return;	}			/* and return */

	/* Process the current source line of the macro. This consists mainly
	   of identifying the arguments to the macro and replacing them with
	   a special character which indicates their argument number */

		Position = 0;			/* reset Position after the previous Get_Token() */
	/* if a .rept block is being loaded, just load the current line. If a
		macro is being loaded, then scan the line for formal args */
	/* The purpose of the next if..else do {} statement is to store the current line away, placing it on a linked list of
	   macro lines. For .rept lines, no formal arguments need to be extracted; for .macro lines, much hair is
	   involved in locating a formal argument and storing an argument code for is rather than the text itself. */

		if (caller == REPT)
			Cur_mline = Load_String(Line,Cur_mline);
		else do {			/* For the rest of the input line, */
			Last = This;		/* Save the type of the last token */
			This = Get_Mtoken(S);	/* Get the next token; Get_Mtoken returns the type of the token loaded into S */
			if (This == ARG) {	/* if it is a macro argument, */
				Cur_mline = Load_Arg(S,Cur_mline);	/* load the special character for it in place of the argument */
				continue; }

		/* Check for concatenation */
			if (Last == TIK) 	/* if the last token was a tik (') */
				Cur_mline = Load_String("'",Cur_mline);	/* load the tik, since it wasn't used for concatenation */
			if (This == TIK) {	/* if the current token is a tik, */
				if (Last = ARG)	/* and if the last token was an argument, then concatenation is being done, so */
				 This = NIL;	/* ignore the current tik mark */
				continue; }
			if (This == NIL) {	/* if Get_Mtoken failed to get a token, complain */
				Prog_Error(E_pass1 = E_MACFORMAL);
				break; }

		/* Finally, load the current macro token */
			Cur_mline = Load_String(S,Cur_mline);

		} while (This != EOL);		/* stop at the end of the source line */
		Print_Line(P_NONE);		/* list the current line */
	}					/* The macro has been defined */
	/* return; */
}



/* Print_Macro() is called on pass 2 to simply list a macro definition. Any
	errors in the definition will have been detected in pass 1 */

Print_Macro()  {
	int 	Nested;
	char	S[STR_MAX];

	Nested = 0;
	while(1) {
		Read_Line();
		Print_Line(P_NONE);
		Get_Token(S);
		if ( seq(S,".macro") || seq(S,".rept") )
			Nested++;
		else if ((seq(S,".endm") || seq(S,".endr")) && (--Nested) < 0) return;
	}

}



/* Load_String --	Loads a char string into a macro line.
	arguments:	char *S, the string to be loaded,
			struct M_line *mline, a ptr to the M_line to be modified.
	results:	returns a M_line ptr which is to be used in the 
			next Load_String operation.
	method:	    If S is not a newline character, then the string S is
			appended to the static char array MLHold, (macro
			line hold), and Load_String returns the same M_line
			that was passed to it.
		    If S is a newline, then the char string in MLHold is
			copied (via Store_String in sym.c) and a ptr to this
			copy is put into the Text component of mline. A new
			macro line is allocated, and it's address loaded into
			mline->next_ml. This ptr to the newly allocated macro
			line is returned.
*/



struct M_line *Load_String(S,mline)
	char *S;
	register struct M_line *mline;
{
	register char *cp;
	register int i;
	char	*lastc();	/* returns ptr to last char of string argument */

	cp = S;
	for (i=0; MLHold[i]; i++);		/* find end of MLHold */
	for(; *cp && i < LINE_MAX-1; (cp++,i++))	/* append S to MLHold */
		MLHold[i] = *cp;
	MLHold[i] = 0;

	if ((*lastc(S))=='\n') {			/* Is this the end of a line? */
		mline->text_ml = Store_String(MLHold);	/* yes, so copy the line, and save a ptr to it */
		MLHold[0] = 0;				/* clear MLHold */
		mline->next_ml = (struct M_line *)malloc(sizeof _M_line);	/* allocate the next M_line on the linked list of M_lines for this macro */
		(mline->next_ml)->text_ml = NULL;
		(mline->next_ml)->next_ml = NULL;	/* initialize the new M_line */
		return(mline->next_ml);			/* and return with a ptr to it */
	}

	return(mline);				/* still loading current line, so return with the same M_line */
}

	
/* Load_Arg	loads the special character code for a macro argument appearing
		in the text of the  macro.

	A macro argument appearing in the text of a macro is represented by a
single byte with value 0200 + <argument index>, where the Nth macro argument
on the .macro line has argument index N.
*/

struct M_line *Load_Arg(form_arg,mline)
	char *form_arg;
	struct M_line *mline;
{
	register char	S[2];
	int		N;

	N = Form_Arg_No(form_arg);
	if (N<1 || N > M_defining.nargs_md) Sys_Error("Invalid formal parameterpassed to Load_Arg",0);
	S[0] = 0200 + N;
	S[1] = 0;
	return(Load_String(S,mline));
}


/* Form_Arg_No	returns N if it's argument is the Nth argument of the current macro being defined.
		Otherwise it returns 0
*/

int Form_Arg_No(S)
register char *S;
{
	register int	i;
	for(i = 0; i<M_defining.nargs_md; i++)
		if (seq(S,M_defining.args_md[i])) return(i+1);
	return(0);
}



/* Get_Mtoken-- Get Macro Token

	The text of a macro is partitioned into 5 types of tokens:

	SPACE's:	a string of spaces or tabs;
	TIK's:		a single apostrophe character (');
	EOL's:		a newline or formfeed character;
	WORD's:		any sequence of characters not containing SPACE's, TIK's, or EOL's;
	ARG's:		a special kind of WORD, one which is a formal argument to the current macro being defined.

*/
int Get_Mtoken(S)
register char *S;
{
	register int 	i;
	register char	C;

	C = Line[Position];

	for (i = 0; i < STR_MAX-1; i++) 		/* check for string of spaces */
		if ((C == ' ') || C == '\t') {
			S[i] = C;
			C = Line[++Position]; }
		else break;
	if (i) {
		S[i] = 0; return(SPACE); }

	if (Get_Token(S)) 				/* attempt to read a word */
		if (Form_Arg_No(S)) return(ARG);	/* if word found, check if it's an argument */
		else return(WORD);

	if (C == '\n' || C == '\014') {			/* Check for newline char */
		Position++;
		S[0] = C;
		S[1] = 0;
		return(EOL); }

	if (C == '\'') {				/* Check for apostrophe */
		Position++;
		S[0] = C;
		S[1] = 0; 
		return(TIK); }


	if (C < ' ' || C > '~') {			/* Invalid character, just return a nil token */
		Position++;				/* skip over the bad char */
		return(NIL);
	}

	S[0] = C; S[1] = 0;				/* just return the character (operator, colon, etc.) */
	Position++;
	return(SPACE);					/* This could return SPACE or WORD */

}




/* Macro() --	handles macro calls 

	This is called by the main loop to recognize macro calls. Any labels
on the current line have already been processed, so the first token we grab
is a candidate for a macro call.
	Expansion is done on the fly during pass 1, so that on pass 2, all we
need do is list the macro call.
	On pass 1, this routine reads the actual arguments to the macro, and sets up
a macro-call (M_call) structure for the macro activation.
*/

Macro()
{
	int		Save,count,level,i,load;
	register char	S[STR_MAX],C;
	char		rdelim,ldelim;
	struct M_bkt	*mbp,*Get_Mac_Bkt();
	register 
	struct M_call	*mcp;
	struct sym_bkt	*sbp;

	Save = Position;				/* remember current position on input source line */

	if (Get_Token(S) == 0) 				/* Pick up the next token on line */
		return(true);				/* if none, we can't do anything */

							/* Search macro table for token */
	if ((mbp = Get_Mac_Bkt(S)) == 0) {
		Position = Save;			/* if not found, not a macro call */
		return (true);	}		

	if (Pass == 2) {				/* On pass 2, just list the macro call */
		if (Lflags.mc_lf) Print_Line(P_NONE);
		return(false); }			/* since we're finished with this line */

	/* Set up macro call structure */
		if (Top_of_M_stack >= MDEPTH_MAX) {
			Prog_Warning(E_LEVELS); 
			goto done; }
		mcp = M_stack[++Top_of_M_stack] = (struct M_call *)malloc(sizeof _M_call);	/* allocate M_call bucket */
		mcp->bkt_mc = mbp;			/* ptr to permanent macro bucket for the macro */
		mcp->line_mc = mbp->text_m;		/* first line of the macro */
		mcp->rc_mc = 1;				/* repeat count is zero */

/* Load macro arguments in  M_call structure */
/* Argument strings are stored sequentially in mcp->buff_mc */
	load = 0;					/* position in buff_mc to load next char */
							/* For each macro argument, */
	for (count = 0; (count < MARGS_MAX) && (load < MARGCHAR_MAX); count ++) {
		mcp->args_mc[count] = & (mcp->buff_mc[load]);	/* set the ptr to its copy in buff_mc */
		Skip_Comma();				/* find first char of argument */
		C = Line[Position];

			/* switch statement places one macro argument into the buff_mc array of the macro call structure */
		switch(C){
						/* Argument enclosed between delimiter chars */
		case '^':				/* explicitly declared delimiter character follows */
			rdelim = ldelim = Line[++Position];
			goto arg_encl;
		case '<':				/* normal delimiters */
			ldelim = '<'; rdelim = '>';
		arg_encl:				/* pick up enclosed argument */
			if (Enclosed(ldelim,rdelim,S) != 0) {	/* extract macro argument */
				Prog_Error(E_MACARG); goto done;
			}
			for(i=0; mcp->buff_mc[load++] = S[i] && load < MARGCHAR_MAX; i++);	/* copy macro arg to buffer */
			break;				/* continue for loop, reading macro arguments

					/* load a numeric argument in a symbol. The value of the symbol is converted
					   to its ASCII representation (in octal) and this representation becomes
					   the macro argument.  */

		case '\\':			/* the expression is preceded by a backslash */
			Position++;			/* move past '\' */
			if (Get_Token(S)) {		/* pick up the symbol */
			    sbp = Lookup(S);		/* get a ptr to its bucket */
			    if (sbp->attr_s & S_DEF)	/* check that it's defined */
			      octalize(sbp->value_s,S); /* move its value expressed in octal into S */
			    else Prog_Error(E_SYMDEF);	/* if it's not defined, then complain */
			    for(i=0; mcp->buff_mc[load++] = S[i] && load < MARGCHAR_MAX; i++);		/* copy S into buff_mc */
			}
			else { Prog_Error(E_SYMBOL); goto done; }	/* if invalid symbol, complain */
			break;

		default:				/* regular argument */

					/* Regular macro argument. Pick up all chars up to a legal separator
					   (blank or comma), or end-of-statement */
		    while (C != ' ' && C != ',' && C != '\t' && !Line_Delim(C) && load < MARGCHAR_MAX-1) {
			mcp->buff_mc[load++] = C;
			C = Line[++Position]; }
		    mcp->buff_mc[load++] = 0;		/* end of macro arg */
		}
	}

done:	
	if (load >= MARGCHAR_MAX)  Prog_Error(E_MLENGTH);	/* check if macro argument storage exceeded */

	Print_Line(P_NONE);				/* put the macro call into temp file (we're on pass 1) */
	return(false);					/* and return false since we're done with this line */
}




/* Automatically Created Symbol count. This is used to create unique local
symbols withing macro expansions. The count starts at 01000 to allow the
programmer to use local symbols 0$ to 0777$. */
int	ACS_count = 01000;




/* Read_Macro_Line
	This is called from Read_Line() to read the next line of the macro
currently being expanded. It returns true if it successfully read a macro
line, false otherwise (implying end of macro expansion).
*/

Read_Macro_Line() 
{
	register int		i,j,k;
	int			index,C;
	struct M_call		*mcp;
	struct M_line		*mlp;
	char			*orig_line, *arg, S[STR_MAX];


/* It is assumed that Macro() has set up the M_call stack, in which case 
M_stack[Top_of_M_stack] contains a ptr to a M_call structure for the current
macro call */

	if (Top_of_M_stack < 0) return(Expanding = false);			/* no macro being expanded */
	Expanding = true;

	mcp = M_stack[Top_of_M_stack];				/* get ptr to current macro call structure */
	mlp = mcp->line_mc;					/* ptr to current macro line structure */
	if (mlp == 0 || (mlp->next_ml == 0)) {			/* if this points to [0,0] m_line, then end of macro */
	    if ((--(mcp->rc_mc)) > 0)				/* but if its a .rept statement, and this is not the last expansion, */
		mcp->line_mc = (mcp->bkt_mc)->text_m;		/* then move current line ptr back to start of text */
	    else {						/* if we are indeed finished expanding, */
		free( M_stack[Top_of_M_stack]);			/* free the macro_expanding structure */
		Top_of_M_stack--;				/* decrement stack pointer */
		}
		return(Read_Macro_Line());			/* and try again */
	}
	orig_line = mlp->text_ml;				/* actual source line */

/* Now step through the line char by char looking for the occurrence of a macro
argument. This is represented by a single char with value 0200+N,  where N is
the index of the argument in the macro's definition. 

   Load the resulting line into Line[].
 */
	for (i = 0, j = 0; orig_line[i] && j < LINE_MAX-1; i++) {
		C = orig_line[i] & 0377;
		if (C < 0200) Line[j++] = C;			/* normal text char, just copy into Line[] */
		else {							/* argument  occurrence */
			index = C - 0200 - 1;		/* index of argument (0 => 1st, 1=> 2nd, etc) */
			arg = mcp->args_mc[index];		/* actual argument string */
								/* Create automatically created symbols */
			if (*arg == 0 && (((mcp->bkt_mc)->ACS_m) & (1 << index))) {	/* actual arg must be absent */
				octalize(ACS_count++, S);	/* put octal rep of ACS_count into string S */
				append("$",S);			/* append $ to create a name of a unique local symbol */
				arg = S;			/* and let the generated symbol be the argument */
			} 
			for (k = 0; arg[k] && j<LINE_MAX-1; k++)	/* copy it into actual line */
				Line[j++] = arg[k];
		}
	}
	Line[j] = 0;						/* end of line */

	Start_Line();						/* initialize per-line variables */

	mcp->line_mc = (mcp->line_mc)->next_ml;			/* step down list of linked macro lines */

	return(true);
}

/*
	Rept: .rept handler

[ Warning: this implementation is painfully inefficient: it keeps the text of
a .rept block in core and forgets it when the block is completed, i.e. the
memory is lost. Future implementations should either use the free storage pkg
to hold the text, or use a file. ]

	.REPT blocks are handled similarly to .macro blocks:
1. A macro_bucket is created for the block, but no name is associated with the
   	macro; furthermore, the macro bucket is not placed in the macro hash table.
2. The text of the .rept block is read into core, and each line of the text is
   	stored as a macro_line structure.
3. After the text of the macro is stored, a macro_call structure is created and
  	placed on the macro call stact, with a repeat count equal to the number
	in the operand field of the .rept statement.
4. Control is returned to the assembler. Read_Line will pick up the text of the
	.rept block via the macro call structure. When the .rept block has been
	repeated enough times, the macro call structure will be destroyed, also
	losing the pointer to the macro lines containing the text of the .rept
	block. 

*/

Rept(){
	struct	M_call 	*mcp;
	struct	M_bkt	*mdp;
	int		RC;	/* repeat count*/

	Print_Line(P_NONE);				/* list the .rept statment */
	if (Pass == 2) {				/* ignore .rept statement on pass 2 */
		Print_Macro();				/* print definition of macro */
		return; }

/* Get the repeat count */
	if ((Get_Operand() == false) ||			/* evaluate the operand field */
		(RC = Operand.value_o) < 0) {	/* assign the value to RC */
			Print_Line();			/* if the repeat count is invalid, print the .rept statement, */
			Print_Macro();			/* and the rest of the .rept block */
			return; } 

	/* Create macro bucket for this .rept block, but don't enter it into the macro hash table */
	mdp = (struct M_bkt *)malloc(sizeof _M_bkt);
	mdp->name_m = 0;
	mdp->next_m = 0;
	mdp->text_m = 0;
	mdp->state_m = DEFINING;
	mdp->ACS_m = 0;

	Load_Macro(mdp,REPT);		/* load text of macro */

	mcp = M_stack[++Top_of_M_stack] = (struct M_call *)malloc(sizeof _M_call);
	mcp->bkt_mc = mdp;
	mcp->line_mc = mdp->text_m;
	mcp->rc_mc = RC;		/* load repeat count into macro call structure */
	return;
}

/* octalize(N,S) puts the octal representation of N into string S) */

octalize(N,S)
int N;
register char *S;
{
	register char	buff[7];
	register int	i;
	long 	NN;

	NN = N & 0177777;
	i = 5;					/* put octal representation into rhs of buff */
	do {
		buff[i--] = NN % 8 + '0';
		NN = NN/8;
	} while (NN > 0);

	while (i < 5) *S++ = buff[++i];		/* copy octal rep into S */
	*S = 0;
}

/*
 * Get_Mac_Bkt(Name)  returns a ptr to the M_bkt structure for the macro named "Name".
 *			If no such macro exists, 0 is returned.
 */
struct M_bkt *Get_Mac_Bkt(Name)
char Name[];
{
	struct M_bkt *mbp;

	for (mbp=Mac_hash_tab[Hash(Name)]; mbp != 0; mbp = mbp->next_m)
		if (seq(Name,mbp->name_m)) return (mbp);
	return(0);
}



