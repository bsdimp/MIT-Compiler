#include "mical.h"
char *oper = "~|^`s.oper.c R1.2 on 12/17/79";

/* Scan_Operand_Field(operands) puts the type of each operand encountered
   in the operands array, and returns the number of operands altogether.
*/

Scan_Operand_Field(operands)
 struct oper operands[];
 {	int numops,save;

	Non_Blank();
	save = Position;
	numops = 0;
	do {	if (Line_Delim(Line[Position])) break;
		Get_Operand(operands++);
		numops++;
		Non_Blank();
	} while (numops < 4);
	Position = save;
	return(numops);
 }


/* Op_Delim 	Returns TRUE if c marks the end of an operand field
 */

Op_Delim(c)
char c;
{
	register char *cp;
	for (cp = "\n|,:()@\014]"; *cp; cp++) if (c == *cp) return(TRUE);
	return(FALSE);
}


/* Num_Operands()	returns the number of operand fields on the current 
		statement, each of them separated by commas.
 */

Num_Operands() {
	register int i,count;	/* index and num of operands */
	register char C;
	int skip;		/* number of chars to skip in scanning the field */
	int save;		

	char 	S[STR_MAX];

	Non_Blank();					/* Move Position to first non_blank char */
	if (Line_Delim(Line[Position])) return(0);	/* If no chars left, no operands */
	count = 1;					/* at least one operand is there */
	skip = 0;					/* don't skip any chars */
	save = Position;
	while(Line_Delim(C = Line[Position]) == FALSE){	/* Look at rest of line */
		if (skip) skip--;
		else if (C == '<' || C == '{') {		/* if enclosed expression */
			Enclosed(C,C+2,S);		/* skip over it; C+2 is the ascii rep of > and } resp. */
			continue; }			/* Position is already past enclosed position */
		else if (C == '\'') skip = 1;
		else if (C == '\"') skip = 2;
		else if (C == ',') count++;			/* ',' separates operands */
		Position++;
	}
	Position = save;				/* restore Position */
	return(count);
}



/*
 * Fetches operand value and register subfields and loads them into
 * the operand structure. This routine will fetch only one set of value
 * and register subfields. It will move Position past a ',', so that
 * subsequent calls to Get_Operand will get succesive operands.
 * It will return FALSE if there were any programmer errors in the 
 * operand, TRUE otherwise.
 */

Get_Operand(opnd)
struct oper *opnd;
{
	char c;
	opnd->type_o=opnd->flags_o=opnd->reg_o=opnd->value_o=opnd->disp_o = 0;
	if (Line[Position] == '#')
	{
		Position++;	/* skip # */
		if (!Evaluate(opnd)) return;
		if (opnd->type_o == t_reg) Prog_Error(E_REG);
		opnd->type_o = t_immed;
	}
	else if (!Evaluate(opnd)) return;
	Non_Blank();
	while (c = Line[Position++]) switch(c)
	{
	case '\014':
	case '|':
	case '\n':
		Position--;		/* don't scan these */
	case ',':
		return;			/* i'm done */
	case ':':
		switch(Line[Position++])
		{
		case 'W':
		case 'w':
			opnd->type_o = t_abss;
			continue;
		case 'L':
		case 'l':
			opnd->type_o = t_absl;
			continue;
		default:
			return;
		}
	case '@':
		if (opnd->type_o != t_reg) return;
		opnd->type_o = t_defer;
		continue;
	case '+':
		if (opnd->type_o != t_defer) return;
		opnd->type_o = t_postinc;
		continue;
	case '-':
		if (opnd->type_o != t_defer) return;
		opnd->type_o = t_predec;
		continue;
	case '(':
		if (!Get_Defer(opnd)) return;
		continue;
	default:
		return;	
	}
	return;
}


/* Get_Defer	Process Displacement or Index Deferred Suboperands
 */

Get_Defer(opnd)
register struct oper *opnd;
{
	if (opnd->type_o != t_defer) return(FALSE);
	opnd->reg_o = opnd->value_o;
	if (!Evaluate(opnd)) return(FALSE);
	Non_Blank();
	switch(Line[Position++])
	{
	case ')':
		opnd->type_o = t_displ;
		break;
	case ',':
		opnd->disp_o = opnd->value_o;
		if (!Evaluate(opnd)) return(FALSE);
		if (opnd->type_o != t_reg) return(FALSE);
		if (Line[Position++] != ':') return(FALSE);
		switch(Line[Position++])
		{
		case 'W':
		case 'w':
			opnd->flags_o |= O_WINDEX;
			break;
		case 'L':
		case 'l':
			opnd->flags_o |= O_LINDEX;
			break;
		default:
			return(FALSE);
		}
		Non_Blank();
		if (Line[Position++] != ')') return(FALSE);
		opnd->type_o = t_index;
		break;
	default:
		return(FALSE);
	}						
	return(TRUE);
}

