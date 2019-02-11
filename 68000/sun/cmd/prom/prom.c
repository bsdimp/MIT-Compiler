/*                     Prom Burner via 68000 Design Module             */
#include "ACIA.c"


#define outputenable	0x0800
#define sample		0x1000
#define pulse 		0x2000
#define chipenable	0x4000
#define programming	(PIAAData & sample)
#define defaultdata	0xFFFF

#define Prom2K 1
#define Prom4K 2

unsigned short promcode[4095], address, data;
unsigned short baseaddress=0x1000;
unsigned char checksum, badchecksum, badburn, mode=Prom2K;
char unixcommand[127]="\ndll promcode.hex\n";

ReadInit()
{PIABData = 0xFFFF;
 PIABControl = 0x0000;		/* Change data port to input */
 PIABData = 0x0000;
 PIABControl = 0x0404;
 if (mode==Prom2K) PIAAData = 0x0000; else PIAAData = chipenable;
}

WriteInit()
{PIABData = 0xFFFF;		/* Change data port to output */
 PIABControl = 0x0000;
 PIABData = 0xFFFF;
 PIABControl = 0x0404;
 if (mode==Prom2K) PIAAData = 0x0000; else PIAAData = chipenable;
}


PIAInit()
{PIAAControl = 0x0404;
 PIAAData = 0x0000;
 PIAAControl = 0x0000;		/* Clear control register to access DDR's */
 PIAAData = 0xEFFF;		/* Port A configured for output */
 PIAAControl = 0x0404;		/* Access data registers */
 ReadInit();
}

Delay()
{/* Delay sampling one-shot for 2us address settling time */}


ProgramProm()
{unsigned short address, passcount;
 WriteInit();
 for (address=0; address<2048*mode; address++)
     {if (promcode[address] != 0xFFFF)		/* Skip no mod locations */
        {PIABData = promcode[address];		/* Write data to prom */
	 while programming;
	 if (mode==Prom2K)
	      PIAAData = pulse + chipenable + outputenable + sample + address;
	 else 
	      PIAAData = pulse + sample + address;
	 Delay();				/* Wait for one-shot to fire */
	 while programming;			/* Sample programming pulse */
	 if (mode==Prom2K)
	      PIAAData = outputenable + address;
	 else
	      PIAAData = chipenable + address;
	}
      if (address % 128 == 0) stringout(".");
     }
 ReadInit();
}

VerifyProm()
{unsigned short address;
 ReadInit();
 if (mode==Prom4K) PIAAData = 0x0000;
 badburn = 0;
 for (address=0; address<2048*mode; address++)
	{PIAAData = address;			/* Set up prom address */
	 Delay();
	 while (programming);
	 if (promcode[address]!=PIABData)
		{badburn = 1;}
	}
 if (mode==Prom4K) PIAAData = chipenable;
}


chartohex(chr) 				/* Convert ascii hex to hex */
char chr;
{if (chr>'9') chr = chr - 'A' + 10;
 else chr = chr - '0';
 return(chr);
}


getbyte(uart)
char uart;
{int word;
 char digit;
 digit = chartohex(getchar(uart));
 word = 16*digit;
 digit = chartohex(getchar(uart));
 word = word + digit;
 if (uart==2) checksum = checksum + word;
 return(word);
}

initcode()
{for (address=0; address<2048*mode; address++) promcode[address] = defaultdata;
}


ReadCode(command) char command[];
{int i, count, address;
 unsigned short data;
 char chr, code=0, validdata, records;
 i = 0;
 records = 0;
 initcode();
 while (command[i]) putchar(command[i++],2);
 while (code!='8') 
	{chr = getchar(2);
	 if (chr == 'S')
	 	{code = getchar(2);
		 if ((code == '2') || (code == '8')) 
			{checksum = 0;
			 records++;
			 count = getbyte(2);
			 address = getbyte(2);
			 address = 256*address + getbyte(2);
			 address = 256*address + getbyte(2) - baseaddress;
			 address = address >> 1;
			 if (address>=0 && address<2048*mode) validdata = 1;
			 else validdata = 0;
			 for (i=0; i<(count-4)/2; i++)
			  {data = getbyte(2);
			   data = (data << 8) + getbyte(2);
			   if (validdata) promcode[address] = data;
			   address++;
			  }
			 chr = getbyte(2); 	
			 if (checksum != 0xFF) return(1);
			 if (records % 8 == 0) putchar('.',1);
			}
		}
	}	
return(0);
}


PromErased()
{int prombad;
 ReadInit();
 if (mode==Prom4K) PIAAData = 0x0000;
 prombad = 0;
 address = 0;
 while ((address<2048*mode) && (prombad == 0))
	{PIAAData = address++;
	 Delay();
	 while (programming) ;
	 data = PIABData;
	 if (data != 0xFFFF) prombad = 1;
 	}
 if (mode==Prom4K) PIAAData = chipenable;
 return(prombad);
}


hextochar(number)			/* Convert hex to ascii hex */
char number;
{if (number<10) number = number + '0';
 else number = number - 10 + 'A';
 return(number);
}

putbyte(number)
unsigned char number;
{putchar(hextochar(number >> 4),1);
 putchar(hextochar(number & 0x0F),1);
}


stringout(string) char string[];
{short pointer=0;
 while (string[pointer]) putchar(string[pointer++],1);
}

upload()
{unsigned short address,data;
 ReadInit();
 if (mode==Prom4K) PIAAData = 0x0000;
 for (address=0; address<2048*mode; address++)
	{PIAAData = address;
	 Delay();
	 while (programming);
	 promcode[address] = PIABData;
	}
 if (mode==Prom4K) PIAAData = chipenable;
}

displaycode()
{unsigned short address,datacount,linenumber;
 char chr;
 address=0;
 while (address<2048*mode)
    {for (linenumber=0; linenumber<16; linenumber++)
	{putbyte(address >> 7);
	 putbyte((address << 1) & 0xFF);
	 stringout("   ");
	 for (datacount=0; datacount<16; datacount++) 
		{putbyte(promcode[address]>>8);
		 putbyte(promcode[address++]);
		}
	 putchar('\n',1);
	}
     if (address<2048*mode)
     	{stringout("More?");	
     	 chr = getchar(1);
     	 putchar('\n',1);
	 if (chr == 'N' || chr == 'n') break;
	}
    }
}

burnprom()
{stringout("Programming");
 ProgramProm();
 if (mode==Prom2K) 
     {VerifyProm();
      if (badburn) stringout("Programming error!\n");
      else stringout("OK\n");
     }
 else stringout("Done\n");
 stringout("Switch to +5V BEFORE proceeding!\n");
}

ReadUnixCommand()
{char chr=' ',i=1;
 stringout("New unix command line: ");
 unixcommand[0] = '\n';
 while (chr != '\015') 
	{chr = getchar(1);
	 if (chr == '\177')
	 	{if (i>1) 
			{i--;
			 putchar('\010',1);putchar(' ',1);putchar('\010',1);
			}
		 else putchar('\007',1);
		}
	 else
		unixcommand[i++] = chr;
	}
 unixcommand[i] = '\0';
 putchar('\n',1);
}

SetBaseAddress()
{char chr;
 stringout("New base address: ");
 baseaddress = getbyte(1);
 baseaddress = (baseaddress << 8) + getbyte(1);
 putchar('\n',1);
}


main()
{int bufferemptydelay=10000;
 char command=' ';
 ACIAInit(1);
 ACIAInit(2);
 PIAInit();
 while (command != 'Q') 
	{if (mode==Prom2K) stringout("Prom>"); else stringout("Prom4K>");
	 command = getchar(1) & 0xDF;
	 putchar('\n',1);
	 switch(command) 
		{case 'U': upload();
			   break; 
		 case 'R': stringout("Downloading");
			   if (ReadCode(unixcommand))
				stringout("Checksum error\n");
			   else
				stringout("OK\n");
			   break; 
		 case 'D': displaycode();
			   break;
		 case 'E': if (PromErased() == 0)
				stringout("Prom Erased\n");
			   else
				stringout("Prom partially burned\n");
			   break;
		 case 'B': burnprom();
			   break;
		 case 'V': VerifyProm();
			   if (badburn) stringout("Error, prom different\n");
			   else stringout("Verified, prom = code\n");
			   break;
		 case 'C': initcode();
			   break;
		 case 'F': ReadUnixCommand();
			   break;
		 case 'A': SetBaseAddress();
			   break;
		 case 'M': if (mode==Prom2K) mode=Prom4K; else mode=Prom2K;
			   break;
		 case ' ':
		 case 'Q': break;
		 default:  stringout("Valid commands are:\n");
			   stringout("      U - upload from prom\n");
			   stringout("      R - download prom code\n");
			   stringout("      D - display prom code\n");
			   stringout("      E - verify prom erased\n");
			   stringout("      B - burn prom with code\n");
			   stringout("      V - verify prom against code\n");
			   stringout("      C - set code to default value\n");
			   stringout("      F - read new unix command line\n");
			   stringout("      A - set prom base address\n");
			   stringout("      M - toggle between 2K-4K mode\n");
			   stringout("      Q - quit and return to MACSBUG\n");
			   break;
		}
	}
 while (bufferemptydelay--);
}
