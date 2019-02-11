/*
    dll - This program down-line loads the SUN terminal
    written by Bill Nowicki October 1980

*/


#include <stdio.h>

   main (argc, argv) 
   int argc;
   char *argv[]; 

 {
   FILE *f;
   char name [20];	/* the input file name */
   char line [256];	/* the line to be downline - loaded */
   int waste;		/* a counter to waste time */
   int limit=6;		/* the time constant */
   int inner;		/* inner loop counter */

   if ( *argv[argc-1] >= '0' && *argv[argc-1] <= '9' ) {
      sscanf( argv[argc-1], "%d", &limit );
      argc--;
      }
   if ( argc < 2 ) strcpy(name, "/usr/sun/tty.dl");
     else strcpy( name, argv[1] );
   if ( (f=fopen(name , "r") ) == NULL) 
	  fprintf(stderr, "file %s not found", name);

   else {
   while ( fgets( line, 256, f) != NULL ) {
      for ( waste=1; waste<=limit; waste++ ) {
	 putchar( '\000' );
	 }
      puts(line);
      }
   }

 }

