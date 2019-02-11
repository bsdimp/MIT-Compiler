#ifdef LEAF
#	define	inputchar(c) {c=getchar();}
#else
#	define	inputchar(c) {c=getchar()&0x7f;if (c=='
') putchar(c='\n');}
#endif
#	define	ERASE	''
#	define	KILL	'^U'
#	define	ENDFILE ''
#ifdef  MC68000
#define	COMMENT(a) asm(a)
#define EXIT _xit
#else
#define COMMENT(a) 
#define EXIT _xit
#endif
#define	ISTRUE(p)  ((p)&0xFF00)
