(* -- UCODE.INC -- *)

(* Host compiler: *)
  (*%SetT UnixPascal T *)

  (* This file contains all types that define U-code *)
CONST
  (* set constant representation in Ucode *)
  Setbackwards = False;    (* high order member first ? - false in VAX *)
  Setdigitbits = 4;        (* ALWAYS HEX! *)
  Maxoperands = 10;   (* maximum number of operands in u-code instruction + 1 *)
  Identlength = 16;     (* size of a string of type ident*)
  Filepartlen = 16;
  Blankpart = '                ';
  Filenamelen = 36;	(* maximum length file name in target operating system *)
  Fileextlen = 3;	(* maximum length of file extensions within U-code system *)
  BlankFilename = '                                    ';
  Blankid = '                ';
  Strglgth = 128;       (* maximum length for string-constant *)
  Maxinstlength = 30; (* maximum size of a b-code instruction, in host words, =
                         max (size of largest set constant (in bits), size of 
                         largest string constant (in bits)) div wordsize+ 2;  *)
  Maxswitches = 10;   (* maximum number of switches user can set in command line *)
  Maxfiles = 3;   (* maximum number of files user can specify in command line *)
TYPE
  Identname = PACKED ARRAY[1..Identlength] OF Char;
  Filepart = PACKED ARRAY [1..Filepartlen] of Char;
  Filename = PACKED ARRAY [1..Filenamelen] of Char;
  Fileext = PACKED ARRAY [1..Fileextlen] OF Char;

  Datatype = (Adt,    (*address (pointer)*)
              Bdt,    (*boolean*)
              Cdt,    (*character*)
              Edt,    (*procedure entry point*)
              Idt,    (*integer, double word*)
              Jdt,    (*integer, single word*)
              Ldt,    (*non-negative integer, single word*)
              Mdt,    (*array or record*)
              Pdt,    (*procedure, untyped*)
              Qdt,    (*real, double word*)
              Rdt,    (*real, single word*)
              Sdt,    (*set*)
              Zdt);   (*undefined*)


  Memtype =  (Zmt,
              Pmt,    (*parameters*)
              Tmt,    (*temporaries*)
              Smt,    (*statically allocated memory*)
              Mmt,    (*complex variables*)
              Fmt,    (*simple variables*)
              Rmt);   (*register*)


  (*constants*)
  Valuptr = ^Valu;
  Valu =

  RECORD                          (*describes a constant value*)
    CASE Datatype OF
      Adt,Bdt,Cdt,Ldt,Jdt: (Ival: Integer);
      Mdt,Qdt,Rdt,Sdt: 
	(Len: 0..Strglgth;
	 Chars: PACKED ARRAY [1..Strglgth] OF Char);
  END;

  (*ucode instructions*)

  Uopcode =
  (Uabs,Uadd,Uadj,Uand,Ubgn,Ubgnb,Uchkf,Uchkt,Uchkh,Uchkl,Uchkn,Uclab,Ucomm,
   Ucup,Ucvt,Ucvt2,Udata,Udead,Udec,Udef,Udif,Udiv,Udsp,Udup,Uend,Uendb,Uent,
   Uequ,Uexpv,Ufjp,Ugeq,Ugrt,Ugoob,Uicup,Uiequ,Uigeq,Uigrt,Uileq,Uiles,
   Uilod,Uimpm,Uimpv,Uineq,Uinc,Uinit,Uinn,Uinst,Uint,Uior,Uistr,Uixa,Ulab,
   Ulca,Ulda,Uldc,Uldp,Uleq,Ules,Ulex,Uloc,Ulod,Umin,Umax,Umod,Umov,Umpy,Umst,
   Umus,Uneg,Uneq,Unew,Unot,Unstr,Uodd,Uoptn,Upar,Uplod,Upop,Upstr,Uregs,Uret,
   Urlod,Urnd,Urstr,Usdef,Usgs,Usqr,Ustp,Ustr,Usub,Uswp,Usym,Utjp,Uujp,Uuni,
   Uvequ,Uvgeq,Uvgrt,Uvles,Uvleq,Uvmov,Uvneq,Uxjp,Uxor,Uzero,Unop,Ueof);

  Bcrec = PACKED RECORD
     CASE Boolean OF False:
    (Opc: Uopcode;       (* 7 bits *)
     Dtype : Datatype;  (* 4 bits *)
     Mtype : Memtype;   (* 2 bits *)
     Lexlev : 0..15;    (* 4 bits *)
     I1: 0..65535;      (* 16 bits *) (* used for labels and block numbers *)
     CASE Uopcode OF
          Ucvt: (Dtype2: Datatype);
          Uent: (Pname: Identname;
                 CASE Uopcode OF
                    Ucup: (Pop,Push,Extrnal: 0..127);
                );
          Uchkl: (Checkval: Valu);
          Uiequ: (Length: Integer;
                  CASE Uopcode OF
                     Uldc: (Constval: Valu);
                     Udata:(Areaname: Identname);
                     Uiequ:(Offset: Integer;
                            CASE Uopcode OF
                               Usym: (Vname: Identname);
                               Uinit: (Offset2:Integer; Initval: Valu);
                               Uxjp: (Label2: 0..35535)
                      )
                )
          );
          True: (Intarray: ARRAY[1..Maxinstlength] OF Integer);
     END (*record*);

  (* source line buffer *)
  Sourceline = PACKED ARRAY [1..Strglgth] OF Char;      

  Opcstring = PACKED ARRAY [1..4] OF Char; (* string representation of an 
                                              Uopcode *)
  (* different types of operands in a u-code inustrtion *)

  Uoperand = (Sdtype, Smtype, Slexlev, Slabel0, Slabel1, Sblockno,
              Sdtype2, Spname0, Spname1, Spop, Spush, Sexternal, Scheckval,
              Slength, Sconstval, Scomment, Sareaname, Soffset,
              Svname0, Svname1, Soffset2, Sinitval, Slabel2,
              Send);
  (* describes the order and type of operands in a u-code inustrtion *)
  Uops = ARRAY [1..Maxoperands] OF Uoperand;

  Utabrec = Record
     Format: Uops;      (* operands *)
     Opcname: Opcstring; (* opcode name table *)
     Hasconst: Boolean; (* true if instruction requirs constant *)
     Instlength: 1..Maxinstlength; (* length of instruction *)
     END;

  Commandrec =
     RECORD
     Filectr: Integer;
     Filenams: Array[1..Maxfiles] of Filename;
     Switchctr: Integer;
     Switches: Array[1..Maxswitches] OF Identname;
     Switchvals: Array[1..Maxswitches] OF Integer;
     END
   ;
