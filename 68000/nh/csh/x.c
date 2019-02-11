char	xstr[];
#line 1 "sh.init.c"



#line 1 "./sh.local.h"


















#line 22 "./sh.local.h"





































#line 69 "./sh.local.h"


#line 81 "./sh.local.h"


#line 85 "./sh.local.h"


#line 89 "./sh.local.h"



#line 4 "sh.init.c"




extern	int await();
extern	int chngd();
extern	int doalias();
extern	int dobreak();
extern	int docontin();
extern	int doecho();
extern	int doelse();
extern	int doend();
extern	int doendif();
extern	int doendsw();
extern	int doexit();
extern	int doforeach();
extern	int doglob();
extern	int dogoto();
extern	int dohash();
extern	int dohist();
extern	int doif();
extern	int dolet();
extern	int dologin();
extern	int dologout();
extern	int donewgrp();
extern	int donice();
extern	int donohup();
extern	int doonintr();
extern	int dorepeat();
extern	int doset();

extern	int dosetenv();

extern	int dosource();
extern	int doswbrk();
extern	int doswitch();
extern	int dotime();

extern	int doumask();

extern	int dowhile();
extern	int dozip();
extern	int execash();
#line 49 "sh.init.c"

extern	int goodbye();
extern	int shift();
extern	int showall();
extern	int unalias();
extern	int dounhash();
extern	int unset();



struct	biltins {
	char	*bname;
	int	(*bfunct)();
	short	minargs, maxargs;
} bfunc[] = {
	(&xstr[1891]),		dolet,		0,	1000,
	(&xstr[691]),	doalias,	0,	1000,
#line 68 "sh.init.c"

	(&xstr[1893]),	dobreak,	0,	0,
	(&xstr[1899]),	doswbrk,	0,	0,
	(&xstr[1907]),		dozip,		0,	1,
	(&xstr[1912]),		chngd,		0,	1,
	(&xstr[1915]),	chngd,		0,	1,
	(&xstr[1921]),	docontin,	0,	0,
	(&xstr[873]),	dozip,		0,	0,
	(&xstr[109]),		doecho,		0,	1000,
	(&xstr[1930]),		doelse,		0,	1000,
	(&xstr[1935]),		doend,		0,	0,
	(&xstr[1939]),	dozip,		0,	0,
	(&xstr[1945]),	dozip,		0,	0,
	(&xstr[1951]),		execash,	1,	1000,
	(&xstr[1956]),		doexit,		0,	1000,
	(&xstr[832]),	doforeach,	3,	1000,
	(&xstr[977]),		doglob,		0,	1000,
	(&xstr[1961]),		dogoto,		1,	1,
#line 88 "sh.init.c"

	(&xstr[1112]),	dohist,		0,	0,
	(&xstr[1942]),		doif,		1,	1000,
	(&xstr[730]),	dologin,	0,	1,
	(&xstr[158]),	dologout,	0,	0,
	(&xstr[764]),	donewgrp,	1,	1,
	(&xstr[643]),		donice,		0,	1000,
	(&xstr[600]),	donohup,	0,	1000,
	(&xstr[1966]),	doonintr,	0,	2,
	(&xstr[1973]),	dohash,		0,	0,
	(&xstr[1980]),	dorepeat,	2,	1000,
	(&xstr[2033]),		doset,		0,	1000,

	(&xstr[1991]),	dosetenv,	2,	2,

	(&xstr[1998]),	shift,		0,	1,
	(&xstr[2004]),	dosource,	1,	1,
	(&xstr[2011]),	doswitch,	1,	1000,
	(&xstr[595]),		dotime,		0,	1000,

	(&xstr[2018]),	doumask,	0,	1,

	(&xstr[689]),	unalias,	1,	1000,
	(&xstr[2024]),	dounhash,		0,	0,
	(&xstr[2031]),	unset,		1,	1000,
	(&xstr[2037]),		await,		0,	0,
	(&xstr[2042]),	dowhile,	1,	1000,
	0,		0,		0,	0,
};





















struct srch {
	char	*s_name;
	short	s_value;
} srchn[] = {
	(&xstr[1891]),			13,
	(&xstr[1893]),		0,
	(&xstr[1899]),		1,
	(&xstr[1907]),			2,
	(&xstr[873]), 		3,
	(&xstr[1930]),			4,
	(&xstr[1935]),			5,
	(&xstr[1939]),		6,
	(&xstr[1945]),		7,
	(&xstr[1956]),			8,
	(&xstr[832]), 	9,
	(&xstr[1961]),			10,
	(&xstr[1942]),			11,
	(&xstr[2048]),		12,
	(&xstr[2033]),			14,
	(&xstr[2011]),		15,
	(&xstr[2042]),		18,
	0,		0,
};

char	*mesg[] = {
	0,
	(&xstr[2054]),
	0,
	(&xstr[2061]),
	(&xstr[2066]),
	(&xstr[2086]),
	(&xstr[2101]),
	(&xstr[2110]),
	(&xstr[2119]),
	(&xstr[2138]),
	(&xstr[2145]),
	(&xstr[2155]),
	(&xstr[2178]),
	0,
	(&xstr[2194]),
	(&xstr[2206]),
};
