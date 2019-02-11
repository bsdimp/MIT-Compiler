unsigned short fp;
long bn;

badblock()
{
	if (bn < fp)
		return(1);
	return(0);
}
