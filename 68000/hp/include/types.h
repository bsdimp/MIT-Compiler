#define NREGS_S	 13		/* number of regs saved in save (a/d2-7,pc) */

typedef	struct { int r[1]; } *	physadr;
typedef	long		daddr_t;
typedef	char *		caddr_t;
typedef	unsigned short	ushort;
typedef	ushort		ino_t;
typedef short		cnt_t;
typedef	long		time_t;
typedef	int		label_t[NREGS_S];
typedef	short		dev_t;
typedef	long		off_t;
typedef	long		paddr_t;
