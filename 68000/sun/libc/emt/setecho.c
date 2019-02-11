/* LINTLIBRARY */
/*
 * setecho.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * setecho(flag) -- sets console echo mode:
 *		if (flag) then echo; else dont't echo;
 */

#include <sunemt.h>

setecho(flag)
int flag;
{
	return(
	    emt_call(EMT_SETECHO,flag)
	);
}
