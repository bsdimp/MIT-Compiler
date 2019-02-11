#include <stdio.h>
main()
{
	float a,b;

	fprintf(stdout,"This is a floating point test\n");
	fprintf(stdout,"2.0 = %g\n",2.0);
	fprintf(stdout,"2.0 = %f\n",2.0);
	fprintf(stdout,"2.0 = %e\n",2.0);
	
	for (a = 1, b= 1.0; a > 0.0;) {
		fprintf(stdout,"a = %g b = %g\n",a,b);
		fprintf(stdout,"a = %f b = %f\n",a,b);
		fprintf(stdout,"a = %e b = %e\n",a,b);
		a /= 2.0;
		b *= 2.0;
	}
	fprintf(stdout,"Done! a = %f b = %f\n",a,b);
}
