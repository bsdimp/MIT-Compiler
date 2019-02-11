#include "mical.h"
char *eval = "~|^`s.eval.c R1.8 on 1/7/80";

int	In_radix = 10;		/* Default input radix for numbers */
char Operators[] = "+-*/&!^<>%";	/* valid operator characters */

/* Prefixes for temporary radix changes */
char	Prefix_tab[] = { '/', '^', '%', 0 } ;	/* The prefixes */
int	Radix_tab[] = {	16, 8, 2, 0 } ;		/* and radices they represent*/


char 	Escape_tab[] = {	/* character escape table */
		'n', '\n',	/* newline, (linefeed) */
		't', '\t',	/* tab */
		'f', '\014',	/* form feed */
		'r', '\r',	/* return */
		'b', '\b',	/* backspace */
		 0 } ;

/* Evaluate(Arg1):
 *	This routine evaluates expressions by calling Get_Term to evaluate
 * each of the two terms for binary operations, and then performing the 
 * operation on the two terms. Get_Term itself evaluates unary operations.
 * 	Arg1 is a pointer to an oper structure, which Evaluate uses to
 * store the left hand term, and eventually to store the value of then
 * entire expression. Thus, grouping is left to right, with no operator 
 * precedence.
 *	This routine can be called recursively by Get_Term, if Get_Term 
 * encounters an expression in brackets ([]).
 *	Position is moved to the first char after the expression.
 */

Evaluate(Arg1)
register struct oper *Arg1; {
	struct oper Arg2;	/* holds value of right hand term */
	register char Op;			/* operator character */

	Non_Blank();				/* Find the operator */
	if (Op_Delim(Line[Position])) {		/* nil operand is zero */
		Arg1->sym_o = 0;
		Arg1->value_o = 0;
		return(TRUE); }
	if (Get_Term(Arg1) == FALSE) return(FALSE);	/* Pick up the first term */
	Non_Blank();
	for (;(Op_Delim(Op = Line[Position]) == FALSE) && (Op != '('); Non_Blank()) {	/* But don't go past end of operand */
		if ((Op=='>') || (Op=='<')) Op = Line[++Position];	/* so the operators ">>" and "<<" are one char */
		if (member(Op,Operators)) {	/* Did we find an operator? */
			Position++;		/* Yep, so move past it */
			if (Get_Term(&Arg2) == FALSE) return(FALSE);	/* Pick up the second term */
			switch(Op) {		/* And perform the operation */
			    case '+':
				if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break; /* no arithmetic on registers */
				if (Arg1->sym_o && Arg2.sym_o) break;	/* Both can't be relocatable */
				if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;	/* Put the offset into Arg1 */
				Arg1->value_o += Arg2.value_o;
				Arg1->flags_o |= Arg2.flags_o&O_COMPLEX;
				continue;					/* go on to next operator */
			    case '-':
					/* A-B has the following relocatability: (abs = absolute, rel = relocatable)
					    A        B        A-B
					   abs      abs       abs  
					   abs      rel	      <error- nonrelocatable>
					   rel      abs       rel
					   rel      rel       if A and B have offsets in the same csect, then 
							      A-B is absolute, otherwise, an <error>
					*/
				if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break; /* no arithmetic on registers */
				if (Arg2.sym_o)		/* if B is relocatable, */
					if (Arg1->sym_o)	/* and A is relocatable, */
								/* then make sure both have offsets in the same csect */
					    if (Arg2.sym_o->csect_s != Arg1->sym_o->csect_s) break; /* break into error */
					    else {
						Arg1->sym_o = 0;	/* result is absolute (no offset) */
						Arg1->flags_o |= O_COMPLEX;	/* but not a simple address for sdi's */
					    }
					else break;		/* if B rel., and A is not, then break into relocation error */
				Arg1->value_o -= Arg2.value_o;
				continue;
			    case '*':
				if (Arg1->sym_o || Arg2.sym_o) break;
				Arg1->value_o *= Arg2.value_o;
				continue;
			    case '/':
				if (Arg1->sym_o || Arg2.sym_o) break;
				Arg1->value_o /= Arg2.value_o;
				continue;
			    case '&':
				if (Arg1->sym_o || Arg2.sym_o) break;
				Arg1->value_o &= Arg2.value_o;
				continue;
			    case '!':
				if (Arg1->sym_o || Arg2.sym_o) break;
				Arg1->value_o |= Arg2.value_o;
				continue;
			    case '^':
				if (Arg1->sym_o || Arg2.sym_o) break;
				Arg1->value_o %= Arg2.value_o;
				continue;
			    case '<':
				if (Arg1->sym_o || Arg2.sym_o) break;
				Arg1->value_o <<= Arg2.value_o;
				continue;
			    case '>':
				if (Arg1->sym_o || Arg2.sym_o) break;
				Arg1->value_o >>= Arg2.value_o;
				continue;
			    case '%':
				if (Arg1->sym_o || Arg2.sym_o) break;
				Arg1->value_o = Arg1->value_o<<24 | Arg2.value_o;
				continue;
			    default:
				Sys_Error("Operators[] and Evaluate() incompaitible for: %c\n",Op);
			} /* switch */
			Prog_Error(E_RELOCATE);			/* if break form switch statement, relocation error */
			return(FALSE);
		} /* if operator present */
		Prog_Error(E_OPERATOR);				/* No operator when expected */
		return(FALSE);
	} /* while not end of operand */
	return(TRUE);
}


/* Get_Term(Vp)
 *	Vp is a ptr to an operand value structure. This routine picks up one
 * "term", which is
 *	1)	A symbol, such as a label; or
 *	2)	A constant, which can be prefixed with "/", "^", or "%" for
 *	    hex, octal, or binary representations resp., or suffixed with a
 *	    ".", for decimal input. (Default radix is set in the descriptor
 *	    file); or
 *	3)	A character constant, which is a <"> followed by two non-line
 *	    terminating characters, or a <'> followed by one.
 *		In addition, Get_Term evaluates the three unary operators "+",
 *	    "-", and "~" (logical not); or
 *	5)	An expression enclosed in brackets ([]).
 *	
 */

rev(x)
  {int c, y = 0;
   for (c=0; c<16; c++)
       {y = (y<<1) | (x&1);
	x >>= 1;
       }
   return y;
  }
       

Get_Term(Vp)
register struct oper *Vp;
{
	register char 	S[STR_MAX],	/* working string */
		flag;		/* to save value of Evaluate in a recursive call to it */
	int	i,index,v_length;
	struct sym_bkt	*sbp,*Lookup();
	struct ins_bkt  *ibp,*Get_Ins_Bkt();		/* instruction  bkt ptr */
	extern char O_global;		/* if 1, undefined symbols are ext */
	extern struct csect *Cur_csect;	/* ptr to current csect */
	extern char *lastc();
	extern int	*Insv_ptrs[];	/* instruction vector pointers */
	extern char Mnemonic[];		/* name of last executable instruction assembled */

	Non_Blank();			/* Find first char of term */
	if (Line[Position] == '+') {	/* If its a unary "+" */
		Position++;		/* skip over it */
		return(Get_Term(Vp)); }	/* and just return the next term */
	if (Line[Position] == '-') {	/* If it's a unary "-" */
		Position++;		/* skip over it */
		if (Get_Term(Vp) == FALSE) return(FALSE);  /* and pick up the next term */
		if (Vp->sym_o) {	/* Make sure the negated term is relocatable */
			Prog_Error(E_RELOCATE); }
		Vp->value_o = -(Vp->value_o);	/* and finally do it */
		return(TRUE); }
	if (Line[Position] == '!') {	/* If it's a unary '!', reversal */
		Position++;		/* skip over it */
		if (Get_Term(Vp) == FALSE) return(FALSE);	/* and pick up the next term */
		if (Vp->sym_o) {	/* Make sure the final term is relocatable */
			Prog_Error(E_RELOCATE); }
		Vp->value_o = rev(Vp->value_o);	/* and reverse the term */
		return(TRUE); }
	if (Line[Position] == '~') {	/* If it's a unary '~', logical negation */
		Position++;		/* skip over it */
		if (Get_Term(Vp) == FALSE) return(FALSE);	/* and pick up the next term */
		if (Vp->sym_o) {	/* Make sure the final term is relocatable */
			Prog_Error(E_RELOCATE); }
		Vp->value_o = ~(Vp->value_o);	/* and logically negate the term */
		return(TRUE); }

	if (Get_Token(S)) {		/* Pick up a Token, which can be either */
					/* a symbol, a number with no prefix, or a decimal number (ending with '.') */
		if ((S[0] < '0') || (S[0] > '9') || (*lastc(S) == '$')) {	/* If it's a symbol */
			sbp = Lookup(S);		/* find its symbol bucket */
			if ((sbp->attr_s & S_DEC) == 0)	/* Make sure it's declared */
				if (O_global == 0) Prog_Error(E_SYMDEF);
			if (sbp->attr_s & S_DEF)	/* if it's defined, use its value */
				Vp->value_o = sbp->value_s;
			else {
				if ((sbp->attr_s & S_EXT) == 0)	/* error if not external */
					Prog_Error(E_SYMDEF);
				Vp->value_o = 0;
			}
			if (sbp->attr_s & S_REG) Vp->type_o = t_reg;
			else
			{
				 /* and offset is the symbol itself */
				Vp->sym_o = (sbp->attr_s & S_DEF) &&
				  (sbp->csect_s == 0 || (sbp->csect_s->attr_cs & R_ABS))
				    ? 0 : sbp;
				Vp->type_o = t_normal;
			}
			return(TRUE); }
		return(Num_Value(S,In_radix,Vp)); }	/* Since not a symbol, must be a number */
	for (i=0;Prefix_tab[i]; i++) 		/* Check for number prefixes */
		if (Line[Position] == Prefix_tab[i]) {	/* if  there is one */
			Position++;			/* move past it */
			if (Get_Token(S) == 0) {	/* Pick up the digits */
				Prog_Error(E_CONSTANT); return(FALSE); }
			return(Num_Value(S,Radix_tab[i],Vp)); }		/* and evaluate the digits in the proper radix */
	if (Line[Position] == '\047') return(Char_Value(1,Vp));	/* Check for character constants */
	if (Line[Position] == '\"') return(Char_Value(2,Vp));
	if (Line[Position] == '[') {				/* Check for enclosed expression */
		Position++;				/* Move past '[' */
		flag = Evaluate(Vp);			/* evaluate the expression */
		if (Line[Position] == ']') Position++;	/* Move past ']' */
		else Prog_Error(E_TERM);
		return(flag); }				/* and return with the status from evaluate */

	Prog_Error(E_TERM);
	return(FALSE);
}

/* Num_Value(S,Radix,Vp) interprets the digits in the char string 'S' in the
 * 	radix 'Radix' and stores the value into the oper_value pointed to
 *	by 'Vp'.
 */
Num_Value(S,Radix,Vp)
char *S;
struct oper *Vp; {
	long val;		/* temporary value holder */
	register char *cp;	/* current char in S */
	register int C;		
	extern char *lastc();

	val = 0;		/* start with zero */
	Lower(S);		/* to get lower case hex letters */
	if (*(cp = lastc(S)) == '.') {		/* if it ends with '.' */
		Radix = 10; *cp = 0; }	/* assume decimal radix, and remove '.' */

	if ((*S == '0') && (*(S+1) == 'x')) { 	/* allow 0x hex notation */
		Radix = 16;  S += 2;
	}

	for(cp = S; C = *cp; cp++) {		/* for each digit, */
		/* At the end of this switch statement,
			C will contain the value of the digit,
			or -1 if no valid digit */
		if (C < '0') C = -1;
		else switch (Radix) {
		    case 10:	if (C > '9') C= -1; else C = C - '0';
				break;
		    case 8:	if (C > '7') C= -1; else C = C - '0';
				break;
		    case 2:	if (C > '2') C= -1; else C = C - '0';
				break;
		    case 16:	if ((C >= 'a') && (C <= 'f')) C = C - 'a' + 10;
				else if (C <= '9') C = C - '0';
				else C = -1;
		}
		if (C == -1) {
			Prog_Error(E_CONSTANT); return(FALSE); }
		else val = val * Radix + C;
	}
	Vp->value_o = val;	/* Move value into oper_value */
	Vp->sym_o = 0;		/* and there's no offset */
	Vp->type_o = t_normal;	/* normal operand type */
	return(TRUE);
}

/* Char_Value(N,Vp) reads the next N, (1 or 2), non-newline chars from the
 *	 input Line, and places them in the oper value pointed at by Vp.
 * 	The chars are loaded low byte first.
 */
Char_Value(N,Vp)
struct oper *Vp; {
	register int val,i,C;

	Position++;
	val = 0;
	for (i = 0; (i<N) && (Line[Position] != '\n')
		&& (Line[Position] != '\014'); i++)
	{
		if ((C = Grab_Char()) != -1) val= val<<8 | (C&0177) ;
		else return(FALSE);
	}
	Vp->value_o = val;
	Vp->sym_o = 0;
	return(TRUE);
}

/* Grab_Char() is used for reading chars in character constants and in 
 * character strings. It's main function ins to recognise characters of 
 * the form \c or \nnn where c is a special character and n is an octal
 * digit.
 * 	Returns the value of the character read, or -1 on an error.
 */
Grab_Char() {
	register int i;
	register char *cp,C;

	if ((C = Line[Position]) == '\\') {	/* if escaped character, */
		C = Line[++Position];			/* move past '/' */
		for (cp=Escape_tab; *cp; cp += 2)	/* see if special escape char present */
			if (*cp == C){
			    Position++; return(*(++cp)); }
		for((i=0,C=0); i<3; i++)			/* check for '\nnn' */
		    if (Line[Position] >= '0' && Line[Position] <= '7') {
			C = C*8 + Line[Position] - '0';
			Position++; }
		    else break;
		if (i) return(C);			/* if there were any digits, return the char we calculated */
		C = Line[Position]; }			/* Otherwise, just use whats there */
	if (((C < ' ') || (C > '~')) && (C != '\t')) {	/* Check char for validity */
		Prog_Error(E_BADCHAR); return(-1); }
	Position++;
	return(C);
}

