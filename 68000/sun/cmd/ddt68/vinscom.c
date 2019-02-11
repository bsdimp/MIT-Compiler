/* 			Compiler for ins68
 *			    V.R. Pratt
 *			    Jan., 1981
 * modified jun 81 by jrl @ Lucasfilm for dissassembler to run on the vax
 */

#include <stdio.h>
#define TABSIZ 128
#define WORDSIZ 16

int line=0, argno, mask, pattern, i, pnt, comma, postc, space;
char modif, length, string[64], 
       prev=0, current=0, next=0,
       sizmod, revargs, more = 1, 
       table[TABSIZ];
/* Translation tables */
  char *mcod = "nijuxyrglpt";			/* modifiers */
  char *trm  = "01D77703456";			/* modifier formats */
  char *pcod = "dDaAeEsnuvmfFcrijxyrk";		/* permissible parameters */
  char *pfmt = "ddaaeEsnuvmffcrnnxyrk";		/* parameter formats */
  char *fcod = "kdaEesvnuyxmfcr";		/* case order for formats */

main()
 {get(); get();
  while (more)
	{i=TABSIZ; while (i) table[--i] = -1;
	 while (more && current != '\n') get();	/* skip to end of line */
	 while (more && next == '\n') get();	/* skip nl's */
	 if (next == EOF) break;
	 line++;
	 modif = argno = sizmod = revargs = mask = pattern = 0;
	 for (i=WORDSIZ;i--;)			/* process 16-bit word */
	   {mask <<= 1; pattern <<= 1;
	    if	    ((get()&-2) == '0')
	       	    {mask++; pattern += current&1;}
	    else if (table[current] < 0) 	/* new argument */
		   {if (current != '.')		/* . is dummy arg */
		       {table[current] = argno++;
		        pattern++;		/* leading 1 delimits field */
		        if (current == 'm') revargs = 1;
		        if (current == 's') sizmod = 1;
		       }
		   }
	    else if (current == prev)
		    {if (current == 's') sizmod = 0;}
	    else fprintf(stderr,"Repeat arg on line %d\n",line);
	   }
	 for (i=TABSIZ;i--;) if (table[i]>=0) table[i] = argno-table[i]-1;
	 if (get() == ',') 
	   while (more && get() != '\t')
	    {i = pos(current,mcod);
	     modif |= trm[i]=='D'? 3: 1<<(trm[i]-'0');
	     if (current == 'g')		/* g is 0000kkkknnnnnnnn */
		{table['k'] = argno++;		/* d/a index register */
		 table['n'] = argno++;		/* 8-bit signed displacement */
		}
	     else if (i<8)			/* nijuxyrg denote an arg */
		     table[current] = argno++;
	    }
	 if (sizmod) modif |= 64;
	 while (next == '\t') get();		/* skip tabs */
	 pnt = 0;				/* initialize output buffer */
	 while (more && get() != '\n') compchar();/* compile string */
	 if (revargs) {string[pnt++] = (char)(0213|(table['m']<<4));
		       string[space] = postc+1-space;
		       string[comma] = pnt+1-comma;
		       string[postc] = space+1-postc;
		       string[pnt]   = comma+1-pnt;
		       pnt++;
		      }
	 length = 6+pnt;
	 pnt = 0;
	 out(length);
	 out(modif);
/* invert this for Vax
	 out(mask>>8); out(mask&255);
	 out(pattern>>8); out(pattern&255);
 */
	 out(mask&255); out(mask>>8);
	 out(pattern&255); out(pattern>>8);

	 while (pnt<length-6) out(string[pnt++]);
	 if (length&1) out(' ');
	 putchar('\n');
	}
  printf("0 \n");
 }

char
norm(x) char x; {return('A' <= x && x <= 'Z'? x+32: x);}

compchar()
 {if (current < 'A' || prev > '@' || next > '@' || table[current] < 0)
   {if (current != '.')			/* . is dummy */
     {string[pnt++] = current; 
      if (revargs)
	 {if (current == ',') {string[pnt++] = 0213|(table['m']<<4);
			       postc = pnt++;
			      }
	  if (current == ' ') {string[pnt++] = 0213|(table['m']<<4);
			       space = pnt++;
			      }
	 }
     }
   }
  else {string[pnt++] = 0200|				  /* identifying bit */
	   	   	(table[current] << 4)|		  /* arg no */
	      		pos(pfmt[pos(current,pcod)],fcod);/* format */
	if (norm(current) == 'f') 
	   {get();					     /* erase ( */
	    do {string[pnt++] = get();} 
	       while (current != ')'); 			     /* skip commas */
	   }
       }
  if (revargs && next == ',')
       {string[pnt++] = 0213|(table['m']<<4);
	comma = pnt++;
       }
 }

get()
 {prev = current; current = next; if (next != EOF) next = getchar(); 
  if (current == EOF) more = 0;
  return (current);}

pos(c,s) char c, *s;
 {int i=0; 
  while (s[i] && s[i] != c) i++;
  if (s[i]) return(i);
  else fprintf(stderr,
    "Unexpected char %o on line %d in %c%c%c\n",c,line,prev,current,next);
 }

out(c) unsigned char c;
 {printf("%d,",c);}

