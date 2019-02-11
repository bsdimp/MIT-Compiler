(* Host compiler: *) 
  (*%SetF HedrickPascal F *)
  (*%SetT UnixPascal T *)

(*%iff UnixPascal*)
{  (*$M-*)}
{}
{  PROGRAM Uini;}
{}
{   INCLUDE 'Ucode.Inc';}
(*%else*)
#include "ucode.h";
#include "uini.h";
(*%endc*)

VAR
  Utab: Array [Uopcode] OF Utabrec;

(* exported procedures *)

(*%iff UnixPascal*)
{}
{PROCEDURE Uini;}
{   FORWARD;}
{}
{PROCEDURE Getutabrec (Uopc: Uopcode; VAR Utabr: Utabrec);}
{   FORWARD;}
{}
(*%endc*)
PROCEDURE Uini{};

  VAR Opctr:Integer;
      Curop: Uopcode;

  PROCEDURE Opc (Lop:Uopcode; Opname: Opcstring);
     BEGIN
     Utab[Lop].Opcname := Opname;
     Opctr := 0;
     Curop := Lop;
     END;

  PROCEDURE Push (Op: Uoperand);
     BEGIN
     Opctr := Opctr + 1;
     Utab[Curop].Format[Opctr] := Op;
     END;

  BEGIN
  Opc(Uabs ,'ABS '); Push(Sdtype);   Push(Send);
  Opc(Uadd ,'ADD ');   Push(Sdtype);   Push(Send);
  Opc(Uadj ,'ADJ '); Push(Sdtype);   Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Uand ,'AND ');   Push(Sdtype);   Push(Send);
  Opc(Ubgn ,'BGN '); Push(Spname1);  Push(Sblockno); Push(Send);
  Opc(Ubgnb,'BGNB');   Push(Send);
  Opc(Uchkf,'CHKF'); Push(Send);
  Opc(Uchkt,'CHKT');   Push(Send);
  Opc(Uchkh,'CHKH'); Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uchkl,'CHKL');   Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uchkn,'CHKN'); Push(Send);
  Opc(Uclab,'CLAB');   Push(Slabel0);  Push(Slength);  Push(Send);
  Opc(Ucomm,'COMM'); Push(Scomment); Push(Send);
  Opc(Ucup ,'CUP ');   Push(Sdtype);   Push(Sblockno); Push(Spname1);
                       Push(Spop);     Push(Spush);    Push(Send);
  Opc(Ucvt ,'CVT '); Push(Sdtype);   Push(Sdtype2);  Push(Send);
  Opc(Ucvt2,'CVT2');   Push(Sdtype);   Push(Sdtype2);  Push(Send);
  Opc(Udata,'DATA'); Push(Spname0);  Push (Sblockno);      Push(Send);
  Opc(Udead,'DEAD'); Push(Smtype);   Push(Sblockno); Push(Soffset);  
		       Push(Slength);  Push(Send);
  Opc(Udec ,'DEC ');   Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Udef ,'DEF '); Push(Smtype);   Push(Slength);  Push(Send);
  Opc(Udif ,'DIF ');   Push(Sdtype);   Push(Slength);   Push(Send);
  Opc(Udiv ,'DIV '); Push(Sdtype);   Push(Send);
  Opc(Udsp ,'DSP ');   Push(Send);
  Opc(Udup ,'DUP '); Push(Sdtype);   Push(Send);
  Opc(Uend ,'END ');   Push(Spname1);  Push(Send);
  Opc(Uendb,'ENDB'); Push(Send);
  Opc(Uent ,'ENT '); Push(Spname0);  Push(Sdtype);   Push(Slexlev);
                     Push(Sblockno); Push(Spop);     Push(Spush);   
                     Push(Sexternal); Push(Send);
  Opc(Uequ ,'EQU '); Push(Sdtype);   Push(Send);
  Opc(Uexpv,'EXPV'); Push (Svname1);   Push(Sdtype); Push(Smtype);   
                     Push(Sblockno);   Push(Soffset);    Push(Slength);  
                     Push(Send);
  Opc(Ufjp ,'FJP '); Push(Slabel1);  Push(Send);
  Opc(Ugeq ,'GEQ ');   Push(Sdtype);   Push(Send);
  Opc(Ugrt ,'GRT '); Push(Sdtype);   Push(Send);
  Opc(Ugoob,'GOOB');   Push(Slexlev);  Push(Slabel1);  Push(Send);
  Opc(Uicup,'ICUP'); Push(Sdtype);   Push(Spop);     Push(Spush);    Push(Send);
  Opc(Uiequ,'IEQU');   Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uigeq,'IGEQ'); Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uigrt,'IGRT');   Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uileq,'ILEQ'); Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uiles,'ILES');   Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uilod,'ILOD'); Push(Sdtype);   Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Uimpm,'IMPM');   Push(Spname0);  Push(Sblockno); Push(Send);
  Opc(Uimpv,'IMPV'); Push(Svname0);  Push(Sdtype);   Push(Smtype);
                     Push(Sblockno); Push(Soffset);  Push(Slength);  
                     Push(Send);
  Opc(Uineq,'INEQ'); Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uinc ,'INC ');   Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uinit,'INIT'); Push(Sdtype); Push(Smtype);   Push(Sblockno); 
                     Push(Soffset);  
                     Push(Soffset2); Push(Slength);  Push(Sinitval); Push(Send);
  Opc(Uinn ,'INN ');   Push(Sdtype);   Push(Slength);   Push(Sblockno);  Push(Send);
  Opc(Uinst,'INST'); Push(Sdtype);   Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Uint ,'INT ');   Push(Sdtype);    Push(Slength);   Push(Send);
  Opc(Uior ,'IOR '); Push(Sdtype);   Push(Send);
  Opc(Uistr,'ISTR'); Push(Sdtype);   Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Uixa ,'IXA '); Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Ulab ,'LAB ');   Push(Slabel0);  Push(Slexlev);  Push(Send);
  Opc(Ulca ,'LCA '); Push(Sdtype);   Push(Slength);  Push(Sblockno); 
		     Push(Sconstval);Push(Send);
  Opc(Ulda ,'LDA ');   Push(Smtype);   Push(Sblockno); Push(Soffset);
                       Push(Slength);  Push (Soffset2); Push(Send);
  Opc(Uldc ,'LDC '); Push(Sdtype);   Push(Slength);  Push(Sconstval);Push(Send);
  Opc(Uldp ,'LDP ');   Push(Slexlev);  Push(Sblockno); Push(Spname1);  Push(Send);
  Opc(Uleq ,'LEQ '); Push(Sdtype);   Push(Send);
  Opc(Ules ,'LES ');   Push(Sdtype);   Push(Send);
  Opc(Ulex ,'LEX '); Push(Slexlev);  Push(Sblockno); Push(Send);
  Opc(Uloc ,'LOC ');   Push(Sblockno); Push(Soffset);  Push(Slength );
                       Push(Send);
  Opc(Ulod ,'LOD '); Push(Sdtype);   Push(Smtype);   Push(Sblockno);
                     Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Umin ,'MIN ');   Push(Sdtype);   Push(Send);
  Opc(Umax ,'MAX ');   Push(Sdtype);   Push(Send);
  Opc(Umod ,'MOD ');   Push(Sdtype);   Push(Send);
  Opc(Umov ,'MOV '); Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Umpy ,'MPY ');   Push(Sdtype);   Push(Send);
  Opc(Umst ,'MST '); Push(Slexlev);  Push(Send);
  Opc(Umus ,'MUS ');   Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Uneg ,'NEG '); Push(Sdtype);   Push(Send);
  Opc(Uneq ,'NEQ ');   Push(Sdtype);   Push(Send);
  Opc(Unew ,'NEW '); Push(Sblockno); Push(Send);
  Opc(Unot ,'NOT ');   Push(Sdtype);   Push(Send);
  Opc(Unstr,'NSTR'); Push(Sdtype);   Push(Smtype);   Push(Sblockno);
                     Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Uodd ,'ODD ');   Push(Sdtype);   Push(Send);
  Opc(Uoptn,'OPTN'); Push(Spname1);  Push(Sblockno); Push(Send);
  Opc(Upar ,'PAR ');   Push(Sdtype);   Push(Smtype);   Push(Sblockno);
                       Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Upop ,'POP '); Push(Sdtype);   Push(Send);
  Opc(Uplod,'PLOD'); Push(Sdtype);   Push(Smtype);   Push(Sblockno);
                     Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Upstr,'PSTR');   Push(Sdtype);   Push(Smtype);   Push(Sblockno);
                       Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Uregs,'REGS');   Push(Slexlev);  Push(Sblockno);  Push(Soffset);  
                       Push(Slength);  Push(Send);
  Opc(Uret ,'RET '); Push(Send);
  Opc(Urlod,'RLOD'); Push(Sdtype);   Push(Smtype);   Push(Sblockno);  
		     Push(Soffset);  Push(Slength);  Push(Soffset2);  Push(Send);
  Opc(Urnd ,'RND ');   Push(Sdtype);   Push(Sdtype2);   Push(Send);
  Opc(Urstr,'RSTR'); Push(Sdtype);   Push(Smtype);   Push(Sblockno);  
		     Push(Soffset);  Push(Slength);  Push(Soffset2);  Push(Send);
  Opc(Usdef,'SDEF');   Push(Sblockno);   Push(Slength);   Push(Send);
  Opc(Usgs ,'SGS '); Push(Sdtype);   Push(Slength);  Push(Send);
  Opc(Usqr ,'SQR ');   Push(Sdtype);   Push(Send);
  Opc(Ustp ,'STP '); Push(Spname1);  Push(Send);
  Opc(Ustr ,'STR ');   Push(Sdtype);   Push(Smtype);   Push(Sblockno);
                       Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Usub ,'SUB '); Push(Sdtype);   Push(Send);
  Opc(Uswp ,'SWP ');   Push(Sdtype);   Push(Sdtype2);  Push(Send);
  Opc(Utjp ,'TJP '); Push(Slabel1);  Push(Send);
  Opc(Uujp ,'UJP ');   Push(Slabel1);  Push(Send);
  Opc(Uuni ,'UNI '); Push(Sdtype);    Push(Slength);   Push(Send);
  Opc(Uvequ,'VEQU'); Push(Sdtype);   Push(Send);
  Opc(Uvgeq,'VGEQ'); Push(Sdtype);   Push(Send);
  Opc(Uvgrt,'VGRT'); Push(Sdtype);   Push(Send);
  Opc(Uvles,'VLES'); Push(Sdtype);   Push(Send);
  Opc(Uvleq,'VLEQ'); Push(Sdtype);   Push(Send);
  Opc(Uvmov,'VMOV'); Push(Sdtype);   Push(Send);
  Opc(Uvneq,'VNEQ'); Push(Sdtype);   Push(Send);
  Opc(Uxjp ,'XJP '); Push(Sdtype);   Push(Slabel1);  Push(Slabel2);
                     Push(Soffset);  Push(Slength);  Push(Send);
  Opc(Uxor ,'XOR ');   Push(Sdtype);   Push(Send);
  Opc(Uzero,'ZERO'); Push(Sdtype);   Push(Smtype);   Push(Sblockno);
                     Push(Soffset);  Push(Slength);  Push(Send);

  (* Initializes tables for writing B-code *)

  FOR Curop := Uabs TO Unop DO
     Utab[Curop].Hasconst := False;

  Utab[Ucomm].Hasconst := True;
  Utab[Uinit].Hasconst := True;
  Utab[Ulca ].Hasconst := True;
  Utab[Uldc ].Hasconst := True;

  Utab[Uabs].Instlength:= 1;
  Utab[Uadd].Instlength:= 1;
  Utab[Uadj].Instlength:= 3;
  Utab[Uand].Instlength:= 1;
  Utab[Ubgn].Instlength:= 5;
  Utab[Ubgnb].Instlength:= 1;
  Utab[Uchkf].Instlength:= 1;
  Utab[Uchkt].Instlength:= 1;
  Utab[Uchkh].Instlength:= 2;
  Utab[Uchkl].Instlength:= 2;
  Utab[Uchkn].Instlength:= 1;
  Utab[Uclab].Instlength:= 2;
  Utab[Ucomm].Instlength:= 2;
  Utab[Ucup].Instlength:= 6;
  Utab[Ucvt].Instlength:= 2;
  Utab[Ucvt2].Instlength:= 2;
  Utab[Udata].Instlength:= 5;
  Utab[Udead].Instlength:= 3;
  Utab[Udec].Instlength:= 2;
  Utab[Udef].Instlength:= 2;
  Utab[Udif].Instlength:= 2;
  Utab[Udiv].Instlength:= 1;
  Utab[Udsp].Instlength:= 1;
  Utab[Udup].Instlength:= 1;
  Utab[Uend].Instlength:= 5;
  Utab[Uendb].Instlength:= 1;
  Utab[Uent].Instlength:= 6;
  Utab[Uequ].Instlength:= 1;
  Utab[Uexpv].Instlength:= 7;
  Utab[Ufjp].Instlength:= 1;
  Utab[Ugeq].Instlength:= 1;
  Utab[Ugrt].Instlength:= 1;
  Utab[Ugoob].Instlength:= 1;
  Utab[Uicup].Instlength:= 1;
  Utab[Uiequ].Instlength:= 2;
  Utab[Uigeq].Instlength:= 2;
  Utab[Uigrt].Instlength:= 2;
  Utab[Uileq].Instlength:= 2;
  Utab[Uiles].Instlength:= 2;
  Utab[Uilod].Instlength:= 3;
  Utab[Uimpm].Instlength:= 5;
  Utab[Uimpv].Instlength:= 6;
  Utab[Uineq].Instlength:= 2;
  Utab[Uinc].Instlength:= 2;
  Utab[Uinit].Instlength:= 4;
  Utab[Uinn].Instlength:= 1;
  Utab[Uinst].Instlength:= 2;
  Utab[Uint].Instlength:= 2;
  Utab[Uior].Instlength:= 1;
  Utab[Uistr].Instlength:= 3;
  Utab[Uixa].Instlength:= 2;
  Utab[Ulab].Instlength:= 1;
  Utab[Ulca].Instlength:= 2;
  Utab[Ulda].Instlength:= 4;
  Utab[Uldc].Instlength:= 2;
  Utab[Uldp].Instlength:= 5;
  Utab[Uleq].Instlength:= 1;
  Utab[Ules].Instlength:= 1;
  Utab[Ulex].Instlength:= 1;
  Utab[Uloc].Instlength:= 3;
  Utab[Ulod].Instlength:= 3;
  Utab[Umin].Instlength:= 1;
  Utab[Umax].Instlength:= 1;
  Utab[Umod].Instlength:= 1;
  Utab[Umov].Instlength:= 2;
  Utab[Umpy].Instlength:= 1;
  Utab[Umst].Instlength:= 1;
  Utab[Umus].Instlength:= 2;
  Utab[Uneg].Instlength:= 1;
  Utab[Uneq].Instlength:= 1;
  Utab[Unew].Instlength:= 1;
  Utab[Unot].Instlength:= 1;
  Utab[Unstr].Instlength:= 3;
  Utab[Uodd].Instlength:= 1;
  Utab[Uoptn].Instlength:= 5;
  Utab[Upar].Instlength:= 3;
  Utab[Uplod].Instlength:= 3;
  Utab[Upop].Instlength:= 1;
  Utab[Upstr].Instlength:= 3;
  Utab[Uregs].Instlength:= 3;
  Utab[Uret].Instlength:= 1;
  Utab[Urlod].Instlength:= 4;
  Utab[Urnd].Instlength:= 1;
  Utab[Urstr].Instlength:= 4;
  Utab[Usdef].Instlength:= 2;
  Utab[Usgs].Instlength:= 2;
  Utab[Usqr].Instlength:= 1;
  Utab[Ustp].Instlength:= 5;
  Utab[Ustr].Instlength:= 3;
  Utab[Usub].Instlength:= 1;
  Utab[Uswp].Instlength:= 2;
  Utab[Usym].Instlength:= 7;
  Utab[Utjp].Instlength:= 1;
  Utab[Uujp].Instlength:= 1;
  Utab[Uuni].Instlength:= 2;
  Utab[Uvequ].Instlength:= 1;
  Utab[Uvgeq].Instlength:= 1;
  Utab[Uvgrt].Instlength:= 1;
  Utab[Uvles].Instlength:= 1;
  Utab[Uvleq].Instlength:= 1;
  Utab[Uvmov].Instlength:= 1;
  Utab[Uvneq].Instlength:= 1;
  Utab[Uxjp].Instlength:= 4;
  Utab[Uxor].Instlength:= 1;
  Utab[Uzero].Instlength:= 3;
  END;

PROCEDURE Getutabrec {(Uopc: Uopcode; VAR Utabr: Utabrec)};
   BEGIN
   Utabr := Utab[Uopc];
   END

(*%ift HedrickPascal *)
{   .}
(*%else*)
   ;
(*%endc*)
