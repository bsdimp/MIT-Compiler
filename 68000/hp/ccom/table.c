/*************************************************************************
*									 *
*		Modified to the hilt for Motorola			 *
*		 standard syntax -- Anny 7/16/82			 *
*									 *
**************************************************************************/

# include "mfile2"

# define TSCALAR TCHAR|TUCHAR|TSHORT|TUSHORT|TINT|TUNSIGNED|TPOINT|TLONG|TULONG /* MFM */
# define EA SNAME|SOREG|SCON|STARREG|SAREG|SBREG
# define EAA SNAME|SOREG|SCON|STARREG|SAREG
# define EB SBREG

/************************************************************************
*									*
*	Definitions gleaned from the code:				*
*									*
*	SAREG -		Operand is in an A (data) register		*
*	STAREG -	Operand is in a temporary A register		*
*	SBREG -		Operand is in a B (address) register		*
*	STBREG -	Operand is in a temporary B register		*
*	SCC -		Operand is in the condition codes		*
*	SCON -		Operand is a constant				*
*	SCCON -								*
*	SC8CON -	Operand is a constant (representable in 8 bits)	*
*	SFLD -		Operand is a subfield of a word.		*
*	STARN -		Operand is accessed indirectly thru a register	*
*				variable				*
*	STARREG -	Operand is accessed indirectly thru a register  *
*				pointer					*
*	SZERO -		Operand is the special constant '0'		*
*	SONE -		OPerand is the special constant '1'		*
*	SMONE -		Operand is the special constant '-1'		*
*	SOREG -								*
*	SICON -								*
*	STASG -
*	SNAME -		Operand is addressable with '#' (immediate)	*
*									*
*	OPLTYPE -	Leaf type node (ICON, NAME, etc.)		*
*************************************************************************
*/




struct optab  table[] = {

ASSIGN,	INAREG|FOREFF|FORCC,
	SAREG|STAREG,	TSCALAR,
	SCCON,	TSCALAR,
		0,	RLEFT  |RRIGHT|RESCC  ,
#ifndef cookies
		"	moveq	AR,AL\n",
#endif
#ifdef cookies
		"	moveq	AR,AL|cookie 1\n",
#endif






ASSIGN,	INAREG|FOREFF|FORCC,
	EAA,	TSCALAR|TFLOAT,
	SZERO,	TANY,
		0,	RLEFT|RRIGHT|RESCC,
#ifndef cookies
		"	clrZB	AL\n",
#endif
#ifdef cookies
		"	clrZB	AL|cookie 2\n",
#endif






ASSIGN,	INAREG|FOREFF|FORCC,
	EAA,	TDOUBLE,
	SZERO,	TANY,
		0,	RLEFT|RRIGHT|RESCC,
#ifndef cookies
		"	clr.l	AL\n	clr.l	UL\n",
#endif
#ifdef cookies
		"	clr.l	AL|cookie 3a\n	clr.l	UL|cookie 3b\n",
#endif






/*
ASSIGN,	INAREG|FOREFF|FORCC,
	SAREG|STAREG,	TSCALAR,
	SCCON,	TSCALAR,
		0,	RLEFT|RRIGHT|RESCC,
		"	moveq	AR,AL\n",
*/






ASSIGN,	INAREG|FOREFF|FORCC,
	EAA,	TSCALAR|TFLOAT,
	EA,	TSCALAR|TFLOAT,
		0,	RLEFT|RRIGHT|RESCC,
#ifndef cookies
		"	moveZB	AR,AL\n",
#endif
#ifdef cookies
		"	moveZB	AR,AL|cookie 4\n",
#endif






ASSIGN,	INAREG|FOREFF,
	EAA,	TDOUBLE,
	EA,	TDOUBLE,
		0,	RLEFT|RRIGHT,
#ifndef cookies
		"	move.l	AR,AL\n	move.l	UR,UL\n",
#endif
#ifdef cookies
		"	move.l	AR,AL|cookie 5a\n	move.l	UR,UL|cookie 5b\n",
#endif






/* THE FOLLOWING COOKIE IS ADDED FOR A TEMPORARY FIX TO FLOAT-DOUBLE CONVERSION */
ASSIGN,	INAREG|FOREFF,
	EAA,	TDOUBLE,
	EA,	TFLOAT,
		0,	RLEFT|RRIGHT,
#ifndef cookies
	"	move.l	AR,AL\n\t clr.l	UL\n",
#else
	"	move.l	AR,AL|cookie 5c\n\t clr.l	UL|cookie 5d\n"
#endif






ASSIGN,	INAREG|FOREFF,
	EAA,	TFLOAT,
	EA,	TDOUBLE,
		0,	RLEFT|RRIGHT,
#ifndef cookies
		"	move.l	AR,AL\n",
#endif
#ifdef cookies
		"	move.l	AR,AL|cookie 6\n",
#endif






ASSIGN,	INBREG|FOREFF,
	EB,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT|RRIGHT|RESCC,
#ifndef cookies
		"	moveZB	AR,AL\n",
#endif
#ifdef cookies
		"	moveZB	AR,AL|cookie 7\n",
#endif






ASSIGN, INAREG|FOREFF,
	SFLD,	TANY,
	SZERO,	TANY,
		0,	RRIGHT,
#ifndef cookies
		"	and.l	#N,AL\n",
#endif
#ifdef cookies
		"	and.l	#N,AL|cookie 8\n",
#endif






ASSIGN, INTAREG|INAREG|FOREFF,
	SFLD,	TANY,
	STAREG,	TANY,
		NAREG,	RRIGHT,
#ifndef cookies
		"F\tmove.l\tAR,-(sp)\n\tmove.l\t#H,A1\n\tlsl.l\tA1,AR\n\tand.l\t#M,AR\n\tand.l\t#N,AL\n\tor.l\tAR,AL\nF\tmove\t(sp)+,AR\n",
#endif
#ifdef cookies
		"F\tmove.l\tAR,-(sp)|cookie 9a\n\tmove.l\t#H,A1\n\tlsl.l\tA1,AR\n\tand.l\t#M,AR\n\tand.l\t#N,AL\n\tor.l\tAR,AL\nF\tmove\t(sp)+,AR|cookie 9b\n",
#endif






ASSIGN, INAREG|FOREFF,
	SFLD,	TANY,
	EA,	TANY,
		2*NAREG,	RRIGHT,
#ifndef cookies
		"\tmoveZB\tAR,A1\n\tmove.l\t#H,A2\n\tlsl.l\tA2,A1\n\tand.l\t#M,A1\n\tand.l\t#N,AL\n\tor.l\tA1,AL\n",
#endif
#ifdef cookies
		"\tmoveZB\tAR,A1|cookie 10a\n\tmove.l\t#H,A2\n\tlsl.l\tA2,A1\n\tand.l\t#M,A1\n\tand.l\t#N,AL\n\tor.l\tA1,AL|cookie 10b\n",
#endif







/* put this here so UNARY MUL nodes match OPLTYPE when appropriate */
UNARY MUL,	INTAREG|INAREG|FORCC,
	SBREG,	TSCALAR,
	SANY,	TANY,
		NAREG|NASR,	RESC1|RESCC,
#ifndef cookies
		"	moveZB	(AL),A1\n",
#endif
#ifdef cookies
		"	moveZB	(AL),A1|cookie 11\n",
#endif






OPLTYPE,	FOREFF,
	SNAME|SOREG|SCON|SAREG|SBREG,	TANY,
	EA,	TANY,
		0,	RRIGHT,
#ifndef cookies
		"",   /* this entry throws away computations which don't do anything */
#endif
#ifdef cookies
		"|cookie 12",
#endif






OPLTYPE,	FORCC,
	SANY,	TANY,
	EAA,	TSCALAR|TFLOAT|TDOUBLE,
		0,	RESCC,
#ifndef cookies
		"	tstZB	AR\n",
#endif
#ifdef cookies
		"	tstZB	AR|cookie 13\n",
#endif






OPLTYPE,	FORCC,
	SANY,	TANY,
	EB,	TSCALAR,
		0,	RESCC,
#ifndef cookies
		"	cmpZB	#0,AR\n",
#endif
#ifdef cookies
		"	cmpZB	#0,AR|cookie 14\n",
#endif






OPLTYPE,	INTAREG|INAREG|FORCC,
	SANY,	TANY,
	SZERO,	TSCALAR,
		NAREG|NASR,	RESC1|RESCC,
#ifndef cookies
		"	moveq	#0,A1\n" /* clrZB	A1*/,
#endif
#ifdef cookies
		"	moveq	#0,A1| cookie 15\n" /* clrZB	A1*/,
#endif






OPLTYPE,	INTAREG|INAREG|FORCC,
	SANY,	TANY,
	SCCON,	TSCALAR,
		NAREG|NASR,	RESC1|RESCC,
#ifndef cookies
		"	moveq	AR,A1\n",
#endif
#ifdef cookies
		"	moveq	AR,A1|cookie 16\n",
#endif






OPLTYPE,	INTAREG|INAREG|FORCC,
	SANY,	TANY,
	EA,	TSCALAR,
		NAREG|NASR,	RESC1|RESCC,
#ifndef cookies
		"	moveZB	AR,A1\n",
#endif
#ifdefAREG,	TANY,
		NAREG,	RRIGHT,
#ifndef cookies
		"F\tmove.l\tAR,-(sp)\n\tmove.l\t#H,A1\n\tlsl.l\tA1,AR\n\tand.l\t#M,AR\n\tand.l\t#N,AL\n\tor.l\tAR,AL\nF\tmove\t(sp)+,AR\n",
#endif
#ifdef cookies
		"F\tmove.l\tAR,-(sp)|cookie 9a\n\tmove.l\t#H,A1\n\tlsl.l\tA1,AR\n\tand.l\t#M,AR\n\tand.l\t#N,AL\n\tor.l\tAR,AL\nF\tmove\t(sp)+,AR|cookie 9b\n",
#endif






ASSIGN, INAREG|FOREFF,
	SFLD,	TANY,
	EA,	TANY,
		2*NAREG,	RRIGHT,
#ifndef cookies
		"\tmoveZB\tAR,A1\n\tmove.l\t#H,A2\n\tlsl.l\tA2,A1\n\tand.l\t#M,A1\n\tand.l\t#N,AL\n\tor.l\tA1,AL\n",
#endif
#ifdef cookies
		"\tmoveZB\tAR,A1|cookie 10a\n\tmove.l\t#H,A2\n\tlsl.l\tA2,A1\n\tand.l\t#M,A1\n\tand.l\t#N,AL\n\tor.l\tA1,AL|cookie 10b\n",
#endif







/* put this here so UNARY MUL nodes match OPLTYPE when appropriate */
UNARY MUL,	INTAREG|INAREG|FORCC,
	SBREG,	TSCALAR,
	SANY,	TANY,
		NAREG|NASR,	RESC1|RESCC,
#ifndef cookies
		"	moveZB	(AL),A1\n",
#endif
#ifdef cookies
		"	moveZB	(AL),A1|cookie 11\n",
#endif






OPLTYPE,	FOREFF,
	SNAME|SOREG|SCON|SAREG|SBREG,	TANY,
	EA,	TANY,
		0,	RRIGHT,
#ifndef cookies
		"",   /* this entry throws away computations which don't do anything */
#endif
#ifdef cookies
		"|cookie 12",
#endif






OPLTYPE,	FORCC,
	SANY,	TANY,
	EAA,	TSCALAR|TFLOAT|TDOUBLE,
		0,	RESCC,
#ifndef cookies
		"	tstZB	AR\n",
#endif
#ifdef cookies
		"	tstZB	AR|cookie 13\n",
#endif






OPLTYPE,	FORCC,
	SANY,	TANY,
	EB,	TSCALAR,
		0,	RESCC,
#ifndef cookies
		"	cmpZB	#0,AR\n",
#endif
#ifdef cookies
		"	cmpZB	#0,AR|cookie 14\n",
#endif






OPLTYPE,	INTAREG|INAREG|FORCC,
	SANY,	TANY,
	SZERO,	TSCALAR,
		NAREG|NASR,	RESC1|RESCC,
#ifndef cookies
		"	moveq	#0,A1\n" /* clrZB	A1*/,
#endif
#ifdef cookies
		"	moveq	#0,A1| cookie 15\n" /* clrZB	A1*/,
#endif






OPLTYPE,	INTAREG|INAREG|FORCC,
	SANY,	TANY,
	SCCON,	TSCALAR,
		NAREG|NASR,	RESC1|RESCC,
#ifndef cookies
		"	moveq	AR,A1\n",
#endif
#ifdef cookies
		"	moveq	AR,A1|cookie 16\n",
#endif






OPLTYPE,	INTAREG|INAREG|FORCC,
	SANY,	TANY,
	EA,	TSCALAR,
		NAREG|NASR,	RESC1|RESCC,
#ifndef cookies
		"	moveZB	AR,A1\n",
#endif
#ifdef cookies
		"	moveZB	AR,A1|cookie 17\n",
#endif






OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	EA,	TDOUBLE,
		NAREG|NASR,	RESC1,
#ifndef cookies
		"	move.l	AR,A1\n	move.l	UR,U1\n",
#endif
#ifdef cookies
		"	move.l	AR,A1|cookie 18a\n	move.l	UR,U1|cookie 18b\n",
#endif






OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	EA,	TFLOAT,
		NAREG|NASR,	RESC1,
#ifndef cookies
		"	move.l	AR,A1\n",
#endif
#ifdef cookies
		"	move.l	AR,A1|cookie 19\n",
#endif






OPLTYPE,	INTBREG|INBREG|FORCC,
	SANY,	TANY,
	EA,	TSCALAR,
		NBREG|NBSR,	RESC1|RESCC,
#ifndef cookies
		"	moveZB	AR,A1\n",
#endif
#ifdef cookies
		"	moveZB	AR,A1|cookie 20\n",
#endif






OPLTYPE,	INTEMP|FORCC,
	SANY,	TANY,
	EA,	TSCALAR,
		NTEMP,	RESC1|RESCC,
#ifndef cookies
		"	moveZB	AR,A1\n",
#endif
#ifdef cookies
		"	moveZB	AR,A1|cookie 21\n",
#endif






OPLTYPE,	INTEMP,
	SANY,	TANY,
	EA,	TDOUBLE,
		NTEMP,	RESC1,
#ifndef cookies
		"	move.l	AR,A1\n	move.l	UR,U1",
#endif
#ifdef cookies
		"	move.l	AR,A1|cookie 22a\n	move.l	UR,U1|cookie 22b",
#endif






OPLTYPE,	FORARG,
	SANY,	TANY,
	SBREG,	TINT|TUNSIGNED|TPOINT,
		0,	RNULL,
#ifndef cookies
		"	pea	(AR)\nZP",
#endif
#ifdef cookies
		"	pea	(AR)|cookie 23a\nZP|cookie 23b",
#endif






OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TINT|TUNSIGNED|TPOINT,
		0,	RNULL,
#ifndef cookies
		"	move.l	AR,Z-\n",
#endif
#ifdef cookies
		"	move.l	AR,Z-|cookie 24\n",
#endif






OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TSHORT,
		NBREG|NBSR,	RNULL,
#ifndef cookies
		"	move.w	AR,A1\n	move.l	A1,Z-\n",
#endif
#ifdef cookies
		"	move.w	AR,A1|cookie 25a\n	move.l	A1,Z-|cookie 25b\n",
#endif






OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TUSHORT,
		NAREG|NASR,	RNULL,
#ifndef cookies
		"	clr.l	A1\n	move.w	AR,A1\n	move.l	A1,Z-\n",
#endif
#ifdef cookies
		"	clr.l	A1|cookie 26a\n	move.w	AR,A1\n	move.l	A1,Z-cookie 26b\n",
#endif






OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TCHAR,
		NAREG|NASR,	RNULL,
#ifndef cookies
		"	move.b	AR,A1\n	ext.w	A1\n	ext.l	A1\n	move.l	A1,Z-\n",
#endif
#ifdef cookies
		"	move.b	AR,A1|cookie 27a\n	ext.w	A1\n	ext.l	A1\n	move.l	A1,Z-|cookie 27b\n",
#endif






OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TUCHAR,
		NAREG|NASR,	RNULL,
#ifndef cookies
		"	clr.l	A1\n	move.b	AR,A1\n	move.l	A1,Z-\n",
#endif
#ifdef cookies
		"	clr.l	A1|cookie 28a\n	move.b	AR,A1\n	move.l	A1,Z-|cookie 28b\n",
#endif






OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TFLOAT,
		0,	RNULL,
#ifndef cookies
		"\tmove.l	AR,Z-\n",
#endif
#ifdef cookies
		"\tmove.l	AR,Z-|cookie 29\n",
#endif






OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TDOUBLE,
		0,	RNULL,
#ifndef cookies
		"	move.l	UR,Z-\n	move.l	AR,Z-\n",
#endif
#ifdef cookies
		"	move.l	UR,Z-|cookie 30a\n	move.l	AR,Z-|cookie 30b\n",
#endif






OPLOG,	FORCC,
	SAREG|STAREG|SBREG|STBREG,	TSCALAR,
	EA,	TSCALAR,
		0,	RESCC,
#ifndef cookies
		"	cmpZL	AR,AL\nZI",
#endif
#ifdef cookies
		"	cmpZL	AR,AL|cookie 31a\nZI|cookie 31b",
#endif






OPLOG,	FORCC,
	EA,	TSCALAR,
	SCON,	TSCALAR,
		0,	RESCC,
#ifndef cookies
		"	cmpZL	AR,AL\nZI",
#endif
#ifdef cookies
		"	cmpZL	AR,AL|cookie 32a\nZI|cookie 32b",
#endif






CCODES,	INTAREG|INAREG,
	SANY,	TANY,
	SANY,	TANY,
		NAREG,	RESC1,
#ifndef cookies
		"	moveq	#1,A1\nZN",
#endif
#ifdef cookies
		"	moveq	#1,A1|cookie 33a\nZN|cookie 33b",
#endif






UNARY MINUS,	INTAREG|INAREG,
	STAREG,	TSCALAR,
	SANY,	TANY,
		0,	RLEFT,
#ifndef cookies
		"	negZB	AL\n",
#endif
#ifdef cookies
		"	negZB	AL|cookie 34\n",
#endif






COMPL,	INTAREG|INAREG,
	STAREG,	TSCALAR,
	SANY,	TANY,
		0,	RLEFT,
#ifndef cookies
		"	notZB	AL\n",
#endif
#ifdef cookies
		"	notZB	AL|cookie 35\n",
#endif






INCR,	INTAREG|INAREG|FOREFF,
	EAA,	TSCALAR,
	S8CON,	TSCALAR,
		NAREG,	RESC1,
#ifndef cookies
		"F	moveZB	AL,A1\n	addqZB	AR,AL\n",
#endif
#ifdef cookies
		"F	moveZB	AL,A1|cookie 36a\n	addqZB	AR,AL|cookie 36b\n",
#endif






DECR,	INTAREG|INAREG|FOREFF,
	EAA,	TSCALAR,
	S8CON,	TSCALAR,
		NAREG,	RESC1,
#ifndef cookies
		"F	moveZB	AL,A1\n	subqZB	AR,AL\n",
#endif
#ifdef cookies
		"F	moveZB	AL,A1|cookie 37a\n	subqZB	AR,AL|cookie 37b\n",
#endif






INCR,	INTAREG|INAREG|FOREFF,
	EAA,	TSCALAR,
	SCON,	TSCALAR,
		NAREG,	RESC1,
#ifndef cookies
		"F	moveZB	AL,A1\n	addZB	AR,AL\n",
#endif
#ifdef cookies
		"F	moveZB	AL,A1|cookie 38a\n	addZB	AR,AL|cookie 38b\n",
#endif






DECR,	INTAREG|INAREG|FOREFF,
	EAA,	TSCALAR,
	SCON,	TSCALAR,
		NAREG,	RESC1,
#ifndef cookies
		"F	moveZB	AL,A1\n	subZB	AR,AL\n",
#endif
#ifdef cookies
		"F	moveZB	AL,A1|cookie 39a\n	subZB	AR,AL|cookie 39b\n",
#endif






INCR,	INTBREG|INBREG|FOREFF,
	EB,	TSCALAR,
	S8CON,	TSCALAR,
		NBREG,	RESC1,
#ifndef cookies
		"F	moveZB	AL,A1\n	addqZB	AR,AL\n",
#endif
#ifdef cookies
		"F	moveZB	AL,A1|cookie 40a\n	addqZB	AR,AL|cookie 40b\n",
#endif






DECR,	INTBREG|INBREG|FOREFF,
	EB,	TSCALAR,
	S8CON,	TSCALAR,
		NBREG,	RESC1,
#ifndef cookies
		"F	moveZB	AL,A1\n	subqZB	AR,AL\n",
#endif
#ifdef cookies
		"F	moveZB	AL,A1|cookie 41a\n	subqZB	AR,AL|cookie 41b\n",
#endif






INCR,	INTBREG|INBREG|FOREFF,
	EB,	TSCALAR,
	SCON,	TSCALAR,
		NBREG,	RESC1,
#ifndef cookies
		"F	moveZB	AL,A1\n	addZB	AR,AL\n",
#endif
#ifdef cookies
		"F	moveZB	AL,A1|cookie 42a\n	addZB	AR,AL|cookie 42b\n",
#endif






DECR,	INTBREG|INBREG|FOREFF,
	EB,	TSCALAR,
	SCON,	TSCALAR,
		NBREG,	RESC1,
#ifndef cookies
		"F	moveZB	AL,A1\n	subZB	AR,AL\n",
#endif
#ifdef cookies
		"F	moveZB	AL,A1|cookie 43a\n	subZB	AR,AL|cookie 43b\n",
#endif






PLUS,		INBREG|INTBREG,
	SBREG,	TPOINT,
	SICON,	TANY,
		NBREG|NBSL,	RESC1,
#ifndef cookies
		"	lea	ZO(AL),A1\n",
#endif
#ifdef cookies
		"	lea	ZO(AL),A1|cookie 44\n",
#endif






PLUS,		FORARG,
	SBREG,	TPOINT,
	SICON,	TANY,
		0,	RNULL,
#ifndef cookies
		"	pea	ZO(AL)\nZP",
#endif
#ifdef cookies
		"	pea	ZO(AL)|cookie 45a\nZP|cookie 45b",
#endif






MINUS,		INBREG|INTBREG,
	SBREG,	TPOINT,
	SICON,	TANY,
		NBREG|NBSL,	RESC1,
#ifndef cookies
		"	lea	ZM(AL),A1\n",
#endif
#ifdef cookies
		"	lea	ZM(AL),A1|cookie 46\n",
#endif






MINUS,		FORARG,
	SBREG,	TPOINT,
	SICON,	TANY,
		0,	RNULL,
#ifndef cookies
		"	pea	ZM(AL)\nZP",
#endif
#ifdef cookies
		"	pea	ZM(AL)|cookie 47a\nZP|cookie 47b",
#endif






ASG PLUS,	INAREG|FORCC,
	EAA,	TSCALAR,
	S8CON,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	addqZB	AR,AL\n",
#endif
#ifdef cookies
		"	addqZB	AR,AL|cookie 48\n",
#endif






ASG PLUS,	INBREG|FORCC,
	EB,	TSCALAR,
	S8CON,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	addqZB	AR,AL\n",
#endif
#ifdef cookies
		"	addqZB	AR,AL|cookie 49\n",
#endif






ASG PLUS,	INAREG|FORCC,
	SAREG|STAREG,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	addZB	AR,AL\n",
#endif
#ifdef cookies
		"	addZB	AR,AL|cookie 50\n",
#endif






ASG PLUS,	INBREG,
	SBREG|STBREG,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT,
#ifndef cookies
		"	addZB	AR,AL\n",
#endif
#ifdef cookies
		"	addZB	AR,AL|cookie 51\n",
#endif






ASG PLUS,	INAREG|FORCC,
	EAA,	TSCALAR,
	SAREG|STAREG,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	addZB	AR,AL\n",
#endif
#ifdef cookies
		"	addZB	AR,AL|cookie 52\n",
#endif






ASG MINUS,	INAREG|FORCC,
	EAA,	TSCALAR,
	S8CON,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	subqZB	AR,AL\n",
#endif
#ifdef cookies
		"	subqZB	AR,AL|cookie 53\n",
#endif






ASG MINUS,	INBREG|FORCC,
	EB,	TSCALAR,
	S8CON,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	subqZB	AR,AL\n",
#endif
#ifdef cookies
		"	subqZB	AR,AL|cookie 54\n",
#endif






ASG MINUS,	INAREG|FORCC,
	SAREG|STAREG,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	subZB	AR,AL\n",
#endif
#ifdef cookies
		"	subZB	AR,AL|cookie 55\n",
#endif






ASG MINUS,	INBREG,
	SBREG|STBREG,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT,
#ifndef cookies
		"	subZB	AR,AL\n",
#endif
#ifdef cookies
		"	subZB	AR,AL|cookie 56\n",
#endif






ASG MINUS,	INAREG|FORCC,
	EAA,	TSCALAR,
	SAREG|STAREG,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	subZB	AR,AL\n",
#endif
#ifdef cookies
		"	subZB	AR,AL|cookie 57\n",
#endif






ASG ER, 	INAREG|FORCC,
	EAA,	TSCALAR,
	SCON,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	eorZB	AR,AL\n",
#endif
#ifdef cookies
		"	eorZB	AR,AL|cookie 58\n",
#endif






ASG ER, 	INAREG|FORCC,
	EAA,	TSCALAR,
	SAREG|STAREG,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	eorZB	AR,AL\n",
#endif
#ifdef cookies
		"	eorZB	AR,AL|cookie 59\n",
#endif






ASG OPSIMP, 	INAREG|FORCC,
	SAREG|STAREG,	TSCALAR,
	EAA,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	OIZB	AR,AL\n",
#endif
#ifdef cookies
		"	OIZB	AR,AL|cookie 60\n",
#endif






ASG OPSIMP, 	INAREG|FORCC,
	EAA,	TSCALAR,
	SCON,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	OIZB	AR,AL\n",
#endif
#ifdef cookies
		"	OIZB	AR,AL|cookie 61\n",
#endif






ASG OPSIMP, 	INAREG|FORCC,
	EAA,	TSCALAR,
	SAREG|STAREG,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	OIZB	AR,AL\n",
#endif
#ifdef cookies
		"	OIZB	AR,AL|cookie 62\n",
#endif






ASG MUL,	INAREG|FORCC,
	SAREG|STAREG,	TSHORT,
	EAA,	TSHORT,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	muls	AR,AL\n",
#endif
#ifdef cookies
		"	muls	AR,AL|cookie 63\n",
#endif






ASG MUL,	INAREG|FORCC,
	SAREG|STAREG,	TUSHORT,
	EAA,	TUSHORT|TSHORT,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	mulu	AR,AL\n",
#endif
#ifdef cookies
		"	mulu	AR,AL|cookie 64\n",
#endif






ASG MUL,	INAREG|FORCC,
	SAREG|STAREG,	TSHORT,
	EAA,	TUSHORT,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	mulu	AR,AL\n",
#endif
#ifdef cookies
		"	mulu	AR,AL|cookie 65\n",
#endif






ASG MUL,	INAREG,
	SAREG|STAREG,	TCHAR,
	EAA,	TCHAR,
		NAREG,	RLEFT,
#ifndef cookies
		"\text.w	AL\n\tmove.b	AR,A1\n\text.w	A1\n\tmuls	A1,AL\n",
#endif
#ifdef cookies
		"\text.w	AL|cookie 66a\n\tmove.b	AR,A1\n\text.w	A1\n\tmuls	A1,AL|cookie 66b\n",
#endif






ASG MUL,	INAREG,
	SAREG|STAREG,	TUCHAR,
	EAA,	TUCHAR|TCHAR,
		NAREG,	RLEFT,
#ifndef cookies
		"\tand.w	#255,AL\n\tclr.w	A1\tmove.b	AR,A1\n\tmuls	A1,AL\n",
#endif
#ifdef cookies
		"\tand.w	#255,AL|cookie 67a\n\tclr.w	A1\tmove.b	AR,A1\n\tmuls	A1,AL|cookie 67b\n",
#endif






ASG DIV,	INAREG|FORCC,
	SAREG|STAREG,	TSHORT,
	EAA,	TSHORT,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	ext.l	AL\n	divs	AR,AL\n",
#endif
#ifdef cookies
		"	ext.l	AL|cookie 68a\n	divs	AR,AL|cookie 68b\n",
#endif






ASG DIV,	INAREG|FORCC,
	SAREG|STAREG,	TUSHORT,
	EAA,	TUSHORT|TSHORT,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	and.l	#65535,AL\n	divu	AR,AL\n",
#endif
#ifdef cookies
		"	and.l	#65535,AL|cookie 69a\n	divu	AR,AL|cookie 69b\n",
#endif






ASG DIV,	INAREG|FORCC,
	SAREG|STAREG,	TSHORT,
	EAA,	TUSHORT,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	and.l	#65535,AL\n	divu	AR,AL\n",
#endif
#ifdef cookies
		"	and.l	#65535,AL|cookie 70a\n	divu	AR,AL|cookie 70b\n",
#endif






ASG DIV,	INAREG,
	SAREG|STAREG,	TCHAR,
	EAA,	TCHAR,
		NAREG,	RLEFT,
#ifndef cookies
		"\text.w	AL\n\tmove.b	AR,A1\n\text.w	A1\n\tdivs	A1,AL\n",
#endif
#ifdef cookies
		"\text.w	AL|cookie 71a\n\tmove.b	AR,A1\n\text.w	A1\n\tdivs	A1,AL|cookie 71b\n",
#endif






ASG DIV,	INAREG,
	SAREG|STAREG,	TUCHAR,
	EAA,	TUCHAR|TCHAR,
		NAREG,	RLEFT,
#ifndef cookies
		"\tand.w	#255,AL\n\tclr.w	A1\tmove.b	AR,A1\n\tdivs	A1,AL\n",
#endif
#ifdef cookies
		"\tand.w	#255,AL|cookie 72a\n\tclr.w	A1\tmove.b	AR,A1\n\tdivs	A1,AL|cookie 72b\n",
#endif






ASG MOD,	INAREG,
	SAREG|STAREG,	TSHORT,
	EAA,	TSHORT,
		0,	RLEFT,
#ifndef cookies
		"	ext.l	AL\n	divs	AR,AL\n	swap	AL\n",
#endif
#ifdef cookies
		"	ext.l	AL|cookie 73a\n	divs	AR,AL\n	swap	AL|cookie 73b\n",
#endif






ASG MOD,	INAREG,
	SAREG|STAREG,	TUSHORT,
	EAA,	TUSHORT|TSHORT,
		0,	RLEFT,
#ifndef cookies
		"	and.l	#65535,AL\n	divu	AR,AL\n	swap	AL\n",
#endif
#ifdef cookies
		"	and.l	#65535,AL|cookie 74a\n	divu	AR,AL\n	swap	AL|cookie 74b\n",
#endif






ASG MOD,	INAREG,
	SAREG|STAREG,	TSHORT,
	EAA,	TUSHORT,
		0,	RLEFT,
#ifndef cookies
		"	and.l	#65535,AL\n	divu	AR,AL\n	swap	AL\n",
#endif
#ifdef cookies
		"	and.l	#65535,AL|cookie 75a\n	divu	AR,AL\n	swap	AL|cookie 75b\n",
#endif






ASG MOD,	INAREG,
	SAREG|STAREG,	TCHAR,
	EAA,	TCHAR,
		NAREG,	RLEFT,
#ifndef cookies
		"\text.w	AL\n\tmove.b	AR,A1\n\text.w	A1\n\tdivs	A1,AL\n	swap	AL\n",
#endif
#ifdef cookies
		"\text.w	AL|cookie 76a\n\tmove.b	AR,A1\n\text.w	A1\n\tdivs	A1,AL\n	swap	AL|cookie 76b\n",
#endif






ASG MOD,	INAREG,
	SAREG|STAREG,	TUCHAR,
	EAA,	TUCHAR|TCHAR,
		NAREG,	RLEFT,
#ifndef cookies
		"\tand.w	#255,AL\n\tclr.w	A1\tmove.b	AR,A1\n\tdivs	A1,AL\n	swap	AL\n",
#endif
#ifdef cookies
		"\tand.w	#255,AL|cookie 77a\n\tclr.w	A1\tmove.b	AR,A1\n\tdivs	A1,AL\n	swap	AL|cookie 77b\n",
#endif






ASG OPSHFT, 	INAREG|FORCC,
	SNAME|SOREG,	TSHORT,
	SONE,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	aOI.w	AL\n",
#endif
#ifdef cookies
		"	aOI.w	AL|cookie 78\n",
#endif






ASG OPSHFT, 	INAREG|FORCC,
	SAREG,	TINT|TSHORT|TCHAR,
	S8CON,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	aOIZB	AR,AL\n",
#endif
#ifdef cookies
		"	aOIZB	AR,AL|cookie 79\n",
#endif






ASG OPSHFT, 	INAREG|FORCC,
	SAREG,	TINT|TSHORT|TCHAR,
	SAREG,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	aOIZB	AR,AL\n",
#endif
#ifdef cookies
		"	aOIZB	AR,AL|cookie 80\n",
#endif






ASG OPSHFT, 	INAREG|FORCC|RESCC,
	EA,	TUSHORT,
	SONE,	TSCALAR,
		0,	RLEFT,
#ifndef cookies
		"	lOI.w	AL\n",
#endif
#ifdef cookies
		"	lOI.w	AL|cookie 81\n",
#endif






ASG OPSHFT, 	INAREG|FORCC,
	SAREG,	TUNSIGNED|TUSHORT|TUCHAR,
	S8CON,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	lOIZB	AR,AL\n",
#endif
#ifdef cookies
		"	lOIZB	AR,AL|cookie 82\n",
#endif






ASG OPSHFT, 	INAREG|FORCC,
	SAREG,	TUNSIGNED|TUSHORT|TUCHAR,
	SAREG,	TSCALAR,
		0,	RLEFT|RESCC,
#ifndef cookies
		"	lOIZB	AR,AL\n",
#endif
#ifdef cookies
		"	lOIZB	AR,AL|cookie 83\n",
#endif






UNARY CALL,	INTAREG,
	SBREG|SNAME|SOREG|SCON,	TANY,
	SANY,	TANY,
		NAREG|NASL,	RESC1, /* should be register 0 */
#ifndef cookies
		"ZC\n",
#endif
#ifdef cookies
		"ZC|cookie 84\n",
#endif






SCONV,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SANY,	TINT|TUNSIGNED|TPOINT,
		0,	RLEFT,
#ifndef cookies
		"",
#endif
#ifdef cookies
		"",
#endif






SCONV,	INTAREG,
	STAREG,	TSCALAR,
	SANY,	TUCHAR,
		0,	RLEFT,
#ifndef cookies
		"	and.l	#255,AL\n",
#endif
#ifdef cookies
		"	and.l	#255,AL|cookie 85\n",
#endif






SCONV,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SANY,	TUSHORT,
		0,	RLEFT,
#ifndef cookies
		"	and.l	#65535,AL\n",
#endif
#ifdef cookies
		"	and.l	#65535,AL|cookie 86\n",
#endif






SCONV,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SANY,	TSHORT|TCHAR,
		0,	RLEFT,
#ifndef cookies
		"",
#endif
#ifdef cookies
		"",
#endif






SCONV,	INTAREG,
	STAREG,	TCHAR,
	SANY,	TSHORT|TUSHORT,
		0,	RLEFT,
#ifndef cookies
		"	ext.w	AL\n",
#endif
#ifdef cookies
		"	ext.w	AL|cookie 87\n",
#endif






SCONV,	INTAREG,
	STAREG,	TCHAR,
	SANY,	TINT|TUNSIGNED|TPOINT,
		0,	RLEFT,
#ifndef cookies
		"	ext.w	AL\n	ext.l	AL\n",
#endif
#ifdef cookies
		"	ext.w	AL|cookie 88a\n	ext.l	AL|cookie 88b\n",
#endif






SCONV,	INTAREG,
	STAREG,	TSHORT,
	SANY,	TINT|TUNSIGNED|TPOINT,
		0,	RLEFT,
#ifndef cookies
		"	ext.l	AL\n",
#endif
#ifdef cookies
		"	ext.l	AL|cookie 89\n",
#endif






SCONV,	INTAREG,
	STAREG,	TUCHAR,
	SANY,	TSCALAR,
		0,	RLEFT,
#ifndef cookies
		"	and.l	#255,AL\n",
#endif
#ifdef cookies
		"	and.l	#255,AL|cookie 90\n",
#endif






SCONV,	INTAREG,
	STAREG,	TUSHORT,
	SANY,	TINT|TUNSIGNED|TPOINT,
		0,	RLEFT,
#ifndef cookies
		"	and.l	#65535,AL\n",
#endif
#ifdef cookies
		"	and.l	#65535,AL|cookie 91\n",
#endif






SCONV,	INAREG|INTAREG,
	EA,	TINT|TUNSIGNED|TPOINT|TSHORT|TUSHORT,
	SANY,	TSHORT|TUSHORT|TCHAR|TUCHAR,
		0,	R