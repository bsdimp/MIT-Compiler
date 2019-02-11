#include "mical.h"
#include <a.out.h>


char	*CCode = (char *)Code;
struct oper operands[OPERANDS_MAX];	/* where all the operands go */
int	numops;			/* # of operands to the current instruction */


struct sym_bkt *SYMBOL();


/*
 * assemble an instruction:
 *   this program is called from the main loop to generate the machine code
 *   for the instrucion
 * on pass 2 it prints the listing line for the current statement 
 */

Instruction(opcode)
register struct	opcode *opcode;
{
	typedef  (*funp)();
	register struct oper *oprnd;
	register int  i;
		 int  mode;
		 int  long_op = 0;		/* two byte opcode */
		 int  first_gen = 1;		/* first general operator */
		 int  op = opcode->op_code;	/* opcode */

	CCode = Code;

	/* handle pseudo ops */
	if(opcode->op_escape == -1) {
		(*(funp)opcode->op_code)();
		return;
	}

	/* check number of operands */
	if(opcode->op_cnt != numops) {
		Prog_Error(E_NUMOPS);
		return;
	}

	/* clear buffer for generated code */
	for(i = 0 ; i < CODE_MAX ; Code[i++] = 0);

	/* put out escape if needed */
	if(opcode->op_escape)
		*CCode++ = opcode->op_escape;

	/*
	 * we now make passes over the operands putting out a little each time
	 */

	/*
	 * put out any information thats actually in the instruction itself
	 * much of the validation of the operand types occurs here
	 */
	for(i = 0 ; i < numops ; i++) {
		oprnd = &operands[i];
		mode = MODE(oprnd);
		switch(opcode->op_oprnd[i]) {
		    case REGFLD:
			if(!GENREG_MODE(mode))
				Prog_Error(E_OPERAND);
			op |= GEN_REG(oprnd) << 3;
			break;
		    case ADDR:
			if(GENREG_MODE(mode))
				Prog_Error(E_OPERAND);
			goto genmode;
		    case WRITEB:
		    case WRITEW:
		    case WRITED:
		    case RMWB:
		    case RMWW:
		    case RMWD:
			if(IMMED_MODE(mode))
				Prog_Error(E_OPERAND);
			goto genmode;
		    case RMW2D:
			if(IMMED_MODE(mode) ||
			   (GENREG_MODE(mode) && GEN_REG(oprnd) & 1))
				Prog_Error(E_OPERAND);
			goto genmode;
		    case READB:
		    case READW:
		    case READD:
		    case REGADDR:
		      genmode:
			long_op++;
			if(mode > 0x1f)
				Prog_Error(E_OPERAND);
			if(INDEX(oprnd))
				mode = INDEX(oprnd);
			if(first_gen) {
				first_gen = 0;
				op |= mode << 11;
			}
			else
				op |= mode << 6;
			break;
		    case PROCREG:
			long_op++;
			if(!PROCREG_MODE(mode))
				Prog_Error(E_OPERAND);
			op = op | PROC_REG(oprnd) << 7;
			break;
		    case MMUREG:
			long_op++;
			if(!MMUREG_MODE(mode))
				Prog_Error(E_OPERAND);
			op = op | MMU_REG(oprnd) << 7;
			break;
		    case SHORT:
			long_op++;
			if(!ABSOL_MODE(mode) ||
			   (NEEDSRELOC(oprnd) ||
			    VALUE(oprnd) < 0 || VALUE(oprnd) > 0xF))
				Prog_Error(E_RANGE);
			op = op | VALUE(oprnd) << 7;
			break;
		    case QUICK:
			if(!IMMED_MODE(mode) ||
			   (NEEDSRELOC(oprnd) ||
			    VALUE(oprnd) < -0x8 || VALUE(oprnd) > 0x7))
				Prog_Error(E_RANGE);
			op = op | (VALUE(oprnd) & 0xF) << 7;
			break;
		    case DISP:
			if(!ABSOL_MODE(mode))
				Prog_Error(E_OPERAND);
			break;
		    case DISPPC:
			if(!ABSOL_MODE(mode))
				Prog_Error(E_OPERAND);
			/* this should do the SDI stuff */
			/* this needs serious work */
			oprnd->value_o -= Dot;
			break;
		    case IMM:
			if(!ABSOL_MODE(mode) ||
			   VALUE(oprnd) < 0 || VALUE(oprnd) > 0xFF)
				Prog_Error(E_RANGE);
			break;
		    default:
			Prog_Error(E_OPERAND);
		}
	}

	if(long_op) {
		*CCode++ = op;
		*CCode++ = op >> 8;
	}
	else
		*CCode++ = op;

	/* now put out any index specifier */
	for(i = 0 ; i < numops ; i++) {
		mode = MODE(&operands[i]);
		if(INDEX(&operands[i]))
			*CCode++ = (mode << 3) | INDEX_REG(&operands[i]);
	}

	/* now put out and values or disps for general addressing modes */
	for(i = 0 ; i < numops ; i++) {
		oprnd = &operands[i];
		mode = MODE(oprnd);
		if(IMMED_MODE(mode)) {
			switch(opcode->op_oprnd[i]) {
			    case READB:
				if(NEEDSRELOC(oprnd) ||
				   VALUE(oprnd) > 0xFF ||
				   VALUE(oprnd) < -0x100)
					Prog_Error(E_RANGE);
				*CCode++ = VALUE(oprnd);
				break;
			    case READW:
				if(NEEDSRELOC(oprnd) ||
				   VALUE(oprnd) > 0xFFFF ||
				   VALUE(oprnd) < -0x10000)
					Prog_Error(E_RANGE);
				/* immediate operands are byte reversed */
				*CCode++ = VALUE(oprnd) >> 8;
				*CCode++ = VALUE(oprnd) >> 0;
				break;
			    case READD:
				if(NEEDSRELOC(oprnd))
					Put_Rel(SYMBOL(oprnd),
						4, R_IMED,
						Dot + (CCode-Code));
				/* immediate operands are byte reversed */
				*CCode++ = VALUE(oprnd) >> 24;
				*CCode++ = VALUE(oprnd) >> 16;
				*CCode++ = VALUE(oprnd) >> 8;
				*CCode++ = VALUE(oprnd) >> 0;
				break;
			    case QUICK:
				break;
			    default:
				Prog_Error(E_OPERAND);
			}
		}
		else if(REGREL_MODE(mode) ||
		        ABSOL_MODE(mode) ||
			MEMIND_MODE(mode)) {
			if(opcode->op_oprnd[i] == SHORT)
				continue;
			/* put out any IMM operands */
			if(opcode->op_oprnd[i] == IMM) {
				if(!ABSOL_MODE(MODE(oprnd)) ||
				   VALUE(oprnd) < 0 || VALUE(oprnd) > 0xFF)
					Prog_Error(E_RANGE);
				else
					*CCode++ = VALUE(oprnd);
				continue;
			}

			/* put out the displacement */
			if(NEEDSRELOC(oprnd))
				if(opcode->op_oprnd[i] == DISPPC)
					Put_Rel(SYMBOL(oprnd),
						4, R_DISP|R_PCREL,
						Dot + (CCode-Code));
				else
					Put_Rel(SYMBOL(oprnd),
						4, R_DISP,
						Dot + (CCode-Code));
			if(NEEDSRELOC(oprnd) ||
			   VALUE(oprnd) > 0x1FFF ||
			   VALUE(oprnd) < -0x2000) {
				/* put out 4 byte disp */
				*CCode++ = (VALUE(oprnd) >> 24 & 0x3F) | 0xC0;
				*CCode++ = VALUE(oprnd) >> 16;
				*CCode++ = VALUE(oprnd) >> 8;
				*CCode++ = VALUE(oprnd) >> 0;
			}
			else if(VALUE(oprnd) > 0x3F ||
				VALUE(oprnd) < -0x40) {
				/* put out 2 byte disp */
				*CCode++ = (VALUE(oprnd) >> 8 & 0x3F) | 0x80;
				*CCode++ = VALUE(oprnd) >> 0;
			}
			else {
				/* put out 1 byte disp */
				*CCode++ = VALUE(oprnd) & 0x7F;
			}
			if(MEMIND_MODE(mode)) {
				/* put out second displacement */
				if(NEEDSRELOC(oprnd) && 0 /* FALSE */)
					if(opcode->op_oprnd[i] == DISPPC)
						Put_Rel(SYMBOL(oprnd),
							4, R_DISP|R_PCREL,
							Dot + (CCode-Code));
					else
						Put_Rel(SYMBOL(oprnd),
							4, R_DISP,
							Dot + (CCode-Code));
				/* put out 4 byte disp */
				*CCode++ = (DISPL(oprnd) >> 24 & 0x3F) | 0xC0;
				*CCode++ = DISPL(oprnd) >> 16;
				*CCode++ = DISPL(oprnd) >> 8;
				*CCode++ = DISPL(oprnd) >> 0;
			}
		}
		else if(!ANYREG_MODE(mode))
			Prog_Error(E_OPERAND);
	}

	if(CCode != Code) {
		Put_Text(Code,CCode - Code);	/* output text */
		BC = CCode - Code;		/* increment LC */
	}
}


MODE(oprnd)
register struct oper *oprnd;
{

	switch(oprnd->type_o) {
	    case t_reg:
		if(gpreg(oprnd->value_o))
			return(oprnd->value_o & 0x7);
		if(tosreg(oprnd->value_o))
			return(0x17);
		/* and extra pseudo mode */
		if(procreg(oprnd->value_o))
			return(32);
		if(mmureg(oprnd->value_o))
			return(33);
		break;

	    case t_immed:
		return(0x14);

	    case t_normal:
		return(0x15);

	    case t_displ:
		if(gpreg(oprnd->reg_o))
			return(0x8 | (oprnd->reg_o & 0x7));
		if(spreg(oprnd->reg_o) || pcreg(oprnd->reg_o))
			return(0x18 | (oprnd->reg_o & 0x3));
		break;

	    case t_memind:
		if(spreg(oprnd->reg_o))
			return(0x10 | (oprnd->reg_o & 0x3));
		break;

	    default:
		printop(oprnd);
		Sys_Error("Unrecognized address mode in line:\n\t%s", iline);
	}

	/* this will generate an error when you try compiling it */
	return(-1);
}

INDEX(oprnd)
register struct oper *oprnd;
{
	if(oprnd->flags_o & O_BINDEX)	return(0x1C);
	if(oprnd->flags_o & O_WINDEX)	return(0x1D);
	if(oprnd->flags_o & O_LINDEX)	return(0x1E);
	if(oprnd->flags_o & O_QINDEX)	return(0x1F);
	return(0);
}

GEN_REG(oprnd)
register struct oper *oprnd;
{
	return(oprnd->value_o);
}

PROC_REG(oprnd)
register struct oper *oprnd;
{
	return(oprnd->value_o & 0xF);
}

MMU_REG(oprnd)
register struct oper *oprnd;
{
	return(oprnd->value_o & 0xF);
}

INDEX_REG(oprnd)
register struct oper *oprnd;
{
	return(oprnd->ireg_o & 7);
}

struct sym_bkt *
SYMBOL(oprnd)
register struct oper *oprnd;
{
	return(oprnd->sym_o);
}

VALUE(oprnd)
register struct oper *oprnd;
{
	return(oprnd->value_o);
}

DISPL(oprnd)
register struct oper *oprnd;
{
	return(oprnd->disp_o);
}


NEEDSRELOC(oprnd)
register struct oper *oprnd;
{
	return(oprnd->sym_o != NULL);
}


GENREG_MODE(mode)
{
	return(mode >= 0 && mode <= 7);
}

ANYREG_MODE(mode)
{
	return(mode >= 0 && mode <= 7 || mode == 0x17 ||
	       mode == 32 || mode == 33);
}

PROCREG_MODE(mode)
{
	return(mode == 32);
}

MMUREG_MODE(mode)
{
	return(mode == 33);
}

IMMED_MODE(mode)
{
	return(mode == 0x14);
}

MEMIND_MODE(mode)
{
	return(mode >= 0x10 && mode <= 0x13);
}

INDEX_MODE(mode)
{
	return(mode >= 0x1C && mode <= 0x1F);
}

ABSOL_MODE(mode)
{
	return(mode == 0x15);
}

REGREL_MODE(mode)
{
	return(mode >= 0x8 && mode <= 0xF ||
	       mode >= 0x18 && mode <= 0x1B);
}


gpreg(reg) {  return(reg >= 0 && reg <= 7); }

spreg(reg) {  return(reg >= 8 && reg <= 10); }

pcreg(reg) {  return(reg == 11); }

tosreg(reg) {  return(reg == 12); }

procreg(reg) {  return(reg >= 8 && reg <= 10 || reg >= 13 && reg <= 16); }

mmureg(reg) {  return(reg >= 32 && reg <= 47); }
