#include "mical.h"
char *random = "~|^`s.random.c R1.3 on 11/8/79";

/* Various useful subroutines */


/* Get_Token(S) reads the next Token, or symbol, from the input line,
	starting at the current Position. It returns the number of chars
	in the token that was found. */

Get_Token(S)
register char S[];
{
	register char C;
	register int i;
	extern char O_debug;

	for (;((C=Line[Position]) == ' ') || (C == '\t');Position++);
	for(i=0; (( (C = Line[Position]) >='0' && C <= '9') ||
			(C >= 'a' && C <= 'z') ||
			(C >= 'A' && C <= 'Z') ||
			(C == '_') || (C == '.') || (C == '$')); (Position++,i++) ) {
		if (i >= STR_MAX) { Prog_Error(E_SYMLEN); i--; break; }
		S[i] = C;
	}
	S[i] = 0;
	return(i);
}


/*
 *
 *  Parsing Routines: Non_Blank(), Skip_Comma(), Line_Delim(), Enclosed()
 *
 */

/* Move Position to the next non-blank character in  the input Line */
Non_Blank(){
	register char C;
	for (;((C=Line[Position]) == ' ') || (C == '\t');Position++);
}

/* Move Position past any comma and to the next non-blank */
Skip_Comma() {
	Non_Blank();
	if (Line[Position] == ',') Position++;
	Non_Blank();
}


/* List of possible line delimiters */
char Line_end_tab[] = { '\n', '|', '\014', 0 } ;

/* Line_Delim(c) returns true if c marks the end of a statement */
Line_Delim(C)
register char C; {
	register char *cp;

	for(cp= Line_end_tab; *cp; cp++) if (C == *cp) return(TRUE);
	return(FALSE);
}

/*
 * Enclosed(left, right, S) 
 *		Extracts char strings enclosed (possibly nested) within delimiter characters
 *	Current line position must be at left delimiter (i.e. Line[Position] == left;) .
 * 	"left" and "right", and places result in string S.
 *		Returns number of chars in S.
 */
Enclosed(left,right,S)
char left,right,S[];
{
	register char	C;
	register int	i;
	int	level;

	if ((C=Line[Position]) != left) return(0);
	for (i=0,level=1; i<STR_MAX && ! Line_Delim(C); i++) {
		C = S[i] = Line[++Position];
		if ((C == right) && (--level) <= 0) {
			Position++;
			S[i] = 0;
			return(i); 
		}
		else if (C == left) level++;
	}
	
	return(0);
}


/* 
 * Get_Encl_String(S) -- Get Enclosed String
 *
 *   			Extract char string from current line position of the form:	
 *				<string>
 *				(string)
 *				"string"
 *				^%string%   , % any character.
 *			String is placed in S.
 *			Returns # chars in S.
 */
Get_String(S)
register char S[];
{
	register char C;
	register int i;

	Non_Blank();
	C = Line[Position];
	if (C == '(') return(Enclosed('(',')',S));
	if (C == '<') return(Enclosed('<','>',S));
	if (C == '\"') return(Enclosed(C,C,S));
	if (C == '^') {
		if (Line_Delim( C = Line[++Position])) { 
			Prog_Error(E_STRING); return(0); }
		return(Enclosed(C,C,S)); }

	/* normal, non-enclosed string. Pick up all contiguous non-blank chars */
	for (i=0; C!=' ' && C!='\t' && !Line_Delim(C) ; i++) {
		*S++ = C;			/* load char into string */
		C = Line[++Position];
	}
	*S = 0;	
	return(i);
}


/*
 * 
 * String Hacking Routines:
 *				append, Concat, Copy, seq, member, lastc, Lower
 *
 */

/* Concatenates string a and b in that order and stores result in c. Returns ptr to c */
char *Concat(c,a,b)
char *a,*c,*b;
{
	register char *cp1,*cp2;

	cp1 = c;
	for (cp2 = a; *cp1 = *cp2; cp1++,cp2++) ;
	for (cp2 = b; *cp1 = *cp2; cp1++,cp2++) ;
	return(c);
}

/* appends string S1 to string S2 */
char *append(S1,S2) 
char *S1,*S2;
{
	register int i,j;
	for (i=0; S2[i]; i++);				/* locate end of S2 */
	for (j=0; S1[j] && i < STR_MAX-1;i++,j++)	/* append S1 to S2 */
		S2[i] = S1[j];
	S2[i] = 0;
	return(S2);
}

/* returns length of string */
Length(S)
char *S;
{
	register int i;
	for (i=0; S[i]; i++);
	return(i);
}

/* Copy string S1 to S2 */
Copy(S1,S2)
char *S1,*S2;
{
	*S2 = 0;					/* empty S2 */
	append(S1,S2);					/* copy S1 to S2 */
}

/* Hashing routine for Symbol and Instruction hash tables */
Hash(S)
register char *S;
{
	register int A,i;

	for(A=0,i=0;S[i];i++)A = A + (S[i]<<(i&01?8:1));
	return(((A*A)>>10)&037);
}

/* string comparison function (String EQuals) */
seq(s1,s2)
register char *s1,*s2;
{
	while (*s1 == *s2) if (*s1 == 0) return(TRUE);
				else { s1++; s2++; }
	return(FALSE);
}

/* Converts all upper case alphabetic chars in string S to lower case. Special
 	chars are unaffected */
Lower(S)
register char *S;
{
	for(;*S;S++) 
		if (*S >= 'A' && *S <= 'Z') *S |= 040;
}

/* member(C,S) return true if character C is in string S, false otherwise */
member(C,S)
register char C,*S; {
	for (;*S;S++) if (C == *S) return(TRUE);
	return(FALSE);
}

/* lastc(S) returns ptr last char in string S */
char *lastc(S)
register char *S; {
	while (*S) S++;
	return (--S);
}
/* Read_Line() is called from the main loop to read the next source line. 
	It calls Start_Line, which
	initializes all "per_line" external variables. It returns TRUE
	if it successfully read a line,
	and aborts (via Sys_Error if it could not. */

FILE *Temp_file;	/* Temporary  to hold source between pass 1 and 2 */
int Line_no = 0;	/* Current line number */

Read_Line() {
	register int C,i;
	char D;
	FILE *In;
	extern char O_debug;
	extern FILE *Source_stack[];	/* Source stack */
	extern int Ss_top;		/* Stack ptr for above */
	extern int Top_of_M_stack;
	extern FLAG Expanding;		/* macro expansion flag */

	if ((D = O_debug)>4) printf("Entering Read_Line\n");
	Start_Line();		/* Initialize externla variables */
	if (Top_of_M_stack >= 0)		/* Check if expanding macro */
		if (Read_Macro_Line()) return(true);
	In = Source_stack[Ss_top];
	while ((C = getc(In)) == EOF)
	{
		fclose(Source_stack[Ss_top]);
		if (Pass == 0) Ehead();
		if ((--Ss_top) < 0)
		{
			Prog_Error(E_END);
			Concat(Line,".end\n",""); 
			Line_no++;
			return(true);
		}
		In = Source_stack[Ss_top];
	}
	/* In temporary file, format of every line is:
		<error byte> <'*' or ' '> <source line> */
	if (In == Temp_file)
	{
		if(C) Prog_Error(C);			/* get pass1 errors */
		C = getc(In);				/* get '*' or ' ' */
		if (C == '*') Expanding = true;
		else Expanding = false;
		C = getc(In);
	}
	/* Finally, read the line in */
	for(i=0;(((Line[i]=C) != '\n') && (C!='\014') && (i<LINE_MAX)); i++)
		if ((C=getc(In))==EOF) break;	/* stop on eof or error */
	Line[i+1] = 0;				/* make the end of string */
	if (i>=LINE_MAX)			/* If didn't get whole line, */
	{
		Line[i] = '\n';			/* put an artificial eol */
		Prog_Warning(E_LINELONG);	/* and complain */
	}
	Line_no++;
	if(D > 1) printf("%d: %s",Line_no,Line);
	return(TRUE);
}
int	Label_count;			/* Number of labels on the current line */
int	Err_code,E_pass1;		/* Error code for pass 1&2, and just for pass 1 */
char	E_warn,				/* -'W' if current error is a warning */
	Rel_mark,			/* =''' if code generated is relative */
	Rel_flag;			/* =1 iff fancy relocation required */

/* Start_Line() resets variables which change from line to line */

Start_Line(){
	register int i;
	extern int Code_length;

	Position = 0;
	Label_count = 0;
	Err_code = 0;
	E_pass1 = 0;
	E_warn = ' ';
	Rel_mark = ' ';
	Rel_flag = 0;
	BC = 0;
	Code_length = 0;
	Operand.type_o = Operand.value_o = 0;
	Operand.sym_o = NULL;
	Operand.reg_o = 0;
}

