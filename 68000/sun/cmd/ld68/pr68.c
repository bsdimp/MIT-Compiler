#include <stdio.h>
#include "b.out.h"

FILE *in;
struct bhdr bhdr;

main(argc,argv) int argc; char *argv[];
  {	if (argc != 2) error('f',"Usage: pr68 filename");
	in = fopen(argv[1],"r");
	if (in == NULL) error('f',"Couldn't open %s for input",argv[1]);
	header();
	text();
	data();
	symbols();
	rtext();
	rdata();
  }

header()
  {	if (fread(&bhdr,sizeof bhdr,1,in) != 1)
	  error('w',"error reading header");
	printf("Magic Number: %ld\n",bhdr.fmagic);
	printf("Text Size: %ld bytes\n",bhdr.tsize);
	printf("Data Size: %ld bytes\n",bhdr.dsize);
	printf("BSS Size: %ld bytes\n",bhdr.bsize);
	printf("Symbol Table Size: %ld bytes\n",bhdr.ssize);
	printf("Text Relocation Size: %ld bytes\n",bhdr.rtsize);
	printf("Data Relocation Size: %ld bytes\n",bhdr.rdsize);
	printf("Entry Location: %ld\n",bhdr.entry);
  }

text()
  {	long i;
	char l[4];
	printf("\nText Segment\n");
	if (bhdr.tsize%4 != 0) error('w',"text size not multiple of 4");
	for (i=0; i<bhdr.tsize; i+=4)
	  {	if (fread(l,sizeof l,1,in) != 1)
			error('w',"read error in text section");
/*		printf("%ld: %3d %3d %3d %3d\n",i,l[0],l[1],l[2],l[3]); */
	  }
  }

data()
  {	long i;
	char l[4];
	printf("\nData Segment\n");
	if (bhdr.tsize%4 != 0) error('w',"data size not multiple of 4");
	for (i=0; i<bhdr.dsize; i+=4)
	  {	if (fread(l,sizeof l,1,in) != 1)
			error('w',"read error in text section");
/*		printf("%ld: %3d %3d %3d %3d\n",i,l[0],l[1],l[2],l[3]); */
	  }
  }

symbols()
  {	short count = 0;
	long i;
	struct sym sym;
	char s[SYMLENGTH],*sp;
	printf("\nSymbol Table\n");
	for (i=0; i < bhdr.ssize; i+=sizeof sym)
	  {	if (fread(&sym,sizeof sym,1,in) != 1)
			error('w',"read error in symbol table section");
		for (sp=s; *sp = getc(in); sp++) i++;
		i++;
		printf("%d: %c%c %ld %s\n",count++,
		  " E??????"[sym.stype/040],
		  "UATDBCR?????????????????????????"[sym.stype&037],
		  sym.svalue,s);
	  }
  }

rtext()
  {	long i;
	struct reloc reloc;
	printf("\nText Relocation Commands\n");
	for (i=0; i<bhdr.rtsize; i+=sizeof reloc)
	  {	if (fread(&reloc,sizeof reloc,1,in) != 1)
			error('w',"error reading text relocation commands");
		printf("%c %c %c %d %ld\n","TDBE"[reloc.rsegment],
		  "BWL?"[reloc.rsize]," D"[reloc.rdisp],reloc.rsymbol,
		  reloc.rpos);
	  }
  }

rdata()
  {	long i;
	struct reloc reloc;
	printf("\nData Relocation Commands\n");
	for (i=0; i<bhdr.rdsize; i+=sizeof reloc)
	  {	if (fread(&reloc,sizeof reloc,1,in) != 1)
			error('w',"error reading data relocation commands");
		printf("%c %c %c %d %ld\n","TDBE"[reloc.rsegment],
		  "BWL?"[reloc.rsize]," D"[reloc.rdisp],reloc.rsymbol,
		  reloc.rpos);
	  }
  }

/* VARAGRS 2 */
error(t,s,a,b,c,d,e,f,g,h,i,j) char t; char *s;
  {	fprintf(stderr,"pr68: ");
	fprintf(stderr,s,a,b,c,d,e,f,g,h,i,j);
	fprintf(stderr,"\n");
	switch (t)
	  { case 'w':	return;
	    case 'f':	exit(1);
	    case 'a':	abort();
	    default:	error('w',"Illegal error type: '%c'",t);
	  }
  }

