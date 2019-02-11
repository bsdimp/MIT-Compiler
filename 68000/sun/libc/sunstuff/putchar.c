/*
 * putchar.c - print a character on standard output
 *
 * An undocumented hack by some annonymous hacker
 *
 * Documented by Bill Nowicki April 1982
 *	- Changed to use emt_putchar instead of:
 */

/*
 *	_doputchar(c)
 *	register char c;
 *	{
 *		while (!linereadytx(0));
 *		lineput(0,c);
 *	}
 */


putchar(c)
register char c;
  {
    /*
     *	if (c == '\n') emt_putchar('\r');
     */
	emt_putchar(c);
  }
