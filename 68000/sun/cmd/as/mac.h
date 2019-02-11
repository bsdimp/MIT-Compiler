#

/******************************************************************************
 *									      *
 *	MICAL Assembler Macro Header					      *
 *									      *
 *	These are the structure definitions and external declarations used to *
 * implement macros in the MICAL assembler. This file also contains a des-    *
 * cription of the implementation.					      *
 *									      *
 ******************************************************************************/




/*

MACRO IMPLEMENTATION

Overview
________


	The MICAL assembler defines and expands macros during the first pass.
No preprocessor is used. 

	When a .macro instruction is encountered during the first pass, the
assembler enters a separate macro defining mode, implemented by the
"Define_Macro" procedure in "mac.c". In this mode, text is read in verbatim
from the input file and associated with the name of the macro being defined
until a .end or .endm statement is encountered. Thus, no processing of the
statements (i.e. execution of pseudo-ops) within a macro is done at the
time the macro is defined. Processing of the statements in a macro is done
only when the macro is expanded.
	Thus only one macro is being defined at any given time. One may
have the definition of macro M2 within the definition of macro M1, but
M2 will actually be defined only when M1 is being expanded.
	When a .endm pseudo-op is identified during macro definition, the
assembler returns to normal assembly mode.

	When a macro is identified in the operation field of an statement
[Macro()], a structure containing the necessary information for the
expansion of the macro is created, and placed on a stack of such macro
calls [Expand_Macro()]. The use of a stack allows nested macro calls, and
even recursive macro calls. The maximum depth of nested (recursive) macro
calls is the defined parameter, MDEPTH_MAX.
	Whenever a macro is being expanded (identified by a structure on
the M_Stack) the routine Read_Line() will read in a source line from
the current macro being expanded instead of from the input file. Since
Define_Macro() uses Read_Line to get the text of a macro definition, this
allows macro definition during macro expansion.
	When a macro is expanded, the macro call itself and the expansion
are loaded into the temporary file which holds the source text between
passes 1 and 2.

	In the second pass, when a .macro is encountered, the assembler
again goes into a special mode similar to pass 1's. Each source line
is merely printed out, until either a .end or .endm statement is encountered,
whereupon normal processing resumes. 
	When a macro call is encountered in pass 2, it is simply listed.
Presumably the code for the macro expansion already follows the macro call.



Macro Definition
----- ----------

	The major data structure for macro definition is the M_defining
structure, reproduced below:
*/


/* Number of arguments to a macro */
#define	MARGS_MAX	16

/* Number of characters in all macro arguments combined (per macro call) */
#define	MARGCHAR_MAX	80

/* Number of nested macro calls */
#define MDEPTH_MAX	16

/* Number of conditional macros */
#define COND_MACROS	16

/* Macro definition information */

	struct {
		struct M_bkt	*bkt_md;		/* bkt for defined macro */
		char		buff_md[MARGCHAR_MAX];	/* storage for macro arguments */
		char		*args_md[MARGS_MAX];	/* ptrs into buff_md. These are the actual arguments */
		int		nargs_md;		/* number of (formal) arguments */
	} M_defining ;


/* Permanent macro information. These are organized like the symbol table 
	(see sym.c) */

	struct M_bkt {
		int		state_m;	/* Defining or Expanding */
		char		*name_m;	/* name of the macro */
		struct M_bkt	*next_m;	/* ptr to next bkt on chain */
		struct M_line	*text_m;	/* head of linked list of M_lines, which contain the text of the macro */
		int		ACS_m;		/* Automatically Created Symbol flags, one per possible macro argument */
	} _M_bkt;

/* Macro Expansion information. Each bucket is allocated upon expansion of
   	a macro. They are maintained in a stack via M_Stack */

	struct M_call {
		struct	M_bkt	*bkt_mc;		/* ptr to permanent info for this macro */
		char		buff_mc[MARGCHAR_MAX];	/* storage for actual arguments of macro call */
		char		*args_mc[MARGS_MAX];	/* ptrs into buff_mc, one per actual argument. */
		struct M_line	*line_mc;		/* ptr to next M_line to expand */
		int		rc_mc;			/* repeat count, for .irpb and .irpc */
	} _M_call;


/* Text Storage. Each line of a macro is stored separately, and is linked
to the following line of the macro. */

	struct M_line {
		struct M_line	*next_ml;		/* ptr to next line of the macro */
		char		*text_ml;		/* ptr to the char string for the line */
	} _M_line;


/* Macro Expansion Stack.
	Each time a macro is expanded, a  ptr to it's M_call structure is
placed on this stack. This allows nested and recursive macros. */

	struct M_call	*M_stack[MDEPTH_MAX];
	int 		Top_of_M_stack ;

/* Conditional Macro Test list */
	int 	CM_top;
	char	*CM_tests[COND_MACROS];

