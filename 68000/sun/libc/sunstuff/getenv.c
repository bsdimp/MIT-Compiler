char *envp[50] = {
"PATH=/usr/sun/bootfile",
"HOME=/mnt/guest",
"TERM=sun",
"USER=guest",
0
};

char *
getenv(s)
char *s;
{

	char **pair;
	for (pair = envp; pair; pair++)
		if (strpref(s,*pair) == 0)
			return *pair + strlen(s) + 1;
	return 0;
}

strpref(a,b)
char *a,*b;
{

	while (*a) if (*a++ != *b++) return 1;
	return 0;
}
