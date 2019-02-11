#define FREE    10
#define REWRITE 100
#define DSIZE 111
#define OPSIMP  101

int dope[200];
struct optab {
    int op;
    int needs;
    int aa[20];
} table[];
struct optab *rwtable;
struct optab *opptr[100];

setrew(){
    register struct optab *q;
    register int i;


    for( q = table; q->op != FREE; ++q ){
        if( q->needs == REWRITE ){
            rwtable = q;
            goto more;
        }
    }
    cerror( "bad setrew" );


more:
    for( i=0; i<DSIZE; ++i ){
        if( dope[i] ){ /* there is an op... */
            for( q=table; q->op != FREE; ++q ){
                if( q->op < OPSIMP ){
                    if( q->op==i ) break;
                }
/*
		else {
		    register opmtemp;

		    opmtemp = 0;
		}
*/
            }
            opptr[i] = q;
        }
    }
}
