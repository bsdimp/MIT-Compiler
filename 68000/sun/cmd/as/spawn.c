/*
 * Utility Subroutines for "Simple" Creation of Processes
 *
 * Calling sequence is similar to that for "execl" and "execv",
 * with exception of extra first argument, which is a pointer
 * to an int[3] array.  On return, the array will contain the
 * process number [0], the fileID of a pipe coming from the
 * spawned process [1], and the fileID of a pipe going to the
 * spawned process [2];  A zero returned code means success, a
 * negative code means failure.  All open files are preserved
 * by this call for the parent process, although the child will
 * only have fileID's for its standard input, output, and error
 * files.
 *
 * Written by j. pershing  -  all rights reversed
 *
 * Modifications:
 *  08/11/76 j. pershing
 *	Usage of registers added.
 *  08/20/76  j. pershing
 *	Usage of registers removed due to c-compiler bug.
 *  08/18/77 T. Eliot
 *	Added access call, exit call after exec, so if bad arguments are given
 *	to us we don't bomb quite so badly.
 */

extern int errno;

spawnl(Ptr, Name, Etc) int Ptr[3]; char *Name, *Etc; {

	return(spawnv(Ptr, Name, &Etc)); }


spawnv(Ptr, Name, Vec) int Ptr[3]; char *Name, **Vec; {

register int	Status, Old0, Old1;
	int	Temp[3];

	Old0 = dup(0);  Old1 = dup(1);
	if (0 <= Old0 && Old0 <= 1) while((Old0 = dup(Old0)) <= 1);
	if (0 <= Old1 && Old1 <= 1) while((Old1 = dup(Old1)) <= 1);
	close(0);  close(1);
	if ((Status = pipe(&Temp[1])) < 0) goto Err;
	Ptr[1] = dup(Temp[1]);

	close(0);
	if ((Status = pipe(&Temp[1])) < 0) goto Err;
	Ptr[2] = Temp[2];

	if ((Status = access(Name,1))) goto Err;

	if ((Status = fork()) == -1) goto Err;

	if ((Ptr[0] = Status) == 0) {
		for (Status = 3; Status < 20; close(Status++));
		(execv(Name, Vec));
		exit(errno);		/* Performed only if execv fails */
	  }

	Status = 0;
   Err:	close(0);  close(1);
	open("/dev/null", 0);
	dup(Old1);  close(Old1);
	close(0);  dup(Old0);  close(Old0);
	return(Status); }

