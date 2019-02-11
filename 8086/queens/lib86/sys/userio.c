/* Default low-level CRT/Keyboard IO for IBM Acorn	6/82 SAW
 * May be replaced by user-supplied routines, eg for bitmap or for
 * terminal emulation.
 */

/* Write n characters to screen:					*/

_user_out(p, n)
/* slightly modified by Bill O'Farrell to put CRs in */
  register char *p;
  register int n;
 {	while (n--){
		if (*p == '\n')
			dos(2,'\r');
		dos(2,*p++);
	}
	return 0;
 }


/* Read n characters from kbd:						*/

_user_in(p, n)
 register char *p;
 register int n;
 {	register count = 0;
	for (;n--;count++) *p++ = dos(1);
 }
