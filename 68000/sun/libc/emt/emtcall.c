/* LINTLIBRARY */
/*
 * emtcall.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_call(traptype[,arg1[,arg2[,arg3]]])
 *	emulator trap calling routine
 */

#include <sunemt.h>

int emt_call(trtype,trarg1,trarg2,trarg3)
int trtype;
int trarg1;
int trarg2;
int trarg3;
{
	asm("	movl a6@(20.),sp@-");
	asm("	movl a6@(16.),sp@-");
	asm("	movl a6@(12.),sp@-");
	asm("	movl a6@(8.),sp@-");
	asm("	trap #15.");
	asm("	addql #8.,sp");
}
