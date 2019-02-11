#include <stdio.h>
#include <b.out.h>

/* dump text portion of .b file as instructions and symbols ... */

long	dot;
FILE *infile;

struct stable {
  struct stable *next;	/* pointer to next table entry */
  long value;		/* value of this symbol */
  char name[1];		/* name of this symbol, asciz form */
} *symhead = NULL;


char *badop = "\t???";
#define IMDF "#%d"			/* immediate data format */

char *bname[16] = { "ra", "sr", "hi", "ls", "cc", "cs", "ne",
		    "eq", "vc", "vs", "pl", "mi", "ge", "lt", "gt", "le" };

char *shro[4] = { "as", "ls", "rox", "ro" };

char *bit[4] = { "btst", "bchg", "bclr", "bset" };

int omove(),obranch(),oimmed(),oprint(),oneop(),soneop(),oreg(),ochk();
int olink(),omovem(),oquick(),omoveq(),otrap(),oscc(),opmode(),shroi();
int extend(),biti();

struct opdesc
{			
	unsigned short mask, match;
	int (*opfun)();
	char *farg;
} opdecode[] =
{					/* order is important below */
  0xF000, 0x1000, omove, "b",		/* move instructions */
  0xF000, 0x2000, omove, "l",
  0xF000, 0x3000, omove, "w",
  0xF000, 0x6000, obranch, 0,		/* branches */
  0xFF00, 0x0000, oimmed, "or",		/* op class 0  */
  0xFF00, 0x0200, oimmed, "and",
  0xFF00, 0x0400, oimmed, "sub",
  0xFF00, 0x0600, oimmed, "add",
  0xFF00, 0x0A00, oimmed, "eor",
  0xFF00, 0x0C00, oimmed, "cmp",
  0xF100, 0x0100, biti, 0,
  0xF800, 0x0800, biti, 0,
  0xFFC0, 0x40C0, oneop, "move_from_sr", /* op class 4 */
  0xFF00, 0x4000, soneop, "negx",
  0xFF00, 0x4200, soneop, "clr",
  0xFFC0, 0x44C0, oneop, "move_to_ccr",
  0xFF00, 0x4400, soneop, "neg",
  0xFFC0, 0x46C0, oneop, "move_to_sr",
  0xFF00, 0x4600, soneop, "not",
  0xFFC0, 0x4800, oneop, "nbcd",
  0xFFF8, 0x4840, oreg, "\tswap\td%D",
  0xFFC0, 0x4840, oneop, "pea",
  0xFFF8, 0x4880, oreg, "\textw\td%D",
  0xFFF8, 0x48C0, oreg, "\textl\td%D",
  0xFB80, 0x4880, omovem, 0,
  0xFFC0, 0x4AC0, oneop, "tas",
  0xFF00, 0x4A00, soneop, "tst",
  0xFFF0, 0x4E40, otrap, 0,
  0xFFF8, 0x4E50, olink, 0,
  0xFFF8, 0x4880, oreg, "\textw\td%D",
  0xFFF8, 0x48C0, oreg, "\textl\td%D",
  0xFFF8, 0x4E58, oreg, "\tunlk\ta%D",
  0xFFF8, 0x4E60, oreg, "\tmove\ta%D,usp",
  0xFFF8, 0x4E68, oreg, "\tmove\tusp,a%D",
  0xFFFF, 0x4E70, oprint, "reset",
  0xFFFF, 0x4E71, oprint, "nop",
  0xFFFF, 0x4E72, oprint, "stop",
  0xFFFF, 0x4E73, oprint, "rte",
  0xFFFF, 0x4E75, oprint, "rts",
  0xFFFF, 0x4E76, oprint, "trapv",
  0xFFFF, 0x4E77, oprint, "rtr",
  0xFFC0, 0x4E80, oneop, "jsr",
  0xFFC0, 0x4EC0, oneop, "jmp",
  0xF1C0, 0x4180, ochk, "chk",
  0xF1C0, 0x41C0, ochk, "lea",
  0xF0C0, 0x50C0, oscc, 0,
  0xF100, 0x5000, oquick, "addq",
  0xF100, 0x5100, oquick, "subq",
  0xF000, 0x7000, omoveq, 0,
  0xF1C0, 0x80C0, ochk, "divu",
  0xF1C0, 0x81C0, ochk, "divs",
  0xF1F0, 0x8100, extend, "sbcd",
  0xF000, 0x8000, opmode, "or",
  0xF1C0, 0x91C0, opmode, "sub",
  0xF130, 0x9100, extend, "subx",
  0xF000, 0x9000, opmode, "sub",
  0xF1C0, 0xB1C0, opmode, "cmp",
  0xF138, 0xB108, extend, "cmpm",
  0xF100, 0xB000, opmode, "cmp",
  0xF100, 0xB100, opmode, "eor",
  0xF1C0, 0xC0C0, ochk, "mulu",
  0xF1C0, 0xC1C0, ochk, "muls",
  0xF1F8, 0xC188, extend, "exg",
  0xF1F8, 0xC148, extend, "exg",
  0xF1F8, 0xC140, extend, "exg",
  0xF1F0, 0xC100, extend, "abcd",
  0xF000, 0xC000, opmode, "and",
  0xF1C0, 0xD1C0, opmode, "add",
  0xF130, 0xD100, extend, "addx",
  0xF000, 0xD000, opmode, "add",
  0xF100, 0xE000, shroi, "r",
  0xF100, 0xE100, shroi, "l",
  0, 0, 0, 0
};

main(argc,argv)
  char **argv;
  {	struct bhdr b;

	if (argc == 2) {
	  if ((infile = fopen(argv[1],"r")) == NULL) {
	    fprintf(stderr,"can't open %s for input\n",argv[1]);
	    exit(1);
	  }
	} else infile = stdin;

	fread(&b, sizeof b, 1, infile);
	
	if (b.fmagic != FMAGIC) {
	  fprintf(stderr,"file is not in b.out format\n");
	  exit(1);
	}

	fseek(infile, sizeof(b) + b.tsize + b.dsize, 0);
	readsym(b.ssize);

	fseek(infile, sizeof b, 0);
	dot = b.entry;
	while (dot < b.tsize+b.entry) {
	  pexact(dot);
	  printf(":\t");
	  printins(instfetch(2));
	  printf("\n");
	}
}

/* print symbol if we're right on top of it... */
pexact(val)
  register int val;
  {	struct stable *s;

	for (s = symhead; s != NULL; s = s->next) {
	  if (val == s->value) { printf("%s",s->name); return; }
	  else if (val < s->value) break;
	}
	printf("0x%x",val);
}

/* build linked list of symbols ordered by increasing value */
readsym(size)
  {	struct sym s;
	register char *p;
	register struct stable *st,*last,*t;
	char name[100];

	while (size > 0) {
	  fread(&s, sizeof s, 1, infile);
	  if (feof(infile)) break;
	  size -= sizeof s;
	  for ( p=name; *p++ = getc(infile)&0377; size--) if (feof(infile)) break;
	  if (!(s.stype & 040)) continue;
	  st = (struct stable *)malloc(sizeof(*st) + strlen(name));
	  strcpy(st->name,name);
	  st->value = s.svalue;

	  for (last = NULL, t = symhead; t != NULL; last = t, t = t->next)
	    if (t->value > st->value) break;
	  if (last == NULL) symhead = st;
	  else last->next = st;
	  st->next = t;
	}
}
	      

printins(inst)
{	register struct opdesc *p;
	register int (*fun)();

	/* this messes up "orb" instructions ever so slightly, but keeps
	 * us in sync between routines...
	 */
	if (inst == 0) {
	  printf("\t.word 0");
	  return;
	}

	for (p = opdecode; p->mask; p++)
		if ((inst & p->mask) == p->match) break;

	if (p->mask != 0) (*p->opfun)(inst, p->farg);
	else printf(badop);
}

long sxtword(i)
  register int i;
  {	return( i>32767 ? i-65536 : i );
}

long instfetch(size)
  register int size;
{	register int ans = 0;

	while (size--) {
	  ans <<= 8;
	  ans |= getc(infile) & 0377;
	  dot++;
	}
	return(ans);
}

printea(mode,reg,size)
long mode, reg;
int size;
{
	long index,disp;

	switch ((int)(mode)) {
	  case 0:	printf("d%D",reg);
			break;

	  case 1:	printf("a%D",reg);
			break;

	  case 2:	printf("a%D@",reg);
			break;

	  case 3:	printf("a%D@+",reg);
			break;

	  case 4:	printf("a%D@-",reg);
			break;

	  case 5:	printf("a%D@(%D)",reg,sxtword(instfetch(2)));
			break;

	  case 6:	index = instfetch(2);
			disp = (char)(index&0377);
			printf("a%d@(%d,%c%D%c)",reg,disp,
			  (index&0100000)?'a':'d',(index>>12)&07,
			  (index&04000)?'l':'w');
			break;

	  case 7:	switch ((int)(reg))
			{
			  case 0:	index = instfetch(2);
					printf("%x:w",index);
					break;

			  case 1:	index = instfetch(4);
					pexact(index);
					break;

			  case 2:	printf("pc@(%D)",sxtword(instfetch(2)));
					break;

			  case 3:	index = instfetch(2);
					disp = (char)(index&0377);
					printf("a%D@(%D,%c%D:%c)",reg,disp,
        			        (index&0100000)?'a':'d',(index>>12)&07,
					(index&04000)?'l':'w');
					break;

			  case 4:	index = instfetch(size==4?4:2);
					printf(IMDF, index);
					break;

			  default:	printf("???");
					break;
			}
			break;

	  default:	printf("???");
	}
}

printEA(ea,size)
long ea;
int size;
{
	printea((ea>>3)&07,ea&07,size);
}

mapsize(inst)
long inst;
{
	inst >>= 6;
	inst &= 03;
	return((inst==0) ? 1 : (inst==1) ? 2 : (inst==2) ? 4 : -1);
}

char suffix(size)
register int size;
{
	return((size==1) ? 'b' : (size==2) ? 'w' : (size==4) ? 'l' : '?');
}

omove(inst, s)
long inst;
char *s;
{
	int size;

	printf("\tmov%c\t",*s);
	size = ((*s == 'b') ? 1 : (*s == 'w') ? 2 : 4);
	printea((inst>>3)&07,inst&07,size);
	putchar(',');
	printea((inst>>6)&07,(inst>>9)&07,size);
}

obranch(inst,dummy)
long inst;
{
	long disp = inst & 0377;
	char *s; 

	s = "s ";
	if (disp > 127) disp |= ~0377;
	else if (disp == 0) { s = " "; disp = sxtword(instfetch(2))-2; }
	printf("\tb%s%s\t",bname[(int)((inst>>8)&017)],s);
	printf("0x%x",dot+disp);
}

oscc(inst,dummy)
long inst;
{
	printf("\ts%s\t",bname[(int)((inst>>8)&017)]);
	printea((inst>>3)&07,inst&07,1);
}

biti(inst, dummy)
long inst;
{
	printf("\t%s\t", bit[(int)((inst>>6)&03)]);
	if (inst&0x0100) printf("d%D,", inst>>9);
	else { printf(IMDF, instfetch(2)); putchar(','); }
	printEA(inst);
}

opmode(inst,opcode)
long inst;
{
	register int opmode = (int)((inst>>6) & 07);
	register int reg = (int)((inst>>9) & 07);
	int size;

	size = (opmode==0 || opmode==4) ?
		1 : (opmode==1 || opmode==3 || opmode==5) ? 2 : 4;
	printf("\t%s%c\t", opcode, suffix(size));
	if (opmode>=4 && opmode<=6)
	{
		printf("d%d,",reg);
		printea((inst>>3)&07,inst&07, size);
	}
	else
	{
		printea((inst>>3)&07,inst&07, size);
		printf(",%c%d",(opmode<=2)?'d':'a',reg);
	}
}

shroi(inst,ds)
long inst;
char *ds;
{
	int rx, ry;
	char *opcode;
	if ((inst & 0xC0) == 0xC0)
	{
		opcode = shro[(int)((inst>>9)&03)];
		printf("\t%s%s\t", opcode, ds);
		printEA(inst);
	}
	else
	{
		opcode = shro[(int)((inst>>3)&03)];
		printf("\t%s%s%c\t", opcode, ds, suffix(mapsize(inst)));
		rx = (int)((inst>>9)&07); ry = (int)(inst&07);
		if ((inst>>5)&01) printf("d%d,d%d", rx, ry);
		else
		{
			printf(IMDF, (rx ? rx : 8));
			printf(",d%d", ry);
		}
	}
}		

oimmed(inst,opcode) 
long inst;
register char *opcode;
{
	register int size = mapsize(inst);
	long const;

	if (size > 0)
	{
		const = instfetch(size==4?4:2);
		printf("\t%s%c\t", opcode, suffix(size));
		printf(IMDF, const); putchar(',');
		printEA(inst,size);
	}
	else printf(badop);
}

oreg(inst,opcode)
long inst;
register char *opcode;
{
	printf(opcode, (inst & 07));
}

extend(inst, opcode)
long	inst;
char	*opcode;
{
	register int size = mapsize(inst);
	int ry = (inst&07), rx = ((inst>>9)&07);
	char c;

	c = ((inst & 0x1000) ? suffix(size) : ' ');
	printf("\t%s%c\t", opcode, c);
	if (*opcode == 'e')
	{
		if (inst & 0x0080) printf("d%D,a%D", rx, ry);
		else if (inst & 0x0008) printf("a%D,a%D", rx, ry);
		else printf("d%D,d%D", rx, ry);
	}
	else if ((inst & 0xF000) == 0xB000) printf("a%D@+,a%D@+", ry, rx);
	else if (inst & 0x8) printf("a%D@-,a%D@-", ry, rx);
	else printf("d%D,d%D", ry, rx);
}

olink(inst,dummy)
long inst;
{
	printf("\tlink\ta%D,", inst&07);
	printf(IMDF, sxtword(instfetch(2)));
}

otrap(inst,dummy)
long inst;
{
	printf("\ttrap\t");
	printf(IMDF, inst&017);
}

oneop(inst,opcode)
long inst;
register char *opcode;
{
	printf("\t%s\t",opcode);
	printEA(inst);
}

pregmask(mask)
register int mask;
{
	register int i;
	register int flag = 0;

	printf("#<");
	for (i=0; i<16; i++)
	{
		if (mask&1)
		{
			if (flag) putchar(','); else flag++;
			printf("%c%d",(i<8)?'d':'a',i&07);
		}
		mask >>= 1;
	}
	printf(">");
}

omovem(inst,dummy)
long inst;
{
	register int i, list = 0, mask = 0100000;
	register int reglist = (int)(instfetch(2));

	if ((inst & 070) == 040)	/* predecrement */
	{
		for(i = 15; i > 0; i -= 2)
		{ list |= ((mask & reglist) >> i); mask >>= 1; }
		for(i = 1; i < 16; i += 2)
		{ list |= ((mask & reglist) << i); mask >>= 1; }
		reglist = list;
	}
	printf("\tmovem%c\t",(inst&100)?'l':'w');
	if (inst&02000)
	{
		printEA(inst);
		putchar(',');
		pregmask(reglist);
	}
	else
	{
		pregmask(reglist);
		putchar(',');
		printEA(inst);
	}
}

ochk(inst,opcode)
long inst;
register char *opcode;
{
	printf("\t%s\t",opcode);
	printEA(inst);
	printf(",%c%D",(*opcode=='l')?'a':'d',(inst>>9)&07);
}

soneop(inst,opcode)
long inst;
register char *opcode;
{
	register int size = mapsize(inst);

	if (size > 0)
	{
		printf("\t%s%c\t",opcode,suffix(size));
		printEA(inst);
	}
	else printf(badop);
}

oquick(inst,opcode)
long inst;
register char *opcode;
{
	register int size = mapsize(inst);
	register int data = (int)((inst>>9) & 07);

	if (data == 0) data = 8;
	if (size > 0)
	{
		printf("\t%s%c\t", opcode, suffix(size));
		printf(IMDF, data); putchar(',');
		printEA(inst);
	}
	else printf(badop);
}

omoveq(inst,dummy)
long inst;
{
	register int data = (int)(inst & 0377);

	if (data > 127) data |= ~0377;
	printf("\tmoveq\t"); printf(IMDF, data);
	printf(",d%D", (inst>>9)&07);
}

oprint(inst,opcode)
long inst;
register char *opcode;
{
	printf("\t%s",opcode);
}
