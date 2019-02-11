#
#include "mical.h"

/*************************************************** 
 *						   *
 * Mical Assembler - conditional assembly handlers *
 *						   *
 ***************************************************/
 
 /*
  * Modified by Bill Nowicki Januray 1982 for V7 C syntax
  */


#define	IF	1
#define IFT	2
#define	IFF	3
#define IFTF	4

/* Ignore flag, set when processing an unsatisfied conditional block */
FLAG	Ignore;


/* Cond_level: level of nested conditional blocks. */
int	Cond_level = 0;

/* Condition and Subcondition block bit vectors. [Sub]Condition[Cond_level] == 
   true whenever current [sub]conditional block is satisfied.
	The outermost conditional block [initial block] is satisfied.
*/
FLAG	Condition[COND_MAX]  = true;		/* sets Condition[0] true */
FLAG 	Subcondition[COND_MAX] = true;	

/* Cond() - check for conditional pseudo-ops.

	If we are currently in an unsatisfied conditional block [Ignore == true],
  then check for the two statements ".endc" (which ends the block) and ".iff"
  (which causes a new conditional block if the current one is unsatisfied).
 */

FLAG Eval_Cond();

Cond() {
	char	S[STR_MAX];
	int	Save;

	Save = Position;			/* save our current position on the input line */
	if ( Get_Token(S)) {			/* Pick up first token */
				/* and call the appropriate routine */

	/* The following five checks should appear before the check of Ignore */
		if (seq(S,".endc")) Endc();
		else if (seq(S,".ift")) Iftf(IFT);
		else if (seq(S,".iff")) Iftf(IFF);	
		else if (seq(S,".iftf")) Iftf(IFTF);
		else if (seq(S,".if")) If();

	/* If Ignore is set, then disregard the line (just print it out); */
		else if (Ignore) {
			Print_Line(P_NONE);	/* print the line */
			return(FALSE); }	/* signifying that processing of the current line is complete */


		else if (seq(S,".iif")) 		/* immediate conditional */
			if (Eval_Cond()) {
				Non_Blank();		/* skip comma */
				if (Line[Position] == ',') Position++;
				return(TRUE); }		 /* it's true, so continue processing this line */
			else {
				Print_Line(P_NONE);	/* it's false, so just print this line, and be done with it */
				return(FALSE); }



	/* No pseudo-op was found, so restore things and continue processing on the line */
		else {	
			Position = Save;
			return(TRUE); }


	/* We found a directive and have processed it */
		return(FALSE);
	}

/* No token was found, so restore Position and continue processing the line */

	Position = Save;
	return(TRUE);
}

Endc() {
	
	if (Cond_level > 0) Cond_level--;			/* decrement condition block level */
	else Prog_Warning(E_ENDC);

	Ignore = Subcondition[Cond_level] ? false : true;	/* Ignore is the opposition of the value of the outer subconditional block */
	Print_Line(P_NONE);
}



/* Enter a new conditional block. Format of statement is:

	.IF	<LOGOP>, <expr>[,<expr>]

  If the <expr> satisfies the the logical operator <LOGOP>, then the 
conditional block is said to have a value of "true", and normal processing
continues. If <expr> does not satisfy <LOGOP>, then the block is said to
have a value of "false", and all normal statements in this block are 
ignored; (exceptions are the subconditional statements .ift, .iff, & .iftf).
	If the block itself is supposed to be ignored, (Ignore == true when
encountering the .if statement), then act as if the expression was not
satisfied.
 */

If(Which) 
int Which;
{

	if (Cond_level >= COND_MAX-1) Prog_Warning(E_LEVELS);
	else {
		Cond_level++;							/* enter a new cond block */
		Condition[Cond_level] = Subcondition[Cond_level] = 
			Ignore? false: Eval_Cond();				/* set the block value accordingly */
		Ignore = Subcondition[Cond_level] ? false : true;		/* set Ignore flag to opposite of block value */
	}
	Print_Line(P_NONE);
}


/* Enter a subconditional block. This is analogous to entering a new
conditional block given that the current conditional block is true (.IFT),
is false (.IFF) or either (.IFTF).
*/
Iftf(Which)
int Which;
{
	switch(Which) {
	case IFT:	Subcondition[Cond_level] = Condition[Cond_level]; break;
	case IFF:	Subcondition[Cond_level] = Condition[Cond_level] ? false : true; break;
	case IFTF:	Subcondition[Cond_level] = true; break;
	default:	Sys_Error("Iftf called with bad option: %d", Which);
	}
	Ignore = Subcondition[Cond_level] ? false : true;	/* set Ignore to oppositie of subconditional block level */

	Print_Line(P_NONE);
}


/* Evaluate a condition of the form

	<LOGOP>, <expr>[,<expr>]
*/

#define	ZERO		01
#define POSITIVE 	02
#define NEGATIVE	04

struct {
	char		*condition;	/* char string representing logical operator */
	char		relation;	/* status of <expr> for condition to be true */

} cond_table[] =  {
	"eq", 	ZERO,
	"z",  	ZERO,
	"ne",	POSITIVE|NEGATIVE,
	"nz",   POSITIVE|NEGATIVE,
	"gt",	POSITIVE,
	"g",	POSITIVE,
	"ge",	POSITIVE|ZERO,
	"lt",	NEGATIVE,
	"l",	NEGATIVE,
	"le",	NEGATIVE|ZERO,
	0
} ;

FLAG Eval_Cond() {

	int	i,V;
	char	S[STR_MAX];
	FLAG	df, def;
	struct sym_bkt *sbp;
	extern struct sym_bkt *Lookup();

	if (Get_Token(S) == 0) {		/* get condition code */
		Prog_Error(E_CONDITION);
		return(false); }

	Lower(S);				/* convert to lower case */
	
	Non_Blank();				/* skip comma */
	if (Line[Position] == ',') Position++;
	Non_Blank();	

	df = false;					/* true if he wants "df" condition */
	if ((df = seq(S,"df")) || seq(S,"ndf")) {	/* check for symbol-defined conditions */
		if (Get_Token(S) == 0) {		/* pick up symbol name */
			Prog_Error(E_SYMBOL);		/* complain if it isn't there */
			return(false); }
		sbp = Lookup(S);			/* get symbol bucket for it */
		def = (sbp->attr_s & S_DEF) ? true : false;	/* set def to true if symbol is defined */
		if (df) return(def);			/* return whatever sense he wants */
		else return(df? false : true);
	}

	Get_Operand(&Operand);				/* evaluate <expr> and load into Operand structure */
	
	V = Operand.value_o;			/* V get operand value */

	for (i = 0; cond_table[i].condition; i++)	/* find condition, and return appropriately */
		if (seq(S,cond_table[i].condition)) 
			if (V > 0 && cond_table[i].relation & POSITIVE) return(true);
			else if (V == 0 && cond_table[i].relation & ZERO) return(true);
			else if (V < 0 && cond_table[i].relation & NEGATIVE) return(true);
			else return(false);

	Prog_Error(E_CONDITION);
	return(false);

}

