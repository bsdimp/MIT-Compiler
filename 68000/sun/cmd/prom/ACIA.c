#include "mul.c"
#include "mdm.h"
#include "reentrant.h"

ACIAInit(uart)
char uart;
{int i=1000;
 if (uart == 1)
	{ACIA1Status = ACReset;
 	 ACIA1Status = Div16 + Da8St1;
	}
 else
 	{ACIA2Status = ACReset;
 	 ACIA2Status = Div16 + Da8St1;
	}
 while (i-->0);			/* Let settle */
}

putchar(chr,uart) char chr,uart;
{if (uart==1)
	{if (chr == '\012') putchar('\015',1);	/* Precede LF by CR */
	 while (!ACIA1TrReady);	/* Wait until previous character sent */
	 ACIA1Data = chr;
	}
else
	{if (chr == '\012') putchar('\015',2);	/* Precede LF by CR */
	 while (!ACIA2TrReady);	/* Wait until previous character sent */
	 ACIA2Data = chr;
	}
}

getchar(uart)
char uart;
{char chr;
 if (uart==1)
	{while (!ACIA1RcReady);		/* Wait for next character to arrive */
	 chr = ACIA1Data & 0x7F;
	 putchar(chr,1);		/* Echo for terminal */
	 return(chr);
	}
 else
	{while (!ACIA2RcReady);		/* Wait for next character to arrive */
	 return(ACIA2Data & 0x7F);
	}
}
