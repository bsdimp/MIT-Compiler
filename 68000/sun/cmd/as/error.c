#include "mical.h"
char *error = "~|^`s.error.c R1.3 on 1/3/80";

/*
 *
 *  Sys_Error(), Prog_Error(), and Describe_Error() for mical assembler 
 *
 */


char *E_messages[] = {
/* 0 */		"<unused>",
/* 1 */		"Missing .end statement",
/* 2 */		"Invalid character",
/* 3 */		"Multiply defined symbol",
/* 4 */		"Symbol storage exceeded",
/* 5 */		"Offset too large",
/* 6 */		"Symbol too long",
/* 7 */		"Undefined symbol",
/* 8 */		"Invalid constant",
/* 9 */		"Invalid term",
/* 10 */	"Invalid operator",
/* 11 */	"Non-relocatable expression",
/* 12 */	"Wrong type for instruction",
/* 13 */	"Invalid operand",
/* 14 */	"Invalid symbol",
/* 15 */	"Invalid assignment",
/* 16 */	"Too many labels",
/* 17 */	"Invalid op-code",
/* 18 */	"Invalid entry point",
/* 19 */	"Invalid string",
/* 20 */	"Bad filename or too many levels",
/* 21 */	"Warning--attribute ignored",
/* 22 */	".Error statement",
/* 23 */	"Too many levels: statement ignored",
/* 24 */	"Invalid condition",
/* 25 */	"Wrong number of operands",
/* 26 */	"Line too long",
/* 27 */	"Invalid register expression",
/* 28 */	"Invalid machine address",
/* 29 */	"Unimplemented directive",
/* 30 */	"Cannot open inserted file",
/* 31 */	"Invalid string",
/* 32 */	"Too many macro arguments",
/* 33 */	"Invalid macro argument",
/* 34 */	"Invalid formal argument",
/* 35 */	"Inappropriate .endc statement; ignored",
/* 36 */	"Warning--relative address may be out of range",
/* 37 */	"Warning--invalid argument; ignored",
/* 38 */	"Invalid instruction vector index",
/* 39 */	"Invalid instruction vector",
/* 40 */	"Invalid macro name",
/* 41 */	"Unable to expand time macro",
/* 42 */	"Bad csect",
/* 43 */	"Odd address",
		0
} ;

int	Errors = 0;		/* Number of errors in this pass */
int	Warnings = 0;		/* Number of warnings on this pass */
int	Err_code = 0;		/* error code. reset each statement */
int	E_pass1;		/* error code for unignored pass 1 error */
int	Err_list[ERR_MAX];	/* list of all error codes in this pass */
int	Err_load = 0;		/* subscript to load into Err_list */
char	E_warn = ' ';		/* 'W' if warning present. reset each stmnt */
extern FILE *listout;		/* use this file for listings *//* Sys_Error is called when a System Error occurs, that is, something is wrong
   with the assembler itself. Each routine of the assembler usually checks the
   arguments passed to it for validity, and calls this routine if its
   parameters are invalid. Explanation is a string suitable for a printf
   control string which explains the error, and Number is the value of the
   offending parameter.  This routine will not return.
*/
Sys_Error(Explanation,Number)
char *Explanation;
{
	fprintf(stderr, "Assembler Error-- ");
	fprintf(stderr, Explanation,Number);
	abort();
}

/* This is called whenever the assembler recognizes an error in the current
statement. It registers the error, so that an error code will be listed with
the statement, and a description of the error will be printed at the end of
the listing */

Prog_Error(code)
register int code;
{
	register int i;

	if (Pass != 2) return;		/* no errors on pass 1 */
	if (E_warn == 'W') {		/* Override a warning */
		E_warn = ' ';		/* by turning off warning flag */
		--Warnings; }		/* decrementing warning count */
				/* but not removing the error description */
	else if (Err_code) return;	/* If there's a previous error (not warning) on this statement, ignore this one */
	Err_code = code;			/* set the current error */
	Errors++;				/* increment error count */
	for (i=0; i < Err_load; i++) if (Err_list[i] == code) return;
	Err_list[Err_load++] = code;
}

/* Prog_Warning registers a warning on a statement. A warning is like an error,
	in that something is probably amiss, but the assembler will still try 
	to generate the .rel file. 
*/

Prog_Warning(code){

	if (Pass != 2) return;
	if (Err_code) return;			/* If an error is already registered, ignore this one */
	Prog_Error(code);				/* Try to register it as an error */
		Errors--;				/* Change error to warning */
		Warnings++;
		E_warn = 'W'; 
}

/* Error_Describe is called at the end of pass 2 to describe the errors
		incurred in the program */

Error_Describe() {
	/* print the trailer info to the error output stream, and also to the
		listing file, if need be */
	extern FLAG O_list;	/* set if listing requested */

	Error_Endprint(stdout);
	if (O_list) Error_Endprint(listout);
	return;
}

/* Error_Endprint actually prints the error descriptions, but sends them
		to outfile, which should be a file descriptor */

Error_Endprint(outfile)
FILE *outfile;
{
	register int i;
	extern char O_debug;				/* debug switch, set from command line */
	if ((Errors == 0) && (Warnings == 0)) return;
	fprintf(outfile, "\n\n\t%d Error(s) and %d Warning(s)\n\t #\tDescription of Error(s)\n\n",Errors,Warnings);
	if (O_debug > 5) fprintf(outfile, "\n    Err_load=%d\n",Err_load);
	for (i=0;i<Err_load;i++)				/* Describe the errors in Err_list */
		fprintf(outfile, "\t%d\t%s\n",Err_list[i],E_messages[Err_list[i]]);
}

/* print a text line so user can see the error */
Print_Error() {
	int fsave;
	extern int Err_code, Line_no;
	extern FLAG O_list;

	if (Err_code == 0) return;	/* nothing to say */
	if (O_list) return;	/* he's going to see it anyway */
	O_list = true;		/* set O_list, so Print_Line will work */
	listout = stdout;	/* print to standard output */
	Print_Line(P_ALL);	/* print the line */
	O_list = false;		/* reset O_list */
}

