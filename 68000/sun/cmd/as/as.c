#
/* 
	This is the main loop of the 68000 assembler.
	Written by Mike Patrick, Fall 76.
	Modified by C. Terman 5/79
	Hacked by J. Gula 10/79
*/

#include "mical.h"

/* when Done is nonzero, the assembler is finished. This is the normal means of exit */
int 	Done = 0;

main(argc,argv)
int argc;
char *argv[];
{
	extern struct sym_bkt *Dot_bkt;	/* ptr to symbol bucket for location counter */
	extern struct csect *Cur_csect;	/* ptr to current csect */
	extern int Errors;		/* number of assembly errors */

	if (Init(argc,argv)){		/* Init returns 1 if it is able to open all source files, read the descriptor file,
					   and generally set things up */
		while (Done == 0) {	/* Done becomes 1 when the assembler is finished, on an unexpected eof, or
					   on an assembler error */
			Read_Line();	/* Read the next line, from source files or macro expansions */

			/* Each of the functions in the following nested if statement will return TRUE if it wasn't able to 
			   process the current line entirely */
			if (Cond())	/* Cond handles all conditional pseudo-ops */
			if (Label())	/* Label picks up all label fields, as well as "=" statements */
			if (Pseudo())	/* Pseudo handles all assembler directives, (including .macro), other than .if, .iif, etc */
			if (Macro())	/* Macro recognizes macro calls, and sets up things so that Read_Line will read them */
			if (Instruction())	/* Instruction handles the normal machine instruction statements */
			ByteWord(2);		/* If all else fails, assume the line is an expression, and call the */
						/* .word pseudo-op handler to process it */
			Dot += BC;	/* increment dot by number of machine addresses */
			Cur_csect->dot_cs = Dot_bkt->value_s = Dot;
			if (Dot > Cur_csect->len_cs)	/* Update Dot bucket and Current csect length */
				Cur_csect->len_cs = Dot;

		}
	}

	exit(Errors? -1: 0);	/* if assembly errors, return -1; otherwise 0 */
}

