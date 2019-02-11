#include <stdio.h>


char	*index();


main(argc, argv)
char **argv;
{
	FILE	*input;
	FILE	*output;
	char	buf[256];
	char	opname[16], subtype[16];
	int	escape, opcode;
	char	op[4][16];
	char	error[16];
	int	cnt;
	int	i;
	char	*opdot, *p, *oprnd;
	int	line = 0;

	if(argc != 3) {
		fprintf(stderr, "usage: %s templates tablefile\n", argv[0]);
		exit(1);
	}

	if((input = fopen(argv[1], "r")) == NULL) {
		fprintf(stderr, "can't open template file\n", argv[1]);
		exit(1);
	}

	if((output = fopen(argv[2], "w")) == NULL) {
		fprintf(stderr, "can't create output file\n", argv[2]);
		exit(1);
	}

	while(fgets(buf, sizeof(buf), input) != NULL) {
		line++;

		if(buf[0] == '\n') {
			/* blank line is passed through */
			fprintf(output, "\n");
			continue;
		}
		if(buf[0] == '#') {
			/* comment */
			continue;
		}

		cnt = sscanf(buf, "%s %s %x %x %s %s %s %s %s",
				  opname, subtype,
				  &escape, &opcode,
				  op[0], op[1], op[2], op[3],
				  error);

		if(cnt < 4 || cnt > 8) {
			fprintf(stderr, "bad input (line %d)\n", line);
			exit(1);
		}

		opdot = index(opname, '.');
		for(p = subtype ; *p ; p++) {
			if(*p == '-') {
				/* no subtype */
				if(opdot != NULL) {
					fprintf(stderr,
						"bad subtyping (line %d)\n",
						line);
					exit(1);
				}
				fprintf(output,	"{ \"%s\"", opname);
				fprintf(output, ", 0x%x, 0x%x, %d",
					escape, opcode, cnt-4);

				for(i = 0 ; i < cnt - 4 ; i++)
					fprintf(output, ", %s", op[i]);

			}
			else {
				if(opdot == NULL) {
					fprintf(stderr,
						"bad subtyping (line %d)\n",
						line);
					exit(1);
				}
				*opdot = *p + ('a' - 'A');
				fprintf(output,	"{ \"%s\"", opname);

				switch(*p) {
				    case 'B':
					fprintf(output, ", 0x%x, 0x%x, %d",
						escape,	opcode, cnt-4);
					break;
				    case 'W':
					fprintf(output, ", 0x%x, 0x%x, %d",
						escape,	opcode | 1, cnt-4);
					break;
				    case 'D':
					fprintf(output, ", 0x%x, 0x%x, %d",
						escape,	opcode | 3, cnt-4);
					break;
				    case 'F':
					fprintf(output, ", 0x%x, 0x%x, %d",
						escape,	opcode | 1, cnt-4);
					break;
				    case 'L':
					fprintf(output, ", 0x%x, 0x%x, %d",
						escape,	opcode, cnt-4);
					break;
				}

				for(i = 0 ; i < cnt - 4 ; i++) {
					strcpy(error, op[i]);
					if((oprnd = index(error, '.')) != NULL)
						*oprnd = *p;
					fprintf(output, ", %s", error);
				}
			}

			fprintf(output, " },\n");
		}
	}
}
