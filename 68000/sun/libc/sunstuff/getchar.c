int
getchar()
{char c; 
 while (!linereadyrx(0));
 c = 127&lineget(0);
 putchar(c);
 return c;
}

