/* non general modes */
#define	REGFLD	1
#define	QUICK	2
#define	SHORT	3
#define	IMM	4
#define	DISP	5
#define	DISPPC	6
#define	PROCREG	7
#define	MMUREG	8

/* general modes */
#define	GENMODE	0x10
#define	READB	(GENMODE + 0)
#define	READW	(GENMODE + 1)
#define	READD	(GENMODE + 2)
#define	WRITEB	(GENMODE + 4)
#define	WRITEW	(GENMODE + 5)
#define	WRITED	(GENMODE + 6)
#define	RMWB	(GENMODE + 8)
#define	RMWW	(GENMODE + 9)
#define	RMWD	(GENMODE + 10)
#define	RMW2B	RMWW
#define	RMW2W	RMWD
#define	RMW2D	(GENMODE + 11)
#define	REGADDR	(GENMODE + 12)
#define	ADDR	(GENMODE + 13)
