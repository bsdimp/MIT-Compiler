/* LINTLIBRARY */
/*
 * emtputchar.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_putchar(c)	-- prints character c on Console
 */

#include <sunemt.h>

int emt_putchar(c)
char c;
{
	return(
	    emt_call(EMT_PUTCHAR,c)
	);
}
