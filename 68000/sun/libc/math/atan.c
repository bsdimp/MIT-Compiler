
/*
	floating-point arctangent

	atan returns the value of the arctangent of its
	argument in the range [-pi/2,pi/2].

	atan2 returns the arctangent of arg1/arg2
	in the range [-pi,pi].

	there are no error returns.

	coefficients are #5077 from Hart & Cheney. (19.56D)
*/


static double sq2p1	 =2.414213562373095048802e0;
static double sq2m1	 = .414213562373095048802e0;
static double pio2	 =1.570796326794896619231e0;
static double pio4	 = .785398163397448309615e0;
static double atanp4	 = .161536412982230228262e2;
static double atanp3	 = .26842548195503973794141e3;
static double atanp2	 = .11530293515404850115428136e4;
static double atanp1	 = .178040631643319697105464587e4;
static double atanp0	 = .89678597403663861959987488e3;
static double atanq4	 = .5895697050844462222791e2;
static double atanq3	 = .536265374031215315104235e3;
static double atanq2	 = .16667838148816337184521798e4;
static double atanq1	 = .207933497444540981287275926e4;
static double atanq0	 = .89678597403663861962481162e3;


/*
	atan makes its argument positive and
	calls the inner routine satan.
*/

double
atan(arg)
double arg;
{
	double satan();

	if(arg>0)
		return(satan(arg));
	else
		return(-satan(-arg));
}


/*
	atan2 discovers what quadrant the angle
	is in and calls atan.
*/

double
atan2(arg1,arg2)
double arg1,arg2;
{
	double satan();

	if((arg1+arg2)==arg1)
		if(arg1 >= 0.) return(pio2);
		else return(-pio2);
	else if(arg2 <0.)
		if(arg1 >= 0.)
			return(pio2+pio2 - satan(-arg1/arg2));
		else
			return(-pio2-pio2 + satan(arg1/arg2));
	else if(arg1>0)
		return(satan(arg1/arg2));
	else
		return(-satan(-arg1/arg2));
}

/*
	satan reduces its argument (known to be positive)
	to the range [0,0.414...] and calls xatan.
*/

double
satan(arg)
double arg;
{
	double	xatan();

	if(arg < sq2m1)
		return(xatan(arg));
	else if(arg > sq2p1)
		return(pio2 - xatan(1.0/arg));
	else
		return(pio4 + xatan((arg-1.0)/(arg+1.0)));
}

/*
	xatan evaluates a series valid in the
	range [-0.414...,+0.414...].
*/

double
xatan(arg)
double arg;
{
	double argsq;
	double value;

	argsq = arg*arg;
	value = ((((atanp4*argsq + atanp3)*argsq + atanp2)*argsq + atanp1)*argsq + atanp0);
	value = value/(((((argsq + atanq4)*argsq + atanq3)*argsq + atanq2)*argsq + atanq1)*argsq + atanq0);
	return(value*arg);
}
