#include "mical.h"
#include <a.out.h>

End()
  {	register int i;
	register struct csect *p;
	extern	FILE *tout;

/* Pass 2 */
	if (Pass > 1) {				/* On the second pass, */
		Fix_Rel();			/* patch up object file */
		Sym_Write(tout);
		return; }

/* Pass 1 */
	fseek(stdin,0L,0);

	sdi_resolve();	/* resolve span dependent instructions */

	for (p = &Csects[0], i=0; i < Csect_load; i++, p++)
		p->len_cs += sdi_inc(p, p->len_cs);

	tsize = (Text_csect->len_cs + 3) & ~3;	/* make long aligned */
	dsize = (Data_csect->len_cs + 3) & ~3;
	bsize = (Bss_csect->len_cs + 3) & ~3;

	Sym_Fix();	/* relocate and globalize */
	sdi_free();	/* release sdi blocks */
	Rel_Header();	/* Initialize output stuff */
	Start_Pass();	/* Init per-pass variables */
	return;
}


/* Initialize per-pass variables */

Start_Pass()
 {	register int i;

	Last_symbol = Dot_bkt;	/* last defined symbol at start of pass */
	Line_no = 0;
	Errors = 0;
	Pass++;
	if (Pass != 2) for (i=0; i<Csect_load; i++) Csects[i].dot_cs = 0;
	else {
	  Text_csect->dot_cs = 0;
	  Data_csect->dot_cs = tsize;
	  Bss_csect->dot_cs = tsize + dsize;
	}
	New_Csect(&Csects[0]);	/* start in text segment */
}


i_even()
{
	if(Cur_csect == Text_csect)
		Prog_Warning(E_EVEN);
	if(Dot&1) {
		Dot++;
		Code[0] = 0;
		Put_Text(Code,1);
	}
}


i_long()
{
	register int i;
	register struct oper *p;

	for(i=0, p=operands; i < numops; i++, p++) {
		if(p->type_o != t_normal) {
			p->sym_o = 0;
			p->type_o = t_normal;
			p->value_o = 0;
			Prog_Error(E_OPERAND);
		}
		else if(p->sym_o)
			Put_Rel(p->sym_o,4,R_NORM,Dot+BC);

		CCode[0] = p->value_o;
		CCode[1] = p->value_o >> 8;
		CCode[2] = p->value_o >> 16;
		CCode[3] = p->value_o >> 24;
		Put_Text(CCode,4);
		BC += 4;
	}
}

i_word()
{
	register int i;
	register struct oper *p;

	for(i=0, p=operands; i < numops; i++, p++) {
		if(p->type_o != t_normal) {
			p->sym_o = 0;
			p->type_o = t_normal;
			p->value_o = 0;
			Prog_Error(E_OPERAND);
		}
		else if(p->sym_o)
			Put_Rel(p->sym_o,2,R_NORM,Dot+BC);

		if(p->value_o < ~0xFFFF || p->value_o > 0xFFFF)
			Prog_Error(E_RANGE);
		CCode[0] = p->value_o;
		CCode[1] = p->value_o >> 8;
	  	Put_Text(CCode,2);
		BC += 2;
	}
}

i_byte()
{
	register int i;
	register struct oper *p;

	for(i=0, p=operands; i < numops; i++, p++) {
		if(p->type_o != t_normal) {
			p->sym_o = 0;
			p->type_o = t_normal;
			p->value_o = 0;
			Prog_Error(E_OPERAND);
		}
		else if(p->sym_o)
			Put_Rel(p->sym_o,1,R_NORM,Dot+BC);

		if(p->value_o < ~0xFF || p->value_o > 0xFF)
			Prog_Error(E_RANGE);
		CCode[0] = p->value_o;
		Put_Text(CCode,1);
		BC++;
	}
}


i_ascii()
{
	register char *p;

	if(numops != 1 || operands[0].type_o != t_string) {
		Prog_Error(E_OPERAND);
		return;
	}
	p = (char *)operands[0].value_o;
	while(*p) {
		Put_Text(p++,1);
		BC++;
	}
}	

i_asciz()
{
	register char *p;

	if(numops != 1 || operands[0].type_o != t_string) {
		Prog_Error(E_OPERAND);
		return;
	}
	p = (char *)operands[0].value_o;
	while(*p) {
		Put_Text(p++,1);
		BC++;
	}
	Put_Text(p,1);
	BC++;
}	


i_zerol()
{
	register int i;
	long zero = 0;

	if(numops != 1 ||
	   operands[0].type_o != t_normal ||
	   operands[0].sym_o != NULL) {
		Prog_Error(E_OPERAND);
		return;
	}
	for(i = operands[0].value_o ; i > 0 ; i--) {
		Put_Text(&zero,4);
		BC += 4;
	}
}	


i_text() {
	New_Csect(Text_csect);
}

i_data() {
	New_Csect(Data_csect);
}

i_bss() {
	New_Csect(Bss_csect);
}

struct csect Csects[CSECT_MAX] = {
  ".text",0,0,0,R_ISPC|R_PURE,	/* text csect */
  ".data",0,0,0,0,		/* data csect */
  ".bss",0,0,0,0		/* uninitialized csect */
} ;

int Csect_load = 4;			/* Next available csect in Csects[] */
struct csect *Cur_csect = &(Csects[0]);	/* ptr to current csect */
struct csect *Text_csect = &(Csects[0]);
struct csect *Data_csect = &(Csects[1]);
struct csect *Bss_csect = &(Csects[2]);

New_Csect(csp)
  register struct csect *csp;
  {	register struct sym_bkt *sbp;	/* for defining new symbol */
	extern struct csect *Cur_csect;	/* ptr to current csect */
	extern struct sym_bkt	*Last_symbol;	/* used for local symbols */
	extern struct sym_bkt	*Dot_bkt;	/* sym_bkt for location counter */
	
	Cur_csect = csp;
	Dot = csp->dot_cs;
	Dot_bkt->csect_s = Cur_csect;	/* update dot's csect. Dot_bkt->value_s will be updated in the main loop */

	sbp = Lookup(csp->name_cs);
	sbp->attr_s |= S_DEC | S_DEF | S_LOCAL;
	sbp->csect_s = Cur_csect;
	sbp->value_s = 0;
}


i_globl()
{
	register int i;
	register struct sym_bkt *sbp;

	if(Pass == 1)
		for (i=0 ; i < numops ; i++) {
			sbp = operands[i].sym_o;
			if(sbp == NULL)
				Prog_Error(E_SYMBOL);
			else {
				sbp->csect_s = 0;	/* don't know which */
				/* declared and external */
				sbp->attr_s |= S_DEC | S_EXT;
			}
		}
}


i_comm()
{
	register struct sym_bkt *sbp;

	if(Pass == 1) {
		sbp = operands[0].sym_o;
		if(sbp == NULL)
			Prog_Error(E_OPERAND);
		else {
			sbp->csect_s = 0;	/* make it undefined */
			sbp->attr_s |= S_DEC | S_EXT | S_COMM;
			sbp->value_s = operands[1].value_o;
		}
	}
}
