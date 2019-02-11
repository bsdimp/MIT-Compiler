/*	SUN1 Dependent IO Macros for use in libc.a
 *			V.R. Pratt
 *			March, 1981
 *
 *
 * feeble attempt at commenting by Bill Nowicki
 * also fixed interrupt bug in the Design module routines.
 * March 1981
 * 17 June 1981 - Jeffrey Mogul -- removed design module stuff entirely
 */

/*
 * SUN-1 dependent part
 * modified by Bill Nowicki March 1981
 *	Added lineresettxint
 */

#include "vectors.h"
#include "nec7201.h"
#include "timer.h"

char wreg1[2][2] = {0,0,0,0};

#define linedata(line) *((char*)DEVADR+DATA+line*SEP)
#define linecontrol(line) *((char*)DEVADR+CONT+line*SEP)

#define DEVADR 0x600000
#define DATA 0
#define CONT 2
#define SEP  4
#define READYRX 1
#define READYTX 4
#define RXINTARM NECrxina /* why was this commented out?  Stops it compiling */
#define TXINTARM NECtxint
#define select(reg) *linectrl = reg

lineservice(serv) 
 {
  IRQ5Vect = serv;
 }

#define NECtxrts 	2	/* RTS */
#define NECtxena	8	/* Tx enable */
#define NECtx8bt	0x60	/* Tx 8 bit characters */
#define NECdtr		0x80	/* Data Terminal Ready */

char NECinit[] = 
  {
    NECchres,
    NECchres,					/* one for luck? */
    2,	4,					/* some problem with clrb */
    4,	NECrx1sb+NEC16clk,			/* 1 stop bit, 16X clock */
    3,	NECrxena+NECrx8bt+NECautoe,		/* 8 data bits, rest normal */
    5,	NECtxrts+NECtxena+NECtx8bt+NECdtr,	/* 8 data bits, rest normal */
    0						/* delimiter */
  };


linereset(line) 
{
	register char *i = NECinit;

	while (*i) linecontrol(line) = *i++;
}

lineresettxint(line)
  {
   linecontrol(line) = (char)NECtxres;
  }

lineget(line)
 {
  return linedata(line);
 }

lineput(line,chr) char chr;
 {
  linedata(line) = chr;
 }

linereadyrx(line)
 {
   return linecontrol(line)&READYRX;
 }

linereadytx(line)
 {
  return linecontrol(line)&READYTX;
 }


lineset(line,reg,val) 
 char val;
 {
   register char *wreg = &wreg1[reg][line];
   register char *linectrl = &linecontrol(line);
	 select(reg);
	 *linectrl = *wreg |= val;
  }


lineclear(line,reg,val) char val;
 {
   register char *wreg = &wreg1[reg][line];
   register char *linectrl = &linecontrol(line);
	 select(reg);
	 *linectrl = *wreg &= ~val;
  }


linearmrx(line)
 {
  lineset(line,1,RXINTARM);
 }


linedisarmrx(line)
 { 
  lineclear(line,1,RXINTARM);
 }


linearmtx(line)
 {
   lineset(line,1,TXINTARM);
 }

linedisarmtx(line)
 {
   lineclear(line,1,TXINTARM);
 }
