(* -- UGTP.PAS -- *)
(* Host compiler: *)
  (*%SetF HedrickPascal F *)
  (*%SetT UnixPascal T *)

(*%ift HedrickPascal*)
{}
{  PROGRAM Ugen;}
{  (*$H:100000*)}
{}
{   INCLUDE 'Ucode.Inc';}
{   INCLUDE 'Ug.Inc';}
{   INCLUDE 'Ugrg.Imp';}
{   INCLUDE 'Ugat.Imp';}
{   INCLUDE 'Ugcd.Imp';}
{   INCLUDE 'Ugsp.Imp';}
{   INCLUDE 'Ugst.Imp';}
{   INCLUDE 'Ugtm.Imp';}
{   INCLUDE 'Uread.Imp';}
{   INCLUDE 'Uscan.Imp';}
(*%else*)

 PROGRAM Ugen (Output);

#include "ucode.h";
#include "ug.h";
#include "ugrg.h";
#include "ugat.h";
#include "ugcd.h";
#include "ugsp.h";
#include "ugst.h";
#include "ugtm.h";
#include "uread.h";
#include "uscan.h";
(*%endc*)


(* Main module of UGEN, U-code to machine code translator. 
   See UG.DOC. *)

CONST
   Endloc = -1;         (* special codes for the statement table *)
   Jumploc = -2;
   Caseloc = -3;
   Returnloc = -4;

VAR
   Commandline: Commandrec;
   Inittime, Readtime, Asmtime, Timer: Integer;  (* execution timers *)

   (* switches *)
   Tbcode : Boolean;    (* true if we are reading binary ucode*)
   Trace: Integer;      (* tracing flag *)

   Stmtctr: Integer;	(* source line statement counter *)
   Dbginfo: Dbginforec; (* current file, proc, etc. *)

   CurP, CurL: Integer;  (* current page/line in source file *)

   Udirect: ARRAY [Uiequ..Uineq] OF Uopcode; (* Direct equiv of indirect Ucode ops *)
   NotU: ARRAY [Ufjp..Utjp] OF Uopcode;   (* Ucode boolean complements *)
   NotArr: ARRAY [Xequ..Xnor] OF Icode;   (* Icode boolean complements *)

   Umap: ARRAY [Uopcode] OF Icode;	

   Localoffset: Integer;   (* offset from next stack frame of last parm *)
   Globaloffset: Integer;  (* partial stack frames beneath the orginal ones *)
				  
   Fakemarkers: Integer;    (* used to keep track of BGNBs*)
   Writedebugcall: Boolean; (* set to true when main proc encountered *)
   Blklexmap: ARRAY [0 .. Blkmax] OF 0..Lexmax;  
         (* Lexical level of each block number *)
   Plex,		(* lexical level of last proc compiled *)
   Clex,		(* lexical level of current proc *)
   Cblk: Integer;	(* block number of current proc *)
   Msize,               (* size of M memory in current procedure *)
   Parcount,		(* current parameter count *)
   Maxparcount: Integer;(* max parcount within one proc *)

   Pregs: Regset;	(* set of all registers used to pass in params *)

   U, NextU: Bcrec;     (* current and next U-code instruction *)
   Skip,		(* if true, skip the next U-code instruction *)
   Retry: Boolean;	(* if true, recompile current U-code instruction *)

   I: Integer;

   NullAt, ZeroConstAt,	(* some commonly used address tokens *)
   CalleeAt,
   FuncresAt: Addrtoken;


PROCEDURE Inittp;

   BEGIN
   Dbginfo.Sourcename := Blankfilename;
   Dbginfo.Debug := False;
   Dbginfo.Profile := False;
   Dbginfo.Filefirstproc := Blabl;
   Trace := 0;
   Tbcode := False;
   Stmtctr := 0;
   CurP := 1;
   CurL := 0;
   Fakemarkers := 0;
   Writedebugcall := False;
   Blklexmap[0] := 2;

   Umap [Uadd] := Xadd;
   Umap [Usub] := Xsub;
   Umap [Umpy] := Xmpy;
   Umap [Udiv] := Xdiv;
   Umap [Umod] := Xmod;
   Umap [Uinc] := Xinc;
   Umap [Udec] := Xdec;
   Umap [Uabs] := Xabs;
   Umap [Uneg] := Xneg;
   Umap [Urnd] := Xrnd;
   Umap [Uadd] := Xadd;
   Umap [Usub] := Xsub;
   IF IsS1 THEN
      BEGIN
      Umap [Umin] := Xmin;
      Umap [Umax] := Xmax;
      END
   ELSE
      BEGIN
      Umap [Umin] := Xles;
      Umap [Umax] := Xgrt;
      END;
   Umap [Uand] := Xand;
   Umap [Uior] := Xor;
   Umap [Uxor] := Xxor;
   Umap [Uequ] := Xequ;
   Umap [Uneq] := Xneq;
   Umap [Uleq] := Xleq;
   Umap [Ugeq] := Xgeq;
   Umap [Ules] := Xles;
   Umap [Ugrt] := Xgrt;
   Umap [Uuni] := Xor;
   Umap [Uint] := Xand;
   Umap [Udif] := Xandcmp;

   Udirect[Uiequ] := Uequ;
   Udirect[Uineq] := Uneq;
   Udirect[Uigrt] := Ugrt;
   Udirect[Uiles] := Ules;
   Udirect[Uigeq] := Ugeq;
   Udirect[Uileq] := Uleq;
   
   NotU[Ufjp] := Utjp;
   NotU[Utjp] := Ufjp;

   NotArr[Xgeq] := Xles;
   NotArr[Xles] := Xgeq;
   NotArr[Xgrt] := Xleq;
   NotArr[Xleq] := Xgrt;
   NotArr[Xequ] := Xneq;
   NotArr[Xneq] := Xequ;
   NotArr[Xand] := Xnand;
   NotArr[Xor]  := Xnor;
   NotArr[Xnand] := Xand;
   NotArr[Xnor]  := Xor;

   MakintconstAt (ZeroConstAt, 0);
   MakregAt (NullAt, Ss, -1);
   NullAt.Form := Empty;
   Makaddrat (CalleeAt, Sa, 0, Blabl, Reference);
   END;


(* Addtoend *)

PROCEDURE Addtoend (VAR Ulbl: Labl; Character: Char);
    (* adds a character to the end of a label *)
    VAR I: Integer;
    BEGIN
    I := Labchars;
    While (Ulbl[I] = ' ') AND (I > 1) DO
        I := I - 1;
    IF I < Labchars THEN I := I + 1;
    Ulbl[I] := Character;
    END;

FUNCTION Ispacked (VAR U: Bcrec): Boolean;
   BEGIN
   Ispacked := (U.Offset MOD AddrUnit <> 0) OR (U.Length MOD AddrUnit <> 0);
   END;

PROCEDURE Sharevar (Varbl: Sharedvar; Val: Integer);
   BEGIN
   SetSpVar (Varbl, Val);
   SetCdVar (Varbl, Val);
   SetRgVar (Varbl, Val);
   SetStVar (Varbl, Val);
   END;


PROCEDURE Convertlabel (VAR Lbl: Labl; I: Integer);

  (*  Convertlabel converts a numeric label into a string of the form $N 
      where N is the ascii representation of the passed label value *)

   VAR 
        Position,
        Divisor: Integer;
        
   BEGIN
   Lbl := Blabl;
   Lbl[1]:='$';
   Position := 1;
   Divisor := 10;
   (* Find largest power of ten smaller than the number given. *)
   While Divisor <= I DO
      Divisor := Divisor * 10;
   REPEAT
      Divisor := Divisor DIV 10;
      Position := Position + 1;
      IF Position > Labchars THEN
         UgenError ('Label too big.                ',I) 
      ELSE
         Lbl[Position]:= Chr(I DIV Divisor + Ord('0'));
      I := I MOD Divisor;
   UNTIL Divisor = 1;
   END;


PROCEDURE Copyfilename (VAR U: Bcrec; VAR Fname: Filename; VAR Lbl: Labl; 
			EndCh: Char);

  (*  U should be a COMM instruction
      containing a file name.  It transfers the file name from the instruction
      to Fname, and it creates a label consisting of the first Labchars-1 
      alphanumeric characters of the file name, followed by Endch.  *)
    
    VAR I,J: Integer;

    BEGIN
    Lbl := Blabl;
    Fname := Blankfilename;
    If U.Opc <> UCOMM THEN
       Ugenerror ('Missing file name             ',Novalue)
    ELSE
       BEGIN
       J := 0;
       For I := 1 to U.Constval.Len DO
           BEGIN
           Fname[I] := U.Constval.Chars[I];
           IF (I < Labchars) THEN
              IF ((Fname[I] >= 'A') AND (Fname[I] <= 'Z')) OR 
                 ((Fname[I] >= '0') AND (Fname[I] <= '9')) THEN
                 BEGIN
                 J := J + 1;
                 Lbl[J] := Fname[I]
                 END;
           END;
       Lbl[J+1] := Endch;
       END;
    END;


PROCEDURE Setoptn (VAR U: Bcrec);
   VAR Error: Boolean;
       Tname: Filename;
       Tlab: Labl;
       Op: Uopcode;
BEGIN
Error := False;
IF U.Pname[1] = 'T' THEN
   IF NOT (U.Pname[2] IN ['B','D','F','L','M','P','R','S','T']) THEN
      Error := True
   ELSE CASE U.Pname[2] OF
      
   'B': IF U.Pname =  'TBCODE          ' THEN 
	   BEGIN
	   Tbcode := U.I1 = 1;
	   IF Tbcode THEN 
	      BEGIN
	      Copyfilename (NextU, Tname, Tlab, ' ');
	      Skip := True;
	      SwitchtoBcode (Tname);
	      END;
	   END
	ELSE Error := True;

   'D': IF U.Pname =  'TDEBUG          ' THEN 
	   BEGIN
           Dbginfo.Debug := U.I1 = 1;
           IF Dbginfo.Debug THEN Runtimerequest (3);
	   END
	ELSE Error := True;
   'E': IF U.Pname =  'TERROR          ' THEN 
        UgenError ('Uncorrected errors in source. ', Novalue);
   'F': IF U.Pname =  'TFASTCHECK      ' THEN SetSpVar (ShFastcheck, U.I1)
	ELSE Error := True;
   'L': IF U.Pname = 'TLOCREGS        ' THEN Error := False
  	ELSE Error := True;
   'M': IF U.Pname = 'TMACHINE        ' THEN 
	   BEGIN
 	   IF U.I1 <> MachineId THEN
              UgenError ('U-code is for another machine!', U.I1);
           END
  	ELSE Error := True;
   'P': IF U.Pname =  'TPROFILE        ' THEN 
        BEGIN
        Dbginfo.Profile := U.I1 = 1;
	Runtimerequest (5);
	END
	ELSE Error := True;
   'R': IF U.Pname =  'TRTIMES         ' THEN Runtimerequest (U.I1)
	ELSE Error := True;
   'S': IF U.Pname =  'TSOURCE         ' THEN 
	   WITH Dbginfo DO
	      BEGIN
	      Copyfilename (NextU, Sourcename, Sourcelabl, '$');
	      Resetsource (Sourcename);
	      Skip := True;
	      Proflabl := Sourcelabl;   
	      Addtoend (Proflabl,'%');
	      END
	ELSE IF U.Pname =  'TSYM            ' THEN 
	   BEGIN
	   Copyfilename (NextU, Dbginfo.Symbolname, Tlab, ' ');
	   Skip := True;
	   END
	ELSE Error := True;
   'T': IF U.Pname =  'TTRACE          ' THEN 
	   BEGIN
	   Trace := U.I1;
	   ShareVar (ShTrace, Trace);
	   END
	ELSE Error := True;
   END;
IF Error THEN UgenError ('Illegal OPTN.                 ',Novalue);
END;
		       

FUNCTION Gettarget (VAR U: Bcrec; VAR TgtAt: Addrtoken): BOOLEAN;

   (* This function is called by procedures that need to find the target
      of some operation in order to perform some optimization.
      If U is a STR, PAR, or ISTR, and the target location is not bit-packed,
      then it creates an address token describing  the location.  
      For ISTR, this involves popping the address off the stack.
      Otherwise, it returns a null token in TgtAt.
   *)

   VAR Isstr: Boolean;
       Opstring: Opcstring;
       

   BEGIN
   Isstr := (U.Opc = Ustr) OR (U.Opc = Uistr) OR 
	    ((U.Opc = Upar) AND NOT DownStkLnk);
    
   IF Isstr THEN Isstr := NOT Isbitpacked (U);
   IF NOT Isstr THEN   
      TgtAt := NullAt
   ELSE
      BEGIN
      IF Odd (Trace) THEN 
	 BEGIN
	 UgenMsg ('Target found:                 ',Novalue);
	 GetOpcstr (U.Opc, Opstring);
	 TraceUcode (U, Opstring); 
	 END;
      CASE U.Opc OF
	 USTR:
	    BEGIN
	    IF Binding THEN
	       Killloc (U.Mtype, U.I1, U.Offset);
	    MakBlkoffsetAt (TgtAt, U, Blklexmap[U.I1], Clex, 
			      Reference);
	    Tgtat.Mtyp := U.Mtype;
	    Tgtat.Bno := U.I1;
	    Tgtat.Offst := U.Offset;
	    END;
	 UISTR: 
	    BEGIN
	    Pop (TgtAt);
	    Adjaddr (TgtAt, U.Offset DIV AddrUnit); 
	    Indirect (TgtAt, Machinetype (U.Dtype, U.Length), 
		       U.Length DIV AddrUnit);
	    IF Binding THEN Killbindings;  
	    END;
	 UPAR: 
	    BEGIN
	    IF (U.Length <> WordSize) THEN
	       UgenError ('Invalid parameter length.     ',U.Length);
	    (* Store parameter on the runtime stack. *)
	    Localoffset := U.Offset DIV AddrUnit + Entrysize + Localstart;
	    IF U.Mtype = Rmt THEN
	       MakBlkoffsetAt (TgtAt, U, 0, 0, Reference)
	    ELSE
		  MakrgoffAt (TgtAt, Machinetype(U.Dtype, U.Length), SP, 
			  Globaloffset+Localoffset, Fnone, Reference);
	    END;
	 END;
      END;
   Gettarget := Isstr;
   END;


PROCEDURE ONEOP;

   (* Processes one U-code instruction. *)

   VAR
      Treg: Register;
      Rgs: Regset;
      TgtAt, At1, At2, At3, At4, At5, At6, At7: Addrtoken;
      I: Integer;
      Tlab,Tlab2: Labl;
      Bitoffset: Integer;
      Done: Boolean;
      Iop: Icode;
   BEGIN
   CASE U.OPC OF


(* ULDC ULCA ULOD ULDA UILOD *)

ULDC,ULCA: (* Push a constant onto the stack. *)

   BEGIN
   MakConstAt (At1, U);      
   Push (At1);                   
   END;

ULOD:
   BEGIN
   (* Create a reference address operand token *)
   At1.Form := Empty;
     WITH U DO
      (* IF bit-packed, extract the byte into a register now. *)
      IF Ispacked (U) THEN
         BEGIN
         Bitoffset := Offset MOD WordSize;
	 U.Offset := U.Offset - Bitoffset;
	 I := U.Length;
	 U.Length := WordSize;
	 IF Binding AND (U.Mtype <> Rmt) THEN
	    IF Matchreg (Machinetype(U.Dtype, U.Length), U.Mtype, U.I1, 
			 U.Offset+Bitoffset, Treg, False) THEN
	       MakRegAt (At1, Machinetype(U.Dtype,U.Length), Treg);
         IF At1.Form = Empty THEN
	    BEGIN
	    MakBlkoffsetAt (At1, U, Blklexmap[U.I1],Clex, Reference);
	    ExtractByte (At1, Bitoffset, I, U.Dtype IN [Jdt,Bdt], False);
	    END;
	 END
      ELSE
         BEGIN
	 IF Binding AND (U.Mtype <> Rmt) AND (U.Length <= Wordsize) THEN
	    IF Matchreg (Machinetype(U.Dtype,U.Length), U.Mtype, U.I1, 
			 U.Offset, Treg, False) THEN
	       MakRegAt (At1, Machinetype(U.Dtype,U.Length), Treg);
         IF At1.Form = Empty THEN
            MakBlkoffsetAt (At1, U, Blklexmap[U.I1], Clex, Reference);
	 END;
   Push(At1);
   END;

ULDA : (* Create a literal address operand token *)
   BEGIN
   U.Dtype := Adt;
   U.Length := WordSize;
   MakBlkoffsetAt (At1, U, Blklexmap[U.I1] ,Clex , Literal);
   Push (At1);
   END;
 
UILOD: 
   BEGIN
   Pop(At1);
   IF Isbitpacked (U) THEN
      BEGIN
      Bitoffset := U.Offset MOD WordSize;
      (* Increment the address by the amount specified. *)
      Adjaddr (At1, (U.Offset-Bitoffset) DIV AddrUnit);   
      ExtractByte (At1, Bitoffset, U.Length, U.Dtype IN [Bdt,Jdt], True);
      END
   ELSE
      BEGIN
      (* Increment the address by the amount specified. *)
      Adjaddr (At1, U.Offset DIV AddrUnit);   
      (* Increase the indirection. *)
      Indirect (At1, Machinetype(U.Dtype,U.Length), U.Length DIV AddrUnit);
      END;

   Push (At1);
   END;


(* URLOD URSTR USTR UNSTR UISTR UINST *)

URLOD:
   BEGIN
   MakBlkoffsetAt (At1, U, Blklexmap[U.I1], Clex, Reference);
   MakRegAt (TgtAt, At1.Mdtype, Regno (U.Offset2));
   Moveit (TgtAt, At1);
   END;

URSTR:
   BEGIN
   MakBlkoffsetAt (TgtAt, U, Blklexmap[U.I1], Clex, Reference);
   MakRegAt (At1, TgtAt.Mdtype, Regno (U.Offset2));
   Moveit (TgtAt, At1);
   END;

USTR:

   BEGIN
   Pop(At1);
   IF Isbitpacked (U) THEN
      BEGIN
      Bitoffset := U.Offset MOD WordSize;
      U.Offset := U.Offset - Bitoffset;
      I := U.Length;  U.Length := WordSize;
      IF NOT Gettarget (U, TgtAt) THEN;
      TgtAt.Offst := TgtAt.Offst + Bitoffset;
      (* Store into a bit-packed location. *)
      DepositByte (TgtAt, At1, Bitoffset, I, False);
      END
   ELSE
      BEGIN
      IF NOT Gettarget (U, TgtAt) THEN;
      Moveit (TgtAt, At1);
      END;
   Clean (TgtAt); 
   END;

UNSTR: 

  (* The stack must be loaded before the NSTR to prevent side effects. *)

   BEGIN
   Pop(At1);
   CopyAt (At2, At1);
   IF Isbitpacked (U) THEN
      UgenError ('NSTR into a packed location.  ',U.Offset);
   Loadstack;
   MakBlkoffsetAt (TgtAt, U, Blklexmap[U.I1], Clex,  Reference);
   (* Form new binding. *)
   IF Binding THEN
      BEGIN
      Killloc (U.Mtype, U.I1, U.Offset);
      Tgtat.Mtyp := U.Mtype;
      Tgtat.Bno := U.I1;
      Tgtat.Offst := U.Offset;
      END;
   Moveit (TgtAt,At1);
   Push (At2);
   Clean (TgtAt); 
   END; (* nstr *)
 
UISTR, UINST: 

   BEGIN
   Pop (At1);
   Pop (TgtAt);
   IF U.Opc = UINST THEN 
      BEGIN
      Loadstack;
      CopyAt (At2, At1);
      END;
   (* Adjust storage address and increase indirection. *)
   IF Ispacked (U) THEN
      BEGIN
      BitOffset := U.Offset MOD WordSize;
      Adjaddr (TgtAt, (U.Offset-Bitoffset) DIV AddrUnit); 
      I := U.Length;
      U.Length := WordSize;
      (* Store into a packed location. *)
      DepositByte (TgtAt, At1, Bitoffset, I, True)
      END
   ELSE 
      BEGIN
      Adjaddr (TgtAt, U.Offset DIV AddrUnit); 
      Indirect (TgtAt, Machinetype (U.Dtype,U.Length), U.Length);
      Moveit (TgtAt, At1);
      END;
   IF U.Opc = UINST THEN Push (At2);
   Clean (TgtAt);
   (* Since we stored to a computed address it is 
      necessary to kill all bindings to memory. *)
   IF Binding THEN Killbindings;  
   END;


(* UMOV UZERO UVMOV UCVT UCVT2 *)

UMOV:

   BEGIN
   Pop(At2);
   Pop(At1);
   Moveblock (At1, At2, U.Length DIV AddrUnit, True);
   Clean (At1);                       
   Clean (At2);
   END;

UZERO:

   IF U.Mtype = Smt THEN
      UgenError ('S zeroing not implemented.    ',Novalue)
   ELSE
      BEGIN
      (* Create a reference address operand token *)
      WITH U DO
	 MakBlkoffsetAt (At1, U, Blklexmap[U.I1], Clex,  Reference);
      Zeroblock(At1, U.Length DIV AddrUnit);
      Clean(At1);
      END;

UVMOV:

   BEGIN
   Pop (At1);
   Pop (At2);
   Pop (At3);
   Movevblock (At1, At2, At3);
   Clean (At1);
   Clean (At2);
   Clean (At3);
   END;

UCVT,UCVT2: 
   (* Usually this instruction is a no-op, since the machine datatype is
      not changed by a change of U-code datatype.  The exceptions to this
      are integer/real conversions, and address-to-integer conversions
      (for printing ORD of a pointer).
      Dtype is the NEW datatype.
    *)
   BEGIN
   IF U.Opc = UCVT2 THEN Pop (At1);
   Pop (At2);
   At3.Mdtype := ILL;
   (* K  L,J *)
   IF ((U.Dtype2 IN [Jdt,Idt,Ldt]) AND (U.Dtype = Rdt)) THEN
      (* Integer -> real *)
      At3.Mdtype := SF
   ELSE IF((U.Dtype2 = Rdt ) AND (U.Dtype IN [Jdt,Idt,Ldt])) THEN
      (* Real -> Integer *)
      At3.Mdtype := Ss
   ELSE IF (U.Dtype2 = Bdt) AND (U.Dtype = Jdt) THEN
      (* Boolean -> Integer *)
      BEGIN
      Skip := Gettarget (NextU, TgtAt);
      IF Is68000 THEN
	 BEGIN
	 MakintconstAt (At4, 1);
	 Emitbinaryop (Xand, TgtAt, At2, At4);
	 END
      ELSE
	 Emitunaryop (Xabs, TgtAt, At2);
      At2 := TgtAt;
      IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
      END
   ELSE IF (U.Dtype2 = Qdt) AND (U.Dtype = Rdt) THEN
      (*Double per. real to single per.*)
      BEGIN
      At3.mdtype := SF;
      Skip := false;
      END
   ELSE IF (U.Dtype2 = Rdt) AND (U.Dtype = Qdt) THEN
      (*Single per. real to double per.*)
      BEGIN
      At3.mdtype := DF;
      END
   ELSE IF (U.Dtype2 IN [Adt,Cdt,Jdt,Idt,Ldt]) AND 
           (U.Dtype IN [Cdt,Jdt,Idt,Ldt]) THEN
      (* Conversion types O.K., but no code needs to be generated. *)
      BEGIN
      Skip := False;
      IF U.Dtype2 = Adt THEN At2.Mdtype := SS;
      END
   ELSE 
      UgenError ('Illegal CVT datatypes.        ',Novalue);
   IF At3.Mdtype <> ILL THEN
      BEGIN
      Skip := Gettarget (U, TgtAt);
      IF NOT Skip THEN
         TgtAt.Mdtype := At3.Mdtype;
      IF Is68000 AND (U.Opc = UCVT2) THEN
         (* Temp.hack to avoid clobbering stack *)
	 BEGIN Push (At1); Moveit (TgtAt, At2); Pop (At1); END
      ELSE
         Moveit (TgtAt, At2);
      IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
      END
   ELSE IF NOT Skip THEN
      Push (At2);
   IF U.Opc = UCVT2 THEN Push (At1);
   END;


(* UABS UNEG USQR URND UNOT UDEC UINC *)

UABS,UNEG,URND:

   BEGIN
   Pop(At1);
   Unpack (At1);
   IF (U.Opc = UABS) AND Is68000 AND NOT (U.Dtype IN [Qdt,Rdt]) THEN
      BEGIN
      CreateLabel (Tlab);
      IF NOT IsWorkReg (At1) THEN
         LoadReg (At1);
      CopyAt (At2, At1);
      Compare (Xgeq, NullAt, At2, ZeroConstAt, Tlab);
      TgtAt := NullAt;
      Emitunaryop (Xneg, TgtAt, At1);
      EmitLab (Tlab);
      Push (At1);
      END
   ELSE
      BEGIN
      Skip := Gettarget (NextU, TgtAt);
      Emitunaryop (Umap[U.Opc], TgtAt, At1);
      IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
      END;
   END;

USQR:

   (* Change Square(At1) to At1*At1 *)
   BEGIN
   Pop(At1);
   CopyAt (At2, At1);
   Push(At2);
   Push(At1);
   U.Opc := Umpy;
   Retry := True;
   END;

UNOT:

   BEGIN
   IF (NextU.Opc = Utjp) OR (NextU.Opc = Ufjp) THEN
      NextU.Opc := NotU[NextU.Opc]
   ELSE
      BEGIN
      Skip := Gettarget (NextU, TgtAt);
      Pop(At1);
      Emitunaryop (Xnot, TgtAt, At1);
      IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
      END;
   END;
 
 

UDEC,UINC:

   BEGIN
   Pop(At1);
   (* Change directions for booleans, since true is -1 instead of 1. *)
   IF (U.Dtype = Bdt) THEN
      IF U.Opc = Udec THEN U.Opc := Uinc ELSE U.Opc := Udec;
   (* Call Adjaddr to deal with INCs and DECs of addresses. *)
   IF (U.Dtype = Adt) THEN 
      BEGIN
      IF U.Opc = Udec THEN U.Length := -U.Length;
      IF U.Length MOD AddrUnit <> 0 THEN
         IF NextU.Opc = UILOD THEN
            NextU.Offset := NextU.Offset + U.Length
	 ELSE
            UgenError ('Bit address increment.        ',U.Length)
      ELSE
         AdjAddr (At1, U.Length DIV AddrUnit);
      Push (At1);
      END
   ELSE IF (IsDec10 OR IsS1) AND (U.Length = 1) THEN		(*inc or dec by 1*)
      BEGIN
      Unpack (At1);
      Skip := Gettarget (NextU, TgtAt);
      Emitunaryop (Umap[U.Opc], TgtAt, At1);
      IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
      END
   ELSE (* all other cases: change to ADD and try again *)
      BEGIN
      MakintconstAt (At2, U.Length);
      Push (At1);  Push (At2);
      IF U.Opc = Udec THEN U.Opc := Usub ELSE U.Opc := Uadd;   
      Retry := True;
      END;
   END;


(* UADD UMPY USUB UDIV UMOD UMIN UMAX UODD *)

UADD,USUB:

   BEGIN 
   Pop(At2);
   Pop(At1);
   (* Change (ADD,SUB) 1 to (INC,DEC). *)
   IF (IsDec10 OR ISS1) AND (Isone (At2) OR Isone (At2)) THEN
      BEGIN 
      IF U.Opc = Uadd THEN U.Opc := Uinc ELSE U.Opc := Udec;     
      U.Length := 1; Retry := True;
      IF Isone (At1) THEN Push(At2) ELSE Push (At1); 
      END
   ELSE 
      BEGIN
      Done := False;
      (* Try to collapse adds of addresses and integers. *)
      IF (U.Opc = Uadd) THEN
         IF U.Dtype = Adt THEN
	    BEGIN
	    CollapseIndex (At1, At2);
	    Push (At1);
	    Done := True;
	    END
         ELSE IF IsS1 THEN
	    IF ColadInt (At1, At2) THEN
	       BEGIN
	       Push (At1);
	       Done := True;
	       END;
 
      IF NOT Done THEN
	 (* If can't collapse, emit the instruction. *)
	 BEGIN
	 (* Packed entities must be expanded to whole words before doing any
	    integer arithmetic, according to the Law *)
         IF IsS1 OR Is68000 THEN
	    BEGIN
            Unpack (At1);  Unpack (At2);
            END;
         IF Is68000 AND Isbetween (At2,1,8) THEN
	    IF U.Opc = Uadd THEN U.Opc := Uinc ELSE U.Opc := Udec;
	 Skip := Gettarget (NextU, TgtAt);
         Emitbinaryop (Umap[U.Opc], TgtAt, At1, At2);
         IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
	 END;
      END;
   END;

UMPY,UDIV,UMOD:

   BEGIN 
   Pop(At2);
   Pop(At1);
   (* Packed entities must be expanded to whole words before doing any
      integer arithmetic, according to the Law. *)
   IF IsS1 OR Is68000 THEN
      BEGIN
      Unpack (At1);  Unpack (At2);
      END;
   (* Change multiplications by positive powers of two to Shifts.  
      Try to collapse this shift, if possible. *)
   IF (U.Opc = Umpy) AND (U.Dtype = Ldt) AND AtPowerOfTwo (At2,I) THEN
      BEGIN
      IF Colshift (At1,I) THEN
	 Push (At1)
      ELSE
	 BEGIN
	 MakintconstAt (At2, I);
	 Skip := Gettarget (NextU, TgtAt);
	 EmitBinaryop (Xshift, TgtAt, At1, At2);
	 IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
	 END
      END
   ELSE 
      BEGIN
      Skip := Gettarget (NextU, TgtAt);
      Emitbinaryop (Umap[U.Opc],TgtAt, At1, At2);  
      IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
      END;
   END;

UMIN,UMAX:

   BEGIN 
   Pop(At2);
   Pop(At1);
   (* If not the same datatype, then expand both to single words. *)
   IF IsS1 OR Is68000 THEN
      BEGIN
      IF (U.Dtype <> Bdt) AND (U.Dtype <> Cdt) THEN
	 BEGIN
	 Unpack (At1);
	 Unpack (At2);
	 END;
      IF (At1.Mdtype <> At2.Mdtype) THEN
	 BEGIN
	 Unpack (At1);  Unpack (At2);
	 END;
      END;
   (* switch boolean test, since true is -1 instead of 1 *)
   IF U.Dtype = Bdt THEN
      IF U.Opc = Umin THEN U.Opc := Umax ELSE U.Opc := Umin;
   Skip := Gettarget (NextU, TgtAt);
   IF IsS1 THEN
      Emitbinaryop (Umap[U.Opc],TgtAt, At1, At2)
   ELSE
      BEGIN
      (* move the first value into the target location *)
      IF NOT Skip THEN
	 MakTmpRegAt (TgtAt, At1.Mdtype);
      CopyAt (At3, At1);
      Moveit (TgtAt, At3); 
      IF IsWorkReg (TgtAt) THEN
         BEGIN Clean (At1); Copyat (At1, TgtAt) END;
      (* if At1 >(max) or <(min) A2, then we're all done; skip around *)
      Createlabel(Tlab);
      CopyAt (At3, At2);
      Compare (Umap[U.Opc], NullAt, At1, At3, Tlab);
      (* otherwise, load the second value into the same register *)
      Moveit (TgtAt, At2);
      Emitlab (Tlab);
      END;
   IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
   END;

UODD:

   (* Odd(I) = (I AND 1) <> 0.  Note that this operator does not appear
      frequently enough to worry about much. *)

   BEGIN
   Pop (At1);
   MakintconstAt (At2, 1);
   At3 := NullAt;
   Compare (Xand, At3, At1, At2, Blabl);
   Push (At3);
   Push (ZeroconstAt);
   U.Opc := UNEQ;
   Retry := True;
   END;


(* UIXA *)

UIXA:

   BEGIN
   Pop(At2);
   Pop(At1);
   IF U.Dtype = Bdt THEN
      BEGIN
      (* At2 := Abs(At2) *)
      TgtAt := NullAt;
      IF Is68000 THEN
	 BEGIN
	 MakintconstAt (At3, 1);
	 Emitbinaryop (Xand, TgtAt, At2, At3);
	 END
      ELSE
	 Emitunaryop (Xabs, TgtAt, At2);
      At2 := TgtAt;
      END;
   IF U.Length MOD AddrUnit <> 0 THEN
      IF IsDec10 OR IsDec20 OR IsMips THEN
	 Byteindex (At1, At2, U.Length)
      ELSE
         UgenError ('Illegal index size.           ',U.Length)
   ELSE
      Index (At1, At2, U.Length DIV AddrUnit);
   Push (At1);
   END;


(* UEQU UNEQ UGRT UGEQ ULES ULEQ UAND UIOR *)

UEQU,UNEQ,UGRT,UGEQ,ULES,ULEQ,UAND,UIOR:

   IF (U.Dtype = Sdt) AND (U.Opc <> Uequ) AND (U.Opc <> Uneq) THEN
      BEGIN (* set inequaltiy *)
      IF U.Opc = Uleq THEN
	 BEGIN
	 Pop (At2); Pop (At1);
	 END
      ELSE
	 (* Set1 >= Set2 -> Set2 <= Set1 *)
	 BEGIN
	 Pop (At1); Pop (At2);
	 END;
      (* To compare sets for inequality, AND the two sets and 
	  compare the result with the set that is supposed to be the 
	  lesser *)
      CopyAt (At3, At1);
      TgtAt := NullAt;
      IF At1.Mdtype <> M THEN
	 Emitbinaryop (Xand, TgtAt, At1, At2)
      ELSE
	 EmitbnvectorOp (Xand, TgtAt, At1, At2);
      Push (TgtAt);
      Push (At3);
      U.Opc := Uequ;
      Retry := True;
      END (* set inequality *)
   ELSE
      BEGIN (* not a set, or set equ/neq *)
      (* If the next instruction in a FJP or TJP, collapses it to 
	 branch-if-cond.  Otherwise, a truth value is computed and pushed. *)

      Pop(At2);
      Pop(At1);
      (* packed comparisons are O.K. as long as they are the same machine type. *)
      CoerceMtypes (At1, At2);
      IF At2.Mdtype <> At1.Mdtype THEN
	 BEGIN 
         Unpack (At1); Unpack (At2);
         END;
      IF (U.Dtype = Bdt) AND (U.Opc >= Ugeq) AND (U.Opc <= Ules) THEN
	 (* comparison of booleans must be reversed, since it is defined in
	    Pascal to be 1, and yet we are representing it as -1 *)
         CASE U.Opc OF
            Ugeq: U.Opc := Uleq;
            Ugrt: U.Opc := Ules;
	    Uior: BEGIN END;
            Uleq: U.Opc := Ugeq;
            Ules: U.Opc := Ugrt;
            END;
      Iop := Umap[U.Opc];
      IF NextU.Opc = Ufjp THEN
	 BEGIN  
         Iop := NotArr[Iop];
         NextU.Opc := Utjp;
         END;
      IF NextU.Opc = Utjp THEN
         BEGIN (* skip-jump *)
         Skip := True;
         Convertlabel (Tlab, NextU.I1);
         TgtAt := NullAt;
         IF At1.Mdtype = M THEN
	    Blockcompare (Iop, TgtAt, At1, At2, Tlab)
	 ELSE IF At1.Mdtype IN [Ds,Df] THEN
	    BEGIN
	    MakIntconstAt (At3, At1.Size);
 	    StringCompare (Iop, Tgtat, At1, At2, At3, Tlab)
	    END
         ELSE
	    Compare (Iop, TgtAt, At1, At2, Tlab);
         END  (* skip-jump *)
      ELSE
	 BEGIN
         Skip := Gettarget (NextU, TgtAt);
         IF At1.Mdtype = M THEN
	    BlockCompare (Iop, TgtAt, At1, At2, Blabl)
	 ELSE IF At1.Mdtype IN [Ds,Df] THEN
	    BEGIN
	    MakIntconstAt (At3, At1.Size);
	    Stringcompare (Iop, TgtAt, At1, At2, At3, Blabl)
	    END
         ELSE
	    Compare (Iop, TgtAt, At1, At2, Blabl);
         IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
	 END;
      END; (* not a set *)


(* UIEQU UINEQ UILEQ UILES UIGEQ UIGRT  UVEQU UVNEQ UVLEQ UVLES UVGEQ UVGRT *)

UIEQU,UINEQ,UILEQ,UILES,UIGEQ,UIGRT:

   BEGIN
   Pop (At2);
   Pop (At1);
   IF (U.Length MOD AddrUnit) <> 0 THEN
      UgenError ('Illegal block length.         ',U.Length);
   Indirect (At1, LentoMdtype (U.Length DIV AddrUnit), U.Length DIV AddrUnit);
   Indirect (At2, LentoMdtype (U.Length DIV AddrUnit), U.Length DIV AddrUnit);
   U.Opc := Udirect[U.Opc];
   IF (U.Opc = Uequ) OR (U.Opc = Uneq) THEN
      BEGIN
      Push (At1);
      Push (At2);
      Retry := True;
      END
   ELSE
      BEGIN (* string comparison *)
      Iop := Umap[U.Opc];
      IF NextU.Opc = Ufjp THEN
	 BEGIN  
         Iop := NotArr[Iop];
         NextU.Opc := Utjp;
         END;
      MakIntconstAt (At3, At1.Size);
      IF NextU.Opc = Utjp THEN
         BEGIN (* skip-jump *)
         Skip := True;
         TgtAt := NullAt;
         Convertlabel (Tlab, NextU.I1);
         Stringcompare (Iop, TgtAt, At1, At2, At3, Tlab);
         END  
      ELSE
	 BEGIN
         Skip := Gettarget (NextU, TgtAt);
	 Stringcompare (Iop, TgtAt, At1, At2, At3, Blabl);
         IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
	 END;
      END;
   END;

UVEQU,UVNEQ,UVLEQ,UVLES,UVGEQ,UVGRT: 

   BEGIN
   Pop (At3);
   Pop (At2);
   Pop (At1);
   Indirect (At1, M, 0);
   Indirect (At2, M, 0);
   Iop := Umap[Udirect[U.Opc]];
   IF NextU.Opc = Ufjp THEN
      BEGIN  
      Iop := NotArr[Iop];
      NextU.Opc := Utjp;
      END;
   IF NextU.Opc = Utjp THEN
      BEGIN (* skip-jump *)
      Skip := True;
      TgtAt := NullAt;
      Convertlabel (Tlab, NextU.I1);
      Stringcompare (Iop, TgtAt, At1, At2, At3, Tlab);
      END  
   ELSE
      BEGIN
      Skip := Gettarget (NextU, TgtAt);
      Stringcompare (Iop, TgtAt, At1, At2, At3, Blabl);
      IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
      END;
   END;


(* UDIF UUNI UINT UMUS USGS UINN *)

UDIF,UUNI,UINT:

   BEGIN
   Pop (At2);
   Pop (At1);
   Skip := Gettarget (NextU, TgtAt);
   IF At1.Mdtype = Ss THEN
      Emitbinaryop (Umap[U.Opc], TgtAt, At1, At2)
   ELSE
      EmitbnvectorOp (Umap[U.Opc], TgtAt, At1, At2);
   IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
   END;

 UINN:

    (* Is At1 in the set At2?  
       This is done with the AND test, which consists of creating a singleton set   
       representing (At1 MOD WordSize) and ANDING it with the appropriate word 
       of At2.  If the result is non-zero, then At1 is IN At2.
       If the "test necessary" flag is on, then we must first test 
       At1 to make sure that it is within the bounds of At2.
       We do all this in one of six ways, depending on the next U-code 
       instruction, and whether the initial test is needed:

	     FJP next and no test needed (this will be the most frequent case):
                 Compare (NAND,..,..,label)
             TJP next and no test needed:
  	         Compare (AND,..,..,label)
             Any other and no test needed:
		 Compare (AND,Tgt,..,..)
	     FJP next and test needed:
                 If not within bounds, jump to label
                 Compare (NAND,..,..,label)
             TJP next and test needed:
	         IF not within bounds jump to L1
  	         Compare (AND,..,..,label)
	       L1:
             Any other and test needed:
		 Load Tgt with FALSE
	         IF not within bounds jump to L1
		 Compare (AND,Tmp,..,..)
		 Compare (NEQ,Tgt,Tmp,0)
	       L1:

       *)

    BEGIN
    Pop (At2); (* the set *)
    Pop (At1); (* the integer *)
    Skip := Gettarget (NextU, TgtAt);
    IF (U.I1 = 1) THEN
       BEGIN 
       IF (NextU.Opc <> UFJP) AND (NextU.Opc <> UTJP) THEN
	  BEGIN 
          (* preload Target with FALSE *)
	  IF NOT Skip THEN MakTmpRegAt (TgtAt, ZeroConstAt.Mdtype);
          Moveit (TgtAt, ZeroConstAt);
	  END;
       (* test if within bounds of set *)
       IF NextU.Opc = UFJP THEN
          Convertlabel(Tlab, NextU.I1)
       ELSE
          Createlabel(Tlab);
       IF At2.Mdtype = Ss THEN
	  At2.Size := APW
       ELSE IF At2.Mdtype = Ds THEN
	  At2.Size := APW*2;
       Jumpifoutofrange (At1, 0, At2.Size*AddrUnit-1, Tlab);
       END;
    IF At2.Size > APW THEN
       BEGIN
       (* At5 := Bittable [At1 MOD AddrUnit]; At6 := At2 [At1 DIV AddrUnit] *)
       Indexset (At1, At2, At5, At6, At7, Bittable);
       Clean (At2); Clean (At7);
       END
    ELSE
       BEGIN (* single word set *)
       (* At5 := Bittable[At1]; At6 := At2 *)
       Indextable (At5, At1, Bittable);
       At6 := At2;
       END;
    IF (NextU.Opc = UFJP) THEN
       BEGIN
       Convertlabel(Tlab2, NextU.I1);
       Compare (Xnand, NullAt, At5, At6, Tlab2)
       END
    ELSE IF (NextU.Opc = UTJP) THEN
       BEGIN
       ConverTlabel(Tlab2, NextU.I1);
       Compare (Xand, NullAt, At5, At6, Tlab2)
       END
    ELSE
       BEGIN
       At3 := NullAt;
       Compare (Xand, At3, At5, At6, Blabl);
       Compare (Xneq, TgtAt, At3, ZeroConstAt, Blabl);
       END;
    IF (U.I1 = 1) AND (NextU.Opc <> UFJP) THEN
       Emitlab (Tlab);
    IF (NextU.Opc = UFJP) OR (NextU.Opc = UTJP) THEN
       Skip := True
    ELSE
       IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
    END; (* INN *)

 USGS:
    (* Make a set that contains only the element on top of the stack. To
       do this, we use a bit table that contain the right bit set to represent
       the sets [0] .. [Addrunit-1].  For single word sets, the set can be merely
       represented by the base of the table indexed by the At2.  For multi-word
       sets, we create a temporary, zero it out, and then move the right entry
       in the table to the appropriate word in the new set.  The entry in the
       table is found by At2 MOD AddrUnit.  The word of the set is found by At2 
       DIV AddrUnit. *)

    BEGIN
    Pop (At1);
    Skip := Gettarget (NextU, TgtAt);
    IF U.Length > WordSize THEN
       BEGIN
       IF NOT Skip THEN
          (* Get a temporary for the set. *)
          MaktempAt (TgtAt, M, U.Length DIV AddrUnit, Reference);
       (* Zero it out. *)
       ZeroBlock (TgtAt, TgtAt.Size);
       (* At2 := Bittable [At1 MOD AddrUnit]; At3 := TgtAt [At1 DIV AddrUnit] *)
       Indexset (At1, TgtAt, At2, At3, At6, Bittable);
       Clean (At6);
       (* Move Bittable[TgtAt] to correct place in set. *)
       Moveit (At3, At2); Clean (At3);
       IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
       END
    ELSE
       BEGIN
       Indextable (At2, At1, Bittable);
       IF Skip THEN 
          BEGIN
          Moveit (TgtAt, At2);
	  Clean (TgtAt);
	  END
       ELSE Push (At2)
       END
    END; (* SGS *)

 UMUS:

    (* Make a set that contains At1..At2. To do this, we zero out a set,
       then test to make sure At1 <= At2, 
       then move the first word into the right place, the the middle words,
       by a block MOVE, then the last word.  The last word must be ANDed
       into place in case it is the same as the first word.

	    0000011111 <- first word   OR  0001111000  <- first and last word
	    1111111111 <- middle word
            1111111111 <- middle word
            1110000000 <- last word
       
       The first and last words are found by indexing into two different tables,
       LMASK and RMASK.
     *)

    BEGIN
    Pop (At2);
    Pop (At1);
    Skip := Gettarget (NextU, TgtAt);
    IF NOT Skip THEN
       (* Get a temporary for the set. *)
       MaktempAt (TgtAt, LentoMdtype(U.Length DIV AddrUnit), 
			U.Length DIV AddrUnit, Reference);    
    (* Zero it out. *)
    ZeroBlock (TgtAt, TgtAt.Size);
    (* If At1 > At2, THEN we're all done. *)
    Createlabel (Tlab);
    CopyAt (At3, At1); CopyAt (At4, At2);
    Compare (Xgrt, NullAt, At3, At4, Tlab);

    (* create the first word *)
    (* At4 := Rmask [At1 MOD AddrUnit]; At3 := TgtAt [At1 DIV AddrUnit];
       At5 := At1 DIV AddrUnit *)
    Indexset (At1, TgtAt, At4, At3, At5, Rmasktable);
    Moveit  (At3, At4);
    (* TgtAt, At3, At5 still active *)
    (* create token representing the last word *)
    (* At4 := Lmask [At2 MOD AddrUnit]; At1 := TgtAt [At2 DIV AddrUnit];
       At6 := At2 DIV AddrUnit *)
    Indexset (At2, TgtAt, At4, At1, At6, Lmasktable);
    (* Tgtat, At3, At4, At5, At6 still active *)
    (* create middle words *)
    (* number of middle words + 1 := At6 - At5 *)
    CopyAt (At2, At6);
    Emitbinaryop (Xsub, At2, At6, At5);
    (* starting position of move := next word after At3 *)
    Adjobject (At3, APW, Ss, APW);
    Oneblock (At3, At2);
    (* NOW AND the last word with anything that is already there *)
    CopyAt (At2, At1);
    Emitbinaryop (Xand, At2, At1, At4);  Clean (At2);
    (* emit the jump-around label *)
    Emitlab (Tlab);
    IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
    END; (* MUS *)


(* UADJ *)

UADJ: 

   BEGIN
   Pop(At1);
   IF Odd (Trace DIV 4) THEN
      BEGIN
      UgenMsg ('ADJ old offset=               ', At1.Displ);
      UgenMsg ('ADJ old length=               ', At1.Size);
      END;
   U.Length := U.Length DIV AddrUnit;
   U.Offset := U.Offset DIV AddrUnit;
   (* Determine if the set can be merely extended or truncated. *)
   Done := False;
   Skip := Gettarget (NextU, TgtAt);
   IF NOT Skip THEN
    IF (U.Offset <= 0) AND Istemp(At1) THEN
      IF U.Length + (-U.Offset) <= At1.Size THEN
         BEGIN (* set grows smaller *)
         CopyAt (TgtAt, At1);
         Clean (At1);
         AdjObject (TgtAt, -U.Offset, LentoMdtype(U.Length), U.Length);
         Push (TgtAt);
	 Done := True;
         END
      (* Else set grows larger -- see if we can expand temp block from end *)
      ELSE 
	 BEGIN
         I := At1.Size; (* remember old size *)
         IF Expandtemp (At1, U.Length + (-U.Offset)) THEN
	    BEGIN 
	    (* zero out the new part that has been added *)
	    CopyAt (TgtAt, At1);
	    Adjobject (At1, I, LentoMdtype(At1.Size-I),At1.Size-I);
            Zeroblock (At1, At1.Size);
            Clean (At1);
            AdjObject (TgtAt, -U.Offset, LentoMdtype(U.Length), U.Length);
	    Push (TgtAt);
 	    Done := True;
            END;
	 END;
   IF NOT Done THEN    
      BEGIN (* we have to copy it to a new temporary *)
      IF NOT Skip THEN
         MakTempat (TgtAt, LentoMdtype(U.Length), U.Length, Reference);
      (* if new length > the section of the old set we are moving then
         zero out new set *)
      IF ((U.Offset > 0) AND (U.Length > At1.Size + U.Offset)) OR
         ((U.Offset <= 0) AND (U.Length > At1.Size - (-U.Offset))) THEN
         Zeroblock (TgtAt, U.Length)
      (* otherwise, if adding zeroes at the bottom, just zero out the bottom *)
      ELSE IF (U.Offset > 0) THEN
         Zeroblock (TgtAt, U.Offset);
      IF U.Offset <= 0 THEN
         BEGIN (* shift up -- only move part of the original set *)
         At1.Size := At1.Size - (-U.Offset);
         Adjobject (At1, -U.Offset, LentoMdtype(At1.Size), At1.Size);
	 END
      ELSE 
	 BEGIN (* shift down -- leave some room at the bottom of the new set *)
         TgtAt.Size := TgtAt.Size - U.Offset;
         AdjObject (TgtAt, U.Offset, LentoMdtype(TgtAt.Size), TgtAt.Size);
	 END;

      (* Move the old set to the new location.  The actual part to be moved 
         is the minimum of At1 and TgtAt.  *)

      At3 := TgtAt;
      IF At1.Size > TgtAt.Size THEN 
         BEGIN
         At1.Size := TgtAt.Size;
         At1.Mdtype := TgtAt.Mdtype;
	 END
      ELSE  
         BEGIN
         At3.Size := At1.Size;
         At3.Mdtype := At1.Mdtype;
	 END;
      Moveit (At3, At1);
      IF Skip THEN Clean (TgtAt) ELSE Push (TgtAt);
      END;
   IF Odd (Trace DIV 4) THEN
      BEGIN
      UgenMsg ('ADJ new offset=               ', TgtAt.Displ);
      UgenMsg ('ADJ new length=               ', TgtAt.Size);
      END;
   END;


(* UDUP USWP UPOP *)

USWP:
  (*This ucode instructions causes the top two virtual stack elements to 
    be swapped*)
   BEGIN
   Pop (At1);
   Pop (At2);
   Push (At1);
   Push (At2);
   END;
 
UDUP:
   (*Duplicate the Operand *)
   BEGIN
   Pop (At1);
   IF At1.Mdtype = M THEN
      BEGIN
      MaktempAt (At2, M, At1.Size, Reference);
      CopyAt (At3, At1);
      Moveit (At2, At3);
      END
   ELSE
      Loadreg (At2);
   Push (At1);
   Push (At2);
   END;

UPOP:
   BEGIN
   Pop(At1);    (*Pop the top element off of the virtual stack*)
   Clean(At1);  (* and release its resources*)
   END;


(* ULAB UBGNB UCLAB UENDB *)

ULAB:
   BEGIN
   ConvertLabel (Tlab,U.I1);
   Emitlab (Tlab);
   (* If label jumped to by another procedure, then code may have to be 
      executed to restore the Sp. *)
   IF U.lexlev = 1 THEN 
      Restframe;
   Basicblock (Fakemarkers = 0);
   END;

UCLAB:
   (* Output the ucode label, and kill all register bindings *)
   BEGIN
   Convertlabel(Tlab,U.I1);
   Emitlab (Tlab);               
   Basicblock (Fakemarkers = 0);
   END;

UBGNB:
   BEGIN
   (* load everything on the stack to prevent side effects *)

   Loadstack;

   (* Create and push onto the stack a MST Stack Token *)
   At1.Form := Smst;
   At1.Reg := 1;
   Push (At1);
   Fakemarkers := Fakemarkers + 1;
   END;

UENDB:
   BEGIN
   (* Make sure TOS is a MST token, then pop it. *)
   Emptystack;
   Pop(At1);
   Fakemarkers := Fakemarkers - 1;
   END;


(* UFJP UTJP UUJP UGOOB *)

UFJP,UTJP:

   BEGIN
   Pop(At1);
   Convertlabel(Tlab,U.I1);
   (* Fjp = Jump if equal to zero*)
   IF U.Opc = Ufjp THEN
      Compare (Xequ, NullAt, At1, ZeroConstAt, Tlab)   
   ELSE
      Compare (Xneq, NullAt, At1, ZeroConstAt, Tlab);
   IF Dbginfo.Debug THEN Addlabelloc (Jumploc, Tlab);
   END;

UUJP:

   BEGIN
   Convertlabel(Tlab,U.I1);              
   IF NextU.Opc = Uujp THEN
      CaseJump (Tlab)
   ELSE
      Simplejump (Tlab);
   IF Dbginfo.Debug THEN Addlabelloc (Jumploc, Tlab);
   END;

UGOOB: 

   BEGIN
   Calleeregs (Rgs);
   Rgs := Rgs - Pregs;
   Restoreregs (Rgs);
   Cutstack (U.Lexlev, Clex);
   (* jump to the given label *)
   ConvertLabel (Tlab,U.I1);
   Simplejump (Tlab);
   IF Dbginfo.Debug THEN Addlabelloc (Jumploc, Tlab);
   END; 


(* UCHKH UCHKL UCHKN UCHKT UCHKF *)

UCHKH, UCHKL:

   IF U.Dtype = Sdt THEN
      BEGIN
      (* Emit code to check that all elements of the set above/below U.Length 
         are zeroes. *)
      Pop (At1);
      CopyAt (At2, At1);
      IF U.Opc = UCHKL THEN
	 (* Zero check from word #0 of set to word #(Length) *)
	 BEGIN
	 IF (U.Length MOD WordSize <> 0) OR (U.Length <= 0) THEN
	    UgenError ('Illegal CHKL value            ',U.Length);
	 At2.Size := U.Length DIV AddrUnit
	 END 
      ELSE
	 BEGIN
	 IF ((U.Length+1) MOD WordSize <> 0) THEN
	       UgenError ('Illegal CHKH value.           ',U.Length);
         U.Length := (U.Length + 1) DIV AddrUnit;
	 IF (U.Length >= At2.Size) THEN
            UgenError ('CHKH value larger than object.',U.Length);
	 (* Zero check goes from word #(Length) to word#(oldSize) *)
         At2.Size := At2.Size - U.Length;
	 Adjobject (At2, U.Length, LenToMdtype (At2.Size), At2.Size);
	 END; 
      IF Odd (Trace DIV 4) THEN
	 BEGIN
         UgenMsg ('CHK offset=                   ', At2.Displ);
         UgenMsg ('CHK length=                   ', At2.Size);
	 END;
      Checkblock (At2, At2.Size);
      Push (At1);
      END
   ELSE
      BEGIN
      (* compare the TOS with the constant from the U-code instruction and
	 jump to error routine if greater/less. *)
      Pop(At1);                         (*Construct the operands*)
      CopyAt (At2, At1);
      (* collapse CHKL, CHKH pair *)
      IF (U.Opc = Uchkl) AND (NextU.Opc = Uchkh) THEN
	 BEGIN
         Emitboundscheck (At2, U.Length, NextU.Length);
         Skip := True;
         END
      ELSE IF (U.Opc = Uchkh) AND (NextU.Opc = Uchkl) THEN
         BEGIN
         Emitboundscheck (At2, NextU.Length, U.Length);
         Skip := True;
         END
      ELSE IF (U.Opc = Uchkl) THEN
         Emitboundscheck (At2, U.Length, Tgtmaxint)
      ELSE (* U.Opc = Uchkh *)
         Emitboundscheck (At2, -Tgtmaxint, U.Length);
      Clean (At2);
      Push (At1);               (*Push the tested value back *)
      END;

UCHKN:
   (* nil check: jump to error routine if pointer is not in the heap *)
   BEGIN
   END;

UCHKT:
   BEGIN
   Pop (At1);
   Emitboundscheck (At1, -1, -1);
   Clean (At1);
   END;

UCHKF:
   BEGIN
   Pop (At1);
   Emitboundscheck (At1, 0, 0);
   Clean (At1);
   END;


(* UOPTN UBGN UCOMM ULOC *)

UOPTN:
   Setoptn (U);

UBGN: (* Beginning of module *)
   WITH Dbginfo DO
      BEGIN
      (* Save the name for later use. *)
      CurModname := U.Pname;            
      (* Make up a label for the MFIB by appending a period. *)
      For I := 1 to Labchars DO
	 Curmodlabl[I] := Curmodname[I];
      Addtoend (Curmodlabl,'.');        
      END;

USTP: 
   IF U.Pname <> Dbginfo.CurModname THEN
      UgenError ('BGN-STP mismatch.             ', Novalue);
    
UCOMM: (* Pass the comment to assembly file *)
   WritComment (U);

ULOC:  (* Beginning of statement. *)
   BEGIN
   CurP := U.I1;
   CurL := U.Offset;
   Stmtctr := Stmtctr + 1;
   IF Dbginfo.Debug OR Dbginfo.Profile THEN
      BEGIN
      (* every LOC in the code stream must be followed immediately by a label *)
      IF (NextU.Opc <> Ulab) THEN
         Createlabel (Tlab)
      ELSE 
	 BEGIN
         ConvertLabel (Tlab,NextU.I1);  Skip := True;
	 END;
      Emitloc (CurP, CurL);
      Emitlab (Tlab);
      END
   ELSE
      Emitloc (CurP, CurL);
   ShareVar (ShPage, CurP);
   ShareVar (ShLine, CurL);

   (* The stack should be empty at this point (e.g. TOS should be a MST token).
      If not, print error and pop it off. *)
   Emptystack;
   (* If this is the first statement of the main block, insert a call to the
      debugger. *)
   IF Writedebugcall THEN
      BEGIN
      Calldebugger;
      Writedebugcall := False;
      END;
   IF Dbginfo.Profile THEN 
      BEGIN (* increment count for this statement *)
      Makaddrat (At1, Ss, Stmtctr-1, Dbginfo.Proflabl, Reference);
      Emitunaryop (Xinc, At1, At1);
      END;
   END;


(* UENT UPLOD URET UEND *)

UENT: 

   BEGIN

   Basicblock (True);

   (* get the name of the procedure and print it out *)
   WITH Dbginfo DO
      BEGIN
      FOR I := 1 TO Labchars DO
         CurProclabl[I] := U.Pname[I];
      CurProcname := '                ';

      (* For Pascal files, the real name of the procedure is in the
         following comment statement *)
      IF CurProclabl [Modchars + 1] = '$' THEN
	 BEGIN
	 IF NextU.Opc <> UCOMM THEN
	    BEGIN
	    UgenError ('Missing procedure name.       ', Novalue);
	    CurProcname := U.Pname;
	    END
	 ELSE 
	    BEGIN
	    FOR I := 1 TO NextU.Constval.Len DO
	       IF I <= Identlength THEN
		   CurProcname[I] := NextU.Constval.Chars[I];
	    Skip := True;
	    END
	 END
      ELSE
	 CurProcname := U.Pname;

      (* save the name of the first procedure of the file and module *)
      IF Dbginfo.Debug OR Dbginfo.Profile THEN
	 BEGIN
	 Createlabel (CurPiblab);
	 IF Modfirstproc[1] = ' ' THEN
	    BEGIN
	    Modfirstproc := CurProclabl;
	    IF Filefirstproc[1] = ' ' THEN
	       Filefirstproc := CurProclabl;
	    END;
         Cblk := U.I1;
(*	 Minvarreg := -1;*)
	 END
       ELSE CurPiblab[1] := ' ';

      (* See if this is the main routine. *)
      IF U.Lexlev = 1 THEN  
	 BEGIN
	 Mainname := CurProcname;
	 Main := CurProclabl;
	 IF Dbginfo.Debug THEN Writedebugcall := True;
	 END;
      END;
   (* Adjust The Lexical Level Pointers *)
   Plex := Clex;
   Clex := U.Lexlev;
   Cblk := U.I1;
   Blklexmap[U.I1] := U.Lexlev;

   Initproc (Dbginfo);
   Newcode (Dbginfo);
   Inittemps;
   EmitEntrycode (Dbginfo.CurProclabl, (Clex < Plex) AND (Clex > 1), 
                  Dbginfo, Clex);

   Globaloffset := 0;
   Localoffset := -1;
   Fakemarkers := 0;
   Msize := Localstart; (* in case there is no DEF statement *)
   MaxParCount := 0;
   Pregs := [];
   
   (* Initialize function result operand. *)
   FuncresAt := NullAt;  
   END;


UPLOD:  (* Load contents of address given into function result register *)
   BEGIN
   At1.Form := Empty;
   FuncResAt.Mdtype := Machinetype(U.Dtype,U.Length);
   MakFuncResAt (FuncresAt);
   IF Binding AND (U.Mtype <> Rmt) THEN
      IF Matchreg (Machinetype(U.Dtype,U.Length), U.Mtype, U.I1, U.Offset, Treg, False) THEN
         MakRegAt (At1, Machinetype(U.Dtype,U.Length), Treg);
   IF At1.Form = Empty THEN
      MakBlkoffsetAt (At1, U, Blklexmap[U.I1], Clex, Reference);
   Moveit (FuncresAt, At1);
   END;

URET: 
   BEGIN

   IF Dbginfo.Debug THEN Addlabelloc (Returnloc, Blabl);
   (* If the function result register has been claimed by Plod, release it. *)
   Calleeregs (Rgs);
   Rgs := Rgs - Pregs;
   Restoreregs (Rgs);
   EmitExitCode ((Clex < Plex) AND (Clex > 1), Clex, Dbginfo);
   Clean (FuncresAt);  
   END;
 
UEND: 
   BEGIN
   Emptystack; (* Make sure stack is empty. *)
   (* Do all fixups.  Peephole optimize.  Write out procedure. *)
   Calleeregs (Rgs);
   WITH Dbginfo DO
      BEGIN
      Mincreg := Maxreg;
      Maxcreg := -1;
      FOR I := 0 to Maxreg DO
	 IF I IN Rgs THEN
	    BEGIN
	    IF I < Mincreg THEN Mincreg := I;
	    IF I > Maxcreg THEN Maxcreg := I;
	    END;
      IF Maxcreg = -1 THEN Mincreg := -1;
      END;
   Rgs := Rgs - Pregs;
   Saveregs (Rgs);
   Writeproc (Dbginfo, Msize, Getmaxtmp);
   END;


(* UMST UPAR UCUP ICUP *)

(* Paramater passing:

   Parameters are stored into their home location in the callee's stack    
frame, unless it will live in a register, in which case it is put directly
into the register.  
   Currently ALL PARAMETERS ARE SINGLE WORDS.  Larger objects are passed
by reference and then copied by the callee.  This greatly simplifies the
allocation of locals to registers.
   A complication arises in nested calls (which are signalled by two MSTs
without an intervening CUP), e.g. I := F(X,G(Y));.
We have already stored
X in its home location in F's stack frame, so that stack frame must be
preserved (although so far we don't know its total size).  Because of this,
the stack pointer must be explicitly adjusted upwards at this point, and
then adjusted downwards after the call, so that parameters will continue
to be loaded in the right order.

*)

UMST: 
   BEGIN


   (* Create MST Stack Token *)
   At1.Form := Smst;
   At1.Displ := Globaloffset;
   At1.Reg := 2;
   At1.Size := Localoffset;
   Push (At1);
   (* If no paramters have been pushed for the previous procedure, there
      is no need to preserve a partial stack frame. *)
   IF Localoffset > -1 THEN
      Globaloffset := Globaloffset + Localoffset + APW;

   Localoffset := -1;
   END;


UPAR: 
   BEGIN
   IF NOT DownStkLnk THEN
      BEGIN
      Pop (At1);
      IF (U.Length <> WordSize) THEN
	 UgenError ('Invalid parameter length.     ',U.Length);
      IF NOT Gettarget (U, TgtAt) THEN;
      Moveit (TgtAt, At1);
      END;
   END;


UICUP, UCUP:

   BEGIN
   IF U.Opc = UICUP THEN 
      Pop (At1); (* pop procedure descriptor *)
   Pop (At4);
   Parcount := 0;
   IF DownStkLnk THEN
      WHILE At4.Form <> Smst DO
	 BEGIN
         Parcount := Parcount + 1;
	 Pushparm (At4, Parcount);
	 IF Is68000 AND (At4.Mdtype = DF) THEN
	    Parcount := Parcount + 1;
	 Pop (At4);
	 END;
   IF Parcount > Maxparcount THEN Maxparcount := Parcount;
   (* Find mdtype of function result and save in At5. *)
   IF U.Dtype = Pdt THEN 
      At5.Mdtype := Ill
   ELSE
      At5.Mdtype := Machinetype (U.Dtype, DtyptoLen(U.Dtype)*Addrunit);
   IF U.Opc = UICUP THEN
      BEGIN
      (* See comments for procedure Restrcalleedisplay. *)
      (* get the procedure descriptor from the stack *)
      Indirect (At1, Sa, 0);
      (* At2 := At1[2:*], e.g., the old display *)
      CopyAt (At2, At1);
      AdjObject (At2, APW, Sa, APW);
      (* Swap displays. *)
      Restrcalleedisplay (At2);
      (* Emit the call. An extra indirection is needed because the argument of
         the call is of type Literal *)
      CopyAt (At3, At1);
      Indirect (At3, Sa, APW);
      Callproc (Parcount, False, Globaloffset, At3);
      Clean (At3);
      Basicblock (False);
      Retrnfromcall (Globaloffset, At5);
      (* Swap displays back. *)
      CopyAt (At2, At1);
      AdjObject (At2, APW, Sa, APW);
      Restrcalleedisplay (At2);
      Clean (At1);
      END
   ELSE
      BEGIN
      For I := 1 to Labchars DO
         CalleeAt.Labfield[I] := U.Pname[I];
      IF U.I1 = 0 THEN CalleeAt.Labfield[Labcharsp1] := 'X'
      ELSE CalleeAt.Labfield[Labcharsp1] := ' ';
      Callproc (Parcount, Blklexmap[U.I1] > Clex, Globaloffset, CalleeAt);
      (* For non-standard routines, add to debugger LOC table *)
      IF Dbginfo.Debug AND (U.Pname[1] <> '$') THEN 
         Addlabelloc (Jumploc, CalleeAt.Labfield);
      Basicblock (False);
      Retrnfromcall (Globaloffset, At5);
      END;

 
   IF At4.Form <> Smst THEN 
      Ugenerror ('Missing MST                   ',Novalue);
   (* If function, push operand representing the function result onto the
      stack. *)
   IF U.Dtype <> Pdt THEN 
      Push (At5);

   Globaloffset := At4.Displ;
   Localoffset := At4.Size;
   END;


(* ULDP *)

ULDP: BEGIN
      (* For the S-1 the procedure descriptor consists of
	 tempblock: Address of procedure
		    CP at time of LDP

	At the UICUP instruction, the saved CP is exchanged with the
	current CP before the call, and is restored after the call.   *)
       
      (* First, reserve a temporary of the appropriate size. *)
      I := Blklexmap[U.I1] - 2; (* number of frame pointers that must be passed *)
      IF IsS1 OR (I = 0) THEN
        MaktempAt (At1, Ds, 2*APW, Reference)
      ELSE
	MaktempAt (At1, M,(2+I)*APW, Reference);

      (*put the address of the procedure in tempblock 0*)
      For I := 1 to Labchars DO
	 Tlab[I] := U.Pname[I];
      MakAddrAt (At2, Sa, 0, Tlab, Literal);
      At1.Mdtype := Sa;
      Moveit (At1, At2);
      
      CopyAt (At2, At1);
      Adjobject (At2, APW, Sa, APW);
      Savepassedprocdisplay (At2, Clex, Blklexmap[U.I1]);
      Clean (At2);

      GetAddr (At1);
      Push (At1);
      END;



(* UNEW UDSP *)

UDSP:

   (* Sets the heap pointer to be (Stktop-1). *)

   BEGIN
   Pop (At2);
   Clean (At2);  (* not used *)
   Pop (At1);
   At1.Mdtype := Sa;
   Makaddrat (At3, Sa, 0, Heapptr, Reference);
   Moveit (At3, At1);
   END;

UNEW:

   BEGIN
   (* Add TOS to the current value of the heap ptr and store new value
      in heap ptr. *)
   Pop (At1);
   Pop (At2);
   MakAddrAt (At3, Sa, 0, Heapptr, Reference);
   IF IsDec10 THEN
      BEGIN
      CopyAt (At4, At3);
      Emitbinaryop (Xsub, At3, At4, At1);
      END
   ELSE
      BEGIN
      CopyAt (At4, At3);
      CollapseIndex (At4, At1);
      Moveit (At3, At4);
      END;

   (* store value of heap ptr in TOP-1 *)
   Indirect (At2, Sa, APW);
   Moveit (At2, At3);
   (* if indicated, zero out the new record *)
   IF U.I1 = 1 THEN
      IF At1.Ctype = Intconst THEN
          BEGIN
          Indirect (At2, LentoMdtype (At1.Displ), At1.Displ);
	  Zeroblock (At2, At1.Displ)
          END
      ELSE
          UgenError ('Variable-length NEW not impl. ', Novalue);
   Clean (At2);
   END;


(* UXJP *)

UXJP:

   BEGIN
   Pop(At1);
   Convertlabel (Tlab, U.Label2);  (* OTHERS label *)
   IF Dbginfo.Debug THEN Addlabelloc (Jumploc, Tlab);
   Jumpifoutofrange (At1, U.Offset, U.Length, Tlab);
   (* Subtract lower bound. *)
   IF U.Offset <> 0 THEN
      BEGIN
      MakIntconstAt (At2, U.Offset);
      Tgtat := NullAt;
      Emitbinaryop (Xsub, TgtAt, At1, At2);
      At1 := TgtAt;
      END;
   (* Construct indexed jump destination. *)
   Convertlabel(Tlab,U.I1);  
   IndexTable (At2, At1, Tlab);
   Jumpindirect (At2);
   IF Dbginfo.Debug THEN Addlabelloc (Caseloc, Tlab);
   Clean (At2);
   END;


(* ULEX UPSTR UREGS UDATA UIMPV UEXPV USDEF UDEF UINIT *)

ULEX: Blklexmap [U.I1] := U.Lexlev;
      
UPSTR: 
   IF (U.Mtype = Rmt) THEN
      Pregs := Pregs + [Regno(U.Offset)];

UREGS: 
   IF U.Lexlev = 0 THEN
      ReserveRegs (U.I1, U.Offset, U.Length DIV AddrUnit, Dbginfo); 

UDATA: BEGIN 
   IF (U.I1 < 1) THEN
      UgenError ('Illegal DATA number           ', U.I1)
   ELSE IF (U.I1 > Maxcommons) THEN
      UgenError ('Too many Commons              ',U.I1)
   ELSE 
      BEGIN
      FOR I := 1 TO Labchars DO
	 Tlab[I] := U.Pname[I];
      SetStaticAreaName (U.I1, Tlab);
      END;
   END;

UIMPV: 
   BEGIN 
   FOR I := 1 TO Labchars DO
      Tlab[I] := U.Vname[I];
   Tlab[Labcharsp1] := 'X';
   WITH U DO (* Add the import variable to the static area list *)
      Addvar (0, Offset DIV AddrUnit, Offset DIV AddrUnit, 
	       Length DIV AddrUnit, Notconst, Constval, Tlab);
   END;

UEXPV: 
   BEGIN 
   U.Dtype := Zdt;
   FOR I := 1 TO Labchars DO
      Tlab[I] := U.Vname[I];
   WITH U DO (* Add the export variable to the static area list *)
      Addvar (1, Offset DIV AddrUnit, Offset DIV AddrUnit, Length DIV AddrUnit, 
	      Notconst, Constval, Tlab);
   END;

USDEF: 
   BEGIN
   IF (U.Length MOD AddrUnit <> 0) THEN
         UgenError ('Area length not aligned.      ',U.Length);
   DumpArea (U.I1, U.Length DIV AddrUnit); 
   END;

UDEF: 
   IF U.Mtype = Mmt THEN
      BEGIN
      Msize := (U.Length DIV AddrUnit) + Localstart;
      IF IsMips THEN MSize := MSize + MaxParCount * APW;
      END
   ELSE IF U.Mtype <> Pmt THEN 
      UgenError ('Illegal memory type           ',Novalue);

UINIT: 
   BEGIN 
   IF U.Mtype <> Smt THEN
      UgenError ('Can only init static          ',Novalue);
   WITH U DO
      BEGIN
      (* If initial value is an address, change from bit to byte address. *)
      IF Dtype = Adt THEN
         IF Initval.Ival <> -1 THEN
	    IF Initval.Ival MOD AddrUnit <> 0 THEN
	       UgenError ('INIT address not aligned.     ',Initval.Ival)
	    ELSE Initval.Ival := Initval.Ival DIV AddrUnit;
      IF Offset MOD AddrUnit <> 0 THEN
         UgenError ('INIT offset not aligned.      ',Offset);
      IF Offset2 MOD AddrUnit <> 0 THEN
         UgenError ('INIT offset2 not aligned.     ',Offset2);
	
      IF U.Length MOD Addrunit <> 0 THEN
	 U.Length := U.Length + Addrunit - (U.Length Mod Addrunit);
      Addvar (I1, Offset DIV AddrUnit, Offset2 DIV AddrUnit, 
               Length DIV AddrUnit, DtypetoCtype (Dtype,Initval), Initval, Blabl);
      END;
   END;


(* Not implemented. *)

UNOP: ; (* do-nothing opcodes *)

(*%ift HedrickPascal*)
{(* The OTHERS case is not necessary.  It merely gives a more intelligent error }
{   message if we have forgotten something.}
{UEOF:}
{  UgenError ('Unexpected end of file.       ',Novalue);}
{}
{OTHERS:}
{  UgenError ('Not implemented.              ',Ord(U.Opc));}
(*%endc*)

END; (* case *)
END; (* oneop *)


PROCEDURE OneModule;

(* Compiles one module.  Calls Initmodule, Oneop. *)

VAR
   Opstring: Opcstring;

BEGIN

Initmodule;		(* Initialize OB for this module. *)

WITH Dbginfo DO
   BEGIN
   Modfirstproc[1] := ' ';
   Highestcommon := 0;
   END;

(* Lookahead mechanism: controlled by the variables Skip and Retry.  If
   Retry is true, that means that Oneop has simplified a U-code instruction by
   changing U, and it should be re-compiled. 
      (e.g. LOD X, LDC 1, ADD -> LOD X, INC 1)
   IF Skip is true, it means that Oneop has already dealt with NextU, and it
   should be ignored.
      (e.g. EQU X, TJP L1 --> Jump-if-equal to L1.
            LOD X, INC 1, STR X --> Increment X)
   Skip is initially set to True so that the pump will be primed correctly.
*)

Skip := True;  Retry := False;  

REPEAT

   Timer := Curtime;
   (* If Retry is not true, then move NextU to U and get next Ucode instruction.*)
   IF Retry THEN
      Retry := False
   ELSE
      BEGIN
      IF Skip THEN
	 BEGIN
         ReadUinstr (U);
         Skip := False;
         END
      ELSE
         U := NextU;
      ReadUInstr (NextU);
      (* Bypass all comments, for better lookahead, except if current instruction
         is ENT or OPTN, for which comments are significant. *)
      IF NextU.Opc = Ucomm THEN
	 IF (U.Opc <> Uent) AND (U.Opc <> Uoptn) THEN
	    WHILE NextU.Opc = Ucomm DO
	       BEGIN
	       WritComment (NextU);
	       ReadUinstr (NextU);
	       END;
      END;

   Readtime := Readtime + (Curtime - Timer);
   Timer := Curtime;

   IF Odd (Trace) THEN 
      BEGIN
      GetOpcstr (U.Opc, Opstring);
      TraceUcode (U, Opstring); 
      END;
   Oneop;
   Asmtime := Asmtime + (Curtime - Timer);

UNTIL (U.Opc = USTP) OR (U.Opc = UEOF);

IF Dbginfo.Debug OR Dbginfo.Profile THEN Writmoduleinfoblock (Dbginfo, CurP, CurL);

END (* OneModule *);


BEGIN (* main block *)

(* Main block. Calls initialization routines, Onemodule. *)

(* Call initialization routines (one per module).  Keep track of time 
   used for initialization. *)
(* Note: InitAt must be called before Inittp. *)

Inittime := Curtime;

(*%ift HedrickPascal *)
{Rewrite (Output, 'Tty:');}
(*%endc*)

WITH Commandline DO
   BEGIN
   (* Get file name(s) and options from user. *)
   Filenams[1] := Blankfilename;
   Filenams[2] := Blankfilename;
   Switches[1] := 'UGEN            ';
   GetCommandline (Commandline);
   (* Filenams[1] should be the source file, Filenams[2] the object file. *)
   IF IsDec10 OR IsS1 THEN
      Addext (Filenams[1],'UCO')
   ELSE
      Addext (Filenams[1],'u  ');
   IF Filectr = 1 THEN
      (* If only one file specified, use same name as source, adding extension. *)
      BEGIN
      Filenams[2] := Filenams[1];
      Newext (Filenams[2], Objext);
      END
   ELSE
      Addext (Filenams[2], Objext);
   END;

InitAt;
InitSp;
InitTp;
InitUr (Commandline.Filenams[1]);
InitCd (Commandline.Filenams[2]);
InitSt;
InitTm;
InitRg;

NextU.Opc := Unop;
WITH Commandline DO
   FOR I := 1 TO Switchctr DO
      BEGIN
      U.Pname := Switches[I];
      U.I1 := Switchvals[I];
      Setoptn (U);
      END;

Inittime := Curtime - Inittime;

Readtime := 0; Asmtime := 0;
Dbginfo.Main[1] := ' ';

(* Process modules until EOF is found. *)

WHILE NextU.Opc <> Ueof DO
  Onemodule;

(* Write out FIB. *)

IF Dbginfo.Main[1] <> ' ' THEN
   Putlab (Mfiblab, 0, True, 'Main FIB        ');
IF Dbginfo.Debug OR Dbginfo.Profile THEN 
   Writfileinfoblock (Dbginfo, Stmtctr);

(* Print statistics. *)
Writstats (Inittime, Readtime, Asmtime);

(* If this file contained the main block, write out the initialization code. *)
Endfile (Dbginfo.Main, Dbginfo.Profile);
Uexit (False);
END.
