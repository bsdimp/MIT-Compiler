exit(status)
register int status;
{
	asm("	trap #14.");
}
