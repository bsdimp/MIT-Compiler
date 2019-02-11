/* Reformat b.out file so that longs are byte-reversed to permit convenient
reading by the 68000.  Relocation commands are fixed to agree with the c68
convention for packing fields, to permit reuse of struct reloc.

   Author: V.R. Pratt
   Date:   March, 1981
*/

#include "b.out.h"
#include <stdio.h>

struct sym68 {			/* fake sym for 68000 */
	short dummy1;		/* ignored */
	char stype;		/* type */
	char slength;		/* length */
	long svalue;
};

struct reloc68 {		/* fake reloc for 68000 */
	unsigned dummy1:3;		/* to complete the byte */
	unsigned rdisp:1;		/* 1 => a displacement */
	unsigned rsize:2;		/* RBYTE, RWORD, or RLONG */
	unsigned rsegment:2;	/* RTEXT, RDATA, RBSS, or REXTERN */
	char dummy2;		/* needs to be zero */
	short rsymbol;		/* id of the symbol of external relocations */
	long rpos;		/* position of relocation in segment */
};

reverse(lwrd) unsigned lwrd;
 {return((lwrd>>24)	     |
	 (lwrd>>8 & 0xff00)  |
	 (lwrd<<8 & 0xff0000)|
	 (lwrd<<24)
	);
 }

sreverse(wrd) unsigned wrd;
 {return((wrd>>8 & 0xff)    |
	 (wrd<<8 & 0xff00)
	);
 }

#define RCDSIZE 256

outbin(file,size,ofile)
FILE *file, *ofile;
{
int count,			/* counts total number of bytes processed*/
    Dcount;			/* number of bytes in current record */
char buffer[RCDSIZE];		/* buffer for data */
    for(count=0; count<size; count += RCDSIZE) 
	{Dcount= (size-count<RCDSIZE) ? size-count : RCDSIZE;
	 if(fread(buffer,Dcount,1,file) != 1)
	     {printf("Read error\n"); exit(1);}
	 fwrite(buffer,Dcount,1,ofile);
	}
}

struct reloc relcom; 
struct reloc68 orelcom;

main(argc,argv)
int argc;
char *argv[];
{
struct bhdr filhdr, nfilhdr;
FILE *infile, *outfile;
char filename[30], ofilename[30];
int i;
struct sym s; struct sym68 s68; char c; int pos, poso=0;

    if(argc<2)
	{printf("Usage: rev68 filename [ outfile ]\n"); /* Default: r.out */
	 exit(1);
	}
    strcpy(filename,argv[1]);   			/* extract file name */
    if((infile=fopen(filename,"r"))==NULL)		 /* open object file*/
       {strcat(filename,".68");     			 /* try .68 form */
	if ((infile=fopen(filename,"r"))==NULL) 
           {printf("rev68: Can't open %s\n",filename);
	    exit(1);
	   }
       }
    if(fread(&filhdr, sizeof(struct bhdr),1,infile) != 1)
	{printf("rev68: %s wrong format\n",filename);/*get header information*/
	 exit(1);
	}
    if(filhdr.fmagic != FMAGIC && filhdr.fmagic != NMAGIC) /* check magic number */
	{printf("rev68: %s not proper .68 file\n",filename); exit(1);}
    if (argc >= 3) strcpy(ofilename, argv[2]);
    else strcpy(ofilename, "r.out");
    if ((outfile = fopen(ofilename,"w")) == NULL)
       {printf("rev68: Can't write %s\n", ofilename);
	exit(1);
       }
    {int n, *hdr = (int*)&filhdr, *nhdr = (int*)&nfilhdr;
     for (n=0; n<8; n++) *nhdr++ = reverse(*hdr++); /* even reverse magic */
    }
    fwrite(&nfilhdr, sizeof(struct bhdr), 1, outfile);
    outbin(infile, filhdr.tsize + filhdr.dsize, outfile);
     for (pos=0; pos < filhdr.ssize; )
       {if (!fread(&s,sizeof s,1,infile)) break;/* Get symbol descriptor */
	pos += sizeof s;
	s68.stype = s.stype;
	s68.slength = s.slength;
	s68.svalue = reverse(s.svalue);
	fwrite((int)&s68+2,6,1,outfile);
	poso += 6;
	while (c = getc(infile)) 
	      {putc(c, outfile);
	       pos++; poso++;
	      }
	putc(0, outfile);
	pos++; poso++;
	if (poso&1) 
	   {putc(0, outfile);		/* word align for 68000 */
	    poso++;
	   }
       }
     while (fread(&relcom, sizeof relcom,1,infile))
	  {orelcom.rdisp = relcom.rdisp;
	   orelcom.rsize = relcom.rsize;
	   orelcom.rsegment = relcom.rsegment;
	   orelcom.rsymbol = sreverse(relcom.rsymbol);
	   orelcom.rpos = reverse(relcom.rpos);
	   orelcom.dummy1 = 0;
	   orelcom.dummy2 = 0;
	   fwrite(&orelcom, sizeof orelcom, 1, outfile);
	  }
    poso = reverse(poso);
    fseek(outfile, 16, 0);
    fwrite(&poso, sizeof poso, 1, outfile);	/* adjust filhdr.ssize */
    fclose(infile);
    fclose(outfile);
}



