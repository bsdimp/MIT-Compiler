#
#include "mical.h"
char *ps3 = "~|^`s.ps3.c R1.6 on 5/19/80";

extern struct sym_bkt *Lookup();

/* Globl() -- .GLOBL directive handler 

	Format of statement:	.GLOBL	<sym> [<sym>]...

This directive declares  global symbols, which are symbols that are declared
(and hence may appear in expressions) but are not defined (have a value).

*/

Globl() {
	char	S[STR_MAX];
	struct sym_bkt *sbp;

	Non_Blank();
	if (Pass ==1) do {
		if (Line[Position] == ',') Position++; Non_Blank();
		if (Get_Token(S) == 0)  {
			if (! Line_Delim(Line[Position]))
				Prog_Error(E_SYMBOL);
			break; }
		sbp = Lookup(S);		/* get symbol bucket */
		sbp->csect_s = 0;		/* don't know which */
		sbp->attr_s |= S_DEC | S_EXT;	/* declared and external */
		Non_Blank();			/* any more symbols to define*/
	   } while(! Line_Delim(Line[Position])) ;

	Print_Line(P_NONE);
	return;
}
/* Comm - .comm directive handler

	Format of statement:	.COMM   <sym>,<length>

Comm symbols are sort of like globals but have a length property.

*/

Comm()
{
	char	S[STR_MAX];
	struct oper op;
	struct sym_bkt *sbp;

	Non_Blank();
	if (Pass ==1) do
	{
		if (Line[Position] == ',') Position++; Non_Blank();
		if (Get_Token(S) == 0)
		{
			if (! Line_Delim(Line[Position])) Prog_Error(E_SYMBOL);
			break;
		}
		sbp = Lookup(S);
		sbp->csect_s = 0;	/* make it undefined */
		sbp->attr_s |= S_DEC | S_EXT | S_COMM;
		Non_Blank();
		if (Line[Position++] != ',') Prog_Error(E_OPERAND);
		Evaluate(&op);
		if (op.type_o == t_reg) Prog_Error(E_REG);
		sbp->value_s = op.value_o;
		Non_Blank();
	   } while(! Line_Delim(Line[Position])) ;

	Print_Line(P_NONE);
	return;
}



/* Print Symbol Table */

Pr_Sym_Tab() 
{
	register int		attr;
	register struct sym_bkt	*sbp;
 
	char			Name[STR_MAX];			/* <title>.sym, to temporarily hold symbol table */
	int			hash_index;
	int			Sta[3];				/* Status table for spawn routine */

	extern char		Title[];
	extern FLAG		O_symtab;
	extern int		L_ndigits,
				L_radix;
	extern struct sym_bkt	*sym_hash_tab[];
	FILE 			*symout;
	if (O_symtab == false) return;				/* O_symtab flag must be set */

/* Open a file to hold the symbol table listing */

	Concat(Name,Title,".sym");				/* make the name of the file */
	if ((symout = fopen(Name, "w")) == NULL)
	{
		printf("Can't open symbol file: %s\n",Name);
		return;
	}

	/* (output of printf will now go to the file just created) */

/* walk down symbol table, creating a line for each symbol to be listed */
	for (hash_index = 0; hash_index < HASH_MAX; hash_index++) 
	    for (sbp = sym_hash_tab[hash_index]; sbp; sbp = sbp->next_s) {

		attr = sbp->attr_s;
		if (attr & (S_REG | S_MACRO | S_LOCAL | S_PERM)) continue;	/* skip register, macro, local and permanent variables */
		fprintf(symout, "%-10s  ",sbp->name_s);				/* print symbol name */
		fprintf(symout,"%O", sbp->value_s);
		fprintf(symout," %c%c", attr&S_DEF? ' ' : 'U', 			/* print "Undefined" and "External" flags */
				attr&S_EXT? 'E' : ' ');
		fprintf(symout, "\n");
	    }


/* create a sub-process to sort the symbol table listing */
	fclose(symout);
#ifndef Stanford
	spawnl(Sta,"/bin/sort","sort",Name,"-o",Name,0);	/* spawn a process to execute a sort command */
#else Stanford
	spawnl(Sta,"/usr/bin/sort","sort",Name,"-o",Name,0);	/* spawn a process to execute a sort command */
#endif Stanford
	wait(0);
}


/* EPrintf -- hands .printf and .errorf statements 

	The single argument is a character which is 'P' for a .printf statement, and 'E' for .errorf.
*/


EPrintf(EP)
char EP; 
{
	extern FILE *listout;	/* listing file id */
	int	Arg[10];	/* numerical arguments to printf statement */
	int	i;
	char	C,		/* Current Character */
		Format_String[LINE_MAX]; /* ptr to start of format string */

	if (Pass == 1) {		/* ignore during pass1 */
		Print_Line(P_NONE); return; }

	Non_Blank();		/* Find start of format string in MICAL statement */
	if (Line[Position++] != '\"') goto Error_return;

	for (i=0; i < LINE_MAX; i++) {		/* This loop exits when
							1.   The end of the format string is encountered ("); or 
							2.   A premature end of line is encountered. */
		/* Grab_Char grabs the next char on the source line, doing escape processing ( see eval.c) */
		if (Line[Position] == '\n' || Line[Position] == '\014' || (C = Grab_Char()) == -1) 	/* get next char */
			goto Error_return; 
		if (C == '\"') {		/* proper end of string */
			Format_String[i] = 0;
			break; }
		else Format_String[i] = C;	/* otherwise load into format string */
	}

	for (i=0; i<10 && ! Line_Delim(Line[Position]); i++) {	/* pickup up to 10 numeric arguments */
		Non_Blank();
		if (Line[Position] == ',') Position++;
		Get_Operand(&Operand);
		Arg[i] = Operand.value_o;
	}
	if (EP == 'E') Prog_Error(22);		/* Cause error if .error statement */
	
	fprintf((EP == 'T')?stdout:listout, Format_String, Arg[0],Arg[1],Arg[2],Arg[3],Arg[4],Arg[5],Arg[6],Arg[7],Arg[8],Arg[9]);

	Print_Line(P_NONE);
	return;

Error_return:
	Prog_Error(31);					/* Invalid string error */
	Print_Line(P_NONE);
	return;
}

