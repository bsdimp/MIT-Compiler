#include <stdio.h>
#include <b.out.h>

FILE *in;
struct bhdr bhdr;
char options[13] = "111111";

main(argc,argv) int argc; char *argv[];
  {	if (argc!=2 && argc!=3) error('f',"Usage: pr68 filename [111111]");
	in = fopen(argv[1],"r");
	if (in == NULL) error('f',"Couldn't open %s for input",argv[1]);
	if (argc == 3) { strcpy(options,argv[2]); strcat(options,"000000"); }
	header();
	text();
	data();
	symbols();
	rtext();
	rdata();
  }

header()
{
/*	if (fread(&bhdr,sizeof bhdr,1,in) != 1)
		error('w',"error reading header");	*/
	get68(in, &bhdr.fmagic, sizeof(bhdr.fmagic));
	get68(in, &bhdr.tsize, sizeof(bhdr.tsize));
	get68(in, &bhdr.dsize, sizeof(bhdr.dsize));
	get68(in, &bhdr.bsize, sizeof(bhdr.bsize));
	get68(in, &bhdr.ssize, sizeof(bhdr.ssize));
	get68(in, &bhdr.rtsize, sizeof(bhdr.rtsize));
	get68(in, &bhdr.rdsize, sizeof(bhdr.rdsize));
	get68(in, &bhdr.entry, sizeof(bhdr.entry));
	if (options[0] == '1')
	  {	printf("Magic Number: %ld\n",bhdr.fmagic);
		printf("Text Size: %ld bytes\n",bhdr.tsize);
		printf("Data Size: %ld bytes\n",bhdr.dsize);
		printf("BSS Size: %ld bytes\n",bhdr.bsize);
		printf("Symbol Table Size: %ld bytes\n",bhdr.ssize);
		printf("Text Relocation Size: %ld bytes\n",bhdr.rtsize);
		printf("Data Relocation Size: %ld bytes\n",bhdr.rdsize);
		printf("Entry Location: %ld\n",bhdr.entry);
	  }
  }

text()
  {	long i;
	char l[4];
	printf("\nText Segment\n");
	if (bhdr.tsize%4 != 0) error('w',"text size not multiple of 4");
	for (i=0; i<bhdr.tsize; i+=4)
	  {	if (fread(l,sizeof l,1,in) != 1)
		  error('w',"read error in text section");
		if (options[1] == '1')
		  printf("%6X:	%2x %2x %2x %2x\n",
		    i,l[0]&0377,l[1]&0377,l[2]&0377,l[3]&0377);
	  }
  }

data()
  {	long i;
	char l[4];
	printf("\nData Segment\n");
	if (bhdr.tsize%4 != 0) error('w',"data size not multiple of 4");
	for (i=0; i<bhdr.dsize; i+=4)
	  {	if (fread(l,sizeof l,1,in) != 1)
		  error('w',"read error in data section");
		if (options[2] == '1')
		  printf("%6X:	%2x %2x %2x %2x\n",
		    i,l[0]&0377,l[1]&0377,l[2]&0377,l[3]&0377);
	  }
  }

symbols()
  {	short count = 0;
	long i;
	struct sym sym;
	char s[SYMLENGTH],*sp;
	printf("\nSymbol Table\n");
	for (i=0; i < bhdr.ssize; i+=(sizeof(sym.stype)+sizeof(sym.svalue)))
	{
/*		if (fread(&sym,sizeof sym,1,in) != 1)
		  error('w',"read error in symbol table section");	*/
		get68(in, &sym.stype, sizeof(sym.stype));
		get68(in, &sym.svalue, sizeof(sym.svalue));
		for (sp=s; *sp = getc(in); sp++) i++;
		i++;
		if (options[3] == '1')
		  printf("%5d: %c%c %6X %s\n",count++,
		    " E??????"[sym.stype/(040<<8)],
		    "UATDBCR?????????????????????????"[(sym.stype>>8)&037],
		    sym.svalue,s);
	  }
  }

rtext()
  {	long i;
	struct reloc reloc;
	printf("\nText Relocation Commands\n");
	for (i=0; i<bhdr.rtsize; i+=sizeof reloc)
	{
/*		if (fread(&reloc,sizeof reloc,1,in) != 1)
		  error('w',"error reading text relocation commands");	*/
		get68(in, &reloc.rinfo, sizeof(reloc.rinfo));
		get68(in, &reloc.rsymbol, sizeof(reloc.rsymbol));
		get68(in, &reloc.rpos, sizeof(reloc.rpos));
		if (options[4] == '1')
			printf("%c %c %c %5d %X\n",
				"TDBE"[(reloc.rinfo>>(6+8))&03],
				"BWL?"[(reloc.rinfo>>(4+8))&03],
				" D"[(reloc.rinfo>>(3+8))&01],
				reloc.rsymbol, reloc.rpos);
	  }
  }

rdata()
  {	long i;
	struct reloc reloc;
	printf("\nData Relocation Commands\n");
	for (i=0; i<bhdr.rdsize; i+=sizeof reloc)
	{
/*		if (fread(&reloc,sizeof reloc,1,in) != 1)
		  error('w',"error reading data relocation commands");	*/
		get68(in, &reloc.rinfo, sizeof(reloc.rinfo));
		get68(in, &reloc.rsymbol, sizeof(reloc.rsymbol));
		get68(in, &reloc.rpos, sizeof(reloc.rpos));
		if (options[5] == '1')
			printf("%c %c %c %5d %X\n",
				"TDBE"[(reloc.rinfo>>(6+8))&03],
				"BWL?"[(reloc.rinfo>>(4+8))&03],
				" D"[(reloc.rinfo>>(3+8))&01],
				reloc.rsymbol, reloc.rpos);
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

get68(file, p, c)
register FILE	*file;
register char	*p;
register c;
{
	if(c == 2) {
		*(short *)p = getc(file);
		*(short *)p = *(short *)p << 8 | getc(file);
	}
	else {
		*(long *)p = getc(file);
		*(long *)p = *(long *)p << 8 | getc(file);
		*(long *)p = *(long *)p << 8 | getc(file);
		*(long *)p = *(long *)p << 8 | getc(file);
	}

	if (feof(file)) error('f', "unexpected eof");
	if (ferror(file)) error('f', "read error encountered");
}
