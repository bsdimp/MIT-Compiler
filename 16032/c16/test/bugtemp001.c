#include "bugtemp.h"
long l,la,lb,*pl,ls,las,lbs,*pls;
short i,ia,ib,*pi,is,ias,ibs,*pis;
short unsigned u,ua,ub,*pu,us,uas,ubs,*pus;
char c,ca,cb,*pc,cs,cas,cbs,*pcs;
struct { int i; } s,ss,*ps,*pss;
long lfunct(larg) long larg; {return larg;}
clear() {l=la=lb=0; pl= &l; i=ia=ib=0; pi= &i; u=ua=ub=0; pu= &u;
         c=ca=cb=0; pc= &c; s.i=0; ps= &s;}
save() {ls=l;las=la;lbs=lb;pls=pl;
        is=i;ias=ia;ibs=ib;pis=pi;
        us=u;uas=ua;ubs=ub;pus=pu;
        cs=c;cas=ca;cbs=cb;pcs=pc;
        ss.i=s.i;pss=ps;
        clear();}
check() {if(l!=ls||la!=las||lb!=lbs||pl!=pls)return 1;
         if(i!=is||ia!=ias||ib!=ibs||pi!=pis)return 1;
         if(u!=us||ua!=uas||ub!=ubs||pu!=pus)return 1;
         if(c!=cs||ca!=cas||cb!=cbs||pc!=pcs)return 1;
         if(s.i!=ss.i||pss!=ps)return 1;
         return 0;}
main() {
 A(v1)I(v2)
{clear();
 u=v1; ua=v2;
 lt=u; lt=lt/ua; l=lt;
save();
 u=v1; ua=v2;
 l=u/ua;
if(check()){printf("fails test 1: %s\n"," l=u/ua;");
goto test2;}
}
test2:; A(v1)I(v2)
{clear();
 u=v1; ua=v2;
 lt=u; lt=lt%ua; l=lt;
save();
 u=v1; ua=v2;
 l=u%ua;
if(check()){printf("fails test 2: %s\n"," l=u%ua;");
goto test3;}
}
test3:;
{clear();
 ;
 i=sizeof(int); ia=sizeof(double);
save();
 ;
 i=sizeof((short)c); ia=sizeof((float)c);
if(check()){printf("fails test 3: %s\n"," i=sizeof((short)c); ia=sizeof((float)c);");
}
}

{clear();
 ;
 i=0;
save();
 ;
 i=sizeof(char[10])-sizeof(char[20])>=0;
if(check()){printf("fails test 4: %s\n"," i=sizeof(char[10])-sizeof(char[20])>=0;");
}
}

{clear();
 c= -1;
 i=c;
save();
 c= -1;
 i=(short unsigned)c;
if(check()){printf("fails test 5: %s\n"," i=(short unsigned)c;");
}
}
 Z(v1)for(v2=1; v2<=4; v2++)
{clear();
 ia=v1; u=v2;
 ut=ia; ut=ut>>u; ib=ut;
save();
 ia=v1; u=v2;
 ib=ia>>u;
if(check()){printf("fails test 6: %s\n"," ib=ia>>u;");
goto test7;}
}
test7:;
{clear();
 la=lb= -1;
 it=la-lb; pl[it]++; lb++;
save();
 la=lb= -1;
 pl[la-lb++]++;
if(check()){printf("fails test 7: %s\n"," pl[la-lb++]++;");
}
}
{register char reg_c;

{clear();

 i=8; ia=1;
save();

 for(reg_c=i=ia=1; reg_c<<=ia; i++);
if(check()){printf("fails test 8: %s\n"," for(reg_c=i=ia=1; reg_c<<=ia; i++);");
}
}
}

{clear();

 i=8; ia=1;
save();

 for(c=i=ia=1; c<<=ia; i++);
if(check()){printf("fails test 9: %s\n"," for(c=i=ia=1; c<<=ia; i++);");
}
}
{register char reg_c;

{clear();

 ct=0200; i=ct>>2;
save();

 reg_c=0; reg_c|=0200; reg_c>>=2; i=reg_c;
if(check()){printf("fails test 10: %s\n"," reg_c=0; reg_c|=0200; reg_c>>=2; i=reg_c;");
}
}
}
 Z(v1)
{clear();
 i=v1; l=99991;
 it= -i; if(it==0)continue; i++; l+=it;
save();
 i=v1; l=99991;
 l+= -i++;
if(check()){printf("fails test 11: %s\n"," l+= -i++;");
goto test12;}
}
test12:; Z(v1)
{clear();
 i=v1; l=99991;
 it= -i; if(it==0)continue; i++; l-=it;
save();
 i=v1; l=99991;
 l-= -i++;
if(check()){printf("fails test 12: %s\n"," l-= -i++;");
goto test13;}
}
test13:; Z(v1)
{clear();
 i=v1; l=99991;
 it= -i; if(it==0)continue; i++; l/=it;
save();
 i=v1; l=99991;
 l/= -i++;
if(check()){printf("fails test 13: %s\n"," l/= -i++;");
goto test14;}
}
test14:; Z(v1)
{clear();
 i=v1; l=99991;
 it= -i; if(it==0)continue; i++; l%=it;
save();
 i=v1; l=99991;
 l%= -i++;
if(check()){printf("fails test 14: %s\n"," l%= -i++;");
goto test15;}
}
test15:; Z(v1)
{clear();
 i=v1; l=99991;
 it= -i; if(it==0)continue; i++; l*=it;
save();
 i=v1; l=99991;
 l*= -i++;
if(check()){printf("fails test 15: %s\n"," l*= -i++;");
goto test16;}
}
test16:; Z(v1)
{clear();
 i=v1; l=99991;
 it= -i; if(it==0)continue; i++; l|=it;
save();
 i=v1; l=99991;
 l|= -i++;
if(check()){printf("fails test 16: %s\n"," l|= -i++;");
goto test17;}
}
test17:; Z(v1)
{clear();
 i=v1; l=99991;
 it= -i; if(it==0)continue; i++; l^=it;
save();
 i=v1; l=99991;
 l^= -i++;
if(check()){printf("fails test 17: %s\n"," l^= -i++;");
goto test18;}
}
test18:; Z(v1)
{clear();
 i=v1; l=99991;
 it= -i; if(it==0)continue; i++; l&=it;
save();
 i=v1; l=99991;
 l&= -i++;
if(check()){printf("fails test 18: %s\n"," l&= -i++;");
goto test19;}
}
test19:; Z(v1)
{clear();
 i=v1; l=99991;
 it= ~i; if(it==0)continue; i++; l+=it;
save();
 i=v1; l=99991;
 l+= ~i++;
if(check()){printf("fails test 19: %s\n"," l+= ~i++;");
goto test20;}
}
test20:; Z(v1)
{clear();
 i=v1; l=99991;
 it= ~i; if(it==0)continue; i++; l-=it;
save();
 i=v1; l=99991;
 l-= ~i++;
if(check()){printf("fails test 20: %s\n"," l-= ~i++;");
goto test21;}
}
test21:; Z(v1)
{clear();
 i=v1; l=99991;
 it= ~i; if(it==0)continue; i++; l/=it;
save();
 i=v1; l=99991;
 l/= ~i++;
if(check()){printf("fails test 21: %s\n"," l/= ~i++;");
goto test22;}
}
test22:; Z(v1)
{clear();
 i=v1; l=99991;
 it= ~i; if(it==0)continue; i++; l%=it;
save();
 i=v1; l=99991;
 l%= ~i++;
if(check()){printf("fails test 22: %s\n"," l%= ~i++;");
goto test23;}
}
test23:; Z(v1)
{clear();
 i=v1; l=99991;
 it= ~i; if(it==0)continue; i++; l*=it;
save();
 i=v1; l=99991;
 l*= ~i++;
if(check()){printf("fails test 23: %s\n"," l*= ~i++;");
goto test24;}
}
test24:; Z(v1)
{clear();
 i=v1; l=99991;
 it= ~i; if(it==0)continue; i++; l|=it;
save();
 i=v1; l=99991;
 l|= ~i++;
if(check()){printf("fails test 24: %s\n"," l|= ~i++;");
goto test25;}
}
test25:; Z(v1)
{clear();
 i=v1; l=99991;
 it= ~i; if(it==0)continue; i++; l^=it;
save();
 i=v1; l=99991;
 l^= ~i++;
if(check()){printf("fails test 25: %s\n"," l^= ~i++;");
goto test26;}
}
test26:; Z(v1)
{clear();
 i=v1; l=99991;
 it= ~i; if(it==0)continue; i++; l&=it;
save();
 i=v1; l=99991;
 l&= ~i++;
if(check()){printf("fails test 26: %s\n"," l&= ~i++;");
goto test27;}
}
test27:; Z(v1)
{clear();
 i=v1; l=99991;
 it= !i; if(it==0)continue; i--; l+=it;
save();
 i=v1; l=99991;
 l+= !i--;
if(check()){printf("fails test 27: %s\n"," l+= !i--;");
goto test28;}
}
test28:; Z(v1)
{clear();
 i=v1; l=99991;
 it= !i; if(it==0)continue; i--; l-=it;
save();
 i=v1; l=99991;
 l-= !i--;
if(check()){printf("fails test 28: %s\n"," l-= !i--;");
goto test29;}
}
test29:; Z(v1)
{clear();
 i=v1; l=99991;
 it= !i; if(it==0)continue; i--; l/=it;
save();
 i=v1; l=99991;
 l/= !i--;
if(check()){printf("fails test 29: %s\n"," l/= !i--;");
goto test30;}
}
test30:; Z(v1)
{clear();
 i=v1; l=99991;
 it= !i; if(it==0)continue; i--; l%=it;
save();
 i=v1; l=99991;
 l%= !i--;
if(check()){printf("fails test 30: %s\n"," l%= !i--;");
goto test31;}
}
test31:; Z(v1)
{clear();
 i=v1; l=99991;
 it= !i; if(it==0)continue; i--; l*=it;
save();
 i=v1; l=99991;
 l*= !i--;
if(check()){printf("fails test 31: %s\n"," l*= !i--;");
goto test32;}
}
test32:; Z(v1)
{clear();
 i=v1; l=99991;
 it= !i; if(it==0)continue; i--; l|=it;
save();
 i=v1; l=99991;
 l|= !i--;
if(check()){printf("fails test 32: %s\n"," l|= !i--;");
goto test33;}
}
test33:; Z(v1)
{clear();
 i=v1; l=99991;
 it= !i; if(it==0)continue; i--; l^=it;
save();
 i=v1; l=99991;
 l^= !i--;
if(check()){printf("fails test 33: %s\n"," l^= !i--;");
goto test34;}
}
test34:; Z(v1)
{clear();
 i=v1; l=99991;
 it= !i; if(it==0)continue; i--; l&=it;
save();
 i=v1; l=99991;
 l&= !i--;
if(check()){printf("fails test 34: %s\n"," l&= !i--;");
goto test35;}
}
test35:;
{clear();
 u=1;
 lt=u; l= -lt;
save();
 u=1;
 l= -(long)u;
if(check()){printf("fails test 35: %s\n"," l= -(long)u;");
}
}

{clear();
 u=1;
 lt=u; l= ~lt;
save();
 u=1;
 l= ~(long)u;
if(check()){printf("fails test 36: %s\n"," l= ~(long)u;");
}
}

{clear();
 i=1;
 lt=i; l= -lt;
save();
 i=1;
 l= -(long)i;
if(check()){printf("fails test 37: %s\n"," l= -(long)i;");
}
}

{clear();
 i=1;
 lt=i; l= ~lt;
save();
 i=1;
 l= ~(long)i;
if(check()){printf("fails test 38: %s\n"," l= ~(long)i;");
}
}

{clear();

 c++; i=c;
save();

 i=c++?c:c;
if(check()){printf("fails test 39: %s\n"," i=c++?c:c;");
}
}
 Z(v1)
{clear();
 u=v1;
 ut= ~u; it=ut; it= ~it; l=it;
save();
 u=v1;
 l= ~(short)~u;
if(check()){printf("fails test 40: %s\n"," l= ~(short)~u;");
goto test41;}
}
test41:;}
