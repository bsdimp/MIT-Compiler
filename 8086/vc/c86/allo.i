# 1 "allo.c"

# 1 "./mfile2"

# 1 "./macdefs"















































	



















# 2 "./mfile2"

# 1 "./mac2defs"


	




	



	





















	

	

	



extern int fltused;
	

# 3 "./mfile2"

# 1 "./manifest"


# 1 "/usr/include/stdio.h"




extern	struct	_iobuf {
	int	_cnt;
	char	*_ptr;
	char	*_base;
	short	_flag;
	char	_file;
} _iob[20];


























struct _iobuf	*fopen();
struct _iobuf	*fdopen();
struct _iobuf	*freopen();
long	ftell();
char	*fgets();
# 3 "./manifest"














































































































































	



























































		

		
	




























# 244 "./manifest"








# 254 "./manifest"







extern int nerrors;  

typedef union ndu NODE;
typedef unsigned int TWORD;

extern int dope[];  
extern char *opst[];  


	

union ndu {

	struct {
		int op;
		int rall;
		TWORD type;
		int su;
		char name[8	];
		NODE *left;
		NODE *right;
		}in; 
	
	struct {
		int op;
		int rall;
		TWORD type;
		int su;
		char name[8	];
		long lval;
		int rval;
		}tn; 
	
	struct {
		int op, rall;
		TWORD type;
		int su;
		int label;  
		}bn; 

	struct {
		int op, rall;
		TWORD type;
		int su;
		int stsize;  
		int stalign;  
		}stn; 

	struct {
		int op;
		int cdim;
		TWORD type;
		int csiz;
		}fn; 
	
	struct {
		

		int op;
		int cdim;
		TWORD type;
		int csiz;
		double dval;
		}fpn; 

	};

# 330 "./manifest"

# 334 "./manifest"

# 339 "./manifest"

# 352 "./manifest"

# 4 "./mfile2"



























	
	













	




	



















	

	
















	










	




















	

extern int rstatus[];
extern int busy[];

extern struct respref { int cform; int mform; } respref[];









extern int stocook;

extern NODE *deltrees[20];
extern int deli;   

extern NODE *stotree;
extern int callflag;

extern int fregs;

# 186 "./mfile2"


extern NODE node[];

extern struct optab {
	int op;
	int visit;
	int lshape;
	int ltype;
	int rshape;
	int rtype;
	int needs;
	int rewrite;
	char * cstring;
	}
	table[];

extern NODE resc[];

extern long tmpoff;
extern long maxoff;
extern long baseoff;
extern long maxtemp;
extern int maxtreg;
extern int ftnno;
extern int rtyflg;

extern int nrecur;  



extern NODE
	*talloc(),
	*eread(),
	*tcopy(),
	*getlr();

extern long rdin();

extern int e2print();

extern char *rnames[];

extern int lineno;
extern char ftitle[];
extern int fldshf, fldsz;
extern int lflag, x2debug, udebug, e2debug, odebug, rdebug, radebug, t2debug, sdebug;









	




# 2 "allo.c"

NODE resc[3];

int busy[8];

int maxa, mina, maxb, minb;

allo0(){ 

	register i;

	maxa = maxb = -1;
	mina = minb = 0;

	 for(i=0;i<8;++i){
		busy[i] = 0;
		if( rstatus[i] & 04	 ){
			if( maxa<0 ) mina = i;
			maxa = i;
			}
		if( rstatus[i] & 020	 ){
			if( maxb<0 ) minb = i;
			maxb = i;
			}
		}
	}



allo( p, q ) NODE *p; struct optab *q; {

	register n, i, j;

	n = q->needs;
	i = 0;

	while( n & 03 ){
		resc[i].in.op = 94;
		resc[i].tn.rval = freereg( p, n&017 );
		resc[i].tn.lval = 0;
		resc[i].in.name[0] = '\0';
		n -= 01;
		++i;
		}

	while( n & 060 ){
		resc[i].in.op = 94;
		resc[i].tn.rval = freereg( p, n&0360 );
		resc[i].tn.lval = 0;
		resc[i].in.name[0] = '\0';
		n -= 020;
		++i;
		}

	if( n & 07400 ){
		resc[i].in.op = 95;
		resc[i].tn.rval = 6;
		if( p->in.op == 100 || p->in.op == 99 || p->in.op == 2+ 100 || p->in.op == 98 ){
			resc[i].tn.lval = freetemp( (8*p->stn.stsize + (16-1))/16 );
			}
		else {
			resc[i].tn.lval = freetemp( (n&07400)/0400 );
			}
		resc[i].in.name[0] = '\0';
		resc[i].tn.lval =  ((resc[i].tn.lval)>>3)  ;
		++i;
		}

	

	 for(j=0;j<8;++j){
		busy[j] &= ~01000;
		}

	for( j=0; j<i; ++j ) if( resc[j].tn.rval < 0 ) return(0);
	return(1);

	}

freetemp( k ){ 



# 98 "allo.c"

	tmpoff += k*16;
	if( k>1 ) {
		   if(  tmpoff% 16  != 0 )  tmpoff = ( ( tmpoff/ 16  + 1) *  16 );
		}
	if( tmpoff > maxoff ) maxoff = tmpoff;
	if( tmpoff-baseoff > maxtemp ) maxtemp = tmpoff-baseoff;
	return( -tmpoff );

	}

freereg( p, n ) NODE *p; {
	
	

	register j;

	
	if(  (dope[p->in.op]&02000) ){
		j = callreg(p);
		if( usable( p, n, j ) ) return( j );
		
		}
	j = p->in.rall & ~010000   ;
	if( j!=020000   && usable(p,n,j) ){ 
		return( j );
		}
	if( n&017 ){
		for( j=mina; j<=maxa; ++j ) if( rstatus[j]&04	 ){
			if( usable(p,n,j) ){
				return( j );
				}
			}
		}
	else if( n &0360 ){
		for( j=minb; j<=maxb; ++j ) if( rstatus[j]&020	 ){
			if( usable(p,n,j) ){
				return(j);
				}
			}
		}

	return( -1 );
	}

usable( p, n, r ) NODE *p; {
	

	
	if( ! (rstatus[r]&(020	|04	)) ) cerror( "usable asked about nontemp register" );

	if( busy[r] > 1 ) return(0);

	if( (n & 0360) && ! (rstatus[r]&010	)) return(0);







	if( (n&017) && (szty(p->in.type) == 2) ){ 
		if( r&01 ) return(0);
		if( ! (rstatus[r+1]&(020	|04	)) ) return( 0 );
		if( busy[r+1] > 1 ) return( 0 );
		if( busy[r] == 0 && busy[r+1] == 0  ||
		    busy[r+1] == 0 && shareit( p, r, n ) ||
		    busy[r] == 0 && shareit( p, r+1, n ) ){
			busy[r] |= 01000;
			busy[r+1] |= 01000;
			return(1);
			}
		else return(0);
		}
	if( busy[r] == 0 ) {
		busy[r] |= 01000;
		return(1);
		}

	
	return( shareit( p, r, n ) );

	}

shareit( p, r, n ) NODE *p; {
	

	if( (n&(04  |0100)) && ushare( p, 'L', r ) ) return(1);
	if( (n&(010 |0200)) && ushare( p, 'R', r ) ) return(1);
	return(0);
	}

ushare( p, f, r ) NODE *p; {
	

	p = getlr( p, f );
	if( p->in.op == 2+ 11 ) p = p->in.left;
	if( p->in.op == 95 ){
		if(  ((p->tn.rval)>=0200) ){
			return( r== ((((p->tn.rval)>>7)&0177)-1) || r== ((p->tn.rval)&0177) );
			}
		else return( r == p->tn.rval );
		}
	if( p->in.op == 94 ){
		return( r == p->tn.rval || ( szty(p->in.type) == 2 && r==p->tn.rval+1 ) );
		}
	return(0);
	}

recl2( p ) register NODE *p; {
	register r = p->tn.rval;
	if( p->in.op == 94 ) rfree( r, p->in.type );
	else if( p->in.op == 95 ) {
		if(  (( r )>=0200) ) {
			rfree(  (((( r )>>7)&0177)-1),  020+4 );
			rfree(  (( r )&0177), 4 );
			}
		else {
			rfree( r,  020+4 );
			}
		}
	}

int rdebug = 0;

rfree( r, t ) TWORD t; {
	
	

	if( rdebug ){
		printf( "rfree( %s ), size %d\n", rnames[r], szty(t) );
		}

	if(  (rstatus[r]&(020	|04	)) ){
		if( --busy[r] < 0 ) cerror( "register overfreed");
		if( szty(t) == 2 ){
			if( (r&01) || ( (rstatus[r]&(020	|04	))^ (rstatus[r+1]&(020	|04	))) ) cerror( "illegal free" );
			if( --busy[r+1] < 0 ) cerror( "register overfreed" );
			}
		}
	}

rbusy(r,t) TWORD t; {
	
	

	if( rdebug ){
		printf( "rbusy( %s ), size %d\n", rnames[r], szty(t) );
		}

	if(  (rstatus[r]&(020	|04	)) ) ++busy[r];
	if( szty(t) == 2 ){
		if(  (rstatus[r+1]&(020	|04	)) ) ++busy[r+1];
		if( (r&01) || ( (rstatus[r]&(020	|04	))^ (rstatus[r+1]&(020	|04	))) ) cerror( "illegal register pair freed" );
		}
	}

rwprint( rw ){ 
	register i, flag;
	static char * rwnames[] = {

		"RLEFT",
		"RRIGHT",
		"RESC1",
		"RESC2",
		"RESC3",
		0,
		};

	if( rw == 0     ){
		printf( "RNULL" );
		return;
		}

	if( rw == 010000    ){
		printf( "RNOP" );
		return;
		}

	flag = 0;
	for( i=0; rwnames[i]; ++i ){
		if( rw & (1<<i) ){
			if( flag ) printf( "|" );
			++flag;
			printf( rwnames[i] );
			}
		}
	}

reclaim( p, rw, cookie ) NODE *p; {
	register NODE **qq;
	register NODE *q;
	register i;
	NODE *recres[5];
	struct respref *r;

	


	if( rdebug ){
		printf( "reclaim( %o, ", p );
		rwprint( rw );
		printf( ", " );
		prcook( cookie );
		printf( " )\n" );
		}

	if( rw == 010000    || ( p->in.op==97 && rw==0     ) ) return;  

	walkf( p, recl2 );

	if(  (dope[p->in.op]&02000) ){
		
		 allchk();  
		}

	if( rw == 0     || (cookie&01 ) ){ 
		tfree(p);
		return;
		}

	

	if( (cookie & 040 ) && (rw&04000)) {
		
		tfree(p);
		p->in.op = 96;
		p->tn.lval = 0;
		p->tn.rval = 0;
		return;
		}

	

	qq = recres;

	if( rw&01) *qq++ = getlr( p, 'L' );;
	if( rw&02 ) *qq++ = getlr( p, 'R' );
	if( rw&04 ) *qq++ = &resc[0];
	if( rw&010 ) *qq++ = &resc[1];
	if( rw&020 ) *qq++ = &resc[2];

	if( qq == recres ){
		cerror( "illegal reclaim");
		}

	*qq = (NODE *)0;

	

	for( r=respref; r->cform; ++r ){
		if( cookie & r->cform ){
			for( qq=recres; (q= *qq) != (NODE *)0; ++qq ){
				if( tshape( q, r->mform ) ) goto gotit;
				}
			}
		}

	
	cerror( "cannot reclaim");

	gotit:

	if( p->in.op == 99 ) p = p->in.left;  

	q->in.type = p->in.type;  
		
	q = tcopy(q);

	tfree(p);

	p->in.op = q->in.op;
	p->tn.lval = q->tn.lval;
	p->tn.rval = q->tn.rval;
	for( i=0; i<8	; ++i )
		p->in.name[i] = q->in.name[i];

	q->in.op = 97;

	

	switch( p->in.op ){

	case 94:
		if( !rtyflg ){
			
			
			
			if( p->in.type == 2 || p->in.type == 3 ) p->in.type = 4;
			else if( p->in.type == 12 || p->in.type == 13 ) p->in.type = 14;
			else if( p->in.type == 6 ) p->in.type = 7;
			}
		if( ! (p->in.rall & 010000    ) ) return;  
		i = p->in.rall & ~010000   ;
		if( i & 020000   ) return;
		if( i != p->tn.rval ){
			if( busy[i] || ( szty(p->in.type)==2 && busy[i+1] ) ){
				cerror( "faulty register move" );
				}
			rbusy( i, p->in.type );
			rfree( p->tn.rval, p->in.type );
			rmove( i, p->tn.rval, p->in.type );
			p->tn.rval = i;
			}

	case 95:
		if(  ((p->tn.rval)>=0200) ){
			int r1, r2;
			r1 =  ((((p->tn.rval)>>7)&0177)-1);
			r2 =  ((p->tn.rval)&0177);
			if( (busy[r1]>1 &&  (rstatus[r1]&(020	|04	))) || (busy[r2]>1 &&  (rstatus[r2]&(020	|04	))) ){
				cerror( "potential register overwrite" );
				}
			}
		else if( (busy[p->tn.rval]>1) &&  (rstatus[p->tn.rval]&(020	|04	)) ) cerror( "potential register overwrite");
		}

	}

ncopy( q, p ) NODE *p, *q; {
	

	


	register i;

	q->in.op = p->in.op;
	q->in.rall = p->in.rall;
	q->in.type = p->in.type;
	q->tn.lval = p->tn.lval;
	q->tn.rval = p->tn.rval;
	for( i=0; i<8	; ++i ) q->in.name[i]  = p->in.name[i];

	}

NODE *
tcopy( p ) register NODE *p; {
	

	register NODE *q;
	register r;

	ncopy( q=talloc(), p );

	r = p->tn.rval;
	if( p->in.op == 94 ) rbusy( r, p->in.type );
	else if( p->in.op == 95 ) {
		if(  ((r)>=0200) ){
			rbusy(  ((((r)>>7)&0177)-1),  020+4 );
			rbusy(  ((r)&0177), 4 );
			}
		else {
			rbusy( r,  020+4 );
			}
		}

	switch(  (dope[q->in.op]&016) ){

	case 010:
		q->in.right = tcopy(p->in.right);
	case 04:
		q->in.left = tcopy(p->in.left);
		}

	return(q);
	}

allchk(){
	

	register i;

	 for(i=0;i<8;++i){
		if(  (rstatus[i]&(020	|04	)) && busy[i] ){
			cerror( "register allocation error");
			}
		}

	}
