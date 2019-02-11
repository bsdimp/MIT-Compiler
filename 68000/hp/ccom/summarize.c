/* file summarize - collects statistics from file /stats/ccstats, summarizes
them and clears the file */

#define MAXLINE	50
#define FIN	fgets(line, MAXLINE, fp) == line
#define skipl	while (line[0] == '\0') line = (fgets(line, MAXLINE, fp))

main(argc,argv)
char **argv;
{
	FILE *fopen(), *fp;
	char	*stats = "/stats/ccstats";
	char	line[MAXLINE];
	int	compcount = 0;		/* # of compilations */
	float	icppr, icppu, icpps;
	float	iccomr,iccomu,iccoms;
	float	iasr,  iasu,  iass;
	float	ildr,  ildu,  ilds;

	if (argc) fprintf(stderr,"unknown params to summarize");
	if (fp = fopen(stats, "r") == NULL) then {
		fprintf(stderr,"unable to open stats file");
		exit(1);
		}
	while (FIN) {
		if (line[0] != '-' || !FIN) break;
		skipl;
	

