/*		Termbas - Basic Terminal Capability Package
				V.R. Pratt
				Mar., 1981

This file implements a terminal-testing program to determine the terminal type
when first started, along with a collection of generally useful terminal
functions.  If your terminal type is not represented, please add the
appropriate entries.
*/


int termtype = -1;

/* Table of terminal commands */

enum terminal	{	vt52,	h19,	concept	};
char cursmo[] = {	 'Y',	'Y',	 'a'	},
    *cursdi[] = {	"ABCD","ABCD",	";<=>"	},
     cleos[]  = {	 'J',	'J',	  3	},
     cleol[]  = {	 'K',	'K',	  19	};

putstr(s) char *s;
{while (*s) putchar(*s++);
}

queryterm()
{while (1) {
	putstr("\nSupply terminal type (hit ? for help)\n");
	termtype = 0;
 	switch(127&getchar()) {
		case '?':	putstr(" v=vt52, h=h-19, c=concept"); break;
		case 'c':	termtype++;
		case 'h':	termtype++;
		case 'v':	return;
		default:	putstr(" Unknown type.");
	}
 }
}

esc_char() {putchar('\033');}

cursorpos(x,y)
{switch(termtype) {
	case vt52:
	case h19:
	case concept:	esc_char(); putchar(cursmo[termtype]);
			putchar(y+' '); putchar(x+' ');
 }
}

cursorstep(dir)
{esc_char();
 putchar(cursdi[termtype][dir]);
}

clearscreen()
{esc_char();
 putchar(cleos[termtype]);
}

clearline()
{esc_char();
 putchar(cleol[termtype]);
}


