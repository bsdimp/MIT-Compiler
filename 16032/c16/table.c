# include "mfile2"

# define TSCALAR TCHAR|TUCHAR|TSHORT|TUSHORT|TINT|TUNSIGNED|TPOINT
# define EA SNAME|SOREG|SCON|STARREG|SAREG

struct optab  table[] = {

ASSIGN,	INAREG|FOREFF,
	EA,	TSCALAR,
	S8CON,	TSCALAR,
		0,	RRIGHT,
		"	movqZB	AR,AL\n",

ASSIGN,	INAREG|FOREFF,
	EA,	TSCALAR|TFLOAT,
	SCON,	TSCALAR|TFLOAT,
		0,	RRIGHT,
		"	movZB	AR,AL\n",

ASSIGN,	INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	EA,	TSHORT,
		0,	RLEFT|RRIGHT,
		"	movxwd	AR,AL\n",

ASSIGN,	INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	EA,	TUSHORT,
		0,	RLEFT|RRIGHT,
		"	movzwd	AR,AL\n",

ASSIGN,	INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT|TSHORT|TUSHORT,
	EA,	TCHAR,
		0,	RLEFT|RRIGHT,
		"	movxbZB	AR,AL\n",

ASSIGN,	INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT|TSHORT|TUSHORT,
	EA,	TUCHAR,
		0,	RLEFT|RRIGHT,
		"	movzbZB	AR,AL\n",

/* this is the catch all for downward or equal moves */
ASSIGN,	INAREG|FOREFF,
	EA,	TSCALAR|TFLOAT,
	EA,	TSCALAR|TFLOAT,
		0,	RLEFT|RRIGHT,
		"	movZB	AR,AL\n",

ASSIGN,	INAREG|FOREFF,
	EA,	TDOUBLE,
	EA,	TDOUBLE,
		0,	RLEFT|RRIGHT,
		"	movd	AR,AL\n	movd	UR,UL\n",

ASSIGN,	INAREG|FOREFF,
	EA,	TFLOAT,
	EA,	TDOUBLE,
		0,	RLEFT|RRIGHT,
		"	movd	AR,AL\n",

ASSIGN, INAREG|FOREFF,
	SFLD,	TANY,
	SZERO,	TANY,
		0,	RRIGHT,
		"	andd	#N,AL\n",

ASSIGN, INTAREG|INAREG|FOREFF,
	SFLD,	TANY,
	EA,	TANY,
		NAREG,	RRIGHT,
		"	movxbd	#H,A1\n	insd	A1,AR,AL,S\n",

ASSIGN,	INTAREG|INAREG|FOREFF,
	EA,	TANY,
	SFLD,	TANY,
		NAREG,	RLEFT,
		"	movxbd	#H,A1\n	extd	A1,AR,AL,S\n",

FLD,	INTAREG|INAREG|FOREFF,
	EA,	TANY,
	SFLD,	TANY,
		NAREG,	RESC1,
		"	movxbd	#H,A1\n	extd	A1,AR,A1,S\n",

/* put this here so UNARY MUL nodes match OPLTYPE when appropriate */
UNARY MUL,	INTAREG|INAREG,
	SAREG,	TSCALAR,
	SANY,	TANY,
		NAREG|NASR,	RESC1,
		"	movZB	(AL),A1\n",

/* this entry throws away computations which don't do anything */
OPLTYPE,	FOREFF,
	SANY,	TANY,
	EA,	TANY,
		0,	RRIGHT,
		"",

OPLTYPE,	FORCC,
	SANY,	TANY,
	EA,	TSCALAR,
		0,	RESCC,
		"	cmpZB	AR,#0\n",

OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	S8CON,	TSCALAR,
		NAREG|NASR,	RESC1,
		"	movqZB	AR,A1\n",

OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	EA,	TSCALAR,
		NAREG|NASR,	RESC1,
		"	movZB	AR,A1\n",

OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	EA,	TDOUBLE,
		2*NAREG|NASR,	RESC1,
		"	movd	AR,A1\n	movd	UR,A2\n",

OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	EA,	TFLOAT,
		NAREG|NASR,	RESC1,
		"	movd	AR,A1\n",

OPLTYPE,	INTEMP,
	SANY,	TANY,
	EA,	TSCALAR,
		NTEMP,	RESC1,
		"	movZB	AR,A1\n",

OPLTYPE,	INTEMP,
	SANY,	TANY,
	EA,	TDOUBLE,
		2*NTEMP,	RESC1,
		"	movd	AR,A1\n	movd	UR,A2",

OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TINT|TUNSIGNED|TPOINT,
		0,	RNULL,
		"	movd	AR,Z-\n",

OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TSHORT,
		0,	RNULL,
		"	movxwd	AR,Z-\n",

OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TUSHORT,
		0,	RNULL,
		"	movzwd	AR,Z-\n",

OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TCHAR,
		0,	RNULL,
		"	movxbd	AR,Z-\n",

OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TUCHAR,
		0,	RNULL,
		"	movzbd	AR,Z-\n",

OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TFLOAT,
		0,	RNULL,
		"	movqd	#0,Z-\n	movd	AR,Z-\n",

OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TDOUBLE,
		0,	RNULL,
		"	movd	UR,Z-\n	movd	AR,Z-\n",

OPLOG,	INAREG|INTAREG,
	EA,	TSCALAR,
	EA,	TSCALAR,
		NAREG,	RESC1,
		"	cmpZL	AL,AR\n	ZVd	A1\n",

OPLOG,	FORCC,
	EA,	TSCALAR,
	EA,	TSCALAR,
		0,	RESCC,
		"	cmpZL	AL,AR\nZI",

OPLOG,	FORCC,
	EA,	TDOUBLE,
	EA,	TDOUBLE,
		0,	RESCC,
		"	movd	UR,Z-\n	movd	AR,Z-\n	movd	UL,Z-\n	movd	AL,Z-\n	jsr	fcmp\nZ0ZI",

CCODES,	INTAREG|INAREG,
	SANY,	TANY,
	SANY,	TANY,
		NAREG,	RESC1,
		"	movqd	#1,A1\nZN",

UNARY MINUS,	INTAREG|INAREG,
	STAREG,	TSCALAR,
	SANY,	TANY,
		0,	RLEFT,
		"	negZB	AL,AL\n",

COMPL,	INTAREG|INAREG,
	STAREG,	TSCALAR,
	SANY,	TANY,
		0,	RLEFT,
		"	comZB	AL,AL\n",

INCR,	INTAREG|INAREG|FOREFF,
	EA,	TSCALAR,
	S8CON,	TSCALAR,
		NAREG,	RESC1,
		"F	movZB	AL,A1\n	addqZB	AR,AL\n",

DECR,	INTAREG|INAREG|FOREFF,
	EA,	TSCALAR,
	S8CON,	TSCALAR,
		NAREG,	RESC1,
		"F	movZB	AL,A1\n	addqZB	#ZM,AL\n",

INCR,	INTAREG|INAREG|FOREFF,
	EA,	TSCALAR,
	SCON,	TSCALAR,
		NAREG,	RESC1,
		"F	movZB	AL,A1\n	addZB	AR,AL\n",

DECR,	INTAREG|INAREG|FOREFF,
	EA,	TSCALAR,
	SCON,	TSCALAR,
		NAREG,	RESC1,
		"F	movZB	AL,A1\n addZB	#ZM,AL\n",

PLUS,		INAREG|INTAREG,
	SAREG,	TPOINT,
	SCON,	TANY,
		NAREG|NASL,	RESC1,
		"	addr	ZO(AL),A1\n",

PLUS,		FORARG,
	SAREG,	TPOINT,
	SCON,	TANY,
		0,	RNULL,
		"	addr	ZO(AL),Z-\n",

	MINUS,		INAREG|INTAREG,
	SAREG,	TPOINT,
	SRCON,	TANY,
		NAREG|NASL,	RESC1,
		"	addr	ZM(AL),A1\n",

MINUS,		FORARG,
	SAREG,	TPOINT,
	SRCON,	TANY,
		0,	RNULL,
		"	addr	ZM(AL),Z-\n",

ASG PLUS,	INAREG,
	EA,	TSCALAR,
	S8CON,	TSCALAR,
		0,	RLEFT,
		"	addqZB	AR,AL\n",

ASG MINUS,	INAREG,
	EA,	TSCALAR,
	S8CON,	TSCALAR,
		0,	RLEFT,
		"	addqZB	#ZM,AL\n",

/*ASG OPSIMP, 	FORCC,
	EA,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT|RESCC,
		"	OIZB	AR,AL\n	cmpZB	AL,#0\n",*/

ASG OPSIMP, 	INAREG,
	EA,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT,
		"	OIZB	AR,AL\n",

ASG MUL,	INAREG|FOREFF,
	EA,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT,
		"	mulZB	AR,AL\n",

ASG DIV,	INAREG|FOREFF,
	EA,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT,
		"	divZB	AR,AL\n",

ASG MOD,	INAREG|FOREFF,
	EA,	TSCALAR,
	EA,	TSCALAR,
		0,	RLEFT,
		"	modZB	AR,AL\n",

ASG LS, 	INAREG,
	EA,	TPOINT|TINT|TSHORT|TCHAR,
	EA,	TSCALAR,
		0,	RLEFT,
		"	ashZB	AR,AL\n",

/*ASG RS, 	INAREG,
	EA,	TPOINT|TINT|TSHORT|TCHAR,
	SCON,	TSCALAR,
		0,	RLEFT,
		"	ashZB	#ZM,AL\n",*/

/*ASG RS, 	INAREG,
	EA,	TPOINT|TINT|TSHORT|TCHAR,
	EA,	TSCALAR,
		NAREG,	RLEFT,
		"	negd	AR,A1\n	ashZB	A1,AL\n",*/

ASG LS, 	INAREG,
	EA,	TUNSIGNED|TUSHORT|TUCHAR,
	EA,	TSCALAR,
		0,	RLEFT,
		"	lshZB	AR,AL\n",

/*ASG RS, 	INAREG,
	EA,	TUNSIGNED|TUSHORT|TUCHAR,
	SCON,	TSCALAR,
		0,	RLEFT,
		"	lshZB	#ZM,AL\n",*/

/*ASG RS, 	INAREG,
	EA,	TUNSIGNED|TUSHORT|TUCHAR,
	EA,	TSCALAR,
		NAREG,	RLEFT,
		"	negd	AR,A1\n	lshZB	A1,AL\n",*/

UNARY CALL,	INTAREG,
	SAREG|SNAME|SOREG|SCON,	TANY,
	SANY,	TANY,
		NAREG|NASL,	RESC1, /* should be register 0 */
		"ZC\n",

SCONV,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SANY,	TINT|TUNSIGNED|TPOINT,
		0,	RLEFT,
		"",

SCONV,	INTAREG,
	STAREG,	TSCALAR,
	SANY,	TUCHAR,
		0,	RLEFT,
		"	andZB	#255,AL\n",

SCONV,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SANY,	TUSHORT,
		0,	RLEFT,
		"	andZB	#65535,AL\n",

SCONV,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SANY,	TSHORT|TCHAR,
		0,	RLEFT,
		"",

SCONV,	INTAREG,
	EA,	TCHAR,
	SANY,	TSHORT|TUSHORT,
		NAREG|NASL,	RESC1,
		"	movxbw	AL,A1\n",

SCONV,	INTAREG,
	EA,	TUCHAR,
	SANY,	TSHORT|TUSHORT,
		NAREG|NASL,	RESC1,
		"	movzbw	AL,A1\n",

SCONV,	INTAREG,
	EA,	TCHAR,
	SANY,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASL,	RESC1,
		"	movxbd	AL,A1\n",

SCONV,	INTAREG,
	EA,	TUCHAR,
	SANY,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASL,	RESC1,
		"	movzbd	AL,A1\n",

SCONV,	INTAREG,
	EA,	TSHORT,
	SANY,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASL,	RESC1,
		"	movxwd	AL,A1\n",

SCONV,	INTAREG,
	EA,	TUSHORT,
	SANY,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASL,	RESC1,
		"	movzwd	AL,A1\n",


SCONV,	INAREG|INTAREG,
	EA,	TINT|TUNSIGNED|TPOINT|TSHORT|TUSHORT,
	SANY,	TSHORT|TUSHORT|TCHAR|TUCHAR,
		0,	RLEFT,
		"",

SCONV,	INAREG|INTAREG,
	EA,	TDOUBLE,
	SANY,	TFLOAT,
		0,	RLEFT,
		"",

SCONV,	INAREG|INTAREG,
	EA,	TFLOAT,
	SANY,	TDOUBLE,
		2*NAREG|NASR,	RESC1,
		"	movd	AL,A1\n	movd	#0,A2\n",

STASG,	FOREFF,
	SNAME|SOREG,	TANY,
	SCON|SOREG|SAREG,	TANY,
		0,	RNOP,
		"ZS",

STASG,	INTAREG|INAREG,
	SNAME|SOREG,	TANY,
	STAREG,	TANY,
		0,	RRIGHT,
		"ZS",

STASG, INAREG|INTAREG,
	SNAME|SOREG,	TANY,
	SCON|SAREG,	TANY,
		NAREG,	RESC1,
		"ZS	movd	AR,A1\n",

INIT,	FOREFF,
	SCON,	TANY,
	SANY,	TINT|TUNSIGNED|TPOINT,
		0,	RNOP,
		"	.long	CL\n",

INIT,	FOREFF,
	SCON,	TANY,
	SANY,	TSHORT|TUSHORT,
		0,	RNOP,
		"	.word	CL\n",

INIT,	FOREFF,
	SCON,	TANY,
	SANY,	TCHAR|TUCHAR,
		0,	RNOP,
		"	.byte	CL\n",

	/* Default actions for hard trees ... */

# define DF(x) FORREW,SANY,TANY,SANY,TANY,REWRITE,x,""

UNARY MUL, DF( UNARY MUL ),

INCR, DF(INCR),

DECR, DF(INCR),

ASSIGN, DF(ASSIGN),

STASG, DF(STASG),

OPLEAF, DF(NAME),

OPLOG,	FORCC,
	SANY,	TANY,
	SANY,	TANY,
		REWRITE,	BITYPE,
		"",

OPLOG,	DF(NOT),

COMOP, DF(COMOP),

INIT, DF(INIT),

OPUNARY, DF(UNARY MINUS),


ASG OPANY, DF(ASG PLUS),

OPANY, DF(BITYPE),

FREE,	FREE,	FREE,	FREE,	FREE,	FREE,	FREE,	FREE,	"help; I'm in trouble\n" };
