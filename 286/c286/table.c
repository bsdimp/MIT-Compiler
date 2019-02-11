# include "mfile2"

# define EA	SNAME|SOREG|SCON|SAREG|SBREG
# define EREG	SAREG|SBREG
# define FEA	SNAME|SOREG|SCON

struct optab  table[] = {

ASSIGN, INAREG|FOREFF,
	EA,	TCHAR|TUCHAR,
	EREG,	TINT|TPOINT|TUNSIGNED,
		0,	RLEFT,
		"	mov	cx,AR\n	movb	AL,cx\n",

ASSIGN,	INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TCHAR|TUCHAR,
	EREG|SCON,	TINT|TUNSIGNED|TCHAR|TUCHAR,
		0,	RRIGHT,
		"	movZB	AL,AR\n",

ASSIGN,	INAREG|FOREFF,
	EREG,	TINT|TUNSIGNED,
	EA,	TINT|TUNSIGNED,
		0,	RLEFT,
		"	mov	AL,AR\n",

ASSIGN,	INAREG|FOREFF,
	EREG,	TCHAR|TUCHAR,
	EA,	TCHAR|TUCHAR,
		0,	RLEFT,
		"	movb	AL,AR\n",

ASSIGN,	FOREFF,
	EA,	TCHAR|TUCHAR,
	EA,	TCHAR|TUCHAR,
		NAREG|NASR,	RNULL,
		"	movb	A1,AR\n	movb	AL,A1\n",

ASSIGN, INAREG|FOREFF,
	EA,	TPOINT|TLONG|TULONG,
	SCON,	TPOINT|TLONG|TULONG|TINT,
		0,	RRIGHT,
		"	mov	AL,AR\n	mov	UL,UR\n",

ASSIGN,	INAREG|FOREFF,
	EA,	TPOINT|TLONG|TULONG,
	EREG,	TPOINT|TLONG|TULONG,
		0,	RRIGHT,
		"	mov	AL,AR\n	mov	UL,UR\n",

ASSIGN,	INAREG|FOREFF,
	EREG,	TPOINT|TLONG|TULONG,
	EA,	TPOINT|TLONG|TULONG,
		0,	RLEFT,
		"	mov	AL,AR\n	mov	UL,UR\n",

ASSIGN,	FOREFF,
	FEA,	TDOUBLE|TFLOAT,
	SOREG,	TDOUBLE|TFLOAT,
		0,	RLEFT,
		"Zq	fldd	AR\n	fstpZl	AL\n",

ASSIGN,	FOREFF,
	FEA,	TDOUBLE|TFLOAT,
	FEA,	TDOUBLE|TFLOAT,
		0,	RLEFT,
		"Zq	fldZr	AR\n	fstpZl	AL\n",

ASSIGN,	INTEMP,
	FEA,	TDOUBLE|TFLOAT,
	FEA,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
		"Zq	fldZr	AR\n	fstZl	AL\n	fstpd	A1\n",

ASSIGN, INAREG|FOREFF,
	SFLD,	TANY,
	SZERO,	TANY,
		0,	RRIGHT,
		"	and	AL,#~M\n",

ASSIGN, INTAREG|INAREG|FOREFF,
	SFLD,	TANY,
	STAREG,	TANY,
		0,	RRIGHT,
"F\tpush\tAR\n\tmov\tcl,*H\n\tshl\tAR,cl\n\tand\tAR,#M\n\tand\tAL,#~M\n\tor\tAL,AR\nF\tpop\tAR\n",

ASSIGN, INAREG|FOREFF,
	SFLD,	TANY,
	EA,	TANY,
		NAREG,	RRIGHT,
"\tmov\tA1,AR\n\tmov\tcl,*H\n\tshl\tA1,cl\n\tand\tA1,#M\n\tand\tAL,#~M\n\tor\tAL,A1\n",

/* put this here so UNARY MUL nodes match OPLTYPE when appropriate */
OPLTYPE,	FOREFF,
	SANY,	TANY,
	EA,	TANY,
		0,	RRIGHT,
		"",   /* this entry throws away computations which don't do anything */

OPLTYPE,	INAREG,
	SANY,	TANY,
	SAREG,	TANY,
		0,	RRIGHT,
		"",

OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	EA,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASR,	RESC1,
		"	mov	A1,AR\n",

OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	EA,	TLONG|TULONG,
		NAREG|NASR,	RESC1,
		"	mov	A1,AR\n	mov	U1,UR\n",

OPLTYPE,	INTBREG|INBREG,
	SANY,	TANY,
	EA,	TPOINT,
		NBREG|NBSR,	RESC1,
		"	lU1	A1,AR\n",		/*zzcode for breg's */

OPLTYPE,	INTBREG|INBREG,
	SANY,	TANY,
	EA,	TINT|TUNSIGNED,
		NBREG|NBSR,	RESC1,
		"	mov	A1,AR\n",

OPLTYPE,	INTEMP,
	SANY,	TANY,
	EREG,	TINT|TUNSIGNED|TPOINT,
		2*NTEMP,	RESC1,
		"	mov	A1,AR\n",

OPLTYPE,	INTEMP,
	SANY,	TANY,
	EREG,	TLONG|TULONG,
		2*NTEMP,	RESC1,
		"	mov	A1,AR\n	mov	U1,UR\n",

OPLTYPE,	FORCC,
	SANY,	TANY,
	EREG,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		0,	RESCC,
		"	orZB	AR,AR\n",

				/* will produce bad TLONG compares */
OPLTYPE,	FORCC,
	SANY,	TANY,
	EREG,	TULONG,
		0,	RESCC,
		"	or	UR,UR\n	jne	.+4\n	or	AR,AR\n",

OPLTYPE,	FORCC,
	SANY,	TANY,
	SNAME|SOREG|SAREG|SBREG,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		0,	RESCC,
		"	cmpZB	AR,*0\n",

OPLTYPE,	FORCC,		/* only good for eq/neq comparisons... */
	SANY,	TANY,
	SNAME|SOREG|SAREG|SBREG,	TLONG|TULONG,
		0,	RESCC,
		"	cmp	UR,*0\n	jne Zx\n	cmp	AR,*0\nZz",

OPLTYPE,	FORCC,
	SANY,	TANY,
	SCON,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		NAREG|NASR,	RESCC,
		"	mov	A1,AR\n	or	A1,A1\n",

OPLTYPE,	FORARG,
	SANY,	TANY,
	EA,	TINT|TUNSIGNED|TPOINT,
		0,	RNULL,
		"	push	AR\nZ-",

OPLTYPE,	FORARG,
	SANY,	TANY,
	SNAME|SOREG|SAREG|SBREG,	TLONG|TULONG,
		0,	RNULL,
		"	push	UR\nZ-	push	AR\nZ-",

OPLTYPE,	FORARG,
	SANY,	TANY,
	FEA,	TDOUBLE|TFLOAT,
		NBREG|NBSR,	RNULL,
"Zq	fldZB	AR\n	sub	sp,*8\n	mov	A1,sp\nZq	fstpd	(A1)\nZ4",

OPLTYPE,	INTEMP,
	SANY,	TANY,
	FEA,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
		"Zq	fldZB	AR\n	fstpd	A1\n",

OPLTYPE,	INTAREG,
	SANY,	TANY,
	FEA,	TDOUBLE|TFLOAT,
		NAREG,	RESC1,
		"Zq	fldZB	AL\n",

OPLTYPE,	INTEMP,
	SANY,	TANY,
	STAREG,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
		"Zq	fstpd	A1\n",

OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	SCCON,	TANY,
		NAREG|NASR,	RESC1,
		"	mov	A1,AR\n",

OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	EA,	TCHAR,
		NAREG|NASR,	RESC1,
		"	movb	A1,AR\nZe",

OPLTYPE,	INTAREG|INAREG,
	SANY,	TANY,
	EA,	TUCHAR,
		NAREG|NASR,	RESC1,
		"	movb	A1,AR\n	and	A1,#255\n",

OPLOG,	FORCC,
	EREG,	TPOINT|TINT|TUNSIGNED,
	EA,	TPOINT|TINT|TUNSIGNED,
		0,	RESCC,
		"	cmp	AL,AR\nZI",

OPLOG,	FORCC,
	EA,	TPOINT|TINT|TUNSIGNED,
	EREG|SCON,	TPOINT|TINT|TUNSIGNED,
		0,	RESCC,
		"	cmp	AL,AR\nZI",

OPLOG,	FORCC,
	EREG,	TCHAR|TUCHAR,
	EA,	TCHAR|TUCHAR,
		0,	RESCC,
		"	cmpb	AL,AR\nZI",

OPLOG,	FORCC,
	EA,	TCHAR|TUCHAR,
	EREG,	TCHAR|TUCHAR,
		0,	RESCC,
		"	cmpb	AL,AR\nZI",

OPLOG,	FORCC,
	EA,	TCHAR|TUCHAR,
	SCCON,	TINT,
		0,	RESCC,
		"	cmpb	AL,AR\nZI",

OPLOG,	FORCC,
	EREG,	TLONG|TULONG,
	EA,	TLONG|TULONG,
		0,	RESCC,
		"ZCZI",

OPLOG,	FORCC,
	EA,	TLONG|TULONG,
	EREG|SCON,	TLONG|TULONG,
		0,	RESCC,
		"ZCZI",

OPLOG,	FORCC,
	FEA,	TDOUBLE|TFLOAT,
	FEA,	TDOUBLE|TFLOAT,
		NTEMP,	RESCC,
"Zq\tfldZl\tAL\n\tfcompZr\tAR\n\tfstsw\tA1\n\tfwait\n\txchg\tah,Z1\n\tsahf\n\txchg\tah,Z1\nZF",

CCODES,	INTAREG|INAREG,
	SANY,	TANY,
	SANY,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		NAREG,	RESC1,
		"	mov	A1,*1\nZN",

CCODES,	INTAREG|INAREG,
	SANY,	TANY,
	SANY,	TLONG|TULONG,
		NAREG,	RESC1,
		"	mov	A1,*1\n	mov	U1,*0\nZN",

UNARY MINUS,	INTAREG|INAREG,
	STAREG,	TINT|TUNSIGNED,
	SANY,	TANY,
		0,	RLEFT,
		"	neg	AL\n",

UNARY MINUS,	INTAREG|INAREG,
	STAREG,	TLONG|TULONG,
	SANY,	TANY,
		0,	RLEFT,
		"	neg	UL\n	neg	AL\n	sbb	UL,*0\n",

UNARY MINUS,	INTEMP,
	FEA,	TDOUBLE|TFLOAT,
	SANY,	TANY,
		4*NTEMP,	RESC1,
		"Zq	fldZl	AL\n	fchs\n	fstpd	A1\n",

COMPL,	INTAREG|INAREG,
	STAREG,	TINT|TUNSIGNED,
	SANY,	TANY,
		0,	RLEFT,
		"	not	AL\n",

COMPL,	INTAREG|INAREG,
	STAREG,	TLONG|TULONG,
	SANY,	TANY,
		0,	RLEFT,
		"	not	AL\n	not	UL\n",

INCR,	FOREFF,
	EA,	TCHAR|TUCHAR,
	SONE,	TANY,
		0,	RESC1,
		"	incb	AL\n",

DECR,	FOREFF,
	EA,	TCHAR|TUCHAR,
	SONE,	TANY,
		0,	RESC1,
		"	decb	AL\n",

INCR,	INTAREG|INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	SONE,	TANY,
		NAREG,	RESC1,
		"F	mov	A1,AL\n	inc	AL\n",

DECR,	INTAREG|INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	SONE,	TANY,
		NAREG,	RESC1,
		"F	mov	A1,AL\n	dec	AL\n",

INCR,	INTAREG|INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	SCON,	TANY,
		NAREG,	RESC1,
		"F	mov	A1,AL\n	add	AL,AR\n",

DECR,	INTAREG|INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	SCON,	TANY,
		NAREG,	RESC1,
		"F	mov	A1,AL\n	sub	AL,AR\n",

INCR,	INTBREG|INBREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	SONE,	TANY,
		NBREG,	RESC1,
		"F	mov	A1,AL\n	inc	AL\n",

DECR,	INTBREG|INBREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	SONE,	TANY,
		NBREG,	RESC1,
		"F	mov	A1,AL\n	dec	AL\n",

INCR,	INTBREG|INBREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	SCON,	TANY,
		NBREG,	RESC1,
		"F	mov	A1,AL\n	add	AL,AR\n",

DECR,	INTBREG|INBREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT,
	SCON,	TANY,
		NBREG,	RESC1,
		"F	mov	A1,AL\n	sub	AL,AR\n",

INCR,	INTAREG|INAREG|FOREFF,
	EA,	TLONG|TULONG,
	SCON,	TANY,
		NAREG,	RESC1,
"F	mov	A1,AL\nF	mov	U1,UL\n	add	AL,AR\n	adc	UL,UR\n",

DECR,	INTAREG|INAREG|FOREFF,
	EA,	TLONG|TULONG,
	SCON,	TANY,
		NAREG,	RESC1,
		"F	mov	A1,AL\nF	mov	U1,UL\n	sub	AL,AR\n	sbb	UL,UR\n",

AND,	FORCC,
	EA,	TINT|TUNSIGNED|TPOINT,
	SCON,	TANY,
		0,	RESCC,
		"	test	AL,AR\n",

AND,	FORCC,
	EREG,	TINT|TUNSIGNED|TPOINT,
	EA,	TANY,
		0,	RESCC,
		"	test	AL,AR\n",

ASG MUL,	INTAREG,
	STAREG,	TINT|TCHAR,
	EA,	TINT|TCHAR,
		NAREG|NASR,	RLEFT,
		"	imulZB	AR\n",

ASG DIV,	INTAREG,
	STAREG,	TINT,
	SCON,	TINT,
		NAREG,	RLEFT,
		"ZV	mov	cx,AR\n	idiv	cx\n",  /* since lhs must be in r1 */

ASG DIV,	INTAREG,
	STAREG,	TINT,
	SOREG|SNAME|SAREG|SBREG,	TINT,
		NAREG,	RLEFT,
		"ZV	idiv	AR\n",  /* since lhs must be in r1 */

ASG MOD,	INTAREG,
	STAREG,	TINT,
	SCON,	TINT,
		NAREG,	RESC1,
		"ZV	mov	cx,AR\n	idiv	cx\n",  /* since lhs must be in r1 */

ASG MOD,	INTAREG,
	STAREG,	TINT,
	SOREG|SNAME|SAREG|SBREG,	TINT,
		NAREG,	RESC1,
		"ZV	idiv	AR\n",  /* since lhs must be in r1 */

ASG MUL,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	EA,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASL,	RLEFT,
		"	mul	AR\n",

ASG DIV,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SCON,	TINT|TUNSIGNED|TPOINT,
		NAREG,	RLEFT,
		"ZV	mov	cx,AR\n	div	cx\n",  /* since lhs must be in r1 */

ASG DIV,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SOREG|SNAME|SAREG|SBREG,	TINT|TUNSIGNED|TPOINT,
		NAREG,	RLEFT,
		"ZV	div	AR\n",  /* since lhs must be in r1 */

ASG MOD,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SCON,	TINT|TUNSIGNED|TPOINT,
		NAREG,	RESC1,
		"ZV	mov	cx,AR\n	div	cx\n",  /* since lhs must be in r1 */

ASG MOD,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT,
	SOREG|SNAME|SAREG|SBREG,	TINT|TUNSIGNED|TPOINT,
		NAREG,	RESC1,
		"ZV	div	AR\n",  /* since lhs must be in r1 */

MINUS,		INTAREG,
	SBREG,	TPOINT,
	SXCON,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASL,	RESC1,
		"	lea	A1,ZM(AL)\n\tmov\tU1,ss\n",
		
MINUS,		INTBREG,
	SBREG,	TPOINT,
	SXCON,	TINT|TUNSIGNED|TPOINT,
		NBREG|NBSL,	RESC1,
		"	lea	A1,ZM(AL)\n\tmov\tU1,ss\n",

PLUS,		INTAREG,
	SBREG,	TPOINT,
	SCON,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASL,	RESC1,
		"	lea	A1,Zc(AL)\n\tmov\tU1,ss\n",
		
PLUS,		INTBREG,
	SBREG,	TPOINT,
	SCON,	TINT|TUNSIGNED|TPOINT,
		NBREG|NBSL,	RESC1,
		"	lea	A1,Zc(AL)\n\tmov\tU1,ss\n",

MINUS,		INTAREG,
	SBREG,	TINT|TUNSIGNED,
	SXCON,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASL,	RESC1,
		"	lea	A1,ZM(AL)\n",
		
MINUS,		INTBREG,
	SBREG,	TINT|TUNSIGNED,
	SXCON,	TINT|TUNSIGNED|TPOINT,
		NBREG|NBSL,	RESC1,
		"	lea	A1,ZM(AL)\n",

PLUS,		INTAREG,
	SBREG,	TINT|TUNSIGNED,
	SCON,	TINT|TUNSIGNED|TPOINT,
		NAREG|NASL,	RESC1,
		"	lea	A1,Zc(AL)\n",
		
PLUS,		INTBREG,
	SBREG,	TINT|TUNSIGNED,
	SCON,	TINT|TUNSIGNED|TPOINT,
		NBREG|NBSL,	RESC1,
		"	lea	A1,Zc(AL)\n",

	/* next 4 entries prevent byte ops on SI or DI */

ASG OPSIMP,	INAREG,
	EREG,	TPOINT|TINT|TUNSIGNED,
	FEA,	TCHAR,
		0,	RLEFT|RESCC,
		"	movb	ax,AR\n	cbw\n	OI	AL,ax\n",

ASG OPSIMP,	INAREG,
	EREG,	TPOINT|TINT|TUNSIGNED,
	FEA,	TUCHAR,
		0,	RLEFT|RESCC,
		"	movb	ax,AR\n	xorb	ah,ah\n	OI	AL,ax\n",

ASG OPSIMP,	INAREG|FOREFF,
	EA,	TCHAR|TUCHAR,
	EREG,	TINT|TPOINT|TUNSIGNED,
		0,	RLEFT|RESCC,
		"	mov	cx,AR\n	OIb	AL,cx\n",

ASG PLUS,	INAREG,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	SONE,	TINT,
		0,	RLEFT|RESCC,
		"	incZB	AL\n",

ASG MINUS,	INAREG,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	SONE,	TINT,
		0,	RLEFT|RESCC,
		"	decZB	AL\n",

ASG PLUS,	INAREG,
	EA,	TLONG|TULONG,
	SONE,	TINT,
		0,	RLEFT|RESCC,
		"	add	AL,*1\n	adc	UL,*0\n",

ASG MINUS,	INAREG,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	SONE,	TINT,
		0,	RLEFT|RESCC,
		"	sub	AL,*1\n	sbb	UL,*0\n",

ASG OPSIMP,	INAREG|FORCC,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	EREG|SCON,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		0,	RLEFT|RESCC,
		"	OIZB	AL,AR\n",

ASG OPSIMP,	INAREG|FORCC,
	EREG,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		0,	RLEFT|RESCC,
		"	OIZB	AL,AR\n",

ASG OPSIMP,	INTAREG|FORCC,
	STAREG,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		0,	RLEFT|RESCC,
		"	OIZB	AL,AR\n",

ASG OPSIMP,	INTAREG|FORCC,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	EREG|SCON,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		NAREG|NASR,	RESC1|RESCC,
		"	OIZB	AL,AR\n	mov	A1,AL\n",

ASG OPSIMP,	INTAREG|FORCC,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	EREG|SCON,	TLONG|TULONG,
		NAREG|NASR,	RESC1|RESCC,
		"	OIZB	AL,AR\nF	mov	A1,AL\n",

ASG PLUS,	INAREG,
	EA,	TLONG|TULONG,
	EREG|SCON,	TLONG|TULONG,
		0,	RLEFT,
		"	add	AL,AR\n	adc	UL,UR\n",

ASG PLUS,	INAREG,
	EREG,	TLONG|TULONG,
	EA,	TLONG|TULONG,
		0,	RLEFT,
		"	add	AL,AR\n	adc	UL,UR\n",

ASG PLUS,	INTAREG,
	STAREG,	TLONG|TULONG,
	EA,	TLONG|TULONG,
		0,	RLEFT,
		"	add	AL,AR\n	adc	UL,UR\n",

ASG MINUS,	INAREG,
	EA,	TLONG|TULONG,
	EREG|SCON,	TLONG|TULONG,
		0,	RLEFT,
		"	sub	AL,AR\n	sbb	UL,UR\n",

ASG MINUS,	INAREG,
	EREG,	TLONG|TULONG,
	EA,	TLONG|TULONG,
		0,	RLEFT,
		"	sub	AL,AR\n	sbb	UL,UR\n",

ASG MINUS,	INTAREG,
	STAREG,	TLONG|TULONG,
	EA,	TLONG|TULONG,
		0,	RLEFT,
		"	sub	AL,AR\n	sbb	UL,UR\n",

ASG OPSIMP,	INAREG,
	EA,	TLONG|TULONG,
	EREG|SCON,	TLONG|TULONG,
		0,	RLEFT,
		"	OI	AL,AR\n	OI	UL,UR\n",

ASG OPSIMP,	INAREG,
	EREG,	TLONG|TULONG,
	EA,	TLONG|TULONG,
		0,	RLEFT,
		"	OI	AL,AR\n	OI	UL,UR\n",

ASG OPSIMP,	INTAREG,
	STAREG,	TLONG|TULONG,
	EA,	TLONG|TULONG,
		0,	RLEFT,
		"	OI	AL,AR\n	OI	UL,UR\n",

OPFLOAT,	INTEMP,
	FEA,	TDOUBLE|TFLOAT,
	FEA,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
		"Zq	fldZl	AL\n	ZOZr	AR\n	fstpd	A1\n",

ASG OPFLOAT,	FOREFF|INAREG,
	FEA,	TDOUBLE|TFLOAT,
	FEA,	TDOUBLE|TFLOAT,
		0,	RLEFT,
		"Zq	fldZl	AL\n	ZOZr	AR\n	fstpZl	AL\n",

LS, 	INTBREG,
	STBREG,	TINT|TUNSIGNED|TPOINT,
	SCON,	TINT,
		0,	RLEFT,
		"	sal	AL,AR\n",

LS, 	INTAREG|INAREG,
	EA,	TINT|TUNSIGNED|TPOINT,
	SCON,	TINT,
		NAREG|NASL,	RESC1,
		"	mov	A1,AL\n	sal	A1,AR\n",

LS, 	INTBREG,
	EA,	TINT|TUNSIGNED|TPOINT,
	SCON,	TINT,
		NBREG|NBSL,	RESC1,
		"	mov	A1,AL\n	sal	A1,AR\n",

ASG LS, 	FOREFF|INAREG,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	SCON,	TINT,
		0,	RLEFT,
		"	salZB	AL,AR\n",

ASG LS, 	INAREG|FOREFF,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	EA,	TINT,
		0,	RLEFT,
		"	mov	cx,AR\n	salZB	AL,cl\n",

ASG LS, 	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	SCON,	TINT,
		0,	RLEFT,
		"	salZB	AL,AR\n",

ASG LS, 	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	EA,	TINT,
		0,	RLEFT,
		"	mov	cx,AR\n	salZB	AL,cl\n",

ASG LS,		INAREG|FOREFF,
	EA,	TLONG|TULONG,
	SONE,	TINT,
		0,	RLEFT,
		"	shl	AL,*1\n	rcl	UL,*1\n",

ASG LS,		INAREG|FOREFF,
	EA,	TLONG|TULONG,
	EA,	TINT,
		0,	RLEFT,
"\tmov\tcx,AR\n\tor\tcx,cx\n\tjz\tZY\nZX\tshl\tAL,*1\n\trcl\tUL,*1\n\tloop\tZy\nZs",

ASG LS,		INTAREG|FOREFF,
	STAREG,	TLONG|TULONG,
	EA,	TINT,
		0,	RLEFT,
"\tmov\tcx,AR\n\tor\tcx,cx\n\tjz\tZY\nZX\tshl\tAL,*1\n\trcl\tUL,*1\n\tloop\tZy\nZs",

ASG RS, 	INAREG|FOREFF,
	EA,	TINT|TCHAR,
	SCON,	TINT,
		0,	RLEFT,
		"	sarZB	AL,AR\n",

ASG RS, 	INAREG|FOREFF,
	EA,	TINT|TCHAR,
	EA,	TINT,
		0,	RLEFT,
		"	mov	cx,AR\n	sarZB	AL,cl\n",

ASG RS, 	INAREG|FOREFF,
	EA,	TUNSIGNED|TPOINT|TUCHAR,
	SCON,	TINT,
		0,	RLEFT,
		"	shrZB	AL,AR\n",

ASG RS, 	INAREG|FOREFF,
	EA,	TUNSIGNED|TPOINT|TUCHAR,
	EA,	TINT,
		0,	RLEFT,
		"	mov	cx,AR\n	shrZB	AL,cl\n",

ASG RS, 	INTAREG,
	STAREG,	TINT|TCHAR,
	SCON,	TINT,
		0,	RLEFT,
		"	sarZB	AL,AR\n",

ASG RS, 	INTAREG,
	STAREG,	TINT|TCHAR,
	EA,	TINT,
		0,	RLEFT,
		"	mov	cx,AR\n	sarZB	AL,cl\n",

ASG RS, 	INTAREG,
	STAREG,	TUNSIGNED|TPOINT|TUCHAR,
	SCON,	TINT,
		0,	RLEFT,
		"	shrZB	AL,AR\n",

ASG RS, 	INTAREG,
	STAREG,	TUNSIGNED|TPOINT|TUCHAR,
	EA,	TINT,
		0,	RLEFT,
		"	mov	cx,AR\n	shrZB	AL,cl\n",

ASG RS,		INAREG|FOREFF,
	EA,	TULONG,
	SONE,	TINT,
		0,	RLEFT,
		"	sar	UL,*1\n	rcr	AL,*1\n",

ASG RS,		INAREG|FOREFF,
	EA,	TULONG,
	EA,	TINT,
		0,	RLEFT,
"\tmov\tcx,AR\n\tor\tcx,cx\n\tjz\tZY\nZX\tsar\tUL,*1\n\trcr\tAL,*1\n\tloop\tZy\nZs",

ASG RS,		INTAREG|FOREFF,
	STAREG,	TULONG,
	EA,	TINT,
		0,	RLEFT,
"\tmov\tcx,AR\nor\tcx,cx\n\tjz\tZY\nZX\tsar\tUL,*1\n\trcr\tAL,*1\n\tloop\tZy\nZs",

ASG RS,		INAREG|FOREFF,
	EA,	TLONG,
	SONE,	TINT,
		0,	RLEFT,
		"	sar	UL,*1\n	rcr	AL,*1\n",

ASG RS,		INAREG|FOREFF,
	EA,	TLONG,
	EA,	TINT,
		0,	RLEFT,
"\tmov\tcx,AR\n\tor\tcx,cx\n\tjz\tZY\nZX\tsar\tUL,*1\n\trcr\tAL,*1\n\tloop\tZy\nZs",

UNARY CALL,	INTAREG,
	SCON,	TANY,
	SANY,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR|TLONG|TULONG,
		NAREG|NASL,	RESC1, /* should be register 0 */
		"	call	Zd\n",

UNARY CALL,	INTAREG,
	SAREG|SNAME|SOREG,	TANY,
	SANY,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR|TLONG|TULONG,
		NAREG|NASL,	RESC1, /* should be register 0 */
		"	call	@AL\n",

UNARY CALL,	INTEMP,
	SCON,	TANY,
	SANY,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
		"	call	Zd\nZq	fstpd	A1\n",

UNARY CALL,	INTEMP,
	SAREG|SNAME|SOREG,	TANY,
	SANY,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
		"	call	@AL\nZq	fstpd	A1\n",

SCONV,	INTAREG,
	STAREG,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	SANY,	TUCHAR,
		0,	RLEFT,
		"	and	AL,#255\n",

SCONV,	INTAREG,
	EA,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
	SANY,	TCHAR,
		NAREG|NASL,	RESC1,
		"	mov	A1,AL\nZe",

SCONV,	INAREG,
	EA,	TLONG|TULONG,
	SANY,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		0,	RLEFT,
		"ZT",

SCONV,	INTAREG,
	STAREG,	TLONG|TULONG,
	SANY,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		0,	RLEFT,
		"ZT",

SCONV,	INTBREG,
	EA,	TLONG|TULONG,
	SANY,	TINT|TUNSIGNED|TPOINT,
		NBREG|NBSL,	RESC1,
		"	mov	A1,AL\n",

SCONV,	INTAREG,
	EA,	TUCHAR,
	SANY,	TLONG|TULONG,
		NAREG|NASL,	RESC1,
	"	movb	A1,AL\n	and	A1,#255\n	mov	U1,*0\n",

SCONV,	INTAREG,
	EA,	TCHAR,
	SANY,	TLONG|TULONG,
		NAREG|NASL,	RESC1,
		"	mov	A1,AL\nZe",

SCONV,	INTAREG,
	EA,	TINT,
	SANY,	TLONG|TULONG,
		NAREG|NASL,	RESC1,
		"	mov	A1,AL\nZE",

SCONV,	INTAREG,
	EA,	TUNSIGNED|TPOINT,
	SANY,	TLONG|TULONG,
		NAREG|NASL,	RESC1,
		"	mov	A1,AL\n	mov	U1,*0\n",

SCONV,	INTAREG,
	STAREG, TINT|TUNSIGNED|TPOINT,
	SANY,	TINT|TUNSIGNED|TPOINT,
		0,	RLEFT,
		"",

SCONV,	INTBREG,
	STAREG, TINT|TUNSIGNED|TPOINT,
	SANY,	TINT|TUNSIGNED|TPOINT,
		NBREG|NBSL,	RESC1,
		"	mov	A1,AL\n",

SCONV,	INTAREG,
	STAREG, TCHAR|TUCHAR,
	SANY,	TCHAR|TUCHAR,
		0,	RLEFT,
		"",

SCONV,	INTAREG,
	STAREG, TLONG|TULONG,
	SANY,	TLONG|TULONG,
		0,	RLEFT,
		"",

SCONV,	INAREG|INTEMP,
	FEA,	TDOUBLE|TFLOAT,
	SANY,	TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		NTEMP,	RESC1,
		"Zq	fldZl	AL\n	fstpi	A1\n	fwait\n",

SCONV,	INAREG|INTEMP,
	FEA,	TDOUBLE|TFLOAT,
	SANY,	TLONG|TULONG|TINT|TUNSIGNED|TPOINT|TCHAR|TUCHAR,
		2*NTEMP,	RESC1,
		"Zq	fldZl	AL\n	fstpl	A1\n	fwait\n",

SCONV,	INTEMP,
	FEA,	TLONG|TULONG,
	SANY,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
		"Zq	fldl	AL\n	fstpd	A1\n",

SCONV,	INTEMP,
	EREG,	TLONG|TULONG,
	SANY,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
"	mov	A1,AL\n	mov	U1,UL\nZq	fldl	A1\n	fstpd	A1\n",

SCONV,	INTEMP,
	FEA,	TINT|TUNSIGNED,
	SANY,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
		"Zq	fldi	AL\n	fstpd	A1\n",

SCONV,	INTEMP,
	EREG,	TINT|TUNSIGNED,
	SANY,	TDOUBLE|TFLOAT,
		4*NTEMP,	RESC1,
		"	mov	A1,AL\nZq	fldi	A1\n	fstpd	A1\n",

PCONV,	INTAREG,
	EA,	TUCHAR,
	SANY,	TPOINT,
		NAREG|NASL,	RESC1,
		"	movb	A1,AL\n	and	A1,#255\n",

PCONV,	INTAREG,
	EA,	TCHAR,
	SANY,	TPOINT,
		NAREG|NASL,	RESC1,
		"	mov	A1,AL\nZe",

PCONV,	INAREG,
	EA,	TLONG|TULONG,
	SANY,	TPOINT,
		0,	RLEFT,
		"ZT",

STASG,	FOREFF,
	EA,	TANY,
	EA,	TANY,
		0,	RNOP,
		"ZS",

/*****

STASG,	FOREFF,
	SNAME|SOREG,	TANY,
	SCON|SAREG|SBREG,	TANY,
		0,	RNOP,
		"ZS",

STASG,	INTAREG|INAREG,
	SNAME|SOREG,	TANY,
	STAREG|STBREG,	TANY,
		0,	RRIGHT,
		"ZS",

STASG, INAREG|INTAREG,
	SNAME|SOREG,	TANY,
	SCON|SAREG|SBREG,	TANY,
		NAREG|NASR,	RESC1,
		"ZS	mov	A1,AR\n",
******/

INIT,	FOREFF,
	SCON,	TANY,
	SANY,	TINT|TUNSIGNED|TPOINT,
		0,	RNOP,
		"	.word	ZL\n",

INIT,	FOREFF,
	SCON,	TANY,
	SANY,	TLONG|TULONG,
		0,	RNOP,
		"	.long	ZL\n",

INIT,	FOREFF,
	SCON,	TANY,
	SANY,	TCHAR|TUCHAR,
		0,	RNOP,
		"	.byte	ZL\n",

	/* for the use of fortran only */
#ifdef	FORT
GOTO,	FOREFF,
	SCON,	TANY,
	SANY,	TANY,
		0,	RNOP,
		"	jbr	CL\n",

GOTO,	FOREFF,
	SNAME,	TLONG|TULONG,
	SANY,	TANY,
		0,	RNOP,
		"	jmp	*UL\n",

GOTO,	FOREFF,
	SNAME,	TINT|TUNSIGNED|TCHAR|TUCHAR|TPOINT,
	SANY,	TANY,
		0,	RNOP,
		"	jmp	*AL\n",
#endif
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
