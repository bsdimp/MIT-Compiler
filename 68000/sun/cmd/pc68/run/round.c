/* Round real number */
round (r)
double r;
{
    if ( *(int*)&r & 0x80000000)
        return (fix(r - 0.5));
    else return (fix (r + 0.5));
}
