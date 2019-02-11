/*
	exp returns the exponential function of its
	floating-point argument.

	The coefficients are #1069 from Hart and Cheney. (22.35D)
*/

#include <errno.h>
#include <math.h>

int	errno;
static double	expp0	= .2080384346694663001443843411e7;
static double	expp1	= .3028697169744036299076048876e5;
static double	expp2	= .6061485330061080841615584556e2;
static double	expq0	= .6002720360238832528230907598e7;
static double	expq1	= .3277251518082914423057964422e6;
static double	expq2	= .1749287689093076403844945335e4;
static double	log2e	= 1.4426950408889634073599247;
static double	sqrt2	= 1.4142135623730950488016887;
static double	maxf	= 10000;

double
exp(arg)
double arg;
{
	double fract;
	double temp1, temp2, xsq;
	int ent;

	if(arg == 0.)
		return(1.);
	if(arg < -maxf)
		return(0.);
	if(arg > maxf) {
		errno = ERANGE;
		return(HUGE);
	}
	arg *= log2e;
	ent = floor(arg);
	fract = (arg-ent) - 0.5;
	xsq = fract*fract;
	temp1 = ((expp2*xsq+expp1)*xsq+expp0)*fract;
	temp2 = ((1.0*xsq+expq2)*xsq+expq1)*xsq + expq0;
	return(ldexp(sqrt2*(temp2+temp1)/(temp2-temp1), ent));
}
