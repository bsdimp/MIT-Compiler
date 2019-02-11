/*	definitions for txtfdb record enumerated types */
#	define	STDSTRINGLENGTH			132
#	define	IDENTLENGTH			16
#	define	RUNBUFSIZE			11
/*	-- was 33 */

/*	enumeration types for txtfdb record */
#	define	NOTOPEN				0
#	define	OPENINPUT			1
#	define	OPENOUTPUT			2

#	define	ANYDEV				0
#	define	TTYDEV				1
#	define	LEAFDEV				2

#	define	TRUE				(-1)
#	define	FALSE				0

#	define	BINARY				0
#	define	CHARFILE			1
#	define	ASCIIFILE			2

typedef char	boolean;

/*	structure definition for txtfdb record */
struct	txtfdb {
/*	int				namelength;*/
/*	char				name[STDSTRINGLENGTH];*/
	int				status;
	int				device;
	boolean				eofflag;
	boolean				bufferinvalid;
	int				filetype;
	boolean				ttymode;
#ifdef MC68000
	int				channel;
	char				prompt[IDENTLENGTH];
	boolean				eolnflag;
	boolean				eopageflag;
	int				charcount;
	int				linecount;
	int				pagecount;
	int				tabcount;
	int				pbuffersize; /* Buffer size in BITS */
	/*int				runbufs[RUNBUFSIZE]; */
	     int			charpos;
	     int			charlast;
	     char			charbuf[(RUNBUFSIZE-2)*sizeof(int)];
#else
    /*  to defeat VAX C alignment, define integers as shorts and add the dummy
     *  d_ to fill out the required space.  This should be adequate for all of
     *  the counts involved, especially if they are positive.
     */
	short				promptlength;
	short				d_promptlength;
	char				prompt[IDENTLENGTH];
	boolean				eolnflag;
	boolean				eopageflag;
	short				charcount;
	short				d_charcount;
	short				linecount;
	short				d_linecount;
	short				pagecount;
	short				d_pagecount;
	short				tabcount;
	short				d_tabcount;
	short				pbuffersize;
	short				d_pbuffersize;
	/*short				runbufs[RUNBUFSIZE]; */
	    short		charpos;
	    short		charlast;
	    char		charbuf[(RUNBUFSIZE*sizeof(int))-
                                                (2*sizeof(short))];
#endif
	char				pbuffer;
};

/* For Leaf or Unix IO, to get at file pointer */
#define File(fdbptr)	((fdbptr)->channel)
