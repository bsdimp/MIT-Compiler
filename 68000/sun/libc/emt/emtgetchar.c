/* LINTLIBRARY */
/*
 * emtgetchar.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * char emt_getchar()	-- returns character read from console keyboard
 */

#include <sunemt.h>

char emt_getchar()
{
	return(
	    emt_call(EMT_GETCHAR)
	);
}
