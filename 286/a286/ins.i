# 1 "ins.c"

# 1 "./mical.h"

# 1 "/usr/include/stdio.h"




extern	struct	_iobuf {
	int	_cnt;
	char	*_ptr;
	char	*_base;
	short	_flag;
	char	_file;
} _iob[20];


























struct _iobuf	*fopen();
struct _iobuf	*fdopen();
struct _iobuf	*freopen();
long	ftell();
char	*fgets();
# 2 "./mical.h"































































































struct ins_bkt {
  struct ins_bkt *next_i;	
  char *text_i;			
  short code_i;			
};


struct csect {
  char *name_cs;	
  long len_cs;		
  long dot_cs;		
  short id_cs;		
  short attr_cs;	
};


struct sym_bkt {
  char *name_s;			
  struct sym_bkt *next_s;	
  struct csect *csect_s;	
  long value_s;			
  short id_s;			
  short attr_s;			
};


struct oper {
  char type_o;			
  char flags_o;			
  char reg_o;			
  struct sym_bkt *sym_o;	
  long value_o;			
};

extern char *soperand(),*exp();
extern char iline[],Code[];
extern short cinfo[];
extern int numops,Errors,Line_no,Pass,BC;
extern struct oper operands[];
extern struct ins_bkt *ins_hash_tab[];
extern struct sym_bkt *Lookup();
extern struct sym_bkt *Dot_bkt;
extern struct sym_bkt *Last_symbol;
extern long Dot,tsize,dsize,bsize;
extern struct csect *Cur_csect,*Text_csect,*Data_csect,*Bss_csect;
extern struct csect Csects[];
extern int Csect_load;
extern char Rel_name[],*Source_name;
extern short *WCode;		
extern char Code_length;	































# 2 "ins.c"

# 1 "./inst.h"



































































































































































































































































# 3 "ins.c"




char	Code_length;		
short	*WCode = (short *)Code;
struct oper operands[16	];	
int	numops;			







Instruction(opindex)
{	register int i,j,k;		

	Code_length = 1;		
	for(i=0;i < 12	; i++) { Code[i] = 0; }
					
	switch (opindex) {		

	case 63:	move(-1); break;

	case 6:	gen_op(0x00,0x0080,0x04,1,1,-1); break;
	case 5:	gen_op(0x10,0x1080,0x14,1,1,-1); break;
	case 97:	gen_op(0x28,0x2880,0x2C,1,1,-1); break;
	case 87:	gen_op(0x18,0x1880,0x1C,1,1,-1); break;
	case 15:	gen_op(0x38,0x3880,0x3C,1,1,-1); break;
	case 7:	gen_op(0x20,0x2080,0x24,1,0,-1); break;
	case 98:	gen_op(0x84,0x00F6,0xA8,0,0,-1); break;
	case 69:	gen_op(0x08,0x0880,0x0C,1,0,-1); break;
	case 102:	gen_op(0x30,0x3080,0x34,1,0,-1); break;

	case 114:	gen_op(0x00,0x0080,0x04,1,1,0); break;
	case 115:	gen_op(0x10,0x1080,0x14,1,1,0); break;
	case 117:	gen_op(0x28,0x2880,0x2C,1,1,0); break;
	case 118:	gen_op(0x18,0x1880,0x1C,1,1,0); break;
	case 133:	gen_op(0x20,0x2080,0x24,1,0,0); break;
	case 134:	gen_op(0x84,0x00F6,0xA8,0,0,0); break;
	case 135:	gen_op(0x08,0x0880,0x0C,1,0,0); break;
	case 136:	gen_op(0x30,0x3080,0x34,1,0,0); break;

	case 55:	load(0x8D); break;
	case 54:	load(0xC5); break;
	case 56:	load(0xC4); break;

	case 33:	disp(0xEB); break;
	case 34:	disp(0x74); break;
	case 35:	disp(0x7C); break;
	case 36:	disp(0x7E); break;
	case 37:	disp(0x72); break;
	case 38:	disp(0x76); break;
	case 39:	disp(0x7A); break;
	case 40:	disp(0x70); break;
	case 41:	disp(0x78); break;
	case 42:	disp(0x75); break;
	case 43:	disp(0x7D); break;
	case 44:	disp(0x7F); break;
	case 45:	disp(0x73); break;
	case 46:	disp(0x77); break;
	case 47:	disp(0x7B); break;
	case 48:	disp(0x71); break;
	case 49:	disp(0x79); break;
	case 60:	disp(0xE2); break;
	case 61:	disp(0xE1); break;
	case 62:	disp(0xE0); break;
	case 50:	disp(0xE3); break;

	case 103:	branch(0x74,0x75); break;
	case 104:	branch(0x75,0x74); break;
	case 105:	branch(0x7E,0x7F); break;
	case 106:	branch(0x7F,0x7E); break;
	case 107:	branch(0x7C,0x7D); break;
	case 108:	branch(0x7D,0x7C); break;
	case 109:	branch(0x76,0x77); break;
	case 110:	branch(0x77,0x76); break;
	case 111:	branch(0x72,0x73); break;
	case 112:	branch(0x73,0x72); break;
	case 113:	branch(0xEB,0); break;

	case 101:	no_ops(0xD7); break;
	case 53:	no_ops(0x9F); break;
	case 84:	no_ops(0x9E); break;
	case 75:	no_ops(0x9C); break;
	case 73:	no_ops(0x9D); break;
	case 1:	no_ops(0x37); break;
	case 19:	no_ops(0x27); break;
	case 4:	no_ops(0x3F); break;
	case 20:	no_ops(0x2F); break;
	case 10:	no_ops(0x98); break;
	case 18:	no_ops(0x99); break;
	case 64:	{ if (numops==0) no_ops(0xA4); else move(0); break; }
	case 65:	no_ops(0xA5); break;
	case 16:	{ if (numops==0) no_ops(0xA6);
			  else gen_op(0x38,0x3880,0x3C,1,1,0); break; }
	case 17:	no_ops(0xA7); break;
	case 88:	no_ops(0xAE); break;
	case 89:	no_ops(0xAF); break;
	case 58:	no_ops(0xAC); break;
	case 59:	no_ops(0xAD); break;
	case 95:	no_ops(0xAA); break;
	case 96:	no_ops(0xAB); break;
	case 29:	no_ops(0xCE); break;
	case 31:	no_ops(0xCF); break;
	case 11:	no_ops(0xF8); break;
	case 14:	no_ops(0xF5); break;
	case 92:	no_ops(0xF9); break;
	case 12:	no_ops(0xFC); break;
	case 93:	no_ops(0xFD); break;
	case 13:	no_ops(0xFA); break;
	case 94:	no_ops(0xFB); break;
	case 32:	no_ops(0xF4); break;
	case 99:	no_ops(0x9B); break;
	case 57:	no_ops(0xF0); break;
	case 78:	no_ops(0xF2); break;
	case 79:	no_ops(0xF3); break;

	case 3:
	case 2:
		if (numops != 0)		
		 { Prog_Error(25); break; };
		Code_length = 2;		
		Code[0] = (opindex==3)?0xD6:0xD5;
		Code[1] = 0x0A;
		break;

	case 116:
	case 119:
		k = 0;				
		i = (opindex==116)?1:0;	
		goto incdec;

	case 27:
	case 21:
		k = -1;				
		i = (opindex==27)?1:0;	
	incdec:	if (numops != 1)		
		 { Prog_Error(25); break; };
		j = reg(operands);		
		if (j>=0 && j<8)		
		 Code[0] = (i?0x40:0x48) | j;
		else one_op(i?0x00FE:0x08FE,k);	
		break;

	case 68:	one_op(0x10F6,-1); break;
	case 67:	one_op(0x18F6,-1); break;
	case 66:	one_op(0x20F6,-1); break;
	case 25:	one_op(0x28F6,-1); break;
	case 22:	one_op(0x30F6,-1); break;
	case 24:	one_op(0x38F6,-1); break;

	case 125:	one_op(0x10F6,0); break;
	case 120:	one_op(0x18F6,0); break;
	case 121:	one_op(0x20F6,0); break;
	case 122:	one_op(0x28F6,0); break;
	case 123:	one_op(0x30F6,0); break;
	case 124:	one_op(0x38F6,0); break;

	case 74:
	case 72:
		if (numops != 1)		
		 { Prog_Error(25); break; };
		i = (opindex==74)?1:0;	
		j = reg(operands);		
		opr_size(1);			
# 175 "ins.c"

		if (j == -1) {		
		  Code[0] = i ? 0xFF:0x8F;
		  Code[1] = i ? 0x30:0x00;
		  addr(operands);	
		} else if (j>=16 && j<=19) {	
		  Code[0] = (i ? 0x06:0x07) | ((j&3)<<3);
	        else Code[0] = (i ? 0x50:0x58) | (j&7);
		break;

	case 100:
		if (numops != 2)		
		 { Prog_Error(25); break; };
		i = reg(operands);		
		j = reg(&operands[1]);		
		k = opr_size(-1);		
		Code[0] = 0x90;			
		if (i==0 && j>=0 && j<8)	
		 { Code[0] |= (j&7); break; };
		if (j==0 && i>=0 && i<8)	
		 { Code[0] |= (i&7); break; };
		if (i>=0 && i<16)		
		 { Code[0] = 0x86 | k;
		   addr(&operands[1]);		
		   Code[1] |= (i&7)<<3;
		   break;
		 }
		else if (j>=0 && j<16)		
		 { Code[0] = 0x86 | k;
		   addr(operands);		
		   Code[1] |= (j&7)<<3;
		   break;
		 };
		Prog_Error(13);		
		break;

	case 26:	in_out(0xE4,0xEC); break;
	case 30:	in_out(0xE5,0xED); break;
	case 70:	in_out(0xE6,0xEE); break;
	case 71:	in_out(0xE7,0xEF); break;
	case 28:	in_out(0xCD,0xCC); break;	

/*	case 85:	shift(0x20,-1); break;
	case 91:	shift(0x28,-1); break;
	case 86:	shift(0x38,-1); break;
	case 82:	shift(0,-1); break;
	case 83:	shift(0x08,-1); break;
	case 76:	shift(0x10,-1); break;
	case 77:	shift(0x18,-1); break;

	case 126:	shift(0x20,0); break;
	case 127:	shift(0x28,0); break;
	case 128:	shift(0x38,0); break;
	case 129:	shift(0,0); break;
	case 130:	shift(0x08,0); break;
	case 131:	shift(0x10,0); break;
	case 132:	shift(0x18,0); break;

	case 51:	jump(0xE9,0x20FF); break;
	case 8:	jump(0xE8,0x10FF); break;

	case 52:	jumpi(0xEA,0x28FF); break;
	case 9:	jumpi(0x9A,0x18FF); break;

	case 80:
	case 81:
		if (numops > 1)				
		 { Prog_Error(25); break; };
		i = (opindex==80)?1:0;
		if (numops == 0)			
		 { Code[0] = i?0xC3:0xCB; break; };
		Code[0] = i?0xC2:0xCA;			
		Code_length = 3;
		i = operands[0].value_o;		
		Code[1] = i&0377; Code[2] = i >> 8;
		if (operands[0].type_o!=1			
		    || operands[0].sym_o!=0)
		 Prog_Error(13);			
		break;

	case 90:
		if (numops != 1)			
		 { Prog_Error(25); break; };
		i = reg(operands);			
		if (i<16 || i>19)			
		 { Prog_Error(13); break; };
		Code[0] = 0x26 | ((i&3)<<3);		
		break;

	 case 	137:	fop0(0xE1D9,1); break;
	 case 	138:	fop1(0x00D8); break;
	 case 	139:	fop1(0x00DA); break;
	 case 	140:	fop1(0x00DC); break;
	 case 	141:	fop1(0x00DE); break;
	 case 	142:	freg(0xC0D8,1); break;
	 case 	143:	freg(0xC0DA,1); break;
	 case 	146:	fop0(0xE0D9,1); break;
	 case 	147:	fop0(0xE2DB,0); break;
	 case 	148:	fop1(0x10D8); break;
	 case 	149:	fop1(0x10DA); break;
	 case 	150:	fop1(0x10DC); break;
	 case 	151:	fop1(0x10DE); break;
	 case 	152:	freg(0xD0D8,0); break;
	 case 153:	fop1(0x18D8); break;
	 case 154:	fop1(0x18DA); break;
	 case 155:	fop1(0x18DC); break;
	 case 156:	fop1(0x18DE); break;
	 case 	157:	freg(0xD8D8,0); break;
	 case 158:	fop0(0xD9DE,1); break;
	 case 159:fop0(0xF6D9,1); break;
	 case 	160:	fop0(0xE1DB,0); break;
	 case 	161:	fop1(0x30D8); break;
	 case 	162:	fop1(0x30DA); break;
	 case 	163:	fop1(0x30DC); break;
	 case 	164:	fop1(0x30DE); break;
	 case 233:	fop1(0x38D8); break;
	 case 234:	fop1(0x38DA); break;
	 case 235:	fop1(0x38DC); break;
	 case 236:	fop1(0x38DE); break;
	 case 	165:	freg(0xF0D8,1); break;
	 case 	166:	freg(0xF0DA,1); break;
	 case 	167:	freg(0xF8D8,1); break;
	 case 168:	freg(0xF8DA,1); break;
	 case 	169:	fop0(0xE0DB,0); break;
	 case 	170:	fstack(0xC0DD); break;
	 case 171:fop0(0xF7D9,1); break;
	 case 	172:	fop0(0xE3DB,0); break;
	 case 	173:	fop1(0x28D9); break;
	 case 174:	fop1(0x20D9); break;
	 case 	175:	fop1(0x00D9); break;
	 case 	176:	fop1(0x00DB); break;
	 case 	177:	fop1(0x00DD); break;
	 case 	178:	fop1(0x00DF); break;
	 case 	179:	fstack(0xC0D9); break;
	 case 180:	fop0(0xECD9,1); break;
	 case 181:	fop0(0xEDD9,1); break;
	 case 182:	fop0(0xEAD9,1); break;
	 case 183:	fop0(0xE9E9,1); break;
	 case 	184:	fop0(0xEBD9,1); break;
	 case 	185:	fop0(0xEED9,1); break;
	 case 	186:	fop0(0xE8D9,1); break;
	 case 	187:	fop0(0xD0D9,1); break;
	 case 	188:	fop1(0x08D8); break;
	 case 	189:	fop1(0x08DA); break;
	 case 	190:	fop1(0x08DC); break;
	 case 	191:	fop1(0x08DE); break;
	 case 	192:	freg(0xC8D8,1); break;
	 case 	193:	freg(0xC8DA,1); break;
	 case 196:	fop0(0xF3D9,1); break;
	 case 	197:	fop0(0xF8D9,1); break;
	 case 	198:	fop0(0xF2D9,1); break;
	 case 199:	fop1(0x20DD); break;
	 case 200:fop0(0xFCD9,1); break;
	 case 	201:	fop1(0x30DD); break;
	 case 202:	fop0(0xFDD9,1); break;
	 case 	203:	fop0(0xFAD9,1); break;
	 case 	204:	fop1(0x10D9); break;
	 case 	205:	fop1(0x10DB); break;
	 case 	206:	fop1(0x10DD); break;
	 case 	207:	fop1(0x10DF); break;
	 case 	208:	fstack(0xD0DD); break;
	 case 	209:	fop1(0x18D9); break;
	 case 	210:	fop1(0x18DB); break;
	 case 	211:	fop1(0x18DD); break;
	 case 	212:	fop1(0x18DF); break;
	 case 	213:	fstack(0xD8DD); break;
	 case 	214:	fop1(0x38D9); break;
	 case 215:	fop1(0x30D9); break;
	 case 	216:	fop1(0x38DD); break;
	 case 	217:	fop1(0x20D8); break;
	 case 	218:	fop1(0x20DA); break;
	 case 	219:	fop1(0x20DC); break;
	 case 	220:	fop1(0x20DE); break;
	 case 237:	fop1(0x28D8); break;
	 case 238:	fop1(0x28DA); break;
	 case 239:	fop1(0x28DC); break;
	 case 240:	fop1(0x28DE); break;
	 case 	221:	freg(0xE0D8,1); break;
	 case 	222:	freg(0xE0DA,1); break;
	 case 	223:	freg(0xE8D8,1); break;
	 case 224:	freg(0xE8DA,1); break;
	 case 	225:	freg(0xE4D9,1); break;
	 case 	226:	no_ops(0x9B); break;
	 case 	227:	fop0(0xE5D9,1); break;
	 case 	228:	fstack(0xC8D9); break;
	 case 229:fop0(0xF4D9,1); break;
	 case 	230:	fop0(0xF1D9,1); break;
	 case 231:fop0(0xF9D9,1); break;
	 case 	232:	fop0(0xF0D9,1); break;

	
	case 241:	ByteWord(2	);
			goto pseudo;
	case 242:	ByteWord(1	);
			goto pseudo;
	case 243:	ByteWord(0	); goto pseudo;
	case 244:	New_Csect(Text_csect); goto pseudo;
	case 245:	New_Csect(Data_csect); goto pseudo;
	case 246:	New_Csect(Bss_csect); goto pseudo;
	case 247:	Globl(); goto pseudo;
	case 248:	Comm(); goto pseudo;
	case 249:	Even(); goto pseudo;
	case 250:	Ascii(0); goto pseudo;
	case 251:	Ascii(1); goto pseudo;
	case 252:	Zerow();
			goto pseudo;

	pseudo:		Code_length = 0;
			break;

	default:	Prog_Error(17);
	};

	if (Code_length) {
	  Put_Text(Code,Code_length);	
	  BC = Code_length;		
	}
}








value(opnd,size,flg)
 register struct oper *opnd;
 {	register int i,j;

	if (flg && size && opnd->type_o==4	) { 
	  size = 0;			
	  Code[0] |= 2;			
	  i = opnd->value_o & 0177600;	
	  if (Pass==2 && i!=0 && i!=0177600)	
	    Prog_Warning(13);	
	}
	j = opnd->value_o;		
	if (opnd->sym_o != 0)	
	  Put_Rel(opnd,size,Dot+Code_length,0);
	Code[Code_length++] = j & 0377;	
	if (size) Code[Code_length++] = j >> 8;	
}










osize(opnd)				
 register struct oper *opnd;
 {	register int i,j;

	i = opnd->type_o;		
	if (i & 020	) return(0);	
	if (i == 2	)
	 return(((j = opnd->value_o)<8 || (j>=16 && j<=19))?1:0);
					
	return(-1);			
}

opr_size(arg)
 {	register struct oper *opnd;	
	register int j,op;

	for (opnd=operands,op=0; op<numops; opnd++,op++) {
	  j = osize(opnd);		
	  if (j == -1) continue;	
 	  else if (arg == -1) arg = j;	
	  else if (arg==0 && j==1 &&	
	    opnd->type_o==2	 &&
	    opnd->value_o<4)	
	    opnd->value_o += 8;
	  else if (arg != j) Prog_Error(13);
					
	};
	return(arg==-1 ? 1 : arg);	
}




reg(opnd)
 register struct oper *opnd;	
 {	if ((opnd->type_o & 017	) != 2	) return(-1);
	else return(opnd->value_o);
}


immed()
 {	register int type;

	if ((type=(operands[1].type_o & 017	))==3	 || type==4	) return(1);
	return(0);
}





addr(opnd)
 register struct oper *opnd;	
 {	register int i;

	if (Code_length < 2) Code_length=2;	

	switch (opnd->type_o & 017	) {	

	case 2	:
		 i = reg(opnd);			
		 if (i<0 || i>15)			
		  { Prog_Error(	27); return; };
		 Code[1] |= 0300 | (i&7);		
		 return;				

	case 1	:
		Code[1] |= 0006;		
		value(opnd,1,0);		
		return;

	index_reg:				
	case 5	:
		switch (opnd->reg_o) {		
		case 3:	Code[1] |= 07;		
			return;

		case 5:	if ((opnd->type_o & 017	)==5	)
			 { Code[1] |= 0100;	
			   opnd->value_o = 0;
			   value(opnd,0,0);
			 }
			Code[1] |= 06;		
			return;

		case 6:	Code[1] |= 04;		
			return;

		case 7:	Code[1] |= 05;		
			return;

		case 64:Code[1] |= 00;		
			return;

		case 65:Code[1] |= 01;		
			return;

		case 66:Code[1] |= 02;		
			return;

		case 67:Code[1] |= 03;		
			return;

		index_error:			
		default:Prog_Error(	27);	
			return;
		};

	case 6	:
		value(opnd,1,0);		
		Code[1] |= 0200;		
		goto index_reg;			

	case 7	:
		value(opnd,0,0);		
		Code[1] |= 0100;		
		goto index_reg;			

	default:Prog_Error(13);		
		return;
	};
}



no_ops(opr)
 {	Code[0] = opr;				
	if (numops != 0) Prog_Error(25);	
}





disp(opr)
 {	register int d;				
	extern struct csect *Cur_csect;		

	Code[0] = opr;				
	if (numops != 1)			
	 { Prog_Error(25); return; };
	d = operands[0].value_o - (Dot + 2);
	if (operands[0].type_o != 1	 ||	
	    operands[0].sym_o->csect_s
	     != Cur_csect ||			
	    -128>d || d>127 )			
	 { Prog_Error(36); d=0; };	
	Code_length = 2;			
	Code[1] = d;				
 };





branch(br,obr)
 {	int offs = 0;
	register struct oper *opp = operands;
	extern struct csect *Cur_csect;	
	extern char shortblist[];	

	if (numops != 1) Prog_Error(25);
	else if ((opp->type_o & 017	) != 1	)	
	  Prog_Error(13);
	else {
	  offs = opp->value_o - (Dot + 2);
	  if (opp->flags_o & 4) goto blong;	
	  else if (Pass == 1)
	    Code_length = makesdi(opp, obr==0 ? 3 : 5, Dot+2, shortblist);
	  else if (opp->sym_o->csect_s != Cur_csect) goto blong;
	  else if (offs >= -128 && offs <= 127) {
	    Code_length = 2;
	    Code[0] = br;
	    Code[1] = offs;
	  } else {
  blong:    if (obr == 0) {		
	      Code[0] = 0xE9;		
	      offs -= 1;		
	      if (operands[0].sym_o->csect_s != Cur_csect)
	        Put_Rel(operands,1,Dot+1,1);
	      Code_length = 3;		
	      Code[1] = offs & 0377;
	      Code[2] = offs >> 8;
	    } else {
	      Code[0] = obr;		
	      Code[1] = 3;		
	      Code[2] = 0xE9;		
	      offs -= 3;		
	      if (operands[0].sym_o->csect_s != Cur_csect)
	        Put_Rel(operands,1,Dot+3,1);
	      Code_length = 5;		
	      Code[3] = offs & 0377;
	      Code[4] = offs >> 8;
	    }
	  }

	}
}




load(op)
 {	register int i,j;

	if (numops != 2)		
	 { Prog_Error(25); return; };
	opr_size(1);			
	i = reg(operands);		
	if (i<0 || i>7)
	 { Prog_Error(13); return; };
	Code[0] = op;			
	Code[1] = i<<3;
	addr(&operands[1]);		
	return;
 };

move(size)				
 {	register int i,j,k;		

	if (numops != 2)		
	 { Prog_Error(25); return; };
	k = opr_size(size);		
	i = reg(operands);		
	j = reg(&operands[1]);		
	if (immed())			
	 if (i != -1)			
	  { if (i>=16)			
	     { Prog_Error(13); return; };
	    Code[0] = 0260 | k<<3 | i&7; 
	    value(&operands[1],k,0);	
	    return;
	  } else			
	  { Code[0] = 0306 | k;		
	    addr(operands);		
	    value(&operands[1],k,0);	
	    return;
	  };
	if ((i==0 || i==8) &&		
	    (operands[1].type_o&017	) == 1	)	
	 { Code[0] = 0240 | k;		
	   value(&operands[1],1,0);	
	   return;
	 };
	if ((j==0 || j==8) &&		
	    (operands[0].type_o&017	) == 1	)	
	 { Code[0] = 0242 | k;		
	   value(operands,1,0);		
	   return;
	 };
	if (i>=16 && i<=19)		
	 { Code[0] = 0216;		
	   addr(&operands[1]);		
	   Code[1] |= (i&3)<<3;		
	   return;
	 };
	if (j>=16 && j<=19)		
	 { Code[0] = 0214;		
	   addr(operands);		
	   Code[1] |= (j&3)<<3;		
	   return;
	 };
	Code[0] = 0210 | k;		
	if (i >= 0 && i < 16)		
	 { Code[0] |= 2;		
	   addr(&operands[1]);		
	   Code[1] |= (i&7)<<3;
	   return;
	 }
	if (j >= 0 && j < 16)		
	 { addr(operands);		
	   Code[1] |= (j&7)<<3;
	   return;
	 }
	Prog_Error(13);
 }









gen_op(op1,op2,op3,dir,sxt,size)	
 {	register int i,j,k;		

	if (numops != 2)		
	 { Prog_Error(25); return; };
	k = opr_size(size);		
	i = reg(operands);		
	j = reg(&operands[1]);		
	if (immed())			
	 if (i==0 || i==8)		
	  { Code[0] = op3 | k;		
	    value(&operands[1],k,0);	
	    return;
	  } else			
	  { Code[0] = (op2 & 0377) | k;	
	    Code[1] = op2 >> 8;		
	    addr(operands);		
	    value(&operands[1],k,sxt);	
	    return;
	  };
	Code[0] = op1 | k;		
	if (i >= 0 && i < 16)		
	 { if (dir) Code[0] |= 2;	
	   addr(&operands[1]);		
	   Code[1] |= (i&7)<<3;		
	   return;
	 };
	if (j >= 0 && j < 16)		
	 { addr(operands);		
	   Code[1] |= (j&7)<<3;		
	   return;
	 };
	Prog_Error(13);		
 }




in_out(op1,op2)
 {	register int v;

	if (numops > 1)			
	 { Prog_Error(25); return; };
	if (numops == 0)		
	 { Code[0] = op2; return; };
	if ((operands[0].type_o&017	)!=1		
 	    || operands[0].sym_o!=0) 
	 { Prog_Error(13); return; };
	if ((v = operands[0].value_o)&0177600)
	 Prog_Warning(13);
	Code[0] = op1;
	Code_length = 2;		
	Code[1] = v;
	return;
 }




one_op(op,size)
 {	if (numops != 1)		
	 { Prog_Error(25); return; };
	Code[0] = (op&0377) | opr_size(size); 
	Code[1] = op >> 8;		
	addr(operands);			
	return;
 }





shift(op,size)
 {	register int i;

	if (numops != 2)			
	 { Prog_Error(25); return; };
	numops = 1;				
	Code[0] = opr_size(size);	
	Code[1] = op >> 8;
	addr(operands);			
	i = operands[1].type_o & 017	;  

	if (i==2	 && operands[1].value_o==9) Code[0] |= 0xD2;  
	else if (i == 3	 || i == 4	) {
	 if (operands[1].sym_o==0 && operands[1].value_o==1)
	   Code[0] |= 0xD0;
	 else { value(&operands[1],0,0); Code[0] |= 0xC0; }
	} else Prog_Error(13);
 }




jump(op1,op2)
 {	register int i,d;

	if (numops != 1)			
	 { Prog_Error(25); return; };
	if (operands[0].type_o & 040	)		
	 { Code[0] = op2 & 0377;
	   Code[1] = op2 >> 8;
	   addr(operands);			
	   return;
	 };
	if (((i=operands[0].type_o)&017	) != 1	) 
	 Prog_Error(36);			
	d = operands[0].value_o - (Dot + 3);
	if (operands[0].sym_o->csect_s != Cur_csect)
	 Put_Rel(operands,1,Dot+1,1);		
	Code_length = 3;			
	Code[0] = op1;
	Code[1] = d & 0377;
	Code[2] = d >> 8;
	return;
 }





jumpi(op1,op2)
 {	if (operands[0].type_o & 040	)		
	 { if (numops != 1)			
	    { Prog_Error(25); return; };
	   Code[0] = op2 & 0377;
	   Code[1] = op2 >> 8;
	   addr(operands);			
	   return;
	 };
	if (numops != 2)			
	 { Prog_Error(25); return; };
	if ((operands[0].type_o & 017	) != 1	)
	 { Prog_Error(13); return; };	
	Code[0] = op1;				
	value(operands,1,0);			
	if (((operands[1].type_o & 017	) != 1	) ||
	    (operands[1].sym_o != 0))	
	 { Prog_Error(13); return; };
	value(&operands[1],1,0);		
	return;
 }


fop0(op,waitf)
 {	register int i = 0;		

	if (numops != 0) Prog_Error(25);	
	if (waitf) Code[i++] = 0x9B;		
	Code[i++] = op & 0377;			
	Code[i++] = op >> 8;			
	Code_length = i;			
}


fop1(op)
 {	if (numops != 1) { Prog_Error(25); return; }
	Code_length = 3;
	addr(operands);		
	Code[2] = Code[1] | (op >> 8);		
	Code[1] = op & 0377;			
	Code[0] = 0x9B;				
}


freg(op,dirf)
 {	register int direction = 0;
	register int reg;

	if (numops != 2) { Prog_Error(25); return; }
	if (operands[0].type_o!=1	 || operands[0].sym_o!=0 ||
	    operands[1].type_o!=1	 || operands[1].sym_o!=0)
	  { Prog_Error(13); return; }
	if (operands[1].value_o == 0) { direction = 1; reg = operands[0].value_o & 07; }
	else reg = operands[1].value_o & 07;
	Code_length = 3;
	Code[0] = 0x9B;				
	Code[1] = op & 0377;			
	Code[2] = (op >> 8) | reg;		
	if (dirf && direction) Code[1] |= 4;	
}


fstack(op)
 {	register reg;

	if (numops != 1) { Prog_Error(25); return; }
	if (operands[0].type_o!=1	 || operands[0].sym_o!=0)
	  { Prog_Error(13); return; }
	reg = operands[0].value_o & 07;
	Code_length = 3;
	Code[0] = 0x9B;				
	Code[1] = op & 0377;			
	Code[2] = (op >> 8) | reg;		
}
