(* log   

    10MAR: added Fpacked, Fpackunit to support packed files.
	      key: Rpacked.
           Cleaned up thresholds.  Eliminated Functhr,Mthr.
	      key: threshold
           added machine, newrelease options.
              key: machine
	   made sets hex always
	      key: setdigitbits
           Records and arrays now always begin and end on addrunit boundaries

    13APR
    added registers key:Minlocreg,MAxlocreg
    added Calcfdbsize
*)

(************************************************************************
 *                                                                      *
 *      (C) COPYRIGHT 1981                                              *
 *      BOARD OF TRUSTEES                                               *
 *      LELAND STANFORD JUNIOR UNIVERSITY                               *
 *      STANFORD, CA. 94305, U. S. A.                                   *
 *                                                                      *
 *      This program may be freely duplicated and distributed           *
 *      provided the copyright notice is retained.                      *
 *                                                                      *
 *      This work was performed as part of the programming language     *
 *      and compiler development at Stanford University for the S-1     *
 *      computer, under subcontracts from the Lawrence Livermore        *
 *      Laboratory to the Computer Science Department, Principal        *
 *      Investigators Profs. Gio Wiederhold and John Hennessy.  The     *
 *      development of the S-1 computer at Livermore is funded by       *
 *      the Office of Naval Research of the U.S.  Navy and the          *
 *      Department of Energy.                                           *
 *                                                                      *
 ************************************************************************)


(************************************************************************
 *
 *                           U C O D E - P A S C A L
 *                           -----------------------
 *
 *      Pascal to U-code compiler, produced for the S-1 Project at Stanford
 *      University by Armando Rodriguez, Peter Nye, and Noah Mendelson.
 *      Derived from the Decsystem-10 Pascal compiler written by H. H. Nagel,
 *      University of Hamburg.
 *
 *      Present maintainer:
 *
 *              Peter Nye
 *              Department of Computer Science
 *              Stanford University
 *              Stanford, Ca 94305
 *
 *              Arpanet address:  PN at SU-AI
 *
 *      This work was performed as part of the programming language and compiler
 *      development at Stanford University for the S-1 computer,
 *      under a subcontract from the Lawrence Livermore Laboratory (derived from
 *      a contract from the Office of Naval Research of the U.S. Navy)
 *      to the Computer Science Department, Principal Investigators Profs. Gio 
 *      Wiederhold and John Hennessy.
 *
 ************************************************************************)


(* options *)

(* 

Sample option line: ( * #g+,tdpy 1,tchk 1,U-8 * )

Switch  Meaning                                 Default Value
------  -------                                 ------- -----

B+      Bounds and nil pointer checking                 +
C+      Print ucode                                     +
D+      Load with debugger                              -
E+      Emit source code (for system debugging)         +
F+      Print binary file (B-code)                      -
G+      Write error messages only to listing file       -
L+      Write full listing                              -
In      Number of characters of identifiers that       16
          are considered significant
Mn      Target machine Id			       10 or 68
N+      Use Mark/Release-type New		        -
O+      Emit optimizer-compatible code                  -
P+      Keep execution profile                          -
Rn      Put up to N local variables in registers        0
S+      Accept standard Pascal only                     -
T---    Code generator options   
U-      Leave procedure names exactly as is             +
Wn      PRINT WARNINGS FOR:                             0
  1       ununsed variables, types, procs, etc.
  10      nested comments
Z---    Optimizer switches
 *)

(*Program header,Consts*)
(* Host compiler: *)
  (*%Set? HedrickPascal F *)
  (*%Set? UnixPascal T *)
  (*%SetF UpasPascal F *)
  (*%Set? Sail F *)

(*%ift HedrickPascal or ift UpasPascal *)
{}
{  PROGRAM PascalCompiler;}
{  (*$H:200000B*)}
{  (*#c+,g+*)}
{}
{   INCLUDE 'Ucode.Inc';}
{   INCLUDE 'Uwri.Imp';}
{   INCLUDE 'Uscan.Imp';}
{}
(*%else*)

 PROGRAM Pascalcompiler (Output);

#include "ucode.h";
#include "uwri.h";
#include "uscan.h";
(*%endc*)


CONST

   Header = 'PASCAL/UCODE (UPAS) 13-APR-82';    (* list file heading *)
   Shortheader = 'UPAS';                        (* monitor heading *)

   Displimit = 20;          (* maximum declaration-scope nesting *)
   Maxerr = 20;             (* maximum errors reported in 1 source line *)
   Maxprserr = 4;           (* maximum token-specific errors reported in 1 
                               source line *)
   
   Rswmax = 41;             (* reserved words *)  
   Rswmaxp1 = 42;           (* reserved words plus 1 *)
   Sbufsize = 128;          (* size of source line buffer (but there is no  
                               limit to length of source lines *)
   Sbufmax = 127;           (* Sbufsize - 1 *)
   Maxdigits = 128;         (* max length of numeric constant in source *)
   Maxblocks = 999;         (* maximum number of procedures allowed *) 
   Maxnest = 20;            (* maximum number of nested procedures *)
   Maxtemps = 50;           (* maximum number of temporaries active at one
                               time within one procedure *)

   (* The following constants are used to convert lower to upper case;
      if this is already done by host runtimes, set UPLOWDIF to 0 *)
   Lcaseahost = 97;         (* ord (lower case A) *)
   Lcasezhost = 122;        (* ord (lower case Z) *)
   Uplowdif = 32;           (* ord (lower case A) - ord (upper case A) *)
   Tab = 9;
   Tabsetting = 8;
   
   (* range of character set to be accepted by compiler,
      NOT including lower case -- for ASCII, space to underbar *)
   Firstchar = ' ';
   Reallastchar = '}'; (* including lower case *)
   (*%ift Sail*)
{   Lastchar = '';     (* excluding lower case *)}
{   Underbar = '';}
   (*%else*)
   Lastchar = '_';     (* excluding lower case *)
   Underbar = '_';
   (*%endc*)

   Aninedifm1 = 7;        (* ord ('A') - ord ('9') - 1*)
   

TYPE   (* Ucode *)

   Levrange = 0..Maxnest;      (*lexical (procedure and record nesting) levels*)
   Blockrange = 0..Maxblocks;  (*procedure numbers*) 
   Addrrange = Integer;        (*memory addresses, in bits*)
   Sizerange = 0..Maxint;      (*size of data objects, in bits*)
   Bitrange = Integer;         (*for bit sizes, less than a word*)
   
   (* for keeping track of memory allocation: *)
   Memsize = PACKED ARRAY[Memtype] OF Addrrange; 
   
   Dtypeset = Set of Datatype;

   (*structures*)

   Strp = ^Structure;    (*pointer to a type descriptor, or to a part of it*)
   Idp = ^Identifier;    (*pointer to a user-defined identifier descriptor*)

   Structform = (Scalar,Subrange,Pointer,Power,Arrays,Records,Files,
                 Tagfwithid,Tagfwithoutid,Variant);

   Declkind = (Standard,Declared);      (* Declared scalar = enumerated type *)

   Structure = PACKED RECORD   (*describes a type or part of it*)
       Stsize: Sizerange;             (*size*)
       Packsize: Sizerange;           (*size if in packed structure*)
       Stdtype: Datatype;             (*ucode data type*)
       Hasholes,                      (*contains hole somewhere within it*)
       Hasfiles: Boolean;             (*contains files somewhere within it*)
       Marker: Integer;               (*used for printing out symbol table*)
       CASE Form: Structform OF
            Scalar:   
               (CASE Scalkind: Declkind OF             (*for enumerated types:*)
                   Standard: ( );
                   Declared: (Fconst: Idp; (*to the first element*)
                              Dimension: Integer;    (*number of elements*)
                              Saddress: Addrrange;   (*of name table for i/o*)
                              Tlev: Levrange));      (*level when declared*)
            Subrange: (Hosttype: Strp;        (*to the unbound type*)
                       Vmin, Vmax: Valu);    (*values of the boundaries*)
            Pointer:  (Eltype: Strp);         (*to the pointed type*)
            Power:    (Basetype: Strp;        (*to the type of the element*)
                       Hardmin,Hardmax,      (*absolute limits of set*)
                       Softmin,Softmax:      (*moveable limits of set*)
                       Integer);
            Arrays:   (Arraypf: Boolean;      (*true if packed*)
                       Aelsize: Sizerange;    (*size of each element*)
                       Aeltype,               (*type of the array element*)
                       Inxtype: Strp);        (*type of the array subscript*)
            Records:  (Recordpf: Boolean;     (*true if packed*)
                       Recfirstfield: Idp;    (*pointer to the first field*)
                       Recvar: Strp);         (*pointer to the variant tag*)
            Files:    (Filepf: Boolean;       (*true if packed file*)
                       Textfile: Boolean;     (*true if the file is type text*)
                       Filetype: Strp);       (*type of the file elements*)
            Tagfwithid,                       (*variant tag*)
            Tagfwithoutid: 
                      (Fstvar,                (*head of the chain of variants*)
                            Elsevar: Strp;    (*represents undeclared variants*)
                            CASE Boolean OF
                                 (*ptr to Id representing named tag*)
                                 True : (Tagfieldp: Idp); 
                                 (*ptr to Structure representing unnamed tag*)
                                 False: (Tagfieldtype: Strp));
            (*if no name was given*)
            Variant:  (Nxtvar,                (*next variant in list*)
                       Subvar: Strp;          (*to the variant inside this one*)
                       Varfirstfield: Idp;    (*to the first field*)
                       Varval: Valu)          (*value that makes this variant 
                                                active*)
    END;


   (*identifiers*)

   Parp = ^Programparameter;
   Programparameter =                   (*describes a program parameter*)
   PACKED RECORD 
             Nextparp: Parp;         (*chain of program parameters*)
             Fileid: Identname;      (*the actual id-name of the parameter*)
          END;


   (* standard procedures and functions requiring special handling *)
   Stdprocfunc = (Spread,Spreadln,Spwrite,Spwriteln,Sppack,Spunpack,
                  Spnew,Spdispose);

   (* different kinds of identifiers *)
   Idclass = (Types,Konst,Vars,Field,Proc,Func,Labels,Progname);

   Setofids = SET OF Idclass;
   Idkind = (Actual,Formal);    (* for parameters *)

   (*describes a user-defined identifier*)

   Proctype = (Special, Inline, Regular);

   LocalIdp = ^LocalId;
   LocalId = RECORD
      Mainrec: Idp;
      Next: LocalIdp;
      END;

   Identifier = PACKED RECORD

      Idname: Identname;          (*the actual name*)
      Llink, Rlink: Idp;          (*alphabetic binary tree*)
      Idtype: Strp;               (*to the type descriptor*)
      Next: Idp;                  (*makes chains of params, decl scalars, etc.*)
      Referenced: Boolean;        (*keeps track of unused identifiers*) 
      CASE Klass: Idclass OF
         Types: ( );
         Konst: (Values: Valu);           (*the actual value*)
         Vars:  
            (Vkind: Idkind;           (*formal: var parameter*)
             Assignedto: Boolean;     (*for warnings*)
             Isparam: Boolean;        (*for warnings: param or var?*)
             Default: Idp;            (*default value of parameter*)
             Loopvar: Boolean;        (*true if in use as a loop varable*)
             Vblock: Blockrange;      (*block number*)  
             Vmty:Memtype;            (*ucode memory type*)
             Vaddr: Addrrange;        (*ucode offset*)
                                      (*or,for long value parameters: 
                                        address where the address of 
                                        the actual parameter is passed*)
             Vindtype: Memtype;       (*ucode memory type*)
             Vindaddr: Addrrange);    (*ucode offset*)
         Field: 
            (Fldaddr: Addrrange;      (*offset inside the record*)
             Inpacked: Boolean);       (*true if packed*)
         Proc,Func:  
            (CASE Prockind: Proctype OF   
             Special: 
                (Key: Stdprocfunc); 
             Inline:
                (Uinst: Uopcode;           (*Ucode instr generated*)
                 Resdtype: Strp;          (*type of result*)
                 Dtypes: Dtypeset);     (*data types of args*)
             Regular: 
                (Pflev: Levrange;         (*lexical scope*)
                 Pfmemblock: Integer;     (*local ucode block number*)
                 Parnumber: Integer;      (*number of parameters*)
                 (*address of the function result, if any:*)
                 Resmemtype: Memtype;     (*ucode memory type*)
                 Resaddr: Addrrange;      (*ucode offset*)
                 Fassigned: Boolean;      (*set to true when
                                            function assigned value *)
                 Nonstandard: Boolean;    (*used for warnings*)
                 CASE Pfkind: Idkind OF   (*formal means parameter*)
                    Actual: 
                       (Externalname: Identname;   (*ucode name*)
                        Forwdecl: Boolean;   (*true if forward declared*)
                        Externdecl: Boolean; (*true if imported*)
                        Savedmsize: Memsize; (*for saving mem counts*)
                        Filelist: Idp;     (* list of files *)
                        Testfwdptr: Idp);  (*linked list of procedures 
                                             declared fwd*)
                    Formal: 
                       (Pfaddr: Addrrange; (*ucode offset of descriptor*)
                        Pfmty: Memtype; (*ucode memory type of descr*)
                        Pfblock: Blockrange; (*block no. of descr*)
                        Fparam:Idp)));  (*chain of parameters*)
                      
         Labels:
            (Scope: Levrange;      (*lexical level where it was declared*)
             Externalref: Boolean; (*true if jumped to from another proc*)
             Defined: Boolean;     (*true when appears*)
             Uclabel: Integer);    (*ucode label assigned to it*)
         Progname: 
            (Proglev: Levrange;            (*always one*)
             Progmemblock: Integer;        (*always one*)
             Progparnumber: Integer;       (*no. of prog parameters*)
             Entname: Identname;           (*ucode name*)
             Progfilelist: Idp;            (*list of global files*)
             Progparamptr: Parp); (*to the chain of prog parameters*)
   END;



   (*other types*)


   (*lexical tokens*) 
   Symbol = (Identsy,Intconstsy,
             Realconstsy,Stringconstsy,Notsy,
             Mulsy,Rdivsy,Andsy,Idivsy,Modsy,Plussy,Minussy,Orsy,
             Ltsy,Lesy,Gesy,Gtsy,Nesy,Eqsy,Insy,
             Lparentsy,Rparentsy,Lbracksy,Rbracksy,Commasy,Semicolonsy,Periodsy,
             Arrowsy,Colonsy,Rangesy,Becomessy,Labelsy,Constsy,Typesy,Varsy,
             Functionsy,Proceduresy,Packedsy,Setsy,Arraysy,Recordsy,Filesy,
             Forwardsy,Beginsy,Ifsy,Casesy,Repeatsy,Whilesy,Forsy,Withsy,
             Gotosy,Endsy,Elsesy,Untilsy,Ofsy,Dosy,Tosy,Downtosy,
             Externsy,Modulesy,Programsy,Thensy,Othersy,Otherssy,Eofsy,Nilsy,
             Includesy); 
   Setofsys = SET OF Symbol;

   (* Display *)
   Disprange = 0..Displimit;   (*for subscripts and indexes to the display*)

   Where = (Blck,  (* this level of display represents a proc/func *)
            Crec); (* this level of display represents a record *)


   (* runtime procedures*)
   Supports = (Allocate, Free, Ifile,
               Readbool, Writebool,
               Readline, Writeline,
               Readpage, Writepage,
               Readint,  Rdintrange,
               Readreal,
               Readchar, Rdcharrange,
               Readscalar,
               Readstring, Readpkstring, Readset,
               Writeint, 
               Writereal, 
               Writechar, Writescalar,
               Writestring, Writepkstring, Writeset,
               Caseerror 
               );

   (*expressions*)
   (*************)

   Attrkind = (Cnst,Varbl,Expr);

   Attr =
   RECORD  (*describes an expression*)
      Atypep: Strp;                   (*pointer to the type descriptor*)
      Adtype: Datatype;               (*data type. to save on indirection*)
      Apacked: Boolean;  (*expr is element of packed array*)
      Rpacked: Boolean;  (*expr is field of packed record*)
      Fpacked: Boolean;  (*expr is buffer of packed file*)
      CASE Kind: Attrkind OF          (*cnst: compile-time known value*)
                                      (*varbl: variables, fields and functions*)
                                      (*expr: the value is on top of the stack*)
           Cnst:  (Cval: Valu);       (*the value of the constant*)
           Varbl: (
                   Indexed: Boolean;  (*true if part of the address is on top 
                                        of the stack*)
                     (*address:*)
                   Amty: Memtype;        (*ucode memory type*)
                   Ablock: Blockrange;   (*ucode procedure number*) 
                   Dplmt: Addrrange;     (*ucode offset*)
	           Baseaddress: Addrrange;(*base address of object*)
                     (*indirection: (var parameters, pointed objects)*)
                   Indirect: Boolean;    (*true if pointed to or formal param*)
                     (*address of the address:*)
                   Indexmt: Memtype;     (*ucode memory type*)
                   Indexr: Addrrange;    (*ucode offset*)
                   Subkind: Strp;     (*ptr to original strp, if was subrange*)
                   Aclass: Idclass);  (*to distinguish var, field, function*)

	  Expr:();
   END;


VAR   (* lexer *)

   Listname, Sourcename, Symname, Uname, Bname, Incfilename: Filename;
   List, Symtbl, Incfile: Text;

   (* Values returned by source program scanner insymbol: *)

   Sy: Symbol;                  (*last symbol scanned*)
   Val: Valu;                   (*value of last constant*)
   Lgth: Integer;               (*length of last string constant*)
   Id: Identname;               (*last identifier *)
   Ch: Char;                    (*last character picked up from source^*)
   Rangenext: Boolean;          (*true if next character is second '.' in '..'*)
   Symmarker: Integer;          (*beginning of current token*)
   

   Sign,Letters,Digits,Lettersdigitsorleftarrow,Syminitchars:  
      SET OF Char;              

   Emptytargetset: Valu;        (*for initializing a set constant*)
   Readingstring: Boolean;      (*if true, don't uppercase*)
   InIncludefile: Boolean;      (*if true, reading from Included file*) 
   Chcntmax: 0..Sbufmax;        (*max number of chars per line*)
   Listrewritten: Boolean;	(*list file has been started*)

   Chcnt: Integer;              (*number of chars in this line*) 
   Chptr: Integer;              (*position of current character in buffer*)
   Bigline: Boolean;            (*current line bigger than line buffer?*)
   Lastbuffer,                  (*contents of previous line*)
   Buffer:  Sourceline;         (*contents of current line*)
   Lastchcnt: Integer;          (*size of the previous line*)
   Linecnt,                     (*current line*)
   Pagecnt,                     (*current page*)
   Symcnt,                      (*no. of tokens already scanned in this line*)
   Tchcnt,                      (*no. of characters in the file*)
   Tlinecnt: Integer;           (*no. of lines in the file*)

   (* all of the above need to be saved when inserting an INCLUDE file *)
   OldChcnt: Integer;           (*number of chars in this line*) 
   OldChptr: Integer;           (*position of current character in buffer*)
   OldBigline: Boolean;         (*current line bigger than line buffer?*)
   OldLastbuffer,               (*contents of previous line*)
   OldBuffer:  Sourceline;      (*contents of current line*)
   OldLastchcnt: Integer;       (*size of the previous line*)
   OldLinecnt,                  (*current line*)
   OldPagecnt,                  (*current page*)
   OldSymcnt,                   (*no. of tokens already scanned in this line*)
   OldTchcnt,                   (*no. of characters in the file*)
   OldTlinecnt: Integer;        (*no. of lines in the file*)

   Rw:  ARRAY [1..Rswmax] OF Identname;          (*reserved word names*)
   Frw: ARRAY [1..Identlength] OF 1..Rswmaxp1;   (*length dividers for rw*)
   Rsy: ARRAY [1..Rswmax] OF Symbol; (*symbol associated to each reserved word*)
   Ssy: ARRAY [Firstchar..Lastchar] OF Symbol;   (*symbols associated with 
                                                   single character tokens*)
   Cputime : Integer;            (*to report elapsed time*) 

   (*error messages:*)

   Currname: Identname; (*idname of the current procedure/function*)
   Errorinlast,         (*error in the previous line?*)
   Needsaneoln: Boolean;(*something printed to the monitor since last writeln?*)
   Listneedsaneoln: Boolean; (*ditto, but to the list file?*)
   Errinx: 0..Maxerr;   (*number of errors in current source line*)
   Errorpos,            (*position of last error *) 
   Errorcount: Integer; (*total number of errors detected in program*)

   Errlist: ARRAY [1..Maxerr] OF RECORD
         Errno: 1..600;                 (*error number*)
         Warning: Boolean;              (* if warning *)
         Varname: Identname;            (*id associated with error?*)
      END;

   (*error messages, by length*)
   Errmess15 : ARRAY [1..27] OF PACKED ARRAY [1..15] OF Char;   
   Errmess20 : ARRAY [1..18] OF PACKED ARRAY [1..20] OF Char;   
   Errmess25 : ARRAY [1..17] OF PACKED ARRAY [1..25] OF Char;    
   Errmess30 : ARRAY [1..22] OF PACKED ARRAY [1..30] OF Char;  
   Errmess35 : ARRAY [1..20] OF PACKED ARRAY [1..35] OF Char;   
   Errmess40 : ARRAY [1..08] OF PACKED ARRAY [1..40] OF Char;
   Errmess45 : ARRAY [1..16] OF PACKED ARRAY [1..45] OF Char;
   Errmess50 : ARRAY [1..10] OF PACKED ARRAY [1..50] OF Char;
   Errmess55 : ARRAY [1..09] OF PACKED ARRAY [1..55] OF Char;   (** 10MAR *)


   (*user-settable switches:*)
   
   Showsource,                  (*put source lines in U-code file*)
   Idwarning,                   (*warn if variables, consts, etc. not used*)
   Commentwarning,              (*warn if nested comments*)
   Logfile,                     (*error messages go to the list file?*)
   Lptfile,                     (*full listing in list file?*)
   Printucode,                  (*generation of Ucode file*)
   Runtimecheck,                (*if true, perform runtime bounds checks *)
   Standardonly,                (*accept only standard pascal*)
   Writebcode,                  (*write binary U-code file *) 
   Emitsyms,                    (*emit symbol table*) 
   Uniquefy,                    (*uniquefy external proc ids *)
   Leavealone,                  (*don't*)
   Optimize,			(*emit code suitable for optimizer*)
   Noruntimes,			(*don't emit runtime request*)
   Markrelease: Boolean;        (*use stack-based NEW and RELEASE*)
   Maxidlength: Integer;        (*user identifiers unique to this many chars*)

   Commandline: Commandrec;     (*interface with user commandline*)
   Sw: Integer;			(*loop temporary*)

   (* target machine description vars *)

   Machine: Integer;	    (* Machine ID. *) 

   (* runtimes *) 
   Errorfile: Boolean;      (* predeclared Error file? (Unix) *)
   Fdbsize,                 (* size of file descriptor block *) (* 1060*36 *)
   Modchars,                (* number of significant characters in a module 
                               name *)
   Labchars: Integer;       (* length of external names *)

   Localsbackwards: Boolean;(* assign locals in negative direction? *)
   Pmemsize,                (* use parameter memory? *)

   Salign,                (* simple types are guaranteed never to cross
                              a boundary of this many bits *)
   Regsize,                 (* size of a register variable *)
   Addrunit,               (* size of addressable unit (e.g. byte size on a
                              byte-addressable machine) *)
   VarAlign,               (* alignment of variables (in bits) *)
   RecAlign,               (* alignment of fields of unpacked records *) 
   ArrAlign,               (* alignment of elements of unpacked arrays *) 
   Fpackunit,	   	   (* alignment of elements of packed files *)
   Rpackunit,              (* alignment of fields of packed records *)
   Apackunit: Integer;     (* alignment of elements of packed arrays *)
   Apackeven,              (* pack arrays evenly? *)
   Pack: Boolean;          (* can be use to inhibit packing *)
   SpAlign: Integer;       (* DEFs, NEWs, and DSPs will always be multiples
                              of this *)

   (* sizes of unpacked data types, in bits -- must always be a multiple of
      Addrunit *)
   Intsize,                 (* size of integer *)
   Realsize,                (* size of real *)
   Pointersize,             (* size of a pointer (address) *)
   Boolsize,                (* size of a boolean *)
   Charsize,                (* size of a character *)
   Entrysize: Integer;      (* size of a procedure descriptor (type E) *)

   (* sizes of sets *)
   Setunitsize,                  (* minimum size of a set *)
   Setunitmax,                   (* highest member of a set unit *)
   Maxsetsize,           (* maximum size of a set *)
   Defsetsize,           (* default size of a set *)
   Psetsize: Integer;      (* minimum packing of sets *)
   Zerobased: Boolean;      (* if true, sets will always be 0-based *)

   (* size of packed objects *)
   Pcharsize,              (* size of packed character *)
   CharsperSalign: Integer;   (* characters per target word *)
   
   Parthreshold: Integer; (* simple objects larger than this will be passed
			    indirectly *)
   Complextypes: Set of Datatype;  (* data types that should not be assigned to 
				      registers *)

   Maxlocalsinregs: Integer;(* maximum number of locals in registers *)

   (*for definition of standard types on target machine*)

   Tgtfirstchar,                    (* lower bound of type char*)
   Tgtlastchar,                     (* upper bound of type char*)
   Tgtmaxint,                       (* largest integer *)
   Maxintdiv10,                     (* for testing for overflow *)
   Tgtmaxexp,                       (* exponent of largest real *) 
   Tgtminexp: Integer;              (* exponent of smallest pos real*)
   Tgtmaxman,                       (* mantissa of largest real *)
   Tgtminman: Real;                 (* mantissa of smallest pos real*)


   (*other vars *)

   (*parser:*)

   Resetpossible,           (*to ignore switches which must not be reset*)
   Searcherror,             (*used as parameter to Searchid -- suppresses
                                  error message*)
   Parseleft,               (*true while parsing left hand side of assignment *)
   Parseright,              (*true most of the rest of the time*)
   Firstsymbol: Boolean;    (*true until the first symbol in program processed*)
   Lastsign:                (*set by Constant for scanning neg integers*)
      (None, Pos, Neg);  

   (* legal symbols to begin a certain construct: see Wirth's book *)
   Constbegsys,Simptypebegsys,Typebegsys,Blockbegsys,Selectsys,Facbegsys,
   Statbegsys,Typedels,Mulopsys,Addopsys,Relopsys: Setofsys;
   Ismodule: Boolean;       (*true if module rather than program*)

   (* Memory allocation: *)
   Memcnt,Globalmemcnt: Memsize;   
   Temps:                                  (* temporaries table *)
      Array[1..Maxtemps] of Record     
	 Free: Boolean;
	 Mty: Memtype;
	 Offset: Integer;
	 Size: Integer;
	 Stamp: Integer;
	 END;
   Tempcount: 0..Maxtemps;

   Lastuclabel: Integer;        (*last ucode label number created*)
   Stampctr: Integer;		(*used for allocation of temporaries*)

   Minlocreg, Maxlocreg: Integer; (*Min and max u-code offset of register locals *)
   Localsinregs: Integer; (*Maximum locals in regs*)

   (*pointers:*)

   Progidp: Idp;            (* ptr to a descriptor of the program *)

   Intptr,Realptr,Charptr,Asciiptr,  (*for predefined types*)
   Posintptr,Addressptr, 
   Boolptr,Nilptr,Textptr,
   Anyfileptr, Anytextptr, Anystringptr: Strp;

   Utypptr,Ucstptr,Uvarptr,
   Ufldptr,Uprocptr,Ufuncptr,   (*pointers to entries for undeclared ids*)

   Forwardpointertype: Idp;     (*head of chain of forw decl type ids*)
   

   (*symbol table*)

   Level: Levrange;             (*current lexical level*)
   Disx,                        (*level of last id searched by searchid*)
   Top: Disprange;              (*current top of display*)
   Memblock: Blockrange;        (*memory block currently local*)
   Memblkctr: Blockrange;       (*number of last memory block*)  
   Lastmarker: Integer;         (*used in printing out symbol table*)
   Extnamcounter: Integer;	(*used in generating unique names*)
   Callnesting: Integer;	(*current depth of call nesting *)

   Display:   ARRAY[Disprange] OF PACKED RECORD 
      Fname: Idp;                (*to the binary tree of Ids for this level*)
      Mblock: Integer;           (*ucode memory block number for this scope*)
      CASE Occur: Where OF       (*describes a record for declarations and 
                                   for with statements*)
           Blck: ( );            (*proc or func*)
           Crec:                 (*record*)
                 (Cblock: Blockrange;    (*procedure where record is declared*)
                  Cindexed: Boolean;     (*true if on top of the stack*)
                  Cmty: Memtype;         (*ucode mem type*)
                  Cdspl: Addrrange;      (*ucode offset*)
                         (*indirection: var params and pointed records*)
                  Cindirect: Boolean;    (*true if pointed*)
                         (*address of the indirect pointer:*)
                  Cindexmt: Memtype;     (*ucode memory type*)
                  Cindexr: Addrrange;    (*ucode offset*)
                  Cmemcnt:Memsize)       (*current lc (local counter)*)
   END;



   (*runtimes:*)
   
   Runtimesupport: RECORD
      Idname: PACKED ARRAY[Supports] OF Identname;  (* name of proc *)
      Pop: PACKED ARRAY [Supports] of 0..15;        (* number of params *)
      Dty: PACKED ARRAY [Supports] OF Datatype;     (* data type of result *)
   END;

   Writesupport:                    (*table of procedures for read and write*)
       ARRAY[Datatype] OF Supports;
   Readsupport: 
       ARRAY[Datatype, Scalar..Subrange] OF Supports;
   Widthdefault:                    (*default field widths*)
       ARRAY[Datatype] OF Integer;    

   Stdfileinitidp,          (* ptr to standard file initialization routine *)
   Resetptr, Rewriteptr,  (* ptrs to std procedures *)
   Bufvalptr, Getptr, Putptr,
   Inputptr, Outputptr: Idp;(* ptr to Input and Output ids *)
   Errorptr: Idp;           (* for default system error file (Unix) *)

   Openinput,Openoutput:    (*true if INPUT or OUTPUT appear in program header*)
      Boolean;

   (*expression compilation:*)

   Gattr: Attr;         (*describes the expression currently being compiled*)


   (*Ucode:*)

   U: Bcrec;                               (* holds current instruction*)


(*eopage,getclock,printtime,printdate,min,max*)

   (* this page contains all system-dependent routines *)

PROCEDURE Quit; 
   (*%ift HedrickPascal*)
{   Extern;  (* System function *)  }
   (*%else*)
   BEGIN
   Halt;
   END;
   (*%endc*)

FUNCTION Getclock: Integer;
   BEGIN
   (*%ift HedrickPascal*)
{   Getclock := Runtime;}
   (*%else*)
    Getclock := Clock;
   (*%endc*)
   END;

(*%iff UpasPascal *)

FUNCTION Eopage(VAR Fil: Text): Boolean;
   (* Returns true if an end of page is found in Fil.
      This program assumes that when eopage is true, eoln is forced to 
      be true, too *)
   
   CONST
      Formfeed = 12;
   BEGIN
   Eopage := ord(Fil^) = formfeed;
   END (*eopage*);

(*%endc*)

(*%ift HedrickPascal*)
{PROCEDURE PrintDate (VAR Fil: Text);}
{   VAR Day: Packed Array[1..9] of Char;}
{   BEGIN}
{   Day := Date;}
{   Write (Fil,Day);}
{   END;}
{}
{PROCEDURE PrintTime (VAR Fil: Text);}
{   VAR Tym: Packed Array[1..9] of Char;}
{   BEGIN}
{   (* Tym := Time;}
{   Write (Fil,Tym); *)}
{   END;}
(*%else*)
PROCEDURE PrintDate (VAR Fil: Text);
   VAR Day: Packed Array[1..10] of Char;
   BEGIN
   Date (Day);
   Write (Fil,Day);
   END;

PROCEDURE PrintTime (VAR Fil: Text);
   VAR Tym: Packed Array[1..10] of Char;
   BEGIN
   Time (Tym);
   Write (Fil,Tym);
   END;
(*%endc*)

(*%IFF UpasPascal *)
 FUNCTION Max (I,J: Integer): Integer;
   BEGIN
   IF I > J THEN Max := I
   ELSE Max := J
   END;

FUNCTION Min (I,J: Integer): Integer;  
   BEGIN
   IF I < J THEN Min := I
   ELSE Min := J
   END;
(*%endc*)

PROCEDURE Openfiles;

Const
  (*%ift UnixPascal*)
  Sourceext = 'p  ';
  Objext = 'u  ';
  Symext = 's  ';
  Lstext = 'l  ';
  Bcoext = 'b  ';
  (*%else*)
{  Sourceext = 'PAS';}
{  Objext = 'UCO';}
{  Symext = 'SYM';}
{  Lstext = 'LST';}
{  Bcoext = 'BCO';}
  (*%endc*)

  BEGIN
  WITH Commandline DO
     BEGIN
     (* Get file name(s) and options from user. *)
     Filenams[1] := Blankfilename;
     Filenams[2] := Blankfilename;
     Switches[1] := 'UPAS            ';
     GetCommandline (Commandline);
     (* Filenams[1] should be the source file, Filenams[2] the object file. *)
     Addext (Filenams[1],Sourceext);
     IF Filectr = 1 THEN
	(* If only one file specified, use same name as source, adding extension. *)
	BEGIN
	Filenams[2] := Filenams[1];
	Newext (Filenams[2],Objext);
        END
     ELSE
        Addext (Filenams[2], Objext);
     Sourcename := Filenams[1];
     Uname := Filenams[2];
     END;
  Bname    := Uname; Newext (Bname,    Bcoext);
  Listname := Uname; Newext (Listname, Lstext);
  Symname  := Uname; Newext (Symname,  Symext);
  (*%ift HedrickPascal or ift UpasPascal *)
{  Rewrite (Output, 'Tty:');}
  (*%endc*)
  (*%ift HedrickPascal*)
{  Reset (Input, Sourcename,'/E');}
  (*%else*)
  Reset (Input, Sourcename);
  (*%endc*)
  (* Ucode file is opened by Ureadinit; other files are opened as needed in
     SetSwitch *)
  Inituwrite (Uname, Bname);
  END;

  FUNCTION CalcFdbsize (Fnamelen: Integer): Integer; 
     FORWARD;

(* InitS1 *)

PROCEDURE InitS1;

   BEGIN
   Machine := 2;    	    (* Machine ID. *)

   (* runtimes *) 
   Errorfile := False;       (* predeclared Error file? (Unix) *)
   Labchars := 8;            (* length of external names *)
   Modchars := 5;            (* number of significant characters in a module 
                               name *)

   Localsbackwards := false; (* assign locals in negative direction? *)
   Pmemsize := 0;            (* use parameter memory? *)

   Salign := 36;           (* simple types are guaranteed never to cross
                              a boundary of this many bits *)
   Regsize := 36;           (* size of a register variable *)
   Addrunit := 9;           (* size of addressable unit (e.g. byte size on a
                              byte-addressable machine) *)
   VarAlign := 36;          (* alignment of variables (in bits) *)
   RecAlign := 9;           (* alignment of fields of unpacked records *) 
   ArrAlign := 9;           (* alignment of elements of unpacked arrays *) 
   Fpackunit := 9;          (* alignment of fields of packed files *)
   Rpackunit := 1;          (* alignment of fields of packed records *)
   Apackunit := 9;          (* alignment of elements of packed arrays *)
   Pack := true;            (* can be use to inhibit packing *)
   Apackeven := true;       (* pack arrays evenly? *)
   SpAlign := 36;           (* DEFs, NEWs, and DSPs will always be multiples
                              of this *)

   (* sizes of unpacked data types, in bits -- must always be a multiple of
      Addrunit *)
   Intsize := 36;            (* size of integer *)
   Realsize := 36;           (* size of real *)
   Pointersize := 36;        (* size of a pointer (address) *)
   Boolsize := 9;            (* size of a boolean *)
   Charsize := 9;           (* size of a character *)
   Entrysize := 36;          (* size of a procedure descriptor (type E) *)

   (* sizes of sets *)
   Setunitsize := 36;             (* minimum size of a set *)
   Setunitmax := 35;              (* highest member of a set unit *)
   Maxsetsize := 720;     (* maximum size of a set *)
   Defsetsize := 144;     (* default size of a set *)
   Psetsize := 36;          (* minimum packing of sets *)
   Zerobased := False;       (* if true, sets will always be 0-based *)

   (* size of packed objects *)
   Pcharsize := 9;          (* size of packed character *)
   CharsperSalign := 4;        (* characters per target word *)
   
   Parthreshold := 36;    (* simple objects larger than this will be passed
			    indirectly *)
   Complextypes := [Mdt]; (* data types that should not be assigned to 
				      registers *)

   Localsinregs := 0;  (* default number of locals in registers *)
   Maxlocalsinregs := 10;  (* maximum number of locals in registers *)

   (*for definition of standard types on target machine*)

   Tgtfirstchar := 0;                (* lower bound of type char*)
   Tgtlastchar := 127;               (* upper bound of type char*)
   Tgtmaxint := Maxint;              (* largest integer *)
   Maxintdiv10 := Maxint div 10;     (* for testing for overflow *)
   Tgtmaxexp := 38;                  (* exponent of largest real *) 
   Tgtmaxman := 0.8507059173;        (* mantissa of largest real *)
   Tgtminexp := -38;                 (* exponent of smallest pos real*)
   Tgtminman := 0.14693680107;       (* mantissa of smallest pos real*)

   Fdbsize := CalcFdbsize (129); (* size of file descriptor block *) 
(* Fdbsize := 37980;         (* size of file descriptor block *) 

   END;



(* Init10 *)

PROCEDURE Init10;

   BEGIN
   Machine := 10;   	    (* Machine ID. *)

   (* runtimes *) 
   Errorfile := False;       (* predeclared Error file? (Unix) *)
   Labchars := 6;            (* length of external names *)
   Modchars := 3;            (* number of significant characters in a 
                               module name *)

   Localsbackwards := false; (* assign locals in negative direction? *)
   Pmemsize := 0;            (* use parameter memory? *)
   
   Salign := 36;           (* simple types are guaranteed never to cross
                               a boundary of this many bits *)
   Regsize := 36;           (* size of a register variable *)
   Addrunit := 36;           (* size of addressable unit (e.g. byte size on a
                               byte-addressable machine) *)
   VarAlign := 36;           (* alignment of variables (in bits) *)
   RecAlign := 36;           (* alignment of fields of unpacked records *) 
   ArrAlign := 36;           (* alignment of elements of unpacked arrays *) 
   Fpackunit := 1;           (* alignment of fields of packed files *)
   Rpackunit := 1;           (* alignment of fields of packed records *)
   Apackunit := 1;           (* alignment of elements of packed arrays *)
   Pack := True;             (* can be use to inhibit packing *)
   Apackeven := False;       (* pack arrays evenly? *)
   SpAlign := 36;            (* DEFs, NEWs, and DSPs will always be multiples
                               of this *)


   (* sizes of unpacked data types, in bits -- must always be a multiple of
      Addrunit *)
   Intsize := 36;            (* size of integer *)
   Realsize := 36;           (* size of real *)
   Pointersize := 36;        (* size of a pointer (address) *)
   Boolsize := 36;           (* size of a boolean *)
   Charsize := 36;           (* size of a character *)
   Entrysize := 36;          (* size of a procedure descriptor (type E) *)

   (* sizes of sets *)
   Setunitsize := 36;        (* minimum size of a set *)
   Setunitmax := 35;         (* highest member of a set unit *)
   Maxsetsize := 720;        (* maximum size of a set *)
   Defsetsize := 144;        (* default size of a set *)
   Psetsize := 1;            (* minimum packing of sets *)
   Zerobased := False;       (* if true, sets will always be 0-based *)

   (* size of packed characters *)
   Pcharsize := 7;           (* minimum packing of characters *)
   CharsperSalign := 5;        (* characters per target word *)

   Parthreshold := 36;    (* simple objects larger than this will be passed
			    indirectly *)
   Complextypes := [Mdt]; (* data types that should not be assigned to 
				      registers *)

   Localsinregs := 10; (* default number of locals in registers *)
   Maxlocalsinregs := 10;  (* maximum number of locals in registers *)

   (*for definition of standard types on target machine*)
   (**********************************)

   Tgtfirstchar := 0;                (* lower bound of type char*)
   Tgtlastchar := 127;               (* upper bound of type char*)
   Tgtmaxint := Maxint;              (* largest integer *)
   Maxintdiv10 := Maxint DIV 10;      (* for testing for overflow *)
   Tgtmaxexp := 38;                  (* exponent of largest real *) 
   Tgtmaxman := 0.8507059173;        (* mantissa of largest real *)
   Tgtminexp := -38;                 (* exponent of smallest pos real*)
   Tgtminman := 0.14693680107;       (* mantissa of smallest pos real*)

   Fdbsize := CalcFdbsize (129); (* size of file descriptor block *)
(* Fdbsize := 1656;          (* size of file descriptor block *) 
   END;

(* InitVax *)

PROCEDURE InitVax;

   BEGIN
   Machine := 11;   	    (* Machine ID. *)

   (* runtimes *) 
   Errorfile := False;       (* predeclared Error file? (Unix) *)
   Labchars := 16;           (* length of external names *)
   Modchars := 13;          (* # of significant characters in a module name *)

   Localsbackwards := false; (* assign locals in negative direction? *)
   Pmemsize := 0;            (* use parameter memory? *)
   
   Salign := 8;           (* simple types are guaranteed never to cross
                              a boundary of this many bits *)
   Regsize := 32;           (* size of a register variable *)
   Addrunit := 8;           (* size of addressable unit (e.g. byte size on a
                              byte-addressable machine) *)
   VarAlign := 32;          (* alignment of variables (in bits) *)
   RecAlign := 8;           (* alignment of fields of unpacked records *) 
   ArrAlign := 8;           (* alignment of elements of unpacked arrays *) 
   Fpackunit := 8;          (* alignment of fields of packed files *)
   Rpackunit := 8;         (* alignment of fields of packed records *)
   Apackunit := 8;          (* alignment of elements of packed arrays *)
   Pack := false;           (* can be use to inhibit packing *)
   Apackeven := true;       (* pack arrays evenly? *)
   SpAlign := 8;            (* DEFs, NEWs, and DSPs will always be multiples
                              of this *)


   (* sizes of unpacked data types, in bits -- must always be a multiple of
      Addrunit *)
   Intsize := 32;            (* size of integer *)
   Realsize := 32;           (* size of real *)
   Pointersize := 32;        (* size of a pointer (address) *)
   Boolsize := 8;            (* size of a boolean *)
   Charsize := 8;            (* size of a character *)
   Entrysize := 32;          (* size of a procedure descriptor (type E) *)

   (* sizes of sets *)
   Setunitsize := 256;        (* minimum size of a set *)
   Setunitmax := 255;         (* highest member of a set unit *)
   Maxsetsize := 256;     (* maximum size of a set *)
   Defsetsize := 256;     (* default size of a set *)
   Psetsize := 256;          (* minimum packing of sets *)
   Zerobased := False;       (* if true, sets will always be 0-based *)

   (* size of packed characters *)
   Pcharsize := 8;          (* minimum packing of characters *)
   CharsperSalign := 4;        (* characters per target word *)
   
   Parthreshold := 32;    (* simple objects larger than this will be passed
			    indirectly *)
   Complextypes := [Mdt]; (* data types that should not be assigned to 
				      registers *)

   Localsinregs := 0;  (* default number of locals in registers *)
   Maxlocalsinregs := 10;  (* maximum number of locals in registers *)

   (*for definition of standard types on target machine*)
   (**********************************)

   Tgtfirstchar := 0;                (* lower bound of type char*)
   Tgtlastchar := 127;               (* upper bound of type char*)
   Tgtmaxint := Maxint;              (* largest integer *)
   Maxintdiv10 := Maxint DIV 10;     (* for testing for overflow *)
   Tgtmaxexp := 36;                  (* exponent of largest real *) 
   Tgtmaxman := 0.8507059173;        (* mantissa of largest real *)
   Tgtminexp := -36;                 (* exponent of smallest pos real*)
   Tgtminman := 0.14693680107;       (* mantissa of smallest pos real*)
   Fdbsize := CalcFdbsize (Filenamelen); (* size of file descriptor block *)
(* Fdbsize := 1280;          (* size of file descriptor block *)

   END;

(* Init68 *)

PROCEDURE Init68;

   BEGIN
   Machine := 68;   	    (* Machine ID. *)

   (* runtimes *) 
   Errorfile := False;       (* predeclared Error file? (Unix) *)
   Labchars := 8;            (* length of external names *)
   Modchars := 5;           (* # of significant characters in a module name *)

   Localsbackwards := true;  (* assign locals in negative direction? *)
   Pmemsize := maxint;       (* use parameter memory? *)
   
   Salign := 16;          (* simple types are guaranteed never to cross
                              a boundary of this many bits *)
   Regsize := 32;           (* size of a register variable *)
   Addrunit := 8;           (* size of addressable unit (e.g. byte size on a
                              byte-addressable machine) *)
   VarAlign := 32;          (* alignment of variables (in bits) *)
   RecAlign := 8;          (* alignment of fields of unpacked records *) 
   ArrAlign := 8;           (* alignment of elements of unpacked arrays *) 
   Fpackunit := 8;          (* alignment of fields of packed files *)
   Rpackunit := 8;         (* alignment of fields of packed records *)
   Apackunit := 8;          (* alignment of elements of packed arrays *)
   Pack := True;           (* can be use to inhibit packing *)
   Apackeven := true;       (* pack arrays evenly? *)
   SpAlign := 16;           (* DEFs, NEWs, and DSPs will always be multiples

   (* sizes of unpacked data types, in bits -- must always be a multiple of
      Addrunit *)
   Intsize := 32;            (* size of integer *)
   Realsize := 32;           (* size of real *)
   Pointersize := 32;        (* size of a pointer (address) *)
   Boolsize := 8;            (* size of a boolean *)
   Charsize := 8;            (* size of a character *)
   Entrysize := 32;          (* size of a procedure descriptor (type E) *)

   (* sizes of sets *)
   Setunitsize := 32;         (* minimum size of a set *)
   Setunitmax := 31;          (* highest member of a set unit *)
   Maxsetsize := 512;     (* maximum size of a set *)
   Defsetsize := 128;     (* default size of a set *)
   Psetsize := 32;           (* minimum packing of sets *)
   Zerobased := False;       (* if true, sets will always be 0-based *)

   (* size of packed characters *)
   Pcharsize := 8;          (* minimum packing of characters *)
   CharsperSalign := 2;        (* characters per target word *)
   
   Parthreshold := 64;    (* simple objects larger than this will be passed
			    indirectly *)
   Complextypes := [Mdt,Adt]; (* data types that should not be assigned to 
				      registers *)
   Localsinregs := 0;  (* default number of locals in registers *)
   Maxlocalsinregs := 3;  (* maximum number of locals in registers *)


   (*for definition of standard types on target machine*)
   (**********************************)

   Tgtfirstchar := 0;                (* lower bound of type char*)
   Tgtlastchar := 127;               (* upper bound of type char*)
   Tgtmaxint := Maxint;              (* largest integer *)
   Maxintdiv10 := Maxint div 10;     (* for testing for overflow *)
   Tgtmaxexp := 36;                  (* exponent of largest real *) 
   Tgtmaxman := 0.8507059173;        (* mantissa of largest real *)
   Tgtminexp := -36;                 (* exponent of smallest pos real*)
   Tgtminman := 0.14693680107;       (* mantissa of smallest pos real*)

   Fdbsize := CalcFdbsize (Filenamelen); (* size of file descriptor block *)
(* Fdbsize := 2672;          (* size of file descriptor block *)
   END;


(* InitMIPS *)

PROCEDURE InitMips;

   BEGIN
   Machine := 2001; 	    (* Machine ID. *)

   (* runtimes *) 
   Errorfile := False;       (* predeclared Error file? (Unix) *)
   Labchars := 8;            (* length of external names *)
   Modchars := 5;           (* # of significant characters in a module name *)

   Localsbackwards := False; (* assign locals in negative direction? *)
   Pmemsize := 0;            (* use parameter memory? *)
   
   Salign := 32;          (* simple types are guaranteed never to cross
                              a boundary of this many bits *)
   Regsize := 32;           (* size of a register variable *)
   Addrunit := 32;          (* size of addressable unit (e.g. byte size on a
                              byte-addressable machine) *)
   VarAlign := 32;          (* alignment of variables (in bits) *)
   RecAlign := 32;          (* alignment of fields of unpacked records *) 
   ArrAlign := 32;          (* alignment of elements of unpacked arrays *) 
   Fpackunit := 32;         (* alignment of fields of packed files *)
   Rpackunit := 1;          (* alignment of fields of packed records *)
   Apackunit := 32;         (* alignment of elements of packed arrays *)
   Pack := True;           (* can be use to inhibit packing *)
   Apackeven := true;       (* pack arrays evenly? *)
   SpAlign := 32;           (* DEFs, NEWs, and DSPs will always be multiples

   (* sizes of unpacked data types, in bits -- must always be a multiple of
      Addrunit *)
   Intsize := 32;            (* size of integer *)
   Realsize := 32;           (* size of real *)
   Pointersize := 32;        (* size of a pointer (address) *)
   Boolsize := 32;           (* size of a boolean *)
   Charsize := 32;           (* size of a character *)
   Entrysize := 32;          (* size of a procedure descriptor (type E) *)

   (* sizes of sets *)
   Setunitsize := 32;         (* minimum size of a set *)
   Setunitmax := 31;          (* highest member of a set unit *)
   Maxsetsize := 512;     (* maximum size of a set *)
   Defsetsize := 128;     (* default size of a set *)
   Psetsize := 32;           (* minimum packing of sets *)
   Zerobased := False;       (* if true, sets will always be 0-based *)

   (* size of packed characters *)
   Pcharsize := 8;          (* minimum packing of characters *)
   CharsperSalign := 4;        (* characters per target word *)
   
   Parthreshold := 32;    (* simple objects larger than this will be passed
			    indirectly *)
   Complextypes := [Mdt]; (* data types that should not be assigned to 
				      registers *)
   Localsinregs := 0;  (* default number of locals in registers *)
   Maxlocalsinregs := 3;  (* maximum number of locals in registers *)


   (*for definition of standard types on target machine*)
   (**********************************)

   Tgtfirstchar := 0;                (* lower bound of type char*)
   Tgtlastchar := 127;               (* upper bound of type char*)
   Tgtmaxint := Maxint;              (* largest integer *)
   Maxintdiv10 := Maxint div 10;     (* for testing for overflow *)
   Tgtmaxexp := 36;                  (* exponent of largest real *) 
   Tgtmaxman := 0.8507059173;        (* mantissa of largest real *)
   Tgtminexp := -36;                 (* exponent of smallest pos real*)
   Tgtminman := 0.14693680107;       (* mantissa of smallest pos real*)

   Fdbsize := CalcFdbsize (Filenamelen); (* size of file descriptor block *)
(* Fdbsize := 2672;          (* size of file descriptor block *)
   END;


(*Log2,Roundup,Rounddown,Alignobject,Aligndown,Findmemorytype,Assignnextmem,Getlabel,Stringsize,Stringchars,Calcfdbsize*)

(***********************************)
(*                                 *)
(* MEMORY ASSIGNMENT PRIMITIVES    *)
(*                                 *)
(***********************************)

FUNCTION Log2(Fval: Integer): Bitrange;
   (*logarithm base two of fval*)
   VAR
      E: Bitrange; H: Integer;

   BEGIN (*log2*)
   E := 0;  H := 1;
   REPEAT
      E := E + 1; H := H * 2;
   UNTIL Fval <= H;
   Log2 := E;
   END;

PROCEDURE Roundup (VAR I: integer; J: integer);
   (* only works for positive numbers *)
   BEGIN
   IF I MOD J <> 0 THEN
      I := (I DIV J + 1) * J
   END;

PROCEDURE Rounddown (VAR I: integer; J: integer);
   (* only works for negative numbers *)
   BEGIN
   IF I MOD J <> 0 THEN
      I := (I DIV J - 1) * J
   END;

PROCEDURE Error (Ferrnr: Integer); 
   FORWARD;

PROCEDURE Alignobject (VAR Memctr: Integer; Size, Align: Integer);
  (* rounds up a memory counter so that an object of length Size will
     be properly aligned *)

   BEGIN
   (* if larger than Salign, make sure it starts at a Salign
      boundary; else if smaller than Salign, make sure it does not 
      overlap Salign boundary *)
   Roundup (Memctr, Align);
   IF Size > Salign THEN Roundup (Memctr, Salign)
   ELSE IF Memctr MOD Salign + Size > Salign THEN
      Roundup (Memctr, Salign);
   END;

PROCEDURE Aligndown (VAR Memctr: Integer; Size, Align: Integer);
  (* rounds down a memory counter so that an object of length Size will
     be properly aligned *)

   BEGIN
   (* if larger than Salign, make sure it starts at a Salign
      boundary; else if smaller than Salign, make sure it does not 
      overlap Salign boundary *)
   Rounddown (Memctr, Align);
   IF Size > Salign THEN Rounddown (Memctr, Salign)
   ELSE IF Memctr MOD Salign + Size > Salign THEN
      Rounddown (Memctr, Salign);
   END;


FUNCTION Findmemorytype (Dty: Datatype; Size: Sizerange;
                         Isparam, Istemp: Boolean): Memtype;
  (* given a data object, which is either a parameter, a local 
     variable, or a temporary, figures out the appropriate memory area
     to put the object in *)

   BEGIN
   IF Isparam THEN 
      BEGIN 
      IF Dty = Mdt THEN Error (171); (* compiler error *)
      IF Pmemsize > 0 THEN
         Findmemorytype := Pmt
      ELSE
         Findmemorytype := Fmt
      END
   ELSE IF Istemp OR (Dty IN Complextypes) OR (Size > ParThreshold) THEN
      Findmemorytype := Mmt
   ELSE
      BEGIN (* simple variable *)
      Findmemorytype := Fmt;
      END;
   END;

FUNCTION Assignnextmemoryloc (Mty: Memtype; Size: Sizerange): Integer;

  (* assigns the next available location within a memory area, after
     making sure alignment is correct.  Updates memory counter *)

   BEGIN
   IF LocalsBackwards AND (Mty in [Fmt,Mmt]) THEN
      BEGIN
      Memcnt[Mty] := Memcnt[Mty] - Size;
      Aligndown (Memcnt[Mty], Size, VarAlign);
      Assignnextmemoryloc := Memcnt[Mty];
      END
   ELSE
      BEGIN
      Alignobject (Memcnt[Mty], Size, VarAlign);
      Assignnextmemoryloc := Memcnt[Mty];
      Memcnt[Mty] := Memcnt[Mty] + Size;
      END
   END;

FUNCTION Getlabel: Integer;
   BEGIN
   Lastuclabel := Lastuclabel + 1;
   Getlabel := Lastuclabel;
   END;

FUNCTION Stringsize (Charcount: Integer): Integer;
   (* given the size of a string in chars, returns the size in bits *)
   VAR I: Integer;
   BEGIN
   I := (Charcount DIV CharsperSalign) * Salign + 
        (Charcount MOD CharsperSalign) * Pcharsize;
   Roundup (I, Addrunit);
   Stringsize := I;
   END;

FUNCTION Stringchars (Strsize: Integer): Integer;
   (* given the size of a string in bits, returns the size in chars *)

   BEGIN
   Stringchars := Strsize DIV Salign * CharsperSalign +
                  Strsize MOD Salign DIV Pcharsize;
   END;

FUNCTION CalcFdbsize {(Fnamelen: Integer): Integer};
   (* Calculates length of a file (File Descriptor Block, actually).
      This must correspond with description of FDB in PIO.  Assumes
      Intsize, etc. have already been set. *)

   VAR I: Integer;
   BEGIN
   (* size of FDB = 3 groups of booleans, 11 integers, an identifier,
     and  a file name *)
   I := Stringsize(Fnamelen); Roundup (I, Salign);
   I := I + Stringsize(Identlength); Roundup (I, Salign);
   I := I + 2*Boolsize; Roundup (I, Salign);
   I := I + 2*Boolsize; Roundup (I, Salign);
   I := I + Boolsize; Roundup (I, Salign);
   CalcFdbsize := I + 11*Intsize;
   END;


(*Makeexternalname,Enterid,Searchsection,Searchid*)

(************************************************************************)
(************************************************************************)
(*                                                                      *)
(*      SYMBOL TABLE MODULE                                             *)
(*                                                                      *)
(*      The symbol table consists of an stack of "sections", each       *)
(*      of which is a binary tree.  There is one section for each       *)
(*      lexical level.  Thus, when a new procedure is entered,          *)
(*      a new section is pushed onto the stack, and when it is exited,  *)
(*      its section is popped.  When searching the symbol table, by     *)
(*      starting at the topmost section, proper scoping is preserved.   *)
(*                                                                      *)
(*      The fields of a record also constitute a section when a WITH    *)
(*      statement is encountered.   The global variable TOP points to   *)
(*      the top of the stack, which may be either a procedure section   *)
(*      (a tree of its local symbols) or a record section (a tree of    *)
(*      its fields).  The variable LEVEL always points to the topmost   *)
(*      procedure section.                                              *)
(*                                                                      *)
(*      Procedures:                                                     *)
(*                                                                      *)
(*         Enterid -- enter an Id into the table                        *)
(*         Searchsection -- search a single section for a given Id      *)
(*         Searchid -- search the whole stack for a given Id.  Also     *)
(*            check that the Id is of the correct type by comparing     *)
(*            it with the type passed.                                  *)
(*                                                                      *)
(************************************************************************)

  PROCEDURE Makeexternalname (VAR Fid: Identname);

   (* Conjures up a unique name for an external variable or procedure.  
      Name must
      be in a form suitable for use by the system loader ( < 6
      characters).  This version creates names of the form:  MMM$NN where
      MMM are leading letters from the current module name, and NN is a
      counter of names generated for this module so far.  The number of
      significant characters in MMM is dtermined by the MODCHARS constant. 
      Since all alphanumeric letters are used for NN, this system generates
      up to 1295 unique names per module *)

    VAR I: Integer;

    BEGIN
    Fid := Progidp^.Idname;             (* whole module name *)
    (* if id name is less than Modchars long, fill in holes with '$' *)
    FOR I := 2 to Modchars DO
       IF (Fid[I] = ' ') OR (Fid[I] = Underbar) THEN Fid[I] := '$';
    Fid [Modchars+1] := '$';
    (* turn Extnamcounter into a character string as
       part of the external name *)
    IF Extnamcounter >= 1296 THEN
       Error(473)  (* too many exported id's *)
    ELSE IF Extnamcounter >= 360 THEN
       Fid[Modchars+2] := Chr (Ord ('A') + Extnamcounter DIV 36 - 10)
    ELSE
       Fid[Modchars+2] := Chr (Ord ('0') + Extnamcounter DIV 36);
    IF Extnamcounter MOD 36 >= 10 THEN
       Fid[Modchars+3] := Chr (Ord ('A') + Extnamcounter MOD 36 - 10)
    ELSE
       Fid[Modchars+3] := Chr (Ord ('0') + Extnamcounter MOD 36);
    FOR I := Labchars+1 TO Identlength DO
      Fid[I] := ' ';
    Extnamcounter := Extnamcounter+1;     (* so we don't reuse the same name *)
    END;                                (* makeexternalname *)


PROCEDURE Enterid(Fidp: Idp);
   (* Enter Id pointed to by Fidp into the symbol table, checking for
      duplications *)

   VAR
      Newname: Identname; Lidp, Lidp1: Idp; Lleft: Boolean;
   BEGIN (*enterid*)
   Lidp := Display[Top].Fname;
   IF Lidp = NIL THEN
      Display[Top].Fname := Fidp
   ELSE
      BEGIN
      Newname := Fidp^.Idname;
      REPEAT
         Lidp1 := Lidp;
         IF Lidp^.Idname <= Newname THEN
            BEGIN
            IF Lidp^.Idname = Newname THEN              (*idname conflict*)
               IF Newname[1]  IN Digits THEN
                  Error(266) (*multi-declared label*)
               ELSE
                  Error(302) (*multi-declared identifier*) ;
            Lidp := Lidp^.Rlink; Lleft := False
            END
         ELSE
            BEGIN
            Lidp := Lidp^.Llink; Lleft := True
            END
      UNTIL Lidp = NIL;
      IF Lleft THEN
         Lidp1^.Llink := Fidp
      ELSE
         Lidp1^.Rlink := Fidp
      END;
   WITH Fidp^ DO
      BEGIN
      Llink := NIL; Rlink := NIL;
      END
   END (*enterid*) ;


PROCEDURE Searchsection(Fidp: Idp; VAR Fidp1: Idp);

   (* Searches binary tree whose head is FIDP;
      This procedure is used directly by Proceduredeclaration to find
      forward declared procedure id's and by Variable to find
      record fields *)

   BEGIN (*searchsection*)
   Fidp1 := NIL;
   WHILE Fidp <> NIL DO
      WITH Fidp^ DO
         BEGIN
         IF Idname = Id THEN
            BEGIN
            Fidp1 := Fidp;
            Fidp := NIL;
            END
         ELSE
            IF Idname < Id THEN
               Fidp := Rlink
            ELSE
               Fidp := Llink
         END;
   END (*searchsection*) ;

PROCEDURE Searchid(Fidcls: Setofids; VAR Fidp: Idp);

   (*  Finds an identifier in the symbol table.
       An error results if the class of the id is not in the set FIDCLS.
       This error is not reported if the caller has turned off the global
       switch SEARCHERROR.  This is done when checking forward referenced
       pointer types. *)

   LABEL
      444;

   VAR
      Lidp: Idp;

   BEGIN (*searchid*)
   FOR Disx := Top DOWNTO 0 DO  (* search each lexical level in turn*)
      BEGIN
      Lidp := Display[Disx].Fname;
      WHILE Lidp <> NIL DO
         WITH Lidp^ DO
            IF Idname = Id THEN
               IF Klass IN Fidcls THEN
                  GOTO 444
               ELSE
                  BEGIN
                  IF Searcherror THEN
                     Error(401);
                  Lidp := Rlink
                  END
            ELSE
               IF Idname < Id THEN
                  Lidp := Rlink
               ELSE
                  Lidp := Llink
      END (*for disx := top downto 0*);

   (*search not succsessful*)

   IF Searcherror THEN
      BEGIN
      IF Id[1] IN Digits THEN
         Error(215) (*undeclared label*)
      ELSE
         Error(253) (*undeclared identifier*);

      (* to avoid returning nil, reference an entry
         for an undeclared id of appropriate class *)

      New (Lidp);
      IF Types IN Fidcls THEN
         Lidp^ := Utypptr^
      ELSE IF Vars IN Fidcls THEN
         Lidp^ := Uvarptr^
      ELSE IF Field IN Fidcls THEN
         Lidp^ := Ufldptr^
      ELSE IF Konst IN Fidcls THEN
         Lidp^ := Ucstptr^
      ELSE IF Proc IN Fidcls THEN
         Lidp^ := Uprocptr^
      ELSE
         Lidp^ := Ufuncptr^;
      Lidp^.Idname := Id;
      Enterid (Lidp);
      END;
   444:
   Fidp := Lidp
   END (*searchid*) ;


(*Initialize,Initruntimes,Initreservedwords,Inituwrite,Initbwrite,Initerrormes*)

(************************************************************************)
(************************************************************************)
(*                                                                      *)
(*      INITIALIZATION MODULE                                           *)
(*                                                                      *)
(*      The procedure Initialize initializes all the global tables      *)
(*      and variables.  The procedures Enterstdnames, Enterstdtypes,    *)
(*      and Enterundecl, which load the symbol table with pre-declared  *)
(*      identifiers, are called after the first symbol has been         *)
(*      read, because if the user turns on the S+ (Standardonly)        *)
(*      switch, nonstandard names and types are not entered in the      *)
(*      symbol table.                                                   *)
(*                                                                      *)
(************************************************************************)
(************************************************************************)


PROCEDURE Initialize;

 PROCEDURE Init;  (* miscellaneous initialization *)

  VAR 
     Lmemtype: Memtype;
     I: Integer;
     Ch: Char;

  BEGIN (*init*)

  (* user option switches *)
  Runtimecheck := True;      Printucode := True;
  Lptfile := False;          Logfile := False;       Maxidlength := Identlength;
  Chcntmax := Sbufmax;       Inincludefile := False;   Listrewritten := False;
  Showsource := False;       Uniquefy := False;	     Optimize := False;
  Idwarning := False;        Commentwarning := False; Noruntimes := False;
  Standardonly := False;     Writebcode := False;    Markrelease := False;
  Resetpossible := True;     Emitsyms := False;  Leavealone := False;
  Extnamcounter := 0;	     Stampctr := 0;	Callnesting := 0;
  Minlocreg := 0;
                             
  Currname := '                ';
  Sign :=             ['+','-'];   
  Digits :=           ['0'..'9'];
  Letters :=          ['A'..'Z'];
  Lettersdigitsorleftarrow := ['0'..'9','A'..'Z',Underbar];
  Syminitchars := ['0'..'9','A'..'Z','''','(','.',':','<','>','$','/','%','{'];

  FOR CH := Firstchar TO Lastchar DO
     Ssy [Ch] := Othersy;

  Ssy['+'] := Plussy;    Ssy['-'] := Minussy;   Ssy['*'] := Mulsy;
  Ssy['/'] := Rdivsy;    Ssy['('] := Lparentsy; Ssy[')'] := Rparentsy;
  Ssy['='] := Eqsy;      Ssy[','] := Commasy;   Ssy['.'] := Periodsy;
  Ssy['['] := Lbracksy;  Ssy[']'] := Rbracksy;  Ssy[':'] := Colonsy;
  Ssy['^'] := Arrowsy;   Ssy['@'] := Arrowsy;   Ssy[';'] := Semicolonsy;
  Ssy['<'] := Ltsy;      Ssy['>'] := Gtsy;



  (* parser *)
  Parseright := True;       Searcherror := True;
  Firstsymbol := True;      Lastsign := None;

  Mulopsys :=      [Mulsy,Idivsy,Rdivsy,Modsy,Andsy];
  Addopsys :=      [Plussy,Minussy,Orsy];
  Relopsys :=      [Ltsy,Lesy,Gesy,Gtsy,Nesy,Eqsy,Insy];
  Constbegsys :=    Addopsys + [Intconstsy,Realconstsy,Stringconstsy,Identsy];
  Simptypebegsys := Addopsys + [Intconstsy,Realconstsy,Stringconstsy,Identsy,
                      Lparentsy] ;
  Typebegsys :=     Addopsys + [Intconstsy,Realconstsy,Stringconstsy,Identsy,
                      Lparentsy,Arrowsy,Packedsy,Arraysy,Recordsy,Setsy,Filesy];
  Typedels :=      [Arraysy,Recordsy,Setsy,Filesy];
  Blockbegsys :=   [Labelsy,Constsy,Typesy,Varsy,Proceduresy,Functionsy,
                      Beginsy];
  Selectsys :=     [Arrowsy,Periodsy,Lbracksy];
  Facbegsys :=     [Intconstsy,Realconstsy,Stringconstsy,Identsy,Lparentsy,
                    Lbracksy,Notsy,Nilsy];
  Statbegsys :=    [Beginsy,Gotosy,Ifsy,Whilesy,Repeatsy,Forsy,Withsy,Casesy];

  (* error handler *)
  Errorpos := -1;           Errorinlast := False;
  Errinx := 0;              Errorcount := 0;       

  (* storage allocation *)
  Memblock := 1;
  Memblkctr := 1;
  FOR Lmemtype := Zmt TO Fmt DO
     Memcnt[Lmemtype] := 0;

  (* others *)
  Forwardpointertype := NIL;
  Lastuclabel := 0;                  
  Lastmarker := 1;

  WITH Emptytargetset DO
     BEGIN
     Len := Setunitsize DIV 4;
     FOR I := 1 TO Strglgth DO
	Chars[I] := '0';
     END;

  END (*initscalars*) ;

PROCEDURE Initruntimes;

 (* initializes tables used for calls of runtime procedures *)

 BEGIN (*Initruntimes*)
 WITH Runtimesupport DO
    BEGIN
    Idname[Allocate   ] := '$NEW            '; 
    Dty   [Allocate   ] := Pdt;  Pop[Allocate  ] := 3;   
    Idname[Free       ] := '$DSP            ';     	(** 10mar *)
    Dty   [Free       ] := Pdt; Pop[Free       ] := 1;   
    Idname[Ifile      ] := '$INITFILE       ';
    Dty   [Ifile      ] := Pdt; Pop[Ifile      ] := 5;   
    Idname[Readline   ] := '$RLN            ';
    Dty   [Readline   ] := Pdt; Pop[Readline   ] := 1;   
    Idname[Writeline  ] := '$WLN            ';
    Dty   [Writeline  ] := Pdt; Pop[Writeline  ] := 1;   
    Idname[Readint    ] := '$RDI            ';
    Dty   [Readint    ] := Pdt; Pop[Readint    ] := 2;   
    Idname[Rdintrange ] := '$RDIRANGE       ';
    Dty   [Rdintrange ] := Pdt; Pop[Rdintrange ] := 4;   
    Idname[Readreal   ] := '$RDR            ';
    Dty   [Readreal   ] := Pdt; Pop[Readreal   ] := 2;   
    Idname[Readstring ] := '$RDUPS          ';
    Dty   [Readstring ] := Pdt; Pop[Readstring ] := 3;   
    Idname[Readpkstring] := '$RDS            ';
    Dty   [Readpkstring] := Pdt; Pop[Readpkstring] := 3;   
    Idname[Readscalar ] := '$RDSCALAR       ';
    Dty   [Readscalar ] := Pdt; Pop[Readscalar ] := 5;   
    Idname[Rdcharrange] := '$RDCRANGE       ';
    Dty   [Rdcharrange] := Pdt; Pop[Rdcharrange] := 4;   
    Idname[Readchar   ] := '$RDC            ';
    Dty   [Readchar   ] := Pdt; Pop[Readchar   ] := 2;   
    Idname[Readbool   ] := '$RDB            ';
    Dty   [Readbool   ] := Pdt; Pop[Readbool   ] := 2;   
    Idname[Readset    ] := '$RDSET          ';
    Dty   [Readset    ] := Pdt; Pop[Readset    ] := 6;   
    Idname[Writeint   ] := '$WRI            ';
    Dty   [Writeint   ] := Pdt; Pop[Writeint   ] := 4;   
    Idname[Writereal  ] := '$WRR            ';
    Dty   [Writereal  ] := Pdt; Pop[Writereal  ] := 4;   
    Idname[Writechar  ] := '$WRC            ';
    Dty   [Writechar  ] := Pdt; Pop[Writechar  ] := 3;   
    Idname[Writebool  ] := '$WRB            ';
    Dty   [Writebool  ] := Pdt; Pop[Writebool  ] := 3;   
    Idname[Writestring] := '$WRUPS          ';
    Dty   [Writestring] := Pdt; Pop[Writestring] := 4;   
    Idname[Writepkstring] := '$WRS            ';
    Dty   [Writepkstring] := Pdt; Pop[Writepkstring] := 4;   
    Idname[Writescalar] := '$WRSCALAR       ';
    Dty   [Writescalar] := Pdt; Pop[Writescalar] := 4;   
    Idname[Writeset   ] := '$WRSET          ';
    Dty   [Writeset   ] := Pdt; Pop[Writeset   ] := 8;   
    Idname[Caseerror  ] := '$CASEERR        ';
    Dty   [Caseerror  ] := Pdt; Pop[Caseerror  ] := 2;   
    END;

 Readsupport[Bdt,Scalar]     := Readbool;   
 Readsupport[Bdt,Subrange]   := Readbool;

 Readsupport[Cdt,Scalar]     := Readchar;
 Readsupport[Cdt,Subrange]   := Rdcharrange;

 Readsupport[Jdt,Scalar]     := Readint;
 Readsupport[Jdt,Subrange]   := Rdintrange;

 Readsupport[Ldt,Scalar]     := Readscalar;
 Readsupport[Ldt,Subrange]   := Readscalar;

 Readsupport[Rdt,Scalar]     := Readreal;

 Writesupport[Bdt]    := Writebool;  
 Writesupport[Cdt]    := Writechar;
 Writesupport[Jdt]    := Writeint;
 Writesupport[Ldt]    := Writescalar;
 Writesupport[Rdt]    := Writereal;

 Widthdefault[Bdt] :=  6;
 Widthdefault[Cdt] :=  1;
 Widthdefault[Jdt] := 12;
 Widthdefault[Ldt] := Identlength;  (*declared scalars*)
 Widthdefault[Rdt] := 16;

 END (*Initruntimes*);



PROCEDURE Initreservedwords;

  VAR Rwctr: 1..Rswmaxp1;

  BEGIN 
  (* Change RSWMAX if you add a symbol.
     Frw[N] is the index of the first reserved word of length N 
     (see INSYMBOL for algorithm).
     Note: INSYMBOL expects reserved words to be at most 9 characters long. *)

  Rwctr := 1; Frw[1] :=  1; Frw[2] :=  1;
  Rw[Rwctr] := 'IF              '; Rsy[Rwctr] := Ifsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'DO              '; Rsy[Rwctr] := Dosy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'OF              '; Rsy[Rwctr] := Ofsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'TO              '; Rsy[Rwctr] := Tosy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'IN              '; Rsy[Rwctr] := Insy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'OR              '; Rsy[Rwctr] := Orsy; Rwctr := Rwctr + 1;
  Frw[3] :=  Rwctr;
  Rw[Rwctr] := 'END             '; Rsy[Rwctr] := Endsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'FOR             '; Rsy[Rwctr] := Forsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'VAR             '; Rsy[Rwctr] := Varsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'DIV             '; Rsy[Rwctr] := Idivsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'MOD             '; Rsy[Rwctr] := Modsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'SET             '; Rsy[Rwctr] := Setsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'AND             '; Rsy[Rwctr] := Andsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'NOT             '; Rsy[Rwctr] := Notsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'NIL             '; Rsy[Rwctr] := Nilsy; Rwctr := Rwctr + 1;
  Frw[4] := Rwctr;
  Rw[Rwctr] := 'THEN            '; Rsy[Rwctr] := Thensy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'ELSE            '; Rsy[Rwctr] := Elsesy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'WITH            '; Rsy[Rwctr] := Withsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'GOTO            '; Rsy[Rwctr] := Gotosy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'CASE            '; Rsy[Rwctr] := Casesy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'TYPE            '; Rsy[Rwctr] := Typesy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'FILE            '; Rsy[Rwctr] := Filesy; Rwctr := Rwctr + 1;
  Frw[5] := Rwctr;
  Rw[Rwctr] := 'BEGIN           '; Rsy[Rwctr] := Beginsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'UNTIL           '; Rsy[Rwctr] := Untilsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'WHILE           '; Rsy[Rwctr] := Whilesy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'ARRAY           '; Rsy[Rwctr] := Arraysy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'CONST           '; Rsy[Rwctr] := Constsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'LABEL           '; Rsy[Rwctr] := Labelsy; Rwctr := Rwctr + 1;
  Frw[6] := Rwctr;
  Rw[Rwctr] := 'RECORD          '; Rsy[Rwctr] := Recordsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'EXTERN          '; Rsy[Rwctr] := Externsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'DOWNTO          '; Rsy[Rwctr] := Downtosy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'PACKED          '; Rsy[Rwctr] := Packedsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'REPEAT          '; Rsy[Rwctr] := Repeatsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'MODULE          '; Rsy[Rwctr] := Modulesy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'OTHERS          '; Rsy[Rwctr] := Otherssy; Rwctr := Rwctr + 1;
  Frw[7] := Rwctr;
  Rw[Rwctr] := 'INCLUDE         '; Rsy[Rwctr] := Includesy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'FORWARD         '; Rsy[Rwctr] := Forwardsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'PROGRAM         '; Rsy[Rwctr] := Programsy; Rwctr := Rwctr + 1;
  Frw[8] := Rwctr;
  Rw[Rwctr] := 'FUNCTION        '; Rsy[Rwctr] := Functionsy; Rwctr := Rwctr + 1;
  Rw[Rwctr] := 'EXTERNAL        '; Rsy[Rwctr] := Externsy;   Rwctr := Rwctr + 1;
  Frw[9] := Rwctr;
  Rw[Rwctr] := 'PROCEDURE       '; Rsy[Rwctr] := Proceduresy;Rwctr := Rwctr + 1;
  Frw[10] := Rwctr;

  END (*reserved words*) ;


PROCEDURE Initerrormessages;
  BEGIN

  Errmess15[ 1] := '":" expected   ';
  Errmess15[ 2] := '")" inserted   ';  
  Errmess15[ 3] := '"(" expected   ';
  Errmess15[ 4] := '"[" expected   ';
  Errmess15[ 5] := '"]" expected   ';
  Errmess15[ 6] := '";" inserted   ';  
  Errmess15[ 7] := '"=" expected   ';
  Errmess15[ 8] := '"," expected   ';
  Errmess15[ 9] := '":=" expected  ';
  Errmess15[10] := '"OF" expected  ';
  Errmess15[11] := '"DO" inserted  ';  
  Errmess15[12] := '"IF" expected  ';
  Errmess15[13] := '"END" expected ';
  Errmess15[14] := '"THEN" inserted';  
  Errmess15[15] := '"EXIT" expected';
  Errmess15[16] := 'Illegal symbol ';
  Errmess15[17] := 'No sign allowed';
  Errmess15[18] := 'Number expected';
  Errmess15[19] := 'Not implemented';
  Errmess15[20] := 'Error in type  ';
  Errmess15[21] := 'Compiler error ';
  Errmess15[22] := 'Unknown machine';
  Errmess15[23] := 'Error in factor';
  Errmess15[24] := 'Too many digits';
  Errmess15[25] := 'Not referenced ';  
  Errmess15[26] := 'Not assigned to';
  Errmess15[27] := 'Set too large  ';

  Errmess20[ 1] := '"BEGIN" expected    ';
  Errmess20[ 2] := '"UNTIL" expected    ';
  Errmess20[ 3] := 'Not a known option  ';
  Errmess20[ 4] := 'Constant too large  ';
  Errmess20[ 5] := 'Digit must follow   ';
  Errmess20[ 6] := 'Exponent too large  ';
  Errmess20[ 7] := 'Constant expected   ';
  Errmess20[ 8] := 'Simple type expected';
  Errmess20[ 9] := 'Identifier expected ';
  Errmess20[10] := 'Realtype not allowed';
  Errmess20[11] := 'Multidefined label  ';
  Errmess20[12] := 'Not standard pascal ';
  Errmess20[13] := 'Set type expected   ';
  Errmess20[14] := 'Undefined label     ';
  Errmess20[15] := 'Undeclared label    ';
  Errmess20[16] := 'File name expected  ';  
  Errmess20[17] := 'Inter-procedure goto';  
  Errmess20[18] := 'Comment not closed  ';  

  Errmess25[ 1] := '"TO"/"DOWNTO" expected   ';
  Errmess25[ 2] := '8 or 9 in octal number   ';
  Errmess25[ 3] := 'Identifier not declared  ';
  Errmess25[ 4] := 'Illegal option value     ';
  Errmess25[ 5] := 'Integer constant expected';
  Errmess25[ 6] := 'Error in parameterlist   ';
  Errmess25[ 7] := 'Already forward declared ';
  Errmess25[ 8] := 'This format for real only';
  Errmess25[ 9] := 'Comment not opened       ';
  Errmess25[10] := 'Type conflict of operands';
  Errmess25[11] := 'Multidefined case label  ';
  Errmess25[12] := 'For integer only "o"/"h" ';
  Errmess25[13] := 'Array index out of bounds';
  Errmess25[14] := 'String constant expected ';

  Errmess25[16] := 'Label already declared   ';
  Errmess25[17] := 'End of program not found ';

  Errmess30[ 1] := 'String constant is too long   ';
  Errmess30[ 2] := 'Identifier already declared   ';
  Errmess30[ 3] := 'Subrange bounds must be scalar';
  Errmess30[ 4] := 'Incompatible subrange types   ';
  Errmess30[ 5] := 'Incompatible with tagfieldtype';
  Errmess30[ 6] := 'Index type may not be integer ';
  Errmess30[ 7] := 'Type of variable is not array ';
  Errmess30[ 8] := 'Type of variable is not record';
  Errmess30[ 9] := 'No such field in this record  ';
  Errmess30[10] := 'Function result not defined   ';
  Errmess30[11] := 'Illegal type of operand(s)    ';
  Errmess30[12] := 'Tests on equality allowed only';
  Errmess30[13] := 'Strict inclusion not allowed  ';
  Errmess30[14] := 'File comparison not allowed   ';
  Errmess30[15] := 'Illegal type of expression    ';

  Errmess30[17] := 'Too many nested withstatements';
  Errmess30[18] := 'Invalid or no program heading ';

  Errmess30[21] := 'Memory requirement is too high';
  Errmess30[22] := 'Too many case list elements   ';

  Errmess35[ 1] := 'String constant crosses line end  "';
  Errmess35[ 2] := 'Label not declared on this level   ';
  Errmess35[ 5] := 'File as value parameter not allowed';
  Errmess35[ 6] := 'Illegal assignment to loop variable'; 
  Errmess35[ 7] := 'No packed structure allowed here   ';
  Errmess35[ 8] := 'Variant must belong to tagfieldtype';
  Errmess35[ 9] := 'Type of operand(s) must be boolean ';
  Errmess35[10] := 'Set element types not compatible   ';
  Errmess35[11] := 'Assignment to files not allowed    ';
  Errmess35[14] := 'Control variable may not be formal ';
  Errmess35[15] := 'Illegal type of for-controlvariable';
  Errmess35[16] := 'Only packed file of char allowed   ';
  Errmess35[17] := 'Constant not in bounds of subrange ';
  Errmess35[18] := 'Neither referenced nor assigned to ';  
  Errmess35[19] := 'New comment begun inside comment   ';
  Errmess35[20] := 'Incongruent parameter              ';

  Errmess40[ 1] := 'Identifier is not of appropriate class  ';
  Errmess40[ 2] := 'Tagfield type must be scalar or subrange';
  Errmess40[ 3] := 'Index type must be scalar or subrange   ';
  Errmess40[ 4] := 'Too many nested scopes of identifiers   ';
  Errmess40[ 5] := 'Pointer forward reference unsatisfied   ';
  Errmess40[ 6] := 'This error message should not appear    ';
  Errmess40[ 7] := 'Type of variable must be file or pointer';
  Errmess40[ 8] := 'Missing corresponding variantdeclaration';

  Errmess45[ 1] := 'Low bound may not be greater than high bound ';
  Errmess45[ 2] := 'Identifier or "case" expected in fieldlist   ';
  Errmess45[ 3] := 'Assignment to non-activated function         ';
  Errmess45[ 4] := 'Only one level of include files supported    ';
  Errmess45[ 5] := 'Missing result type in function declaration  ';
  Errmess45[ 6] := 'N switch must be turned on for mark/release  ';
  Errmess45[ 7] := 'Index type is not compatible with declaration';
  Errmess45[ 8] := 'Error in type of standard procedure parameter';
  Errmess45[ 9] := 'Error in type of standard function parameter ';
  Errmess45[10] := 'Real and string tagfields not implemented    ';
  Errmess45[11] := 'Set element type must be scalar or subrange  ';
  Errmess45[13] := 'No constant or expression for var argument   ';
  Errmess45[14] := 'Extern declaration not allowed in procedures ';
  Errmess45[15] := 'Body of forward declared procedure missing   ';
  Errmess45[16] := 'Double file specification in program heading ';

  Errmess50[ 3] := 'Parameter type does not agree with declaration    ';
  Errmess50[ 4] := 'Include files may contain only external procedures';
  Errmess50[ 5] := 'Label type incompatible with selecting expression ';
  Errmess50[ 6] := 'Statement must end with ";","end","else"or"until" ';

  Errmess50[10] := 'Standard procedures may not be parameters.        ';
   
  Errmess55[ 1] := 'Illegal function result type                           ';
  Errmess55[ 2] := 'Repetition of result type not allowed if forw. decl.   ';
  Errmess55[ 3] := 'Repetition of parameter list not allowed if forw. decl.';
  Errmess55[ 4] := 'Number of parameters does not agree with declaration   ';
  Errmess55[ 5] := 'Result type of parameter-func does not agree with decl.';
  Errmess55[ 6] := 'Selected expression must have type of control variable ';
  Errmess55[ 7] := 'Already declared. previous declaration was not forward ';
  Errmess55[ 8] := 'Option may not be changed after beginning of program   ';
  Errmess55[ 9] := 'N switch must be turned off for dispose -- release used'; (** 10mar *)
   
  END (*error messages*) ;


BEGIN (*initialize*)
Init;
Initruntimes;
Initreservedwords;
Initerrormessages;
END (*initialize*);



(*Enterstdtypes,Enterstdnames,Enterundecl*)

PROCEDURE Enterstdtypes;
   (* Create the Structure (type) descriptor blocks for the predefined
    types, and hang them from known global pointers *)


   BEGIN (*enterstdtypes*)
   New(Intptr,Scalar,Standard);                              (*integer*)
   WITH Intptr^ DO
      BEGIN
      Form := Scalar; Scalkind := Standard; Marker := 0;
      Stsize := Intsize; Packsize := Intsize; Stdtype := Jdt;
      Hasholes := False; Hasfiles := False;
      END;
   New(PosIntptr,Scalar,Standard);                           (*non-neg integer*)
   WITH Posintptr^ DO
      BEGIN
      Form := Scalar; Scalkind := Standard; Marker := 0;
      Stsize := Intsize; Packsize := Intsize;
      Stdtype := Ldt;
      Hasholes := False; Hasfiles := False;
      END;
   New(Realptr,Scalar,Standard);                             (*real*)
   WITH Realptr^ DO
      BEGIN
      Form := Scalar; Scalkind := Standard; Marker := 0;
      Stsize := Realsize;Packsize := Realsize; Stdtype := Rdt;
      Hasholes := False; Hasfiles := False;
      END;
   New(Charptr,Scalar,Standard);                             (*char*)
   WITH Charptr^ DO
      BEGIN
      Form := Scalar; Scalkind := Standard; Marker := 0;
      Stsize := Charsize; Packsize := Pcharsize; Stdtype := Cdt;
      Hasholes := False; Hasfiles := False;
      END;
   New(Boolptr,Scalar,Declared);                             (*boolean*)
   WITH Boolptr^ DO
      BEGIN
      Form := Scalar; Scalkind := Declared; Marker := 0;
      Stsize := Boolsize; Packsize := Rpackunit; Stdtype := Bdt;
      Hasholes := False; Hasfiles := False;
      END;
   New(Nilptr,Pointer);                                      (*nil*)
   WITH Nilptr^ DO
      BEGIN
      Form := Pointer; Marker := 0; Stdtype := Adt;
      Eltype := NIL; Stsize := Pointersize; Packsize := Pointersize;
      Hasholes := False; Hasfiles := False;
      END;
   New(Addressptr,Pointer);                                  (*'any pointer'*)
   WITH Addressptr^ DO
      BEGIN
      Form := Pointer; Stdtype := Adt; Marker := 0;
      Eltype := NIL; Stsize := Pointersize; Packsize := Pointersize; 
      Hasholes := False; Hasfiles := False;
      END;
   New(Anyfileptr,Files);                                  (*'any file'*)
   New(Anytextptr,Files);                                  (*'any text file'*)
   New(Anystringptr,Arrays);                               (*'any string'*)
   WITH Anystringptr^ DO
      BEGIN
      Form := Arrays;
      Stsize := Charsize;
      Packsize := Charsize;
      Stdtype := Mdt;
      Hasholes := False; Hasfiles := False;
      END;

   New(Textptr,Files);                                       (*text*)
   WITH Textptr^ DO
      BEGIN
      Form := Files; Filetype := Charptr; Marker := 0;
      Filepf := False; Textfile := True; Stdtype := Mdt;
      Stsize := Fdbsize + Charsize; Packsize := Stsize;
      Hasholes := False; Hasfiles := True;
      END;
   New(Asciiptr,Files);                                       (*text*)
   WITH Asciiptr^ DO
      BEGIN
      Form := Files; Filetype := Charptr; Marker := 0;
      Filepf := False; Textfile := True; Stdtype := Mdt;
      Stsize := Fdbsize + Charsize; Packsize := Stsize;
      Hasholes := False; Hasfiles := True;
      END;

   END (*enterstdtypes*) ;

PROCEDURE Enterstdnames;
   (*insert in the symbol table the identifier descriptor blocks for the*)
   (*predeclared types, variables, constants, procedures and functions*)
   VAR
      Lidp: Idp;
      

   PROCEDURE Enterstdid(Fidclass: Idclass; Fname: Identname; Fidtype: Strp; 
                        Fnext: Idp; Fival: Integer);
      (*enter in the symbol table the descriptor of a predefined type or 
        constant*)
      BEGIN (*enterstdid*)
      IF Fidclass = Types THEN
         New(Lidp,Types)
      ELSE
         New(Lidp,Konst);
      WITH Lidp^ DO
         BEGIN
         Klass := Fidclass; Idname := Fname; Idtype := Fidtype; Next := Fnext;
         IF Fidclass = Konst THEN
            Values.Ival := Fival;
         END;
      Enterid(Lidp)
      END (*enterstdid*);

BEGIN (*enterstdnames*)

Enterstdid(Types,'INTEGER         ',Intptr,NIL,0);
Enterstdid(Types,'REAL            ',Realptr,NIL,0);
Enterstdid(Types,'CHAR            ',Charptr,NIL,0);
Enterstdid(Types,'BOOLEAN         ',Boolptr,NIL,0);
Enterstdid(Types,'TEXT            ',Textptr,NIL,0);
Enterstdid(Konst,'MAXINT          ',Intptr,NIL,Tgtmaxint);    

IF NOT Standardonly THEN
   Enterstdid(Types,'ASCII           ',Asciiptr,NIL,0);

Enterstdid(Konst,'FALSE           ',Boolptr,NIL,0);
Enterstdid(Konst,'TRUE            ',Boolptr,Lidp,1);

WITH Boolptr^ DO
   BEGIN
   Fconst := Lidp;
   Tlev := 0;
   Dimension := 1
   END;

New(Inputptr,Vars);
WITH Inputptr^ DO
   BEGIN
   Klass := Vars; Idname := 'INPUT           ';
   Idtype := Textptr;
   Vkind := Actual; Next := NIL;
   Vblock := 1;   Vmty := Smt;  Vaddr := 0;
   Referenced := True;  
   END;

New(Outputptr,Vars);
WITH Outputptr^ DO
   BEGIN
   Klass := Vars; Idname := 'OUTPUT          ';
   Idtype := Textptr;
   Vkind := Actual; Next := NIL;
   Vblock := 1;  Vmty := Smt;
   Referenced := True;  
   END;

New(Errorptr,Vars);
WITH Errorptr^ DO
   BEGIN
   Klass := Vars; Idname := 'STDERROR        ';
   Idtype := Textptr;
   Vkind := Actual; Next := NIL;
   Vblock := 1;   
   Referenced := True;  
   END;

end;(* enterstdnames *)

PROCEDURE Enterundecl;

   (*create identifier descriptor blocks for an 'undeclared' or 'undefined'*)
   (*object of each class, and hang them from global variables, for searchid*)
   (*to return when an identifier is not found. this way, an idptr will never*)
   (*be nil*)

   BEGIN (*enterundecl*)
   New(Utypptr,Types);
   WITH Utypptr^ DO
      BEGIN
      Klass := Types; Idname := '                '; Idtype := NIL; Next := NIL;
      END;
   New(Ucstptr,Konst);
   WITH Ucstptr^ DO
      BEGIN
      Klass := Konst; Idname := '                '; Idtype := NIL; Next := NIL;
      Values.Ival := 0
      END;
   New(Uvarptr,Vars);
   WITH Uvarptr^ DO
      BEGIN
      Klass := Vars; Idname := '                '; Idtype := NIL; 
      Next := NIL; Vblock := 0; Vaddr := 0; Vkind := Actual; Loopvar := False;
      END;
   New(Ufldptr,Field);
   WITH Ufldptr^ DO
      BEGIN
      Klass := Field; Idname := '                '; Idtype := NIL; Next := NIL; 
      Fldaddr := 0; Inpacked := False;
      END;
   New(Uprocptr,Proc,Regular,Actual);
   WITH Uprocptr^ DO
      BEGIN
      Klass := Proc; Prockind := Regular; Pfkind := Actual; 
      Idname := '                '; Idtype := NIL; Forwdecl := False;
      Next := NIL; Externdecl := False; Pflev := 0; Nonstandard := False;
      END;
   New(Ufuncptr,Func,Regular,Actual);
   WITH Ufuncptr^ DO
      BEGIN
      Klass := Func; Prockind := Regular; Pfkind := Actual; 
      Idname := '                '; Idtype := NIL; Next := NIL; 
      Forwdecl := False; Nonstandard := False;
      Externdecl := False; Pflev := 0; Resmemtype := Zmt; Resaddr := 0;
      END
   END (*enterundecl*) ;


(*Enterstdprocs*)
Procedure Enterstdprocs;

   (* enter standard procedures and functions into the symbol table *)

   VAR
      Lmty: Memtype;
      Lparnumber: Integer;
      Nullstrptr: Strp;
      Minusoneptr, Zeroptr, Oneptr, Nullstridptr: Idp;
      Listhead, Listtail, Procidp: Idp;

   PROCEDURE Enterspecialproc (Fname: Identname; Fkey: Stdprocfunc;
             Fklass:Idclass);

      VAR Lidp: Idp;

      (* create an Id record for a procedure/function needing special
         parsing *)

      BEGIN
      New(Lidp,Proc,Special);
      WITH Lidp^ DO
         BEGIN
         Klass := Fklass; Prockind := Special;
         Idname := Fname; Idtype := NIL;
         Next := NIL; Key := Fkey;
         END;
      Enterid(Lidp)
      END;

   PROCEDURE Enterinlinefunc (Fname: Identname; Finst: Uopcode; 
                FDtypes:Dtypeset; FResdtype: Strp);
      (* create an Id record for a function that is generated inline *)

      VAR Lidp: Idp;

      BEGIN
      New(Lidp,Proc,Inline);
      WITH Lidp^ DO
         BEGIN
	 IF (Finst = Unew) OR (Finst = Udsp) THEN
	    Klass := Proc
	 ELSE
            Klass := Func; 
         Prockind := Inline;
         Idname := Fname; Idtype := NIL;
         Next := NIL; Dtypes := Fdtypes;
         Resdtype := Fresdtype; Uinst := Finst;
         END;
      Enterid(Lidp)
      END;

   PROCEDURE Enterstdstring(VAR Stringptr: Strp; StrSize: Integer);
      (* Create a Structure (type) descriptor stringptr, for a string with
       size Strsize.  This is for standard procedures
       that take string arguments *)

      VAR
         Lstrp: Strp;


      BEGIN (*enterstdstring*)
      New(Lstrp,Subrange);    (* create Structure for index *)
      WITH Lstrp^ DO
         BEGIN
         Form := Subrange;
         Hosttype := Intptr; Vmin.Ival := 1; Vmax.Ival := StrSize;
         Stsize := Intsize; Stdtype := Jdt; Marker := 0;
         Packsize := Intsize; Hasholes := False; Hasfiles := False;
         END;
      New(Stringptr,Arrays);    (* create Structure for array *)
      WITH Stringptr^ DO
         BEGIN
         Form := Arrays; Arraypf := True;  Marker := 0;
         Aeltype := Charptr; Inxtype := Lstrp;
         Aelsize := Pcharsize;
         Stsize := Stringsize (Strsize);
         Packsize := Stsize; Stdtype := Mdt;
         Hasholes := True; Hasfiles := False;
         END;
      END;

   PROCEDURE Enterstdparameter(Fidtype: Strp; Fidkind: Idkind; Defaultidp: Idp);
      (* Add one more element to the list of parameters for a predefined  
         procedure/function *)

      VAR 
         Lmty: Memtype;
         Lidp: Idp;   
      BEGIN (*enterstdparameter*)
      New(Lidp,Vars);
      IF Listhead = NIL THEN
         BEGIN
         FOR Lmty := Zmt TO Fmt DO Memcnt[Lmty] := 0;
         Lparnumber := 1
         END
      ELSE
         Lparnumber := Lparnumber + 1;
      WITH Lidp^ DO
         BEGIN
         Klass := Vars;
         Idname := '                ';
         Idtype := Fidtype;
         Vkind := Fidkind; 
         IF Next = NIL THEN 
         Vblock := 0;   
         Vmty := Zmt;  Vaddr := 0;
         Next := NIL;
         Isparam := True;  Default := Defaultidp;
         END;
      (* add to end of parameter list *)
      IF Listhead = NIL THEN
         Listhead := Lidp
      ELSE
         Listtail^.Next := Lidp;
      Listtail := Lidp;
      END (*enterstdparameter*);


   PROCEDURE Enterregularproc(Fname, Fextname: Identname; Fidtype: Strp;
                              Nonstd: Boolean);
      (*enter in the symbol table the id record for a predefined 
        procedure/function; Listhead should be the list of parameters, and
        Fidtype the type of the function result, or NIL if not a function;
        a ptr to the new record is returned in Procidp (global)*)

      BEGIN (*Enterregularproc*)
      IF Fidtype <> NIL THEN
         BEGIN
         New(Procidp,Func,Regular,Actual);
         Procidp^.Klass := Func;
         END
      ELSE
         BEGIN
         New(Procidp,Proc,Regular,Actual);
         Procidp^.Klass := Proc;
         END;
      WITH Procidp^ DO
         BEGIN
         Prockind := Regular; Pfkind := Actual;
         Pfmemblock := 0; Nonstandard := Nonstd;
         Idtype := Fidtype; Next := Listhead; Forwdecl := False;
         IF Listhead = NIL THEN Parnumber := 0
         ELSE Parnumber := Lparnumber;
         Pflev := 2; Externdecl := True; 
         Externalname := Fextname; Idname := Fname;
         END;
      Enterid(Procidp)
      END (*Enterregularproc*);

BEGIN (* Enterstdprocs *)


New(Stdfileinitidp,Proc,Regular,Actual);        
WITH Stdfileinitidp^ DO
   BEGIN
   Klass := Proc; Prockind := Regular; Pfkind := Actual;
   Idtype := NIL; Next := NIL; Forwdecl := False; Parnumber := 5;
   Pflev := 2; Externdecl := False; Pfmemblock := 0;
   Externalname := '$INITSTD        '; Idname := Externalname;
   END;

(* enter proc/funcs needing special treatment *)
Enterspecialproc ('READ            ',Spread,Proc);
Enterspecialproc ('READLN          ',Spreadln,Proc);
Enterspecialproc ('WRITE           ',Spwrite,Proc);
Enterspecialproc ('WRITELN         ',Spwriteln,Proc);
Enterspecialproc ('PACK            ',Sppack,Proc);
Enterspecialproc ('UNPACK          ',Spunpack,Proc);
Enterspecialproc ('NEW             ',Spnew,Proc);
Enterspecialproc ('DISPOSE         ',Spdispose,Proc);

(* enter funcs for which inline code will be generated *)
Enterinlinefunc ('ABS             ',Uabs,[Jdt,Ldt,Rdt],NIL);
Enterinlinefunc ('SQR             ',Usqr,[Jdt,Ldt,Rdt],NIL);
Enterinlinefunc ('ODD             ',Uodd,[Jdt,Ldt],Boolptr);
Enterinlinefunc ('ORD             ',Ucvt,[Adt,Bdt,Cdt,Jdt,Ldt],Intptr);
Enterinlinefunc ('CHR             ',Ucvt,[Jdt,Ldt],Charptr);
Enterinlinefunc ('PRED            ',Udec,[Bdt,Cdt,Jdt,Ldt],NIL);
Enterinlinefunc ('SUCC            ',Uinc,[Bdt,Cdt,Jdt,Ldt],NIL);
Enterinlinefunc ('ROUND           ',Urnd,[Rdt],NIL);
Enterinlinefunc ('TRUNC           ',Ucvt,[Rdt],NIL);
Enterinlinefunc ('MIN             ',Umin,[Bdt,Cdt,Jdt,Ldt,Rdt],NIL);
Enterinlinefunc ('MAX             ',Umax,[Bdt,Cdt,Jdt,Ldt,Rdt],NIL);
Enterinlinefunc ('MARK            ',Unew,[Jdt,Ldt],NIL);
Enterinlinefunc ('RELEASE         ',Udsp,[Jdt,Ldt],NIL);

(* enter all other standard proc/funcs *)

New (Zeroptr, Konst);   
With Zeroptr^ DO
   BEGIN
   Klass := Konst;
   Idtype := Intptr;
   Values.Ival := 0;
   END;
New (Oneptr, Konst);
Oneptr^ := Zeroptr^;
Oneptr^.Values.Ival := 1;
New (MinusOneptr, Konst);
MinusOneptr^ := Zeroptr^;
MinusOneptr^.Values.Ival := -1;
  
Enterstdstring(Nullstrptr,1);  
New (Nullstridptr);
With Nullstridptr^ DO
   BEGIN
   Idtype := Nullstrptr;
   Klass := Konst;
   Values.Len := 1;
   Values.Chars[1] := ' ';
   END;

Listhead := NIL;
Enterstdparameter(Anyfileptr,Formal,NIL);
Enterregularproc('GET             ','$GET            ',NIL,False);
Getptr := Procidp;
Enterregularproc('PUT             ','$PUT            ',NIL,False);
Putptr := Procidp;
Enterregularproc('BUFVAL          ','$BUFVAL         ',Charptr,True);
Bufvalptr := Procidp;
Enterregularproc('CLOSE           ','$CLOSE          ',NIL,True);
Enterregularproc('BREAK           ','$BREAK          ',NIL,True);

Listhead := NIL;
Enterstdparameter(Anyfileptr,Formal,Inputptr);
Enterregularproc('EOF             ','$EOF            ',Boolptr,False);

Listhead := NIL;
Enterstdparameter(Anytextptr,Formal,Inputptr);
Enterregularproc('EOLN            ','$ELN            ',Boolptr,False);
Enterregularproc('READPAGE        ','$RDPAGE         ',NIL,True);
Enterregularproc('EOPAGE          ','$EOPAGE         ',Boolptr,True);

Listhead := NIL; 
Enterstdparameter(Anytextptr,Formal,Outputptr);
Enterregularproc('PAGE            ','$WRPAGE         ',NIL,False);

Listhead := NIL;
Enterstdparameter(Anyfileptr,Formal,Inputptr);
Enterstdparameter(Anystringptr,Actual,Nullstridptr);
Enterstdparameter(Intptr,Actual,Zeroptr);
Enterstdparameter(Intptr,Actual,Zeroptr);
Enterregularproc ('RESET           ','$RES            ',Nil,False);
Resetptr := Procidp;

Listhead := NIL;
Enterstdparameter(Anyfileptr,Formal,Outputptr);
Enterstdparameter(Anystringptr,Actual,Nullstridptr);
Enterstdparameter(Intptr,Actual,Zeroptr);
Enterstdparameter(Intptr,Actual,Zeroptr);
Enterregularproc ('REWRITE         ','$REW            ',Nil,False);
Rewriteptr := Procidp;

(*log,sin,cos,exp,sqrt,atn*)
   
Listhead := NIL;
Enterstdparameter(Realptr,Actual,NIL);
Enterregularproc('COS             ','$COS            ',Realptr,False);
Enterregularproc('EXP             ','$EXP            ',Realptr,False);
Enterregularproc('SQRT            ','$SQT            ',Realptr,False);
Enterregularproc('LN              ','$LOG            ',Realptr,False);
Enterregularproc('ARCTAN          ','$ATN            ',Realptr,False);
Enterregularproc('SIN             ','$SIN            ',Realptr,False);

Listhead := NIL;
Enterstdparameter(Intptr,Actual,Oneptr);
Enterregularproc('CLOCK           ','$CLK            ',Intptr,True);

Listhead := NIL;
Enterstdparameter(Intptr,Actual,MinusOneptr);
Enterregularproc('HALT            ','$HALT           ',NIL,True);

Listhead := NIL;
Enterstdparameter (Intptr,Formal,NIL);
Enterstdparameter (Intptr,Formal,NIL);
Enterstdparameter (Intptr,Formal,NIL);
Enterregularproc('PDATE           ','$PDATE          ',NIL,True);
 
Listhead := NIL;
Enterstdparameter (Intptr,Actual,NIL);
Enterstdparameter (Intptr,Actual,NIL);
Enterstdparameter (Boolptr,Actual,NIL);
Enterregularproc('RANDOM          ','$RANDOM         ',Intptr,True);

Listhead := NIL;
Enterregularproc('SPACE           ','$SPACE          ',Intptr,True);
Enterregularproc('PTIME           ','$PTIME          ',Intptr,True);
Enterregularproc('TTYINREADY      ','$TTYINREADY     ',Boolptr,True);

Listhead := NIL;
Enterstdparameter (Anystringptr,Formal,NIL);
Enterstdparameter (Intptr, Actual, NIL);
Enterregularproc('DATE            ','$DATE           ',NIL,True);
Enterregularproc('TIME            ','$TIME           ',NIL,True);

Listhead := NIL;
Enterstdparameter (Anystringptr,Actual,NIL);
Enterstdparameter (Intptr, Actual, NIL);
Enterregularproc('DFILE           ','$DFILE          ',Boolptr,True);
Enterregularproc('FEXISTS         ','$FEXISTS        ',Boolptr,True);

Listhead := NIL;
Enterstdparameter (Anystringptr,Actual,NIL);
Enterstdparameter (Intptr, Actual, NIL);
Enterstdparameter (Anystringptr,Actual,NIL);
Enterstdparameter (Intptr, Actual, NIL);
Enterregularproc('RFILE           ','$RFILE          ',Boolptr,True);

Listhead := NIL;
Enterstdparameter (Anyfileptr,Formal,NIL);
Enterstdparameter (Anystringptr,Formal,NIL);
Enterstdparameter (Intptr,Actual,NIL);
Enterregularproc('FILESTATUS      ','$FILESTATUS     ',Intptr,True);
 
Listhead := NIL;
Enterstdparameter (Anytextptr,Formal,NIL);
Enterstdparameter (Intptr,Formal,NIL);
Enterstdparameter (Intptr,Formal,NIL);
Enterstdparameter (Intptr,Formal,NIL);
Enterregularproc('FILEPOS         ','$FILEPOS        ',NIL,True);
 
Listhead := NIL;
Enterstdparameter (Anytextptr,Formal,NIL);
Enterstdparameter (Boolptr,Actual,NIL);
Enterregularproc('SETTTYMODE      ','$SETTTYMODE     ',NIL,True);
   
END (*enterstdprocs*) ;


(*Uco...,Support,Stdcallinit,Par *)

   
(******************************************************************************)
(******************************************************************************)
(*                                                                            *)
(*      UCODE WRITING MODULE                                                  *)
(*                                                                            *)
(* U-code is a stack-based intermediate  language.  It comes in two forms: a  *)
(* text representation,  and a binary  representation (B-code).   This module *)
(* contains routines for writing both U-code and B-code.                      *)
(*                                                                            *)
(* Each instruction, whether in U-code or B-code form, is passed in the       *)
(* form of a B-code  record, called U. To find out where each value  of       *)
(* an instruction  is in  the record,  you  should look  at the  the  operand *)
(* initialization code in INITUWRITE (this initializes the operand table,     *)
(* which describes  the  type and  order  of  the operands  for  each  U-code *)
(* instruction).  For  example, the  ISTR  instruction has  operands  SDTYPE, *)
(* SOFFSET, and  SLENGTH, and the  three operands for the  instruction would  *)
(* be found  in  U.DTYPE, U.OFFSET, and U.LENGTH.                             *)
(*                                                                            *)
(*  Some exceptions:                                                          *)
(*     SPNAME0 and SPNAME1 are both stored in U.PNAME.  The 0 and 1 indicate  *)
(*       whether then name should appear before or after the Opcode.          *)
(*       Similarly, SVNAME0 and SVNAME1 are stored in U.VNAME.                *)
(*     SLABEL0, SLABEL1, and SBLOCKNO  are all stored in U.I1.                *)
(*     For SCOMMENT, the comment is stored as a string constant in U.CONSTVAL.*)
(*                                                                            *)
(* Since a B-code record is variable in length, depending on the instruction, *)
(* it  is   alternately  represented   as  an   array  of   integers.    This *)
(* representation is used when  reading or writing to  a file.  A routine  is *)
(* provided to calculate the length of each instruction.  Since  instructions *)
(* which include  a  constant,  such  as LDC,  may  have  different  lengths, *)
(* depending on the constant, the length of the constant must be added to the *)
(* length of the record being read or written for those instructions.         *)
(******************************************************************************)
(******************************************************************************)



FUNCTION RealMtype (Blk: Integer; Fmty: Memtype; Foffset: Integer): Memtype;

   BEGIN
   IF (Blk = Memblock) AND (Foffset >= Minlocreg) AND (Foffset <= Maxlocreg) 
      AND (Fmty <> Pmt) THEN
         RealMtype := Rmt
   ELSE
	 RealMtype := Fmty;
   END;
      
PROCEDURE Uco0(Fop: Uopcode);
   (* chkf,chkt,chkn,ret,dsp,vmov*)
   BEGIN
   U.Opc := Fop; Uwrite (U);
   END;

PROCEDURE Uco1type(Fop:Uopcode; Fdty: Datatype);
   (* abs, add, and, div, dup, equ, geq, grt, ior, leq, les, 
      min, max, mod, mpy, neg, neq, not, odd, sqr, sub, xor *)
   BEGIN
   U.Opc := Fop; U.Dtype := Fdty; Uwrite (U);
   END;

PROCEDURE Uco1int(Fop:Uopcode; Fint: Integer);
   (* fjp, mst, tjp, ujp, new *)
   BEGIN
   U.Opc := Fop;
   IF Fop = Umst THEN U.Lexlev := Fint
   ELSE U.I1 := Fint;
   Uwrite (U);
   END;

PROCEDURE Uco1idp (Fop:Uopcode; Fidp: Idp);
   (* cup, ent, icup, ldp, 
    plod, pstr, sym, and lca, when it loads identifier names (specifically
    for names of declared scalars, for i/o routines;
    not yet implemented: impv, expv, impm, data, endd, init *)

   VAR I: 1..Identlength;

   BEGIN
   U.Opc := Fop;
   IF (Fidp <> NIL) THEN
      WITH U,Fidp^ DO
         CASE Fop OF
            Uend:
               IF Klass = Progname THEN Pname := Entname
               ELSE Pname := Externalname;
            Ubgn: BEGIN Pname := Idname; I1 := 0; END;
            Ustp: Pname := Idname;
            Uimpv, Uexpv:
               BEGIN
               Vname := Idname;
	       Mtype := Vmty; I1 := Vblock; Offset := Vaddr;
	       Dtype :=Idtype^.Stdtype; Length := Idtype^.Stsize;
               END;
            Uplod:
               IF Klass = Func THEN
                  IF Idtype <> NIL THEN
                     BEGIN
                     Dtype := Idtype^.Stdtype;
		     I1 := Pfmemblock;
		     Offset := Resaddr;
	             Mtype := Realmtype (Pfmemblock, Resmemtype, Resaddr);
                     Length := Idtype^.Stsize;
                     END
                  ELSE
                     Error(171);
            Upstr:
               IF Idtype <> NIL THEN
                  IF Klass = Func THEN
                     BEGIN
                     Dtype := Adt; Mtype := Resmemtype; I1 := Pfmemblock;
                     Offset := Resaddr;  Length := Idtype^.Stsize;
                     END
                  ELSE IF Vkind = Formal THEN
                     BEGIN
                     Dtype := Adt; Mtype := Vmty; I1 := Vblock;
                     Offset := Vaddr;  Length := Pointersize;
                     END
                  ELSE IF (Idtype^.Stdtype <> Mdt) AND
                     (Idtype^.Stsize <= Parthreshold) THEN  
                     BEGIN
                     Dtype := Idtype^.Stdtype; Mtype := Vmty; I1 := Vblock;
                     Offset := Vaddr;  Length := Idtype^.Stsize;
                     END
                  ELSE (* passed indirectly *)
                     BEGIN
                     Dtype := Adt; Mtype := Vindtype; I1 := Vblock;
                     Offset := Vindaddr;  Length := Pointersize;
                     END;
            Ucup, Uent, Uicup:
               BEGIN
               Push := 0; Dtype := Pdt;
               IF Klass = Func THEN
                  IF Idtype <> NIL THEN
                     WITH Idtype^ DO
                        IF (Stsize <= Parthreshold) AND (Stdtype <> Mdt) THEN
                           BEGIN
                           Push := 1; Dtype := Stdtype;
                           END;
               CASE Fop OF
                  Uent:
                     IF Klass = Progname THEN 
                        BEGIN
                        Pname := Entname;
                        Lexlev := Proglev;
                        I1 := Progmemblock;
                        Pop := Progparnumber;
                        Extrnal := 1;
                        END
                     ELSE
                        BEGIN
                        Pname := Externalname;
                        Lexlev := Pflev; I1 := Pfmemblock; Pop := Parnumber;
                        Extrnal := Ord (Ismodule);
                        END;
                  Ucup:
                     BEGIN
                     I1 := Pfmemblock;
                     Pname := Externalname;
                     Pop := Parnumber;
                     END;
                  Uicup:
                     Pop := Parnumber;
               END; (*case *)
               END;
            Uldp:
               BEGIN
               Lexlev := Pflev; I1 := Pfmemblock;Pname := Externalname;
               END;
            Ulca :
               BEGIN
               Dtype := Mdt; Length := Stringsize (Identlength); I1 := 0;
               FOR I := 1 TO Identlength DO
                  Constval.Chars[I] := Idname[I];
               Constval.Len := Identlength;
               END;
            END (*case*);
   Uwrite (U);
   END (*uco1idp*);

PROCEDURE Ucoinit (Fdty: Datatype; Foffset, Foffset2: Addrrange; 
                 Flength: Sizerange; Fval: Valu);
   BEGIN
   U.Opc := Uinit;
   U.I1 := 1;
   U.Mtype := Smt;
   U.Dtype := Fdty;
   U.Offset := Foffset;
   U.Offset2 := Foffset2;
   U.Length := Flength;
   U.Initval := Fval;
   Uwrite (U);
   END;

PROCEDURE Uco2typtyp(Fop:Uopcode;Fdty1,Fdty2: Datatype);
   (*cvt, cvt2, swp, rnd*)
   BEGIN
   U.Opc := Fop;
   U.Dtype := Fdty1;
   U.Dtype2 := Fdty2;
   Uwrite (U);
   END;

PROCEDURE Uco1attr(Fop:Uopcode; Fattr: Attr);
   (*generates the ucode inUSTRtions with addressing parameters, described in an
    attr record: ldc, lca, ilod, inst, istr, lda, lod, nstr, str *)
   BEGIN (*uco1attr*)
   WITH Fattr,U DO
      BEGIN
      Opc := Fop;
      CASE Fop OF
         Uldc, Ulca:
            BEGIN
            Dtype := Adtype;
            IF Adtype = Mdt THEN 
               Length := Stringsize (Cval.Len)
            ELSE IF Atypep <> NIL THEN
               Length := Atypep^.Stsize;
            Constval := Cval; U.I1 := 0;
            END;
         Ulda:
            BEGIN
            Mtype := Amty; I1 := Ablock; Offset := Dplmt;
            Length := Pointersize;  Offset2 := Baseaddress;
            END;
         Uilod, Uinst,Uistr:
            BEGIN
            Dtype := Adtype; Mtype := Amty; Offset := Dplmt;
            IF Atypep <> NIL THEN
               IF Apacked or Rpacked or Fpacked THEN
                  BEGIN
                  IF Subkind <> NIL THEN
		     Length:= Subkind^.Packsize
                  ELSE
                     Length:= Atypep^.Packsize;
		  IF Fpacked THEN Roundup (Length, Fpackunit)(** 10MAR *)
                  END
               ELSE
                  Length:= Atypep^.Stsize
            END;
         Ulod, Unstr,Ustr:
            BEGIN
            Dtype := Adtype;
	    I1 := Ablock;
	    Offset := Dplmt;
	    Mtype := Realmtype (Ablock, Amty, Dplmt);
            IF Atypep <> NIL THEN
               IF Apacked or Rpacked or Fpacked THEN
                  BEGIN
                  IF Subkind <> NIL THEN
		     Length:= Subkind^.Packsize
                  ELSE
                     Length:= Atypep^.Packsize;
		  IF Fpacked THEN Roundup (Length, Fpackunit)(** 10MAR *)
                  END
               ELSE
                  Length:= Atypep^.Stsize
	    END;
         END (*case fop of*);
      END;
   Uwrite (U);
   END (*uco1attr*);

PROCEDURE Uco2typint(Fop:Uopcode; Fdty: Datatype; Fint: Integer);
   (* chkh, chkl, dec, dif, inc, iequ, igeq, igrt, ileq, iles, ineq, int, ixa, 
      umov, uni *)
   BEGIN (*uco2typint*)
   U.Opc := Fop;
   U.Dtype := Fdty;
   U.Length := Fint;
   Uwrite (U);
   END (*uco2typint*);

PROCEDURE Uco2intint(Fop:Uopcode; Fint1, Fint2: Integer);
   (* clab, goob, lab, lex*)
   BEGIN
   U.Opc := Fop;
   WITH U DO
      CASE Fop OF
         Uclab,Usdef: BEGIN I1 := Fint1; Length := Fint2 END;
         Ugoob,Ulab:  BEGIN I1 := Fint1; Lexlev := Fint2 END;
         Ulex:        BEGIN Lexlev := Fint1; I1 := Fint2 END;
      END;
   Uwrite (U);
   END;

PROCEDURE Uco2nameint (Fop:Uopcode; Fname: Identname; Fint: Integer);
   (*optn*)
   BEGIN
   U.Opc := Fop;
   U.Pname := Fname;
   U.I1 := Fint;
   Uwrite (U);
   END;

PROCEDURE Uco3int(Fop:Uopcode; Fdty: Datatype; Fint1,Fint2: Integer);
   (*adj, ilod, inst, istr, inn *)
   (* size ALWAYS first (adj,ilod,istr) *)  
   BEGIN (*uco3*)
   U.Opc := Fop;
   U.Dtype := Fdty;
   U.Length := Fint1;
   IF U.Opc = Uinn THEN
      U.I1 := Fint2
   ELSE
      U.Offset := Fint2;
   Uwrite (U);
   END (*uco3*);

PROCEDURE Uco3intval(Fop:Uopcode; Fdty: Datatype; Fint1,Fint2: Integer);
   (*ldc*)
   (* size ALWAYS first (adj,ilod,istr) *)  
   BEGIN (*uco3*)
   U.Opc := Fop;
   U.Dtype := Fdty;
   U.Length := Fint1;
   U.Constval.Ival := Fint2;
   Uwrite (U);
   END (*uco3*);

PROCEDURE Uco3val(Fop:Uopcode; Fdty: Datatype; Fint: Integer; Fvalu: Valu);
   (*ldc, lca *)
   BEGIN
   U.Opc := Fop;
   U.I1 := 0;
   U.Dtype := Fdty;
   U.Length := Fint;
   U.Constval := Fvalu;
   Uwrite (U);
   END;

PROCEDURE Uco4int (Fop:Uopcode; Llev, Int, Off, Len: Integer);
   (*regs*)
   BEGIN
   U.Opc := Fop;
   U.Lexlev := LLev;
   U.I1 := Int;
   U.Offset := Off;
   U.Length := Len;
   Uwrite (U);
   END;

PROCEDURE Uco5typaddr(Fop:Uopcode; Fdty: Datatype; Fmty: Memtype; 
                      Fblock: Integer; Foffset,Flen: Addrrange);
   (*lod, nstr, plod, pstr, str*)

   BEGIN
   U.Opc := Fop;
   U.Dtype := Fdty;
   U.I1 := Fblock;
   U.Offset := Foffset;
   U.Mtype := Realmtype (Fblock, Fmty, Foffset);
   U.Length := Flen;
   Uwrite (U);
   END;

PROCEDURE Uco6 (Fop:Uopcode; Fdty: Datatype; Fmty: Memtype; 
                      Fblock: Integer; Foffset,Flen,Foffset2: Addrrange);
   (*rlod, rstr*)

   BEGIN
   U.Opc := Fop;
   U.Dtype := Fdty;
   U.Mtype := Fmty;
   U.I1 := Fblock;
   U.Offset := Foffset;
   U.Offset2 := Foffset2;
   U.Length := Flen;
   Uwrite (U);
   END;

PROCEDURE Ucolda (Fdty: Datatype; Fmty: Memtype; 
                      Fblock: Integer; Foffset,Flen: Addrrange);
   BEGIN
   U.Opc := Ulda;
   U.Dtype := Fdty;
   U.I1 := Fblock;
   U.Mtype := Fmty;
   U.Offset := Foffset;
   U.Offset2 := Foffset;
   U.Length := Flen;
   Uwrite (U);
   END;

PROCEDURE Ucodef(Fmty: Memtype; Fint: Integer);
   BEGIN
   U.Opc := Udef;
   U.Mtype := Fmty;
   U.Length := Fint;
   Uwrite (U);
   END;

PROCEDURE Ucoloc(Fline,Fpage,Fstat: Integer);

   BEGIN (*ucoloc*)
   U.Opc := Uloc;
   U.I1 := Fpage;
   U.Offset := Fline;
   U.Length := Fstat;
   Uwrite (U);
   END (*ucoloc*);

PROCEDURE Ucoxjp(Fdty: Datatype; Ffirstlabel, Fotherslabel: Integer;
                 Flowbound, Fhighbound: Integer);
   BEGIN (*ucoxjp*)
   U.Opc := Uxjp;
   U.Dtype := Fdty;
   U.I1 := Ffirstlabel;
   U.Label2 := Fotherslabel;
   U.Offset := Flowbound;
   U.Length := Fhighbound;
   Uwrite (U);
   END (*ucoxjp*);

PROCEDURE Support(Fsupport: Supports);
   (*generates a call to a standard procedure cup *)
   BEGIN (*support*)
   WITH Runtimesupport DO
      BEGIN
      U.Opc := Ucup;
      U.Dtype := Dty[Fsupport];
      U.I1 := 0;
      U.Pname := Idname[Fsupport];
      U.Pop := Pop[Fsupport];
      U.Push := Ord (U.Dtype <> Pdt);
      END;
   Uwrite (U);
   END (*support*);

PROCEDURE Stdcallinit (VAR Parcount: Integer);
   (* starts call to standard procedure *)
   BEGIN
   Uco1int (Umst,2);
   Parcount := 0;
   END;

PROCEDURE Par (Dtype: Datatype; VAR Parcount: Integer); 
   (* calculates address and generates PAR instruction for procedure calls *)
   VAR Lmty: Memtype;
       Size: Addrrange;
   BEGIN
   CASE Dtype OF
      Adt:      Size := Pointersize;
      Bdt:      Size := Boolsize;
      Cdt:      Size := Charsize;
      Edt:	Size := Entrysize;
      Ldt,Jdt:  Size := Intsize;
      Mdt:      BEGIN Size := 0; Error (171); END; (* compiler error *)
      Rdt:      Size := Realsize;
      Sdt:  	Size := Setunitsize;
      END;
   IF Pmemsize > 0 THEN
       Lmty := Pmt
   ELSE
       Lmty := Mmt;
   IF Parcount MOD Varalign <> 0 THEN
      Roundup (Parcount, Varalign);
   Uco5typaddr (Upar, Dtype, Lmty, 0, Parcount, Size);
   Parcount := Parcount + Size;
   END;

(*Printline,Error,Warning,Skipiferr,Errandskip,Iferrskip,Printerrmsg*)

(************************************************************************)
(*                                                                      *)
(*      ERROR HANDLING MODULE                                           *)
(*                                                                      *)
(*      An error message, when printed on the terminal, looks like      *)
(*      this:                                                           *)
(*                                                                      *)
(*        4/  2 CASE KIND OF                                            *)      
(*    PROG1          ^---                                               *)
(*    1.  IDENTIFIER NOT DECLARED                                       *)
(*                                                                      *)
(*      On the first occurence of an error or warning, the line is      *)
(*      printed out (by procedure Printline).  An arrow with dashes     *)
(*      is used to point to the current symbol, and the error number    *)
(*      is stored in Errlist.  Before Getnextline reads in the nextline,*)
(*      it prints out all the error messages that are in Errlist.       *)
(*                                                                      *)
(*      Some warnings are not associate with the current line, for      *)
(*      instance if a variable is not used or a procedure declared      *)
(*      forward never appears.  Procedure ErrorwithId and WarningwithId *)
(*      are called in these cases, an the Id to be printed is stored    *)
(*      in Errlist.                                                     *)
(*                                                                      *)
(************************************************************************)


PROCEDURE Printline;
   (* Writes out the current line with arrows pointing to the current token,
    or adds arrows to already printed line *)

   CONST
      Dashes = '----------------------------------------';
   BEGIN
   IF Errinx = 0 THEN
      BEGIN (* write out erroneous line(s) and set up error line *)
      IF Lptfile OR Logfile THEN
         BEGIN
         IF Listneedsaneoln THEN Writeln (List);
         IF Lptfile THEN
            Write(List,' ***** ')
         ELSE IF Logfile THEN
            BEGIN
            IF (Symcnt = 1) AND NOT Errorinlast THEN
               Writeln(List,'--------  ',Lastbuffer:Lastchcnt);
            Writeln(List,Linecnt:5,'/',Pagecnt:3,' ',Buffer:Chcnt);
            Write(List,Currname:9);
            END;
         Listneedsaneoln := True;
         END;
      IF Needsaneoln THEN Writeln (Output);
      Needsaneoln := True;
      IF (Symcnt = 1) AND NOT Errorinlast THEN
         Writeln(Output,'--------  ',Lastbuffer:Lastchcnt);
      Writeln(Output,Linecnt:5,'/',Pagecnt:3,' ',Buffer:Chcnt);
      Write(Output,Currname:9);
      END;
   (* add arrows to error line *)
   IF Lptfile OR Logfile THEN
      BEGIN
      Write(List,' ':Symmarker-Errorpos,'^');
      IF Chptr-Symmarker > 1 THEN Write (List,Dashes:Chptr-Symmarker-1);
      END;
   Write(Output,' ':Symmarker-Errorpos,'^');
   IF Chptr-Symmarker > 1 THEN Write (Output,Dashes:Chptr-Symmarker-1);
   Errorpos := Chptr;
   END;

PROCEDURE Pusherror (Errno: Integer; Warning: Boolean; Varnam: Identname);
   (* record an error in Errlist *)
   BEGIN
   IF ((Errinx < Maxerr) AND (Varnam[1] <> ' ')) OR 
      (Errinx < Maxprserr) THEN
         BEGIN
         Errinx := Errinx + 1;
         Errlist[Errinx].Errno := Errno;
         Errlist[Errinx].Warning := Warning;
         Errlist[Errinx].Varname := Varnam;
         END;
   END;

PROCEDURE Error (* Ferrnr: Integer *);
   VAR Ignore: Boolean;
   BEGIN (*error*)
   (* if there was an error already at the same token, don't count it *)
   Ignore := Errinx > 0;
   IF Ignore THEN
      Ignore := (Chptr = Errorpos) AND NOT Errlist[Errinx].Warning;
   IF NOT Ignore THEN
      BEGIN
      Errorcount := Errorcount + 1;
      Printline;
      Pusherror (Ferrnr,False,'                ');
      END;
   StopUcode;
   END (*error*) ;


PROCEDURE Errorwithid ( Ferrnr: Integer; Varnam: Identname ) ;
   (*report error no. ferrnr, including the string ftext, picked from the*)
   (*source file*)
   BEGIN
   Errorcount := Errorcount + 1;
   Pusherror (Ferrnr,False,Varnam);
   StopUcode;
   END;

PROCEDURE Warning (Ferrnr: Integer);
   (*report an error, but don't count it: it is not fatal*)
   BEGIN (* warning *)
   IF Chptr <> Errorpos THEN
      BEGIN
      Printline;
      Pusherror (Ferrnr,True,'                ');
      END;
   END (* warning *);

PROCEDURE Warningwithid (Ferrnr: Integer; Varnam:Identname);  
   BEGIN
   Pusherror (Ferrnr,True,Varnam);
   END;

PROCEDURE Insymbol; FORWARD;

PROCEDURE Skipiferr(Fsyinsys:Setofsys; Ferrnr:Integer; Fskipsys: Setofsys);

   (*if the last symbol scanned, sy, is not in the set fsyinssys, then:*)
   (*report error number ferrnr and skip the tokens (symbols) until you*)
   (*hit one of the symbols in the set fskipsys*)

   BEGIN
   IF NOT (Sy IN Fsyinsys) THEN
      BEGIN
      Error(Ferrnr);
      WHILE NOT (Sy IN Fskipsys + Fsyinsys + [Eofsy]) DO Insymbol;
      END;
   END;

PROCEDURE Iferrskip(Ferrnr: Integer; Fsys: Setofsys);
   BEGIN
   Skipiferr(Fsys,Ferrnr,Fsys)
   END;

PROCEDURE Errandskip(Ferrnr: Integer; Fsys: Setofsys);
   BEGIN
   Skipiferr([ ],Ferrnr,Fsys)
   END;

PROCEDURE Printerrmsg (Errno: Integer);
   (* print error message *)
   VAR I: Integer;
      Llptfile: Boolean;
   BEGIN
   (* error number = errormessagelength*10 + errormessageindex; *)
   I := Errno MOD 50;
   Llptfile := Lptfile OR Logfile;
   CASE Errno DIV 50 OF
      3:
         BEGIN
         IF Llptfile THEN
            Write(List,Errmess15[I]);
         Write(Output,Errmess15[I])
         END;
      4:
         BEGIN
         IF Llptfile THEN
            Write(List,Errmess20[I]);
         Write(Output,Errmess20[I])
         END;
      5:
         BEGIN
         IF Llptfile THEN
            Write(List,Errmess25[I]);
         Write(Output,Errmess25[I])
         END;
      6:
         BEGIN
         IF Llptfile THEN
            Write(List,Errmess30[I]);
         Write(Output,Errmess30[I])
         END;
      7:
         BEGIN
         IF Llptfile THEN
            Write(List,Errmess35[I]);
         Write(Output,Errmess35[I])
         END;
      8:
         BEGIN
         IF Llptfile THEN
            Write(List,Errmess40[I]);
         Write(Output,Errmess40[I])
         END;
      9:
         BEGIN
         IF Llptfile THEN
            Write(List,Errmess45[I]);
         Write(Output,Errmess45[I])
         END;
      10:
         BEGIN
         IF Llptfile THEN
            Write(List,Errmess50[I]);
         Write(Output,Errmess50[I])
         END;
      11:
         BEGIN
         IF Llptfile THEN
            Write(List,Errmess55[I]);
         Write(Output,Errmess55[I]);
         END
      END (*case ERRNO div 50 of*);
   IF Llptfile THEN
      BEGIN
      Writeln(List);
      Listneedsaneoln := False;
      END;
   Writeln(Output);
   Needsaneoln := False;
   END  (*printerrmsg*) ;




(*Popfile,Pushfile,Newfile,Getnextline,Nextch,Skipedirectory*)

(************************************************************************)
(*                                                                      *)
(*      LEXER MODULE                                                    *)
(*                                                                      *)
(*      The main procedure in this module is Insymbol, which gets       *)
(*      the next symbol and returns the symbol type in the global       *)
(*      variable Sy, the value, if any, in Val, and the symbol itself,  *)
(*      if it is an identifier, in Id.  Note that reserved words are    *)
(*      not considered identifiers, and each one is considered a        *)
(*      seperate symbol type.                                           *)
(*                                                                      *)
(*      The source program is read a line at a time into the line       *)
(*      buffer.  It is not uppercased until it is retrieved from        *)
(*      the buffer by Nextch, and even then only if it is not a         *)
(*      string.                                                         *)
(*                                                                      *)
(*                                                                      *)
(*                                                                      *)
(************************************************************************)


PROCEDURE Finishline;
   VAR I: Integer;
   BEGIN
   (* prints error messages *)
   (* finish arrow line *)
   IF Needsaneoln THEN Writeln (Output);
   IF Listneedsaneoln THEN Writeln (List);
   FOR I := 1 TO Errinx DO
      WITH Errlist[I] DO
         BEGIN
         IF Lptfile OR Logfile THEN
            BEGIN
            Write (List,I:1,'.  ');
            IF Warning THEN Write (List,' ** WARNING: ** ');
            IF Varname[1] <> ' ' THEN
              Write (List,'IN ',Currname:Max(1,Idlen(Currname)),', ',
                     Varname:Idlen(Varname),' ');
            END;
         Write (Output,I:1,'.  ');
         IF Warning THEN Write (Output,' ** WARNING: ** ');
         IF Varname[1] <> ' ' THEN
           Write (Output,'IN ',Currname:Max(1,Idlen(Currname)),', ',
                  Varname:Idlen(Varname),' ');
         Printerrmsg (Errno);
         END;
   END;

PROCEDURE Getnextline (VAR Infile: Text);

   (* Reads next nonempty line from source into line buffer, processing
      page mark if there is one*)

   VAR
	Tabcount: Integer;
        I: Integer;
   BEGIN (*getnextline*)
   IF Errinx > 0 THEN  Finishline;
   Lastbuffer := Buffer;
   Lastchcnt := Chcnt;
   Errorinlast := (Errinx > 0);
   (* while end of page, get next page *)
   WHILE Eopage(Infile) AND NOT Eof(Infile) DO
      BEGIN
      Linecnt := 0;
      Pagecnt := Pagecnt + 1;
      IF Lptfile THEN
         BEGIN (* start new page in listing file *)
         Page(List);
         Write(List,Header,'     Listing produced on ');
         Printdate(List);
         Write(List,' AT ');
         Printtime(List);
         Write(List,' [ ',Progidp^.Idname:Max(1,Idlen(Progidp^.Idname)),' ]');
         Writeln(List,' PAGE ',Pagecnt:3); Writeln(List);
         END;
   {  Write (Output, Pagecnt:3, '..'); (* print page number on terminal *)
      Needsaneoln := True;}
      Readln(Infile)  (*to overread second <lf> in page mark*)
      END;
   IF Bigline THEN Symmarker := 1
   ELSE
      BEGIN
      Linecnt := Linecnt + 1;
      Tlinecnt := Tlinecnt + 1;
      (* every 500 lines, write line number on terminal *)
   {  IF Linecnt MOD 500 = 0 THEN
         BEGIN
         Write(Output,'(',Linecnt:5,')');
         Needsaneoln := True;
         END; }
      END;
   Symcnt := 0;
   Errorpos := 0;
   Errinx := 0;
   Chcnt := 0;
   IF NOT Eof (Infile) THEN
      WHILE NOT Eoln (Infile) AND (Chcnt < Chcntmax) DO
         BEGIN
         IF Ord(Infile^) = Tab THEN
	    BEGIN
  	    Tabcount := Tabsetting - ((Chcnt+1)MOD Tabsetting);
	    FOR I := Chcnt TO Min (Chcnt + Tabcount, Chcntmax-1) DO
	       BEGIN
	       Chcnt := Chcnt + 1;
	       Buffer[Chcnt] := ' ';
	       END;
            END
	 ELSE
	    BEGIN
            Chcnt := Chcnt + 1;
            Buffer[Chcnt] := Infile^;
	    END;
  	 Get (Infile);
         END;
   
   Bigline := NOT Eoln (Infile);
   IF NOT Bigline THEN
      BEGIN
      Readln (Infile);
      Chcnt := Chcnt + 1;     (* put in space for EOLN marker *)
      Buffer[Chcnt] := ' ';
      END;
   IF ShowSource AND PrintUcode THEN
      Writebuf (Buffer, Chcnt);
   Chptr := 1;
   Tchcnt := Tchcnt + Chcnt;         (*keep count of chars*)
   IF Lptfile THEN
      BEGIN
      Write (List, Linecnt:5,'   ');
      IF Chcnt > 0 THEN
	 Write (List, Buffer:Chcnt);
      Writeln (List);
      END;
   END (*getnextline*);


PROCEDURE Nextch;
   (* Gets next character from the line buffer, reading in a new line if 
      necessary.    A new line will always have at least one character in it, 
      namely the end of line character *)

   BEGIN (*nextch*)
   Chptr := Chptr + 1;
   IF Chptr > Chcnt THEN
      IF InIncludeFile THEN
         IF Eof(Incfile) THEN Sy := Eofsy
         Else Getnextline (Incfile)
      ELSE
         IF Eof(Input) THEN Sy := Eofsy
         Else Getnextline (Input);
   Ch := Buffer[Chptr];
   If not Readingstring then
      (* convert to uppercase, if not inside string *)
      IF (Ord (Ch) >= Lcaseahost) AND (Ord (Ch) <= Lcasezhost) THEN
         Ch := Chr (Ord (CH) - Uplowdif);
   (*%iff HedrickPascal*)
   (* convert non-printing characters to spaces *)
   IF NOT (Ch IN [Firstchar..Reallastchar]) THEN Ch := ' ';
   (*%endc*)
   END (*nextch*);


   (*%ift sail*)
{PROCEDURE Skipedirectory (VAR Infile: Text);}
{   (*if the first page of the file is a directory for the editor E at Sail,}
{     skip that page*)}
{   VAR I: Integer;}
{   BEGIN}
{   WHILE (Infile^ <> ';') DO Get (Infile);}
{   Readln (Infile);}
{   FOR I := 1 TO Sbufmax DO}
{      Buffer[I] := ' ';}
{   Getnextline (Infile);}
{   Ch := Buffer[1];}
{   IF (Ord (Ch) >= Lcaseahost) AND (Ord (Ch) <= Lcasezhost) THEN}
{      Ch := Chr (Ord (CH) - Uplowdif);}
{   END;}
   (*%endc*)

PROCEDURE Newfile (VAR Infile: Text);
   VAR I: Integer;
   BEGIN
   Chcnt := 0;             Linecnt := 0;           Pagecnt := 1;
   Tchcnt := 0;            Tlinecnt := 0;
   Bigline := False;       
   FOR I := 1 TO Sbufmax DO
      Lastbuffer[I] := ' ';
   Getnextline (Infile);
   Ch := Buffer[1];
   IF (Ord (Ch) >= Lcaseahost) AND (Ord (Ch) <= Lcasezhost) THEN
      Ch := Chr (Ord (CH) - Uplowdif);
   Rangenext := False;
   Sy := Othersy;
   Insymbol;
   (*%ift sail*)
{   IF (Sy = Identsy) THEN                  (* skip E directory (at SAIL only) *)}
{      IF (Id = 'COMMENT         ') THEN}
{	 BEGIN Skipedirectory (Infile); Insymbol END;}
   (*%endc*)
   END;

PROCEDURE Popfile;
   BEGIN
   Chcnt := OldChcnt;
   Chptr := OldChptr;
   Bigline := OldBigline;
   Lastbuffer := OldLastbuffer;
   Buffer := OldBuffer;
   Lastchcnt := OldLastchcnt;
   Linecnt := OldLinecnt;
   Pagecnt := OldPagecnt;
   Symcnt := OldSymcnt;
   Tchcnt := OldTchcnt;
   Tlinecnt := OldTlinecnt;
   InIncludefile := False;
   Write (Output, ') ');
   END;

PROCEDURE Pushfile (Var Fname: Filename);

   VAR I: Integer;

   BEGIN
   OldChcnt := Chcnt;
   OldChptr := Chptr;
   OldBigline := Bigline;
   OldLastbuffer := Lastbuffer;
   OldBuffer := Buffer;
   OldLastchcnt := Lastchcnt;
   OldLinecnt := Linecnt;
   OldPagecnt := Pagecnt;
   OldSymcnt := Symcnt;
   OldTchcnt := Tchcnt;
   OldTlinecnt := Tlinecnt;
   InIncludefile := True;
   Write (Output, ' ( ');
   FOR I := 1 to Filenamelen DO
       IF Fname[I] <> ' ' THEN Write (Output, Fname[I]);
   Write (Output, ' ');
   Reset (IncFile, Fname);
   Newfile (Incfile);
   END;

(*Setswitch*)

PROCEDURE Setswitch (Switchname: Identname; Switchval: Integer);

   (** 10mar whole proc *)

   VAR Lch: Char;
       Lswitch: Boolean;

   BEGIN
   Lch := Switchname[1];
   IF (Switchname[2] <> ' ') AND (Lch <> 'T') AND (Lch <> 'Z') THEN
      WarningWithId (203, Switchname); (* not a known option *) (** 10mar *)
   Lswitch := Switchval <> 0;
   IF Switchname[1] = '!' THEN
      Resetpossible := False
   ELSE IF NOT Resetpossible AND (Lch IN ['D','M','P','O']) THEN 
      Warning(558)  
   ELSE IF NOT (Lch IN ['B','C','D','E','F','G','I','L','M','N','O',
			'P','R','S','T','U','W','Z']) THEN 
       WarningWithId (203, Switchname) (* not a known option *) (** 10mar *)
   ELSE CASE Lch OF
      'B': Runtimecheck := Lswitch;
      'C': Printucode := Lswitch;
      'D': IF Lswitch THEN
	      BEGIN
	      IF Lswitch and NOT Emitsyms THEN
		 Rewrite (Symtbl,Symname);
	      Emitsyms := True;
	      Uco2nameint (Uoptn, 'TDEBUG          ', 1); 
	      END;
      'E': Showsource := Lswitch;
      'F': BEGIN
	   Writebcode := Lswitch; 
	   IF Writebcode THEN EmitBcode;
	   END;
      'G': BEGIN
	   Logfile := Lswitch;
	   IF Logfile AND NOT Listrewritten THEN
	      BEGIN
	      Rewrite (List,Listname);
	      Listrewritten := True;
	      END;
	   END;
      'I': Maxidlength := Switchval;
      'L': BEGIN
	   Lptfile := Lswitch;
	   IF Lptfile AND NOT Listrewritten THEN
	      BEGIN
	      Rewrite (List, Listname);
	      Listrewritten := True;
	      END;
	   END;
      'M': (** 10MAR *)
	   IF Machine <> Switchval THEN
	      BEGIN
	      IF (Switchval = 10) OR (Switchval = 20) THEN
	         Init10
	      ELSE IF (Switchval = 2) THEN
	         InitS1
	      ELSE IF Switchval = 68 THEN
		 Init68
	      ELSE IF Switchval = 11 THEN
		 Initvax
	      ELSE IF Switchval = 2001 THEN
		 Initmips
	      ELSE
    	         WarningwithId (172, Blankid); (* unknown machine *)
              Uco2nameint (Uoptn, 'TMACHINE        ', Switchval); 
	      END;
      'N': Markrelease := Lswitch; (** 10MAR *)
      'O': Optimize := Lswitch; (** 10MAR *)
      'P': IF Lswitch THEN
	      BEGIN
	      Uco2nameint (Uoptn, 'TPROFILE        ', 1); 
	      Ucofname (Sourcename);
	      END;
      'R': IF Switchval > Maxlocalsinregs THEN
	      Localsinregs := Maxlocalsinregs
	   ELSE
	      Localsinregs := Switchval;
      'S': Standardonly := Lswitch;
      'T': BEGIN 
	   Uco2nameint (Uoptn, Switchname, Switchval); 
	   IF (Switchname = 'TRUNTIMES       ') AND (Switchval = 0) THEN
              Noruntimes := True 
           END;
      'U': IF Lswitch THEN
	      BEGIN Uniquefy := True; Leavealone := False END
           ELSE
	      BEGIN Uniquefy := False; Leavealone := True END;
      'W': BEGIN
	   Switchval := Switchval MOD 100;
	   Idwarning := Switchval MOD 10 = 1;
	   Switchval := Switchval DIV 10;
	   Commentwarning := Switchval MOD 10 = 1;
	   END;
      'Z': Uco2nameint (Uoptn, Switchname, Switchval); 
      END  (*CASE LCH OF*);
   END;

(*Skipcomment,Options,Number*)

PROCEDURE Insymbol;

   LABEL
      111,222,999;

   VAR
      I, K: Integer;
      Ival: Integer;
      Stringtoolong :Boolean ; 
      String: PACKED ARRAY [1..Strglgth] OF Char;

   PROCEDURE Skipcomment (Beginchar, Endchar: Char);

      (* Pass through the comment and throw it away, except if it is an
         option comment.
         Note that this routine looks for a matching comment character,
         rather than ANY terminating comment character.  This is contrary
         to the standard, which states that a right curly bracket should
         be treated exactly the same as an asterisk-left paren, but it
         is very useful for commenting out large blocks of code. 
         
       *)

      VAR
         Loopdone: Boolean;
         N: Integer;

      PROCEDURE Options;

         (* Parse the options in a comment in which the first character is
            a hash mark (#).  The possible values for options, and 
            consequent setting of variables, are:
               '+': Lvalue = 1
               '-': Lvalue = 0
	       positive number: Lvalue = number
               quoted string: Loadname = string, Loadnamectr = Length(string) 
         *)

	 VAR
	    Lvalue : Integer;
	    Optnname: Identname;
	    Loadname: Sourceline;
	    Loadnamectr: Integer;
	    I:Integer;

	 BEGIN (*OPTIONS*)
	 REPEAT
	    Nextch;
	    WHILE Ch = ' ' DO Nextch;
	    Optnname := Blankid;
	    Optnname[1] := Ch;
	    IF (Ch < 'A') OR (Ch > 'Z') THEN
	       Warning (203) (*UNKNOWN OPTION*);
	    IF NOT (Ch IN ['*','}','\']) THEN  
	       Nextch;
	    IF Optnname[1] IN ['T','Z'] THEN  (* Optimizer or code gen. option *)
	       BEGIN
	       I := 2;
	       Symmarker := Chptr; 
	       IF NOT (Ch IN Letters) THEN Warning(203)
	       ELSE
		  BEGIN
		  Optnname[2] := Ch;
		  Nextch;
		  WHILE Ch IN Letters + Digits DO
		     BEGIN
		     I := I+1;
		     Optnname[I] := Ch;
		     Nextch;
		     END;
		  END;
	       END;
	    WHILE Ch = ' ' DO Nextch;
	    Lvalue := 0;
	    Symmarker := Chptr; 
	    IF Optnname = 'TLOAD           ' THEN
	       BEGIN
	       Loadnamectr := 0;
	       IF Ch <> '''' THEN Warning (254);
	       Nextch;
	       While (Ch <> '''') AND NOT Eoln (Input) DO
		  BEGIN
		  Loadnamectr := Loadnamectr + 1;
		  Loadname[Loadnamectr] := Ch;
		  Nextch;
		  END;
	       IF CH <> '''' THEN Warning (254) ELSE Nextch;
	       Writeoptn (Optnname, 1); 
	       Writebuf (Loadname, Loadnamectr);
	       END
	    ELSE
	       BEGIN
	       IF NOT (Ch IN (Digits+['+','-'])) THEN
		  Warning (254);
	       IF Ch IN ['+','-'] THEN
		  BEGIN
		  Lvalue := Ord (Ch = '+');
		  Nextch;
		  END
	       ELSE IF Ch IN Digits THEN
		  BEGIN
		  Lvalue := 0;
		  REPEAT
		     Lvalue := Lvalue * 10 + (Ord(Ch)-Ord('0'));
		     Nextch
		  UNTIL NOT (Ch IN Digits);
		  END;
	       Setswitch (Optnname, Lvalue);
	       END;
	    WHILE Ch = ' ' DO Nextch;
	 UNTIL Ch <> ',';
	 END   (*OPTIONS*) ;

      BEGIN (*SKIPCOMMENT*)
      Nextch;
      Loopdone := False;
      IF Ch = '#' THEN Options;
      IF Endchar <> ')' THEN
	 BEGIN
	 WHILE (Ch <> Endchar) AND (Sy <> Eofsy) DO 
	   BEGIN
	   Nextch;
	   IF Commentwarning AND (Ch = Beginchar) THEN
	      BEGIN
	      Symmarker := Chptr; 
	      Warning (369);
	      END
	   END;
	 Nextch;
	 END
      ELSE IF (Sy <> Eofsy) THEN 
         BEGIN
         REPEAT
            IF (Ch = '*') THEN
               BEGIN
               Nextch;
               Loopdone := Ch = ')'
               END
            ELSE IF Ch = '(' THEN
               BEGIN
               Nextch;
               IF Commentwarning AND (Ch = '*') THEN
                  BEGIN
                  Symmarker := Chptr; 
                  Warning (369);
                  END
               END
            ELSE
               Nextch;
         UNTIL Loopdone OR (Sy = Eofsy); 
         Nextch;
	 END;
      IF Sy = Eofsy THEN
         Error (218);
      END (*SKIPCOMMENT*);

      
   PROCEDURE Number;   

   VAR
      Index : Integer;  
      Tempival: Integer;

   (* Parses numeric constant.  This could be a decimal integer, or a
      real number, with or without an exponent *)

   (* Note: The digits of an Intconstsy are stored as and Identsy too. This
    allows entering labels like all other identifiers into the symbol
    table. *)

   BEGIN
   Id := '                ';

   WHILE Ch = '0' DO Nextch; (* skip any leading zeroes *)
   (* SAVE ALL DIGITS IN THE INTEGER PART OF THE NUMBER *)
   IF Lastsign = Neg THEN
      BEGIN
      Val.Chars[1] := '-';
      Lastsign := None;
      END
   ELSE
      Val.Chars[1] := ' ';
   Index:=1;
   WHILE Ch IN Digits DO
      BEGIN                              (* PARSING DIGIT IN INT PART *)
      Index:=Index+1;                    (* POINT TO NEXT SYMDIG SLOT *)
      IF Index <= Strglgth THEN 
         Val.Chars[Index] := Ch; (* SAVE THE DIGIT *)
      IF Index <= Identlength THEN 
         Id[Index] := Ch;                (* ADD TO SYMBOL NAME FOR LABELS*)
      Nextch;                            (* READ THE NEXT CHAR *)
      END;
   IF (Ch <> '.') AND (Ch <> 'E') THEN    (*REAL NUMBER*)
      Sy := Intconstsy
   ELSE
         BEGIN (* real or integer,range *)
         Sy:=Realconstsy;                 (* INDICATE SYMBOL TYPE *)
         IF (Ch = '.') THEN
            BEGIN                         (* EXPLICIT FRACTION *)
            Nextch;                       (* SKIP THE POINT *)
            IF Ch = '.' THEN
               BEGIN                      (* THIS IS INTEGER W/.. *)
               Sy:=Intconstsy;            (* MAKE SURE THIS IS PARSED AS INT *)
               Rangenext := True;         (* PSEUDO OP FOR RANGE *)
               END                        (* END OF THIS IS INTEGER W/.. *)
            ELSE                          (* THERE IS A SINGLE POINT *)
	       BEGIN
	       IF Index = 1 THEN
		  BEGIN
		  Index := Index + 1;
		  Val.Chars[Index] := '0';
		  END;
	       Index := Index + 1;
	       Val.Chars[Index] := '.';
               IF Ch IN Digits THEN       (* CHAR AFTER POINT IS NUMERAL *)
                  WHILE Ch IN Digits DO    (* SCAN THROUGH ALL DIGITS *)
                     BEGIN                 (* LOOP THROUGH FRACTION DIGITS *)
                     Index:=Index+1;       (* SYMDIGS POINTER *)
                     IF Index <= Strglgth THEN 
                        Val.Chars[Index] := Ch;
                     (* SAVE THIS DIGIT *)
                     Nextch;
                     END  (* OF LOOP THROUGH FRACTION DIGS*)
               ELSE ERROR (205)               (* DIGIT AFTER POINT NOT NUMERAL*)
	       END;
            END;(* OF EXPLICIT FRACTION *)
         (* AT THIS POINT ALL DIGITS HAVE BEEN SCANNED.  HANDLE A POSSIBLE
            EXPONENT *)
         IF Sy=Realconstsy THEN               (* STILL LOOKS LIKE A REAL # *)
            BEGIN                             (* CHECK REAL FOR EXPONENT *)
            IF Ch = 'E' THEN
               BEGIN                          (* HANDLE EXPLICIT EXPONENT *)
	       Index := Index + 1;
               Val.Chars[Index] := Ch;
               Nextch;                        (* SKIP THE 'E' *)
               IF Ch IN Sign THEN
                  BEGIN                       (* EXPLICIT SIGN *)
                  Index := Index + 1;
                  Val.Chars[Index] := Ch;
                  Nextch                      (* SKIP THE SIGN *)
                  END ;
               IF NOT(Ch IN Digits) THEN 
                  Error(205)  (* NON-NUMERIC EXPONENT *)
               ELSE                           (* EXPONENT IS NUMERIC *)
                  REPEAT                      (* LOOP THROUGH EXPONENT DIGITS *)
                     Index := Index + 1;
                     Val.Chars[Index] := Ch;
                     Nextch;
                  UNTIL NOT(Ch IN Digits);
               (* NON-NUMERIC DELIMITS EXPONENT *)
               END;(* OF EXPLICIT EXPONENT *)
            Val.Len := Index;
            END
        END;(* real or integer,range *)
   IF Sy = Intconstsy THEN
      BEGIN                  
      Tempival := 0;
      FOR K := 2 TO Index DO
         IF -Tempival <= Tgtmaxint DIV 10 THEN
            BEGIN
            IF (-Tempival = Maxintdiv10) THEN
               BEGIN
               IF Ord (Val.Chars[K]) - Ord('0') > Tgtmaxint MOD 10 THEN
                  BEGIN Error(204); Tempival := 0 END
               END;
            Tempival := 10*Tempival - (Ord(Val.Chars[K]) - Ord('0'));
            END
         ELSE
            BEGIN
            Error(204); Tempival := 0
            END;
      IF Val.Chars[1] <> '-' THEN
         Tempival := - Tempival;
      Val.Ival := Tempival
      END                     
   END;  (* number *)


(*Insymbol*)

   BEGIN   (*INSYMBOL*)
   111:
   IF Sy = Eofsy THEN  
	 BEGIN
	 Writeln (Output);
	 Writeln (Output, 'Compiler error: reading past end of file...');
	 Quit;
	 END;
   WHILE (Ch = ' ') AND (Sy <> Eofsy) DO  (*SKIP BLANKS*)
      Nextch;
   Symmarker := Chptr;  
   IF Sy = Eofsy THEN  
      BEGIN
      IF InIncludefile THEN 
	 BEGIN
         Popfile;
	 Sy := Othersy;
	 GOTO 111;
	 END
      END
   ELSE IF Rangenext THEN
         BEGIN
         Sy := Rangesy;
         Nextch;
         Rangenext := False;
         END
      ELSE IF NOT (Ch IN Syminitchars) THEN
         BEGIN (* simple one-character symbols *)
	 IF (Ch >= Firstchar) AND (Ch <= Lastchar) THEN
            Sy := Ssy[Ch]
	 ELSE
            Sy := Othersy;
         Nextch
         END
      ELSE 
         CASE Ch OF

            '{':  
               BEGIN
               Skipcomment ('{', '}'); GOTO 111;
               END;

            '%':  
               BEGIN
               Skipcomment ('%', '\'); GOTO 111;
               END;

            '(':                           (*MIGHT BE A COMMENT*)
               BEGIN
               Nextch;
               IF Ch = '*' THEN
                  BEGIN
                  Skipcomment ('(', ')'); GOTO 111;
                  END
               ELSE IF Ch = '/' THEN    
                  BEGIN Sy := Lbracksy; Nextch END
               ELSE
                  Sy := Lparentsy
               END;

            '/':                          
               BEGIN
               Nextch;
               IF Ch = ')' THEN
                  BEGIN Sy := Rbracksy; Nextch; END
               ELSE
                  Sy := Rdivsy
               END;

            'A','B','C','D','E','F','G','H','I','J','K','L','M',
            'N','O','P','Q','R','S','T','U','V','W','X','Y',
            'Z','$':                                   (*IDENTIFIER*)

               (* THE $ IS NON-STANDARD, AND IS USED TO COMPILE RUNTIMES, SO
                THAT THE RUNTIMES WILL HAVE NON-STANDARD NAMES.  *)

               BEGIN
               K := 0 ; Id := '                ';
               REPEAT
                  IF K < Identlength THEN
                     BEGIN
                     K := K + 1; Id[K] := Ch
                     END ;
                  Nextch
               UNTIL  NOT (Ch IN Lettersdigitsorleftarrow);

               (* SEE IF IT IS A RESERVED WORD -- COMPARE WITH ALL RESERVED
                WORDS OF THE SAME SIZE *)
               IF K <= 9 THEN
                  FOR I := Frw[K] TO Frw[K+1] - 1 DO
                     IF Rw[I] = Id THEN
                        BEGIN
                        Sy := Rsy[I];
                        GOTO 222
                        END;
               FOR K := Maxidlength+1 TO Identlength DO
                  Id[K] := ' ';
               Sy := Identsy;
   222:
	       IF Sy = Includesy THEN
		  BEGIN
		  Incfilename := Blankfilename;
		  WHILE Ch = ' ' DO Nextch;
		  IF Ch <> '''' THEN
		     Error (264) (* string constant expected *)
		  ELSE
		     BEGIN
		     I := 1;
		     Nextch;
		     Readingstring := True;
		     While Ch <> '''' DO
	                BEGIN
		        IF I <= Filenamelen THEN Incfilename[I] := Ch;
			I := I + 1;
		        Nextch;
		        END;
		     Readingstring := False;
		     Nextch;  While Ch = ' ' DO Nextch;
		     IF Ch <> ';' THEN 
		        Warning (156)
		     ELSE Nextch;
		     IF InIncludefile THEN
			Error (454) (* only one level of Include files supported *)
		     ELSE Pushfile (Incfilename);
	             GOTO 999;
		     END
		  END;

               END;
            '0','1','2','3','4','5','6','7','8','9': 
               NUMBER;  (* numeric constant *)

            '''':                  (*STRING CONSTANT*)
               BEGIN
               Lgth := 0; Sy := Stringconstsy; Stringtoolong := False;
               REPEAT
                  BEGIN (* GET UP TO NEXT QUOTE *)
                  Readingstring := True;
                  REPEAT
                     Nextch;
                     IF Lgth <= Strglgth THEN
                        BEGIN
                        Lgth := Lgth + 1;
                        IF Lgth <= Strglgth THEN
                           String[Lgth] := Ch
                        END
                     ELSE
                        Stringtoolong := True
                  UNTIL (Chptr = Chcnt) OR (Ch = ''''); 
                  IF Stringtoolong THEN
                     Error(301);
                  Readingstring := False;
                  IF Ch <> '''' THEN
                     Error(351)
                  ELSE
                     Nextch;
                  END (* GET UP TO NEXT QUOTE *)
               UNTIL Ch <> '''';
               Lgth := Lgth - 1;
               IF Lgth = 1 THEN
                  Val.Ival := Ord(String[1])
               ELSE
                  BEGIN
                  WITH Val DO
                     BEGIN
                     Len := Lgth;
                     Chars := String;
                     END;
                  END
               END;
            ':':                   (*COLON OR ASSIGNMENT*)
               BEGIN
               Nextch;
               IF Ch = '=' THEN
                  BEGIN
                  Sy := Becomessy; Nextch
                  END
               ELSE
                  Sy := Colonsy
               END;
            '.':                   (*ONE PERIOD OR TWO*)
               BEGIN
               Nextch;
               IF Ch = '.' THEN
                  BEGIN
                  Sy := Rangesy; Nextch   
                  END
               ELSE
                  Sy := Periodsy
               END;
            '<','>':               (*< OR <> OR <=, > OR >=*)
               BEGIN
               Sy := Ssy[Ch]; Nextch;
               IF (Sy=Ltsy) AND (Ch='>') THEN
                  BEGIN
                  Sy := Nesy; Nextch
                  END
               ELSE
                  IF Ch = '=' THEN
                     BEGIN
                     IF Sy = LtSy THEN
                        Sy := LeSy
                     ELSE
                        Sy := GeSy;
                     Nextch
                     END
               END;
            END (*CASE*);
   Firstsymbol := False;
   Symcnt := Symcnt + 1;
   999:
   END (*INSYMBOL*) ;



(*Block,Remap*)

PROCEDURE Block(Fprocp: Idp; Fsys,Leaveblocksys: Setofsys);
   (*parses the block that forms the program or a procedure/function*)
   TYPE
      Marker = ^Integer;
   VAR
      Lsy: Symbol;
      Remapped: Boolean;
      Heapmark: Marker;
      Forwardprocedures: Idp;
      RegReflist: LocalIdP;
      Regsmemcnt: Integer;
      Regtempaddr: Integer;        (*addr of temp allocated to register*)

(************************************************************************)
(*                                                                      *)
(*      REMAP -- combines F and M memory into M memory                  *)
(*                                                                      *)
(*      Initially all large objects are mapped into M memory            *)
(*      and simple objects into F memory.  This is done to make         *)
(*      simple objects easier to address and to make sure that memory   *)
(*      is allocated in the parameter area only for the addresses of    *)
(*      large objects, not the objects themselves.  Remap combines      *)
(*      the two memory types by copyng the objects in F memory into     *)
(*      the front of M memory.                                          *)
(*                                                                      *)
(************************************************************************)

   PROCEDURE Remap (Fidp: Idp);

      VAR
         Moffset: Addrrange;
         

      PROCEDURE RemapId (Varidp: Idp);
         VAR Tptr: Localidp;
         BEGIN
	 WITH Varidp^ DO
	    BEGIN
	    IF Llink <> NIL THEN RemapId (Llink);
	    IF Rlink <> NIL THEN RemapId (Rlink);
	    IF Klass = Vars THEN
	       BEGIN
   	       IF Vmty <> Smt THEN Vblock := Fidp^.Pfmemblock;
	       IF Vmty = Mmt THEN
		  BEGIN
		  Vaddr := Moffset + Vaddr;
		  IF Idtype <> NIL THEN
		     IF (Idtype^.Stdtype = Mdt) OR 
			(Idtype^.Stsize > Parthreshold) THEN
			   IF Vindtype = Fmt THEN Vindtype := Mmt;
		  END
	       ELSE 
		  BEGIN 
                  IF Vmty = Fmt THEN 
		     BEGIN
		     Vmty := Mmt;
		     IF (Vaddr >= Minlocreg) AND (Vaddr <= Maxlocreg) THEN
			BEGIN
			New (Tptr);
			Tptr^.Mainrec := Varidp;
		        Tptr^.Next := Regreflist;
			Regreflist := Tptr;
		        END
		     END
		  END
	       END (* vars *)
	    ELSE IF (Klass IN [Proc,Func]) THEN
	       IF Pfkind = Formal THEN
		  BEGIN
		  Pfblock := Fidp^.Pfmemblock;
		  IF Pfmty = Fmt THEN
		     Pfmty := Mmt;
	          END;
            END;
         END (* RemapId *);

      BEGIN (*remap*)
      IF Localsbackwards THEN
         BEGIN
         Rounddown (Memcnt[Fmt], SpAlign);
         Rounddown (Memcnt[Mmt], SpAlign);
         END
      ELSE
         BEGIN
         Roundup (Memcnt[Fmt], SpAlign);
         Roundup (Memcnt[Mmt], SpAlign);
         END;
      IF (Localsinregs = 0) OR (Memcnt[Fmt] = 0) THEN 
         Maxlocreg := -1
      ELSE 
	 IF Abs(Memcnt[Fmt]) > Localsinregs * Regsize THEN
	    Maxlocreg := Localsinregs * Regsize - Regsize
	 ELSE
	    Maxlocreg := Abs(Memcnt[Fmt]) - Regsize;
      IF Localsbackwards THEN
	 BEGIN
	 Regsmemcnt := -Maxlocreg - Regsize;
	 Maxlocreg := -Minlocreg - Regsize;
	 Minlocreg := Regsmemcnt;
         END;

      Regsmemcnt := Memcnt[Fmt];
      IF Fidp <> NIL THEN
         WITH Fidp^ DO            
            (*if a function, remap the result.*)
            IF Klass = Func THEN
               IF Resmemtype = Fmt THEN
                  Resmemtype := Mmt;

      (*calculate the offset of M memory *)
      Moffset := Memcnt[Fmt];
      Memcnt[Mmt] := Memcnt[Fmt] + Memcnt[Mmt];

      IF Display[Level].Fname <> NIL THEN
         RemapId (Display[Level].Fname);

      Memcnt[Fmt] := 0;
      END (*remap*);
(*Getbounds,String,Comptypes,Constant*)

   PROCEDURE Getbounds(Fstrp: Strp; VAR Fmin, Fmax: Integer);
      FORWARD;

   FUNCTION String(Fstrp: Strp) : Boolean;
      FORWARD;

(************************************************************************)
(*                                                                      *)
(*      COMPTYPES -- decides whether two types are compatible           *)
(*                                                                      *)
(*      According to the standard:                                      *)
(*                                                                      *)
(*     Two types shall be designated compatible if they are  identical, *)
(*     or  if  one is a subrange of the other, or if both are subranges *)
(*     of the same type, or if they are  string  types  with  the  same *)
(*     number  of  components,  or  if they are set-types of compatible *)
(*     base-types.                                                      *)
(*                                                                      *)
(************************************************************************)

   FUNCTION Comptypes(Fstrp1,Fstrp2: Strp) : Boolean;

      BEGIN (*comptypes*)
      IF Fstrp1 = Fstrp2 THEN
         Comptypes := True
      ELSE
         IF (Fstrp1 <> NIL) AND (Fstrp2 <> NIL) THEN
            IF Fstrp1^.Form = Fstrp2^.Form THEN
               CASE Fstrp1^.Form OF
                  Records, Files, Scalar:         
                     Comptypes := False;
                  Pointer:
                     Comptypes := (Fstrp1 = Nilptr) OR (Fstrp2 = Nilptr);
                  Subrange:
                     Comptypes := Comptypes(Fstrp1^.Hosttype,Fstrp2^.Hosttype);
                  Power:
                     Comptypes := Comptypes(Fstrp1^.Basetype,Fstrp2^.Basetype);
                  Arrays:
                     IF String (Fstrp1) AND String (Fstrp2) THEN 
                        IF (Fstrp1^.Inxtype = NIL) OR 
                           (Fstrp2^.Inxtype = NIL) THEN
                              Comptypes := True
                        ELSE Comptypes := Fstrp1^.Arraypf AND Fstrp2^.Arraypf 
                           AND (Fstrp1^.Inxtype^.Vmax.Ival =
                                Fstrp2^.Inxtype^.Vmax.Ival)
                     ELSE
                        Comptypes := False;
                  END (*case fstrp1^.form of*)
            ELSE
               (*fstrp1^.form <> fstrp2^.form*)
               IF Fstrp1^.Form = Subrange THEN
                  Comptypes := Comptypes(Fstrp1^.Hosttype,Fstrp2)
               ELSE IF Fstrp2^.Form = Subrange THEN
                  Comptypes := Comptypes(Fstrp1,Fstrp2^.Hosttype)
               ELSE
                  Comptypes := False
         ELSE    (*if one of them is nil, they are compatible*)
            Comptypes := True;
      END (*comptypes*) ;

(************************************************************************)
(*                                                                      *)
(*      GETBOUNDS -- given a pointer to a subrange or scalar type,      *)
(*                   returns upper and lower bounds                     *)
(*                                                                      *)
(************************************************************************)

   PROCEDURE Getbounds;    (* (fstrp: strp; var fmin, fmax: integer) *)

      (* given a pointer to a subrange or scalar type, return upper
         and lower bounds in fmin and fmax *)

      BEGIN (*getbounds*)
      Fmin := 0; Fmax := 0;
      IF Fstrp <> NIL THEN
         IF Fstrp = Intptr THEN
            BEGIN (* type integer = minint..maxint *)
            Fmin := -Maxint ;
            Fmax := Maxint
            END
         ELSE IF (Fstrp^.Form <= Subrange) AND NOT Comptypes(Realptr,Fstrp) THEN
               WITH Fstrp^ DO
                  IF Form = Subrange THEN
                     BEGIN
                     Fmin := Vmin.Ival;
                     Fmax := Vmax.Ival
                     END
                  ELSE (* scalar *)
                     IF (Fstrp = Charptr) THEN
                        BEGIN
                        Fmin := TgtfirstChar;
                        Fmax := TgtlastChar;
                        END
                     ELSE IF (Scalkind=Declared) THEN
                        Fmax := Dimension
                     ELSE Error (171); (* compiler error *)

      END (*getbounds*) ;

(************************************************************************)
(*                                                                      *)
(*      STRING -- returns true if Fstrp describes a packed array of     *)
(*                char whose lower index is 1                           *)
(*                                                                      *)
(************************************************************************)

   FUNCTION String  (* (fstrp: strp) : boolean *) ;
      (* returns true if fstrp describes a packed array of char *)
      BEGIN (*string*)
      String := False;
      IF Fstrp <> NIL THEN  
         IF Fstrp^.Form = Arrays THEN
            IF Fstrp^.Inxtype <> NIL THEN
               String := (Fstrp^.Aeltype = Charptr) AND
               (Fstrp^.Inxtype^.Stdtype IN [Jdt,Ldt]) AND
               (Fstrp^.Inxtype^.Vmin.Ival = 1);
      END (*string*) ;




(************************************************************************)
(*                                                                      *)
(*      CONSTANT -- parses a constant                                   *)
(*                                                                      *)
(*      The value is returned in FVALU and the type in FSTRP            *)
(*                                                                      *)
(************************************************************************)

   PROCEDURE Constant(Fsys: Setofsys; VAR Fstrp: Strp; VAR Fvalu: Valu);
      VAR
         Lstrp, Lstrp1: Strp;
         Lidp: Idp;

      BEGIN (*constant*)
      Lstrp := NIL; Fvalu.Ival := 0;
      Skipiferr(Constbegsys,207,Fsys);
      IF Sy IN Constbegsys THEN
         BEGIN
         IF Sy = Stringconstsy THEN                    (*string constant*)
            BEGIN
            IF Lgth = 1 THEN
               Lstrp := Charptr
            ELSE  (*not a predefined length*)
               BEGIN
               New(Lstrp1,Subrange);
               WITH Lstrp1^ DO
                  BEGIN
                  Form := Subrange; Marker := 0;
                  Stsize := Intsize; Packsize := Intsize; Stdtype := Jdt;
                  Vmin.Ival := 1; Vmax.Ival := Lgth; Hosttype  := Intptr;
                  Hasholes := False; Hasfiles := False;
                  END;
               New(Lstrp,Arrays);
               WITH Lstrp^ DO
                  BEGIN
                  Form := Arrays; Marker := 0;
                  Aeltype := Charptr; Inxtype := Lstrp1;  Stdtype := Mdt;
                  Arraypf := True; Aelsize := Pcharsize;
                  Packsize := Stringsize (Lgth);
                  Stsize := Packsize;
                  Hasholes := Lgth * Pcharsize <> Packsize;
                  Hasfiles := False;
                  END;
               END (*others*);
            Fvalu := Val; Insymbol
            END
         ELSE    (*sy <> stringconstsy*)
            BEGIN
            Lastsign := None;                         (*parse a +- sign*)
            IF Sy in [Plussy,Minussy] THEN
               BEGIN
               IF Sy = Plussy THEN
                  Lastsign := Pos
               ELSE
                  Lastsign := Neg;
               Insymbol
               END;
            IF Sy = Identsy THEN                      (*constant idname*)
               BEGIN
               Searchid([Konst],Lidp);
               WITH Lidp^ DO
                  BEGIN
                  Lstrp := Idtype; Fvalu := Values;
                  Referenced := True; 
                  END;
               IF Lastsign <> None THEN
                  IF Lastsign = Neg THEN
                     WITH Fvalu DO
                        IF Lstrp = Intptr THEN
                           Ival := -Ival
                        ELSE IF Lstrp = Realptr THEN
                           Chars[1] := '-'
                        ELSE Error(167)
                  ELSE IF Lstrp^.Form <> Scalar THEN
                        Error(167);
               Insymbol
               END     (*if sy = identsy*)
            ELSE                     (*number*)
               IF Sy IN [Intconstsy,Realconstsy] THEN
                  BEGIN
                  IF Sy = Intconstsy  THEN
                     Lstrp := Intptr
                  ELSE
                     Lstrp := Realptr;
                  Fvalu := Val;
                  Insymbol;
                  END  (*sy in [intconstsy, ...]*)
               ELSE    (*invalid constant*)
                  Errandskip(168,Fsys)
            END (*sy <> stringconstsy*);
         Iferrskip(166,Fsys);
         END     (*if sy in constbegsys*);
      Fstrp := Lstrp;
      END (*constant*) ;


(*Prntsym*)
   PROCEDURE Prntsymbol(fidp:idp);

      (* Prints a symbol in the symbol table file.  The format is given in the
         debugger document.  Every type is only printed once.  It is given a 
         number when it is printed, which is stored in its Id record in Marker.
         When the type is encountered later, only that number is printed *) 


      FUNCTION Newtag(p: strp): boolean;

         (*  If this type has never been encountered before, associate
             a tag with it, print that tag and return TRUE.  If it
             has been seen before print its tag and return FALSE. *)

         BEGIN
         IF p^.Marker = 0 THEN
            BEGIN
            p^.Marker := lastMarker;
            Write(Symtbl, '<', lastMarker:1, '> ');
            lastMarker := lastMarker + 1;
            Newtag := true;
            END
         ELSE
            BEGIN
            Write(Symtbl, '<', p^.Marker:1, '> ; ');
            Newtag := false;
            END
         END;
         (* PSEARCH *)



      PROCEDURE Prnttype(typp:strp);

         VAR
            vp: idp; wp: strp; min, max, i: integer;


         BEGIN
         IF typp <> NIL THEN
            CASE typp^.form OF

               subrange:
                         IF typp^.Hosttype <> NIL THEN
                            BEGIN
                            getbounds(typp, min, max);
                            Write(Symtbl,'U ',min:1,' ',max:1,
                                  ' ');
                            IF Newtag(typp^.Hosttype) THEN
                               Prnttype(typp^.Hosttype);
                            Write(Symtbl, '; ');
                            END;

               scalar: 
 
                  IF Typp^.Scalkind = Standard THEN
                     Write (Symtbl,GetDtyname(Typp^.Stdtype),'; ')
                  ELSE if typp = Boolptr THEN
                     Write (Symtbl,'B; ')
                  ELSE
                     BEGIN
                     Write(Symtbl, 'X ');
                     getbounds(typp, min, max);
                     Write(Symtbl, max:1, ' ');
                     vp := typp^.fconst;
                     FOR i :=min TO max DO
                        BEGIN
                        if (i+1) mod 10 = 0 then writeln (symtbl);
                        Write(Symtbl,vp^.Idname:Idlen(vp^.Idname),' ');
                        vp := vp^.next
                        END;
                     Write(Symtbl, '; ')
                     END;

               pointer:  IF typp^.eltype <> NIL THEN
                            BEGIN
                            Write(Symtbl, 'P ');
                            IF Newtag(typp^.eltype) THEN
                               Prnttype(typp^.eltype);
                            Write(Symtbl, '; ');
                            END;

               power:   IF typp^.Basetype <> NIL THEN
                           BEGIN
                           Write(Symtbl, 'S ');
                           with typp^ do
                             Write(Symtbl, softmin:1,' ',
                                   softmax:1, ' ');
                           IF Newtag(typp^.Basetype) THEN
                              Prnttype(typp^.Basetype);
                           Write(Symtbl, '; ');
                           END;

               files:   IF typp^.Filetype <> NIL THEN
                           BEGIN
                           Write(Symtbl, 'F ');
                           IF Newtag(typp^.Filetype) THEN
                              Prnttype(typp^.Filetype);
                           Write(Symtbl, '; ');
                           END;

               records: 
                           BEGIN
                           Write(Symtbl,'D ',
                                 Typp^.Packsize:1);
                           vp := typp^.Recfirstfield;
                           (* check for no-fixed-fields kludge *)
                           if typp^.recvar <> nil then
                              if typp^.recvar^.fstvar <> nil then
                                 if typp^.recvar^.fstvar^.varfirstfield = vp 
                                    then vp :=  NIL;
                           WHILE vp <> NIL DO
                              BEGIN
                              Writeln(Symtbl);
                              Write(Symtbl, ' ! ');
                              Write(Symtbl,vp^.Idname:Idlen(vp^.Idname),' ');
                              Write(Symtbl,vp^.fldaddr:1,' ');
                              IF Vp^.Idtype <> NIL THEN
                                 IF Vp^.Inpacked THEN
                                    Write(Symtbl,Vp^.Idtype^.Packsize:1,' ')
                                 ELSE
                                    Write(Symtbl,Vp^.Idtype^.Stsize:
                                          1,' ');
                              IF Newtag(vp^.idtype) THEN
                                Prnttype(vp^.idtype);
                              vp := vp^.next;
                              END;
                           IF typp^.recvar <> NIL THEN
                              Prnttype(typp^.recvar);
                           Writeln(Symtbl);
                           Write(Symtbl,' . ; ');
                           END;

               tagfwithid,tagfwithoutid:   
                       IF typp^.tagfieldp <> NIL THEN
                            BEGIN
                            Writeln(Symtbl);
                            Write(Symtbl, ' ? ');
                            IF Typp^.form = Tagfwithid THEN
                               BEGIN
                               Write(Symtbl,Typp^.tagfieldp^.idname:
                                     Idlen(Typp^.tagfieldp^.idname),' ');
                               Write(Symtbl,typp^.tagfieldp^.fldaddr:
                                       1,' ');
                               wp := typp^.tagfieldp^.idtype;
                               if wp <> nil then
                                 IF Newtag(wp) THEN Prnttype(wp);
                               END
                            ELSE
                               BEGIN
                               Writeln(Symtbl);
                               Write(Symtbl, ' & ');
                               IF typp^.Tagfieldtype <> NIL THEN
                                  IF Newtag(typp^.Tagfieldtype) THEN
                                     Prnttype (typp^.Tagfieldtype);
                               END;
                            wp := typp^.fstvar;
                            WHILE wp <> NIL DO
                               BEGIN
                               Writeln (Symtbl);
                               Write(Symtbl,'  ( ',wp^.varval.ival:
                                            1,' : ');
                               vp := wp^.varfirstfield;
                               WHILE vp <> NIL DO
                                  BEGIN
                                  writeln (symtbl);
                                  Write(Symtbl, '  ! ');
                                  Write(Symtbl,vp^.Idname:Idlen(vp^.Idname),
                                        ' ');
                                  Write(Symtbl,vp^.fldaddr:1,
                                        ' ');
                                  IF Newtag(vp^.idtype) THEN
                                    Prnttype(vp^.idtype);
                                  vp := vp^.next;
                                  END;
                               IF wp^.subvar <> NIL THEN
                                  Prnttype(wp^.subvar);
                               Writeln(Symtbl);
                               Write(Symtbl, '  . ) ');
                               wp := wp^.nxtvar;
                               END;
                            END;

               arrays:  IF (typp^.inxtype<> NIL) AND (typp^.aeltype <> NIL) THEN
                           BEGIN
                           Write(Symtbl,'A ',typp^.aelsize:1,
                                 ' ');
                           IF Newtag(typp^.inxtype) THEN
                              Prnttype(typp^.inxtype);
                           IF Newtag(typp^.aeltype) THEN
                              Prnttype(typp^.aeltype);
                           Write(Symtbl, '; ');
                           END;

               END (*CASE FORM OF...*) ;

         END;
         (* PRNTTYPE *)


      BEGIN   (* Prntsymbol *)
        With Fidp^ DO
         CASE klass OF
            vars:  BEGIN
               writeln (symtbl);
               Write(Symtbl, 'V ');
               IF vkind = formal THEN
                  Write(Symtbl,'^ ')
               ELSE
                  Write(Symtbl,'$ ');
               Write(Symtbl,Idname:Idlen(Idname),' ',Getmtyname(Vmty),' ',
                     vblock:1,' ',vaddr:1,' ');
               IF idtype <> NIL THEN
                  IF Newtag(idtype) THEN
                     Prnttype(idtype);
               END;


            proc,func:  
               if pfkind <> actual then
                  begin
                  writeln(symtbl);
                  Write (Symtbl,' V ',GetMtyname(Pfmty),' ',
                           Pfaddr:7,' ',Idname);
                  Lastmarker := Lastmarker + 1;
                  writeln (Symtbl,'<',Lastmarker:1,'>','E;');
                  end;
            konst:   
                  begin
                  writeln (symtbl);
                  Write(Symtbl, 'K ');
                  Write(Symtbl,Idname:Idlen(Idname),' ');
                  Write(Symtbl,values.ival:1, ' ; ');
                  end;
            types,field,labels: ;
            END; (* case *)
      END;  (* Prntsymbol *)

(*Inittemps,Zerovars*)

   PROCEDURE Inittemps;

      (* Initializes temporary table.  This must be called AFTER the
         declarations are processed. *)

      BEGIN
      IF Regtempaddr <> 0 THEN
         WITH Temps[1] DO
	    BEGIN
            Size := Intsize;
            Mty := Mmt;
            Offset := Regtempaddr;
	    Free := True;
	    Tempcount := 1;
	    END
      ELSE Tempcount := 0;
      END;

   PROCEDURE Zerovars (Filelist: Idp);
      (* Zeroes out the first two words of files (to mark them as "closed"),
         as well as all of any records
         or arrays that contain holes or files. A list of such variables is
         kept for each procedure.  The variables are zeroed at procedure
         entry if in M memory, or at the beginning of runtime, if files and in  
         S memory, or at load time, if not files and in S memory.  (This is so 
         that files will be marked as "closed" when the program is restarted
         but not reloaded.) *)
      VAR
         Lfileptr: Idp;  
         Zeroval: Valu;
         Lsize: Sizerange;
      BEGIN
      Zeroval.Ival := 0;
      Lfileptr := Filelist;
      WHILE Lfileptr <> NIL DO
         BEGIN
         WITH Lfileptr^ DO
            BEGIN
            (* Lfileptr^.Idtype cannot be NIL, or else wouldn't be on 
               this list *)
            IF Idtype^.Form = Files THEN Lsize := Intsize*2
            ELSE Lsize := Idtype^.Stsize;

            (**** temporarily: zero out S memory variables at load time only *)
         (* IF NOT Idtype^.Hasfiles AND (Vmty = Smt) THEN
               (* zero out holes at load time only * )
               Ucoinit (Jdt, Vaddr, Vaddr+(Lsize-1) DIV Intsize * Intsize,
                        Intsize, Zeroval)
            ELSE 
               (* zero out at runtime * )
               Uco5typaddr (Uzero, Mdt, Vmty, Vblock, Vaddr, Lsize);
          *)

            IF Vmty = Smt THEN
               Ucoinit (Jdt, Vaddr, Vaddr+(Lsize-1) DIV Intsize * Intsize,
                        Intsize, Zeroval)
            ELSE 
               Uco5typaddr (Uzero, Mdt, Vmty, Vblock, Vaddr, Lsize);
            END;

         Lfileptr := Lfileptr^.Next;
         END;
      END;

(*Simpletype,Sizeofsubrange*)

(************************************************************************)
(************************************************************************)
(*                                                                      *)
(*      TYPE DEFINITION MODULE                                          *)
(*                                                                      *)
(*      The main procedure Typedefinition, parses a type definition     *)
(*      and returns a ponter to a structure that describes the          *)
(*      type.                                                           *)
(*                                                                      *)
(*      Principle procedures are:                                       *)
(*                                                                      *)
(*      Simpletype:parses ennumerated types and subranges               *)
(*      Fieldlist: parses a field list for a record, calculating the    *)
(*                 size of the record as it goes                        *)
(*      Typedefinition: parses a pointer, array, record, or set type    *)
(*                      definition                                      *)
(*                                                                      *)
(************************************************************************)
(************************************************************************)


(************************************************************************)
(*                                                                      *)
(*      SIMPLETYPE                                                      *)
(*                                                                      *)
(*         Parses:                                                      *)
(*           1) An ennumerated type of the form (Id1, Id2, ..., Idn)    *)
(*           2) A subrange                                              *)
(*           3) A previously declared type identifier (renaming types)  *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Simpletype(Fsys: Setofsys; VAR Fstrp: Strp);
   (* parses the definition of a nonstructured type. i.e. previously defined
    type, subrange, or ennumerated type (declared scalars) *)
   VAR
      Lstrp: Strp;
      Lidp: Idp;
      Lcnt,Maxval: Integer;
      Lvalu: Valu;

   PROCEDURE Sizeofsubrange(Fstrp: Strp);

      (* FSTRP points to a structure record of form SUBRANGE whose lower
       bound and STSIZE has been filled in.  This procedure parses the upper
       bound, fills it in, an then calculates the packed size for
       the subrange *)
      VAR
         Lstrp: Strp;
         Lvalu: Valu;

      BEGIN (*sizeofsubrange*)
      Constant(Fsys,Lstrp,Lvalu);
      WITH Fstrp^ DO
         IF NOT Comptypes(Hosttype,Lstrp) THEN
            Error(304)
         ELSE
            BEGIN
            Vmax := Lvalu;
            IF Hosttype <> NIL THEN
               CASE Hosttype^.Stdtype OF
                  Bdt:
                     Packsize := Boolptr^.Packsize;
                  Cdt:
                     Packsize := Pcharsize;
                  Jdt,Ldt:
                     BEGIN
                     IF (Vmax.Ival = TgtMaxint)OR (Vmin.Ival <= -TgtMaxint) THEN
                        Packsize := Intsize
                     ELSE IF Vmin.Ival < 0 THEN
                        BEGIN (* signed integer *)
                        IF Vmax.Ival + 1 > -Vmin.Ival THEN
                           Maxval := Vmax.Ival + 1
                        ELSE Maxval := -Vmin.Ival;
                        Packsize := Log2 (Maxval) + 1;
                        END 
                     ELSE (*unsigned integer*)
                        BEGIN
                        Packsize := Log2 (Vmax.Ival+1);
                        Stdtype := Ldt;
                        END;
                     While Packsize MOD Rpackunit > 0 do
                        Packsize := Packsize + 1;
                     END;
                       
                  END (*case hosttype^.stdtype of*)
            END  (*comptypes*);
      END (*sizeofsubrange*);

   PROCEDURE Declscalars (VAR Fstrp: Strp);
      VAR
         Ttop: Disprange;
         Listhead, Listtail, Lidp: Idp;

      (* Parses a list of declared scalars for an ennumerated type).  A   
          Structure record to decribe this type is created and returned, 
          and is added to the global list headed by Declscalarptr *)
      BEGIN
      (* This declaration might be in the middle of a record declaration,
         in which casethe top of the display might point to the record.
         But we want the declared scalars to be entered as local identifiers,
         so we must temporarily pop the stack back down to that level. *)
      Ttop := Top;
      WHILE Display[Top].Occur <> Blck DO Top := Top - 1;
      New(Fstrp,Scalar,Declared);
      Listhead := NIL; 
      Lcnt := 0;
      REPEAT
         (* Get next declared scalar *)
         Insymbol;
         New(Lidp,Konst);
         IF Sy = Identsy THEN
            BEGIN
            IF Listhead = NIL THEN Listhead := Lidp
            ELSE Listtail^.Next := Lidp;
            WITH Lidp^ DO
               BEGIN
               Klass := Konst;
               Idname := Id; Idtype := Fstrp;
               Values.Ival := Lcnt;
               Referenced := True;
               END;
            Enterid(Lidp);
            Lcnt := Lcnt + 1;
            Insymbol
            END
         ELSE
            Error(209);
         Iferrskip(166,Fsys + [Commasy,Rparentsy]);
         Listtail := Lidp
      UNTIL Sy <> Commasy;
      Listtail^.Next := NIL;
      Top := Ttop;  (* restore display *)

      WITH Fstrp^ DO
         BEGIN
         Form := Scalar; Scalkind := Declared; Marker := 0;
         Fconst := Listhead; Stsize := Intsize; Saddress := -1;
         Packsize := Log2(Lcnt);
         Hasholes := False; Hasfiles := False;
         While Packsize MOD Rpackunit > 0 do
            Packsize := Packsize + 1;
         Stdtype := Ldt;
         Dimension := Lcnt - 1;
         Tlev := Level;
         END;
      IF Sy = Rparentsy THEN
         Insymbol
      ELSE
         Warning(152)  
      END; (* Declscalars *)

   BEGIN (*simpletype*)
   Skipiferr(Simptypebegsys,208,Fsys);
   IF NOT (Sy IN Simptypebegsys) THEN
      Fstrp := NIL
   ELSE
      BEGIN
      IF Sy = Lparentsy THEN  
         DeclScalars (Fstrp) (* ennumerated type *)
      ELSE
         BEGIN
         IF Sy = Identsy THEN
            BEGIN
            Searchid([Types,Konst],Lidp);
            Insymbol;
            IF Lidp^.Klass = Konst THEN         
               BEGIN  (*subrange delimited by a named constant*)
               (* create record to describe the subrange and fill in Vmin *)
               New(Fstrp,Subrange);
               WITH Fstrp^, Lidp^ DO
                  BEGIN
                  Referenced := True; 
                  Form := Subrange;  Marker := 0;
                  Hasholes := False; Hasfiles := False;
                  IF String(Idtype) OR (Idtype = Realptr) THEN
                        BEGIN
                        Error(303); Idtype := NIL;
                        END
                  ELSE
                        Hosttype := Idtype;
                  Vmin := Values; Stsize := Intsize;
                  IF Idtype <> NIL THEN
                     Stdtype := Idtype^.Stdtype;
                  END;
               IF Sy = Rangesy THEN  
                  Insymbol
               ELSE
                  Error(151);
               Sizeofsubrange(Fstrp);  (* get vmax and compute size *)
               END
            ELSE                       (* renaming types *)
               BEGIN
               Fstrp := Lidp^.Idtype;
               Lidp^.Referenced := True;  
               END;
            END (*sy = identsy*)
         ELSE
            BEGIN                      (*subrange delimited by constant values*)
            New(Fstrp,Subrange);
            Constant(Fsys + [Rangesy],Lstrp,Lvalu);  
            IF String(Lstrp) THEN
               BEGIN
               Error(303); Lstrp := NIL
               END;
            WITH Fstrp^ DO
               BEGIN
               Form := Subrange;  Marker := 0;
               Hasholes := False; Hasfiles := False;
               Hosttype := Lstrp; Vmin := Lvalu; Stsize := Intsize;
               IF Lstrp <> NIL THEN
                  Stdtype := Lstrp^.Stdtype;
               END;
            IF Sy = Rangesy THEN  
               Insymbol
            ELSE
               Error(151);
            Sizeofsubrange(Fstrp);
            END;
         IF Fstrp <> NIL THEN (*check that Vmin <= Vmax*)
            WITH Fstrp^ DO
               IF Form = Subrange THEN
                  IF Hosttype <> NIL THEN
                        IF Vmin.Ival > Vmax.Ival THEN
                           Error(451)
         END;
      Iferrskip(166,Fsys)
      END
   END (*simpletype*) ;



(*Fieldlist,Recsection*)

(************************************************************************)
(*                                                                      *)
(*      FIELDLIST -- parses the list of fields in the definition of a   *)
(*                   record or one of its variants                      *)
(*                                                                      *)
(*      On return, Ffirstfield points to the list of fields for the     *)
(*      fixed part of the record, and Tagstrp points to the Tagwithid   *)
(*      or the Tagwithoutid for the variant part. Recsize is the        *)
(*      size of the record.  It also acts as a counter, and MUST be     *)
(*      initialized by the calling procedure.                           *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Typedefinition(Fsys: Setofsys; VAR Fstrp: Strp); FORWARD;

PROCEDURE Fieldlist(Fsys: Setofsys; Packflag: Boolean; VAR Tagstrp: Strp; 
                    VAR Ffirstfield: Idp; VAR Recsize: Integer; 
                    VAR FHoles,FFiles: Boolean);
   LABEL
      555;
   VAR
      Lidp,Tagidp,Sametypelist,Lastfield: Idp;
      Minsize,Maxsize: Sizerange;
      Caselisthead, Caselisttail, Sametypehead, Lstrp, Tagtype, 
         Lsubvarlist: Strp;
      Lvalu: Valu;
      Lid : Identname ;

   PROCEDURE Recsection( Fidp: Idp);
      (* Allocates memory for the field pointed to by fidp. Increments
         Recsize to reflect the new allocation *)
      VAR
         Size: Integer;
         Oldrecsize: Integer;
      BEGIN (*recsection*)
      Oldrecsize := Recsize;
      IF Fidp^.Idtype <> NIL THEN 
         BEGIN
         IF NOT Packflag or NOT Pack THEN
            BEGIN
            Size := Fidp^.Idtype^.Stsize;
            Alignobject (Recsize, Size, RecAlign);
            END
         ELSE
            BEGIN
            Size := Fidp^.Idtype^.Packsize;
            (* pack records no closer than specified *)
            Alignobject (Recsize, Size, Rpackunit);
            END;
	 (* If record or array, make sure it begins on an addrunit boundary. *)
         IF Fidp^.Idtype^.Stdtype = Mdt THEN (** 10MAR *)
            Alignobject (Recsize, Size, Addrunit);
         Fholes := Fholes OR (Oldrecsize <> Recsize);
         Fidp^.Inpacked := Packflag;
         Fidp^.Fldaddr := Recsize;
         Recsize := Recsize + Size;
         END  (* idtype <> nil *)
      END (*recordsection*) ;

   BEGIN   (* fieldlist *)

   (***************************************************************)
   (*                                                             *)
   (*     FIRST PART -- get the fixed parts of the record         *)
   (*                                                             *)
   (***************************************************************)

   Ffirstfield := NIL;
   WHILE Sy = Semicolonsy DO
      Insymbol;
   Skipiferr(Fsys + [Identsy,Casesy],452,Fsys);
   (* a fieldlist consists of an arbitrary number of fixed parts followed
    by AT MOST one case variant *)
   WHILE Sy = Identsy DO     (*for each field*)
      BEGIN
      Sametypelist := NIL;
      (* get a list of IDs separated by commas *)
      (* at the end, Sametypelist points to a backwards chain of IDs *)
      REPEAT
         IF Sy = Commasy THEN Insymbol;
         IF Sy = Identsy THEN
            BEGIN
            New(Lidp,Field);
            WITH Lidp^ DO
               BEGIN
               Klass := Field;
               Idname := Id; Idtype := NIL; Next := NIL
               END;
            IF Ffirstfield = NIL THEN
               Ffirstfield := Lidp
            ELSE
               Lastfield^.Next := Lidp;
            IF Sametypelist = NIL THEN
               Sametypelist := Lidp;
            Lastfield := Lidp;
            Enterid(Lidp);
            Insymbol
            END
         ELSE
            Error(209);
         Skipiferr([Commasy,Colonsy],166,Fsys + [Semicolonsy,Casesy]);
      UNTIL Sy <> Commasy;
      IF Sy = Colonsy THEN
         Insymbol
      ELSE
         Error(151);
      (* parse the type definition for this field; return in LSTRP *)
      Typedefinition(Fsys + [Casesy,Semicolonsy],Lstrp);
      IF Lstrp <> NIL THEN
         BEGIN
         FHoles := FHoles OR Lstrp^.Hasholes;
         FFiles := FFiles OR Lstrp^.Hasfiles;
         END;
      (* hang the type descriptor from all the identifiers
       and allocate memory space for them *)
      WHILE Sametypelist <> NIL DO
         BEGIN
         Sametypelist^.Idtype := Lstrp;
         Recsection(Sametypelist);
         Sametypelist := Sametypelist^.Next;
         END;

      WHILE Sy = Semicolonsy DO
         BEGIN
         Insymbol;
         Skipiferr(Fsys + [Identsy,Casesy,Semicolonsy],452,Fsys);
         END;
      END (*while: for each field*);

   (***************************************************************)
   (*                                                             *)
   (*     SECOND PART -- get the variant part of the record       *)
   (*                                                             *)
   (***************************************************************)

   IF Sy <> Casesy THEN  (*parse the variant part*)
      Tagstrp := NIL
   ELSE
      BEGIN   (*tagfield and tag type*)
      Tagidp := NIL;             (*possibility of no tagfield identifier*)
      Insymbol;
      IF Sy <> Identsy THEN
         Errandskip(209,Fsys + [Lparentsy]) 
      ELSE
         BEGIN (* tagfield name and case list type *)
         Lid := Id ;
         Insymbol ;
         IF (Sy <> Colonsy) AND (Sy <> Ofsy) THEN
            BEGIN
            Error(151) ;
            Errandskip(160,Fsys + [Lparentsy])
            END
         ELSE
            BEGIN
            IF Sy = Colonsy THEN  (* tagfield exists *)
               BEGIN
               New(Tagstrp,Tagfwithid);  
               Tagstrp^.Form := Tagfwithid;
               New(Tagidp,Field) ;
               WITH Tagidp^ DO
                  BEGIN
                  Klass := Field; Idname := Lid ; Idtype := NIL ; 
                  Next := NIL; 
                  END ;
               Enterid(Tagidp) ;
               Insymbol ;
               IF Sy <> Identsy THEN
                  BEGIN
                  Errandskip(209,Fsys + [Lparentsy]) ; GOTO 555
                  END
               ELSE
                  BEGIN
                  Lid := Id ;
                  Insymbol ;
                  IF Sy <> Ofsy THEN
                     BEGIN
                     Errandskip(160,Fsys + [Lparentsy]) ; GOTO 555
                     END
                  END
               END
            ELSE        (*sy = ofsy. no tagfield exists*)
               BEGIN
               New(Tagstrp,Tagfwithoutid) ;
               Tagstrp^.Form := Tagfwithoutid;
               END;
            WITH Tagstrp^ DO
               BEGIN
               Marker := 0;
               Stsize :=  0 ;
               Hasholes := False; Hasfiles := False;
               Fstvar := NIL;
               IF Form=Tagfwithid THEN
                  Tagfieldp := NIL
               ELSE
                  Tagfieldtype := NIL
               END;
            Id := Lid ;
            (* find the tag type in the symbol table *)
            Searchid([Types],Lidp) ;   
            Tagtype := Lidp^.Idtype;
            IF Tagtype <> NIL THEN
               IF (Tagtype^.Form > Subrange) THEN
                  Error(402)
               ELSE    (* scalar or subrange *)
                  BEGIN
                  IF Comptypes(Realptr,Tagtype) THEN
                     Error(210);
                  WITH Tagstrp^ DO
                     BEGIN
                     Packsize := Tagtype^.Packsize;
                     IF Form = Tagfwithid THEN
                        Tagfieldp := Tagidp
                     ELSE
                        Tagfieldtype := Tagtype
                     END;
                  IF Tagidp <> NIL THEN
                     BEGIN
                     Tagidp^.Idtype := Tagtype;
                     Recsection(Tagidp); (*reserves space for the tagfield *)
                     END
                  END;
            Insymbol
            END (*(sy = colonsy) or (sy = ofsy)*)
         END;    (* tagfield name and type *)

   555:
      (* parse each case value; call recsection to get field list for that
       value *)
      Caselisthead := NIL; Minsize := Recsize; Maxsize := Recsize;
      (* Elsevar describes all the variant cases that are not specified,
         which have no extra fields and hence have the current value of
         Recsize for their size (used for New and Dispose *)
      IF Tagstrp <> NIL THEN  
         BEGIN
         New (Lstrp,Variant);
         Lstrp^.Stsize := Recsize;
         Tagstrp^.Elsevar := Lstrp;
         END;
      WHILE Sy = Semicolonsy DO
         Insymbol;
      REPEAT
         Sametypehead := NIL;
         REPEAT  (*parse the list of values*)
            IF  Sy = Commasy THEN Insymbol;
            Constant(Fsys + [Commasy,Colonsy,Lparentsy],Lstrp,Lvalu);
            IF  NOT Comptypes(Tagtype,Lstrp) THEN
               Error(305);
            New(Lstrp,Variant);
            WITH Lstrp^ DO
               BEGIN
               Form := Variant;
               Marker := 0;
               Varval := Lvalu;
               Nxtvar := NIL;
               IF Tagstrp <> NIL THEN Packsize := Tagstrp^.Packsize 
               END;
            IF Sametypehead = NIL THEN Sametypehead := Lstrp;
            IF Caselisthead = NIL THEN Caselisthead := Lstrp
            ELSE Caselisttail^.Nxtvar := Lstrp;
            Caselisttail := Lstrp
         UNTIL Sy <> Commasy;
         IF Sy = Colonsy THEN
            Insymbol
         ELSE
            Error(151);
         IF Sy = Lparentsy THEN    (*parse the fieldlist*)
            Insymbol
         ELSE
            Error(153);
         Fieldlist(Fsys + [Rparentsy,Semicolonsy],Packflag,Lsubvarlist,
                   Lidp,Recsize,Fholes,Ffiles);
         IF Recsize > Maxsize THEN
            Maxsize := Recsize;
         Lstrp := Sametypehead;
         WHILE Lstrp <> NIL DO 
            BEGIN
            Lstrp^.Subvar := Lsubvarlist; 
            Lstrp^.Varfirstfield := Lidp;
            Lstrp^.Stsize := Recsize ;
            Lstrp := Lstrp^.Nxtvar;
            END;
         IF Sy = Rparentsy THEN
            BEGIN
            Insymbol;
            Iferrskip(166,Fsys + [Semicolonsy])
            END
         ELSE
            Warning(152); 
         WHILE Sy = Semicolonsy DO
            Insymbol;
         Recsize := Minsize;
      UNTIL Sy IN Fsys;
      Recsize := Maxsize;
      IF Tagstrp <> NIL THEN Tagstrp^.Fstvar := Caselisthead;
      END  (*if sy = casesy*);

   (* make sure the record ends on an addrunit boundary *)
   Roundup (Recsize, Addrunit); (** 10MAR *)
   END (*fieldlist*) ;


(*Typedefinition*)

(************************************************************************)
(*                                                                      *)
(*      TYPEDEFINITION -- parses a type definition, and constructs      *)
(*         a Structure record to describe it.  Returns pointer to       *)
(*         record in Fstrp.                                             *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Typedefinition (* Fsys: Setofsys; VAR Fstrp: Strp *);

   VAR
      Lstrp,Lstrp1,Lstrp2: Strp;
      Oldtop: Disprange;
      Lidp: Idp;
      Lsize,Oldlsize: Integer;
      Lholes, Lfiles: Boolean;
      I,Lmin,Lmax: Integer;
      Loopdone,
      Packflag: Boolean;
      Elementsperword: Bitrange;

   BEGIN (*typedefinition*)
   Fstrp := NIL;
   Skipiferr(Typebegsys,170,Fsys);
   IF Sy IN Typebegsys THEN
      BEGIN
      IF Sy IN Simptypebegsys THEN
         Simpletype(Fsys,Fstrp)
      ELSE
         IF Sy = Arrowsy THEN                  (*pointer type*)
            BEGIN
            New(Fstrp,Pointer);
            WITH Fstrp^ DO
               BEGIN
               Form := Pointer; Marker := 0;
               Eltype := NIL; Stsize := Pointersize; 
               Packsize := Pointersize; Stdtype := Adt;
               END;
            Insymbol;
            (* The type of the pointer may not have been declared yet,
               so make up a temporary record to save its name and a 
               pointer to Fstrp, and put in on the global Forwardpointertype
               list.  Then, at the end of all declarations, the list can
               be used to do the final binding of Eltype *)
            IF Sy = Identsy THEN
               BEGIN
               New(Lidp,Types);
               WITH Lidp^ DO
                  BEGIN
                  Klass := Types; Idname := Id; Idtype := Fstrp;
                  Next := Forwardpointertype
                  END;
               Forwardpointertype := Lidp;
               Insymbol;
               END
            ELSE
               Error(209)
            END     (*pointer type*)
         ELSE                                     (* structured types *)
            BEGIN
            IF Sy = Packedsy THEN                   (*packed*)
               BEGIN
               Insymbol;
               Skipiferr(Typedels,170,Fsys);
               Packflag := True;
               END
            ELSE
               Packflag := False;
            IF Sy IN [Arraysy,Recordsy,Setsy,Filesy] THEN 
               CASE Sy OF
                  Arraysy:                            (*array type*)
                     BEGIN
                     Insymbol;
                     IF Sy = Lbracksy THEN
                        Insymbol
                     ELSE
                        Error(154);
                     Lstrp1 := NIL;
                     Loopdone := False;           (*parse the subscript type*)

                     (* The following gets the subscript types.  If there
                      are multiple subscripts, e.g. 'ARRAY [1..5,1..6] of CHAR',
                      then the resulting structure must be the same as if it
                      were 'ARRAY[1..5] of ARRAY[1..6] OF CHAR'.  To do this, 
                      for each new subscript, a new Strp of type Array is made
                      and linked backwards through the field Aeltype.
                      Lstrp1 always points to the most recent. Later,
                      the chain is reversed so that the subscripts are in
                      the right order. *)

                     REPEAT
                        (* get next subrange *)
                        New(Lstrp,Arrays);
                        WITH Lstrp^ DO
                           BEGIN
                           Form := Arrays; Aeltype := Lstrp1; Inxtype := NIL;
                           Arraypf := Packflag; Stsize := 0; Stdtype := Mdt;
                           Marker := 0; 
                           END;
                        Lstrp1 := Lstrp;
                        Simpletype(Fsys + [Commasy,Rbracksy,Ofsy],Lstrp2);

                        IF Lstrp2 <> NIL THEN
                           IF Lstrp2^.Form <= Subrange THEN
                              BEGIN
                              IF Lstrp2^.Stdtype = Rdt THEN 
                                 BEGIN
                                 Error(210); Lstrp2 := NIL
                                 END
                              ELSE
                                 IF (Lstrp2 = Intptr) OR 
                                    (Lstrp2 = Posintptr) THEN
                                       BEGIN 
                                       Error(306); Lstrp2 := NIL
                                       END;
                              Lstrp^.Inxtype := Lstrp2
                              END
                           ELSE
                              BEGIN
                              Error(403); Lstrp2 := NIL
                              END;
                        Loopdone := Sy <> Commasy;
                        IF NOT Loopdone THEN
                           Insymbol
                     UNTIL Loopdone;
                     IF Sy = Rbracksy THEN
                        Insymbol
                     ELSE
                        Error(155);
                     IF Sy = Ofsy THEN
                        Insymbol
                     ELSE
                        Error(160);
                     Typedefinition(Fsys,Lstrp); (*parse the element type*)
                   
                     IF Lstrp = NIL THEN 
                        BEGIN
                        Lholes := False;
                        Lfiles := False;
                        Lsize := 0
                        END
                     ELSE
                        BEGIN
                        Lholes := Lstrp^.Hasholes;
                        Lfiles := Lstrp^.Hasfiles;
                        IF Lstrp1^.Arraypf AND Pack THEN 
                           Lsize := Lstrp^.Packsize
                        ELSE 
                           Lsize := Lstrp^.Stsize;
                        END;
                     (* Reverse chain and calculate total size for array.
                      Where declaration is ARRAY [1..J,1..K,1..L] of M, Lsize
                      will be, each time through the loop:
                      1.  L * size(M)
                      2.  K * L * size(M)
                      3.  j * K * L * size (M)
                      *)
                     REPEAT
                        WITH Lstrp1^ DO
                           BEGIN
                           Lstrp2 := Aeltype; Aeltype := Lstrp;
                           IF Inxtype <> NIL THEN
                              BEGIN
                              Getbounds(Inxtype,Lmin,Lmax);
                              I := Lmax - Lmin + 1;
                              IF Arraypf AND Pack THEN
                                 (* pack arrays no closer than specified *)
                                 Roundup (Lsize,Apackunit)
                              ELSE Roundup (Lsize, ArrAlign);
                              (* make sure size of large array elements is
                                 a multiple of Salign *)
                              Oldlsize := Lsize;
                              IF Lsize > Salign THEN  
                                 BEGIN
                                 Roundup (Lsize,Salign);
                                 Aelsize := Lsize;
                                 Lsize := Lsize * I;
                                 END 
                              (* for small array elements, pack evenly or
                                 unevenly without overlapping words *)
                              ELSE IF Apackeven THEN
                                 BEGIN
                                 WHILE Salign MOD Lsize > 0 DO
                                    Lsize := Lsize + 1;
                                 Aelsize := Lsize;
                                 Lsize := Lsize * I;
                                 END
                              ELSE (* uneven packing *)
                                 BEGIN
                                 Elementsperword := Salign DIV Lsize;
                                 IF Elementsperword = 1 THEN Lsize := Salign;
                                 Aelsize := Lsize;
                                 Lsize := (I DIV Elementsperword) * Salign +
                                    (I MOD Elementsperword) * Lsize;
                                 END;
		              (* arrays must always end on an addrunit boundary *)
			      Roundup (Lsize, Addrunit);  (** 10MAR *)
                              Hasholes := Lholes OR (Oldlsize * I <> Lsize);
                              Hasfiles := Lfiles;
                              Packsize := Lsize;
                              Stsize := Lsize;
                              END
                           END;
                        Lstrp := Lstrp1; Lstrp1 := Lstrp2
                     UNTIL Lstrp1 = NIL;
                     Fstrp := Lstrp;
                     END   (*array type*);
                  Recordsy:
                     BEGIN                        (*record type*)
                     Insymbol;
                     (* Push a new entry onto the display to hold the fields
                        of the new record *)
                     Oldtop := Top;
                     IF Top < Displimit THEN
                        BEGIN
                        Top := Top + 1; Display[Top].Fname := NIL ;
                        Display[Top].Occur := Crec ;
                        END
                     ELSE
                        Error(404);
                     Lsize := 0; Lholes := False; Lfiles := False;
                     Fieldlist(Fsys-[Semicolonsy] + [Endsy],Packflag,Lstrp,
                               Lidp,Lsize,Lholes,Lfiles);
                     New(Fstrp,Records);
                     WITH Fstrp^ DO
                        BEGIN
                        Form := Records; Stdtype := Mdt; Marker := 0;
                        (* if we assigned Lidp, records with no fixed part 
                           would lose *)
                        Recfirstfield := Display[Top].Fname;
                        Recvar := Lstrp; Stsize := Lsize; Packsize := Lsize; 
                        Recordpf := Packflag;
                        Hasholes := Lholes;  Hasfiles := Lfiles;
                        END;
                     Top := Oldtop;
                     IF Sy = Endsy THEN
                        Insymbol
                     ELSE
                        Error(163)
                     END (*record type*);
                  Setsy:
                     BEGIN                           (*set type*)
                     Insymbol;
                     IF Sy = Ofsy THEN
                        Insymbol
                     ELSE
                        Error(160);
                     Simpletype(Fsys,Lstrp);
                     (* defaults in case of error: *)
                     Lmin := 0;  Lmax := Defsetsize - 1;
                     IF Lstrp <> NIL THEN
                        WITH Lstrp^ DO
                           IF Form = Scalar THEN
                              BEGIN
                              IF Scalkind = Standard THEN
                                 IF Stdtype = Cdt THEN
                                    BEGIN
                                    Lmax := TgtlastChar;
                                    Lmin := TgtfirstChar;
                                    END
                                 ELSE Error(177)
                              ELSE
                                 BEGIN (* enumerated types *)
                                 Lmax := Dimension;
                                 Lmin := 0;
                                 END
                              END
                           ELSE IF Form = Subrange THEN
                              BEGIN
                              IF (Hosttype = Realptr) THEN Error(177)
                              ELSE
                                 BEGIN
                                 Lmin := Vmin.Ival;
                                 Lmax := Vmax.Ival;
                                 END;
                              END
                           ELSE (* not Subrange or Scalar *)
                              BEGIN
                              Error(461); Lstrp := NIL
                              END;
                     (* make sure LMIN begins on SETUNIT boundary *)
                     IF Lmin MOD Setunitsize <> 0 THEN
                        BEGIN
                        IF Lmin >= 0 THEN
                          Lmin := (Lmin DIV Setunitsize)*Setunitsize 
                        ELSE
                          Lmin := (Lmin DIV Setunitsize-1)*Setunitsize
                        END;
                     New(Fstrp,Power);
                     WITH Fstrp^ DO
                        BEGIN
                        Form := Power; Stdtype := Sdt; Marker := 0;
                        Hasfiles := False; Hasholes := False;
                        Basetype := Lstrp; 
                        Hardmin := Lmin; Hardmax := Lmax;
                        Packsize := Hardmax - Hardmin + 1;
                        (* round unpacked size up to nearest SETUNIT *)
                        IF Packsize MOD Setunitsize <> 0 THEN
                           Stsize :=(Packsize DIV Setunitsize + 1) * Setunitsize
                        ELSE Stsize := Packsize;
                        IF Stsize > Maxsetsize THEN
                           BEGIN 
                           Error (177);
                           Stsize := Defsetsize;
                           END;
                        (* if large set, do not pack *)
                        IF Packsize >= Salign THEN
                           Packsize := Stsize
                        ELSE
                           BEGIN (* otherwise, calculate packed size *)
                           Packsize := Max (Packsize,Psetsize);
                           WHILE Packsize MOD Rpackunit > 0 DO
                              Packsize := Packsize + 1;
                           END;
                        Softmin := Hardmin;  Softmax := Stsize + Hardmin - 1;
                        END
                     END (*set type*);
                  Filesy:
                     BEGIN                          (*file type*)
                     Insymbol;
                     IF Sy = Ofsy THEN
                        Insymbol
                     ELSE
                        Error(160);
                     Typedefinition(Fsys,Lstrp);
                     IF Lstrp = NIL THEN Lsize := 0
                     ELSE IF Packflag THEN Lsize := Lstrp^.packsize
                     ELSE Lsize := Lstrp^.Stsize;
                     Roundup (Lsize, Addrunit);
                     New(Fstrp,Files);
                     WITH Fstrp^ DO
                        BEGIN
                        Marker := 0;
                        Form := Files;
                        Stdtype := Mdt;
                        Hasfiles := True; Hasholes := False;
                        (* size of file buffer is Fdbsize + room for
                         one record from the file *)
                        Filetype := Lstrp; Stsize := Lsize+Fdbsize;
                        Filepf := Packflag; Packsize := Stsize;
                        Textfile := (Filepf AND (Filetype = Charptr));
                        END;
                     END    (*file type*);
                  END (*case*);
            END;
      Iferrskip(166,Fsys)
      END;    (*sy in typebegsys*)
   END (*typedefinition*) ;


(*Resolvepointers,Labeldecl,Constantdecl,Typedecl,Variabledecl*)

(************************************************************************)
(************************************************************************)
(*                                                                      *)
(*      DECLARATIONS MODULE  -- handles Label, Const, Type, Var,        *)
(*          Procedure, and Function declarations                        *)
(*                                                                      *)
(*      Principle procedures are: Labeldeclaration, Constdeclaraton,    *)
(*          Typedeclaration, Vardeclaration, and Proceduredeclaration.  *)
(*      Procedure Resolvepointers is called at the end of a set of      *)
(*          Type or Var definitions to resolve all pointer type         *)
(*          references                                                  *)
(*                                                                      *)
(************************************************************************)
(************************************************************************)

   PROCEDURE Resolvepointers; 

      (* For each pointer type that was declared, find the type and patch up
         Eltype in the pointer structure record to point to it *)
      VAR
         Lidp: Idp;
      BEGIN
      WHILE Forwardpointertype <> NIL DO
         BEGIN
         Searcherror := False;
         Id := Forwardpointertype^.Idname;
         Searchid([Types],Lidp);
         Searcherror := True;
         IF Lidp = NIL THEN
            Errorwithid(405,Forwardpointertype^.Idname)
         ELSE IF Lidp^.Idtype <> NIL THEN
            Forwardpointertype^.Idtype^.Eltype := Lidp^.Idtype;
         Forwardpointertype := Forwardpointertype^.Next;
         END;
      END;


   PROCEDURE Labeldeclaration;
      (*parses a set of label declarations*)
      VAR
         Lidp: Idp;
         Loopdone: Boolean;
      BEGIN (*labeldeclaration*)
      Loopdone := False;
      REPEAT
         IF Sy = Intconstsy THEN
            BEGIN
            New(Lidp,Labels);
            WITH Lidp^ DO
               BEGIN
               Klass := Labels; Scope := Level; Idname := Id; Idtype := NIL;
               Referenced := False; Defined := False;
               Next := NIL;  Externalref := False;  
               (* allocate a label number for it *)
               Lastuclabel := Lastuclabel + 1; Uclabel := Lastuclabel;
               END;
            Enterid(Lidp);
            Insymbol
            END
         ELSE
            Error(255);
         Iferrskip(166,Fsys + [Commasy,Semicolonsy]);
         Loopdone := Sy <> Commasy;
         IF NOT Loopdone THEN
            Insymbol
      UNTIL Loopdone;
      IF Sy = Semicolonsy THEN
         Insymbol
      ELSE
         Warning(156)  
      END (*labeldeclaration*) ;

   PROCEDURE Constantdeclaration;
      (*parses a set of constant declarations*)
      VAR
         Lidp: Idp;
         Lstrp: Strp;
         Lvalu: Valu;
      BEGIN (*constantdeclaration*)
      Skipiferr([Identsy],209,Fsys);
      WHILE Sy = Identsy DO
         BEGIN
         New(Lidp,Konst);
         WITH Lidp^ DO
            BEGIN
            Klass := Konst; Idname := Id; Idtype := NIL; Next := NIL;
            Referenced := False; 
            END;
         Insymbol;
         IF Sy = Eqsy THEN
            Insymbol
         ELSE
            Error(157);

         Constant(Fsys + [Semicolonsy],Lstrp,Lvalu);

         Enterid(Lidp);
         Lidp^.Idtype := Lstrp; Lidp^.Values := Lvalu;
         IF Sy = Semicolonsy THEN
            BEGIN
            Insymbol;
            Iferrskip(166,Fsys + [Identsy])
            END
         ELSE
            Warning(156) 
         END     (*while sy = identsy*)
      END (*constantdeclaration*) ;

   PROCEDURE Typedeclaration;
      (*parses a set of type declarations *)
      VAR
         Lidp: Idp;
         Lstrp: Strp;

      BEGIN (*typedeclaration*)
      Skipiferr([Identsy],209,Fsys);
      WHILE Sy = Identsy DO         (*parse the type declaration*)
         BEGIN
         New(Lidp,Types);
         WITH Lidp^ DO
            BEGIN
            Klass := Types; Idname := Id; Next := NIL;
            Referenced := False; 
            END;
         Insymbol;
         IF Sy = Eqsy THEN
            Insymbol
         ELSE
            Error(157);

         Typedefinition(Fsys + [Semicolonsy],Lstrp);

         Lidp^.Idtype := Lstrp;
         Enterid(Lidp);
         IF Sy = Semicolonsy THEN
            BEGIN
            Insymbol;
            Iferrskip(166,Fsys + [Identsy])
            END
         ELSE
            Warning(156) 
         END     (*while symbol = identsy*);

      (* resolve forward pointer references *)
      Resolvepointers;
      END (*typedeclaration*) ;

   PROCEDURE Variabledeclaration;
        
      (* Parses a set of variable declarations, assigning memory to each
         variable.  Also builds a list of files declared for this block. *)
      VAR
         Lidp,Sametypehead,Sametypetail: Idp;
         Lstrp: Strp;
         Lsize: Sizerange;
         Loopdone: Boolean;
         Tfilelisthead,Tfilelisttail: Idp;   (* list of files *) 

      BEGIN (*variabledeclaration*)
      Tfilelisthead := NIL;  
      REPEAT
         Loopdone := False;      (* get a list of ids, separated by commas *)
         Sametypehead := NIL;
         REPEAT
            IF Sy = Identsy THEN
               BEGIN
               New(Lidp,Vars);
               WITH Lidp^ DO
                  BEGIN
                  Klass := Vars; Idname := Id; Next := NIL;
                  Idtype := NIL; Vkind := Actual; Vblock := Memblock;
                  Referenced := False;  Assignedto := False; Isparam := False; 
                  Loopvar := False; 
                  END;
               Enterid(Lidp);
               IF Sametypehead = NIL THEN Sametypehead := Lidp
               ELSE Sametypetail^.Next := Lidp;
               Sametypetail := Lidp;
               Insymbol
               END
            ELSE
               Error(209);
            Skipiferr(Fsys + [Commasy,Colonsy] + Typedels,166,[Semicolonsy]);
            Loopdone := Sy <> Commasy;
            IF NOT Loopdone THEN
               Insymbol
         UNTIL Loopdone;

         (* get the type for this list *)
         IF Sy = Colonsy THEN      
            Insymbol
         ELSE
            Error(151);
         Typedefinition(Fsys + [Semicolonsy] + Typedels,Lstrp);

         (* assign memory to each variable in the list *)
         WHILE Sametypehead <> NIL DO    
            WITH  Sametypehead^ DO
               BEGIN
               Idtype := Lstrp;  (* hand the type from the idname *)
               Vmty := Zmt; Vaddr := 0;
               IF Lstrp <> NIL THEN
                  BEGIN
                  IF Vblock = 1 THEN Vmty := Smt
                  ELSE Vmty := Findmemorytype (Lstrp^.Stdtype, Lstrp^.Stsize,
                                               False, False);
                  Vaddr := Assignnextmemoryloc (Vmty, Lstrp^.Stsize);
                  IF (Lstrp^.Hasfiles) OR (Lstrp^.Hasholes) THEN
                     BEGIN 
                     IF Tfilelisthead = NIL THEN
                        Tfilelisthead := Sametypehead
                     ELSE
                        Tfilelisttail^.Next := Sametypehead;
                     Tfilelisttail := Sametypehead;
                     END;
                  END;
               Sametypehead := Next
               END     (*while nxt <> nil*);
         IF Sy = Semicolonsy THEN
            BEGIN
            Insymbol;
            Iferrskip(166,Fsys + [Identsy])
            END
         ELSE
            Warning(156) 
      UNTIL NOT (Sy  IN  Typedels + [Identsy]);

      (* attach the file list to the Id of the program, procedure, 
         or function *)
      IF Tfilelisthead <> NIL THEN 
         IF Fprocp = NIL THEN 
            BEGIN
            Tfilelisttail^.Next := Progidp^.Progfilelist;
            Progidp^.Progfilelist := Tfilelisthead;
            END
         ELSE 
            BEGIN
            Tfilelisttail^.Next := Fprocp^.Filelist;
            Fprocp^.Filelist := Tfilelisthead;
            END;
      (* resolve forward pointer references *)
      Resolvepointers; 
      (* allocate one register temporary, but only if at least one simple
         variable has been declared *)
      IF (Localsinregs * Regsize > Abs(Memcnt[Fmt])) AND 
         (Memcnt[Fmt] > 0) AND (Regtempaddr = 0) THEN
         Regtempaddr := Assignnextmemoryloc (Fmt, Intsize);
      END (*variabledeclaration*) ;



(*Functiontype,Parameterlist*)

(************************************************************************)
(*                                                                      *)
(*      FUNCTIONTYPE: parses the type of a function, and records        *)
(*        the relevent information in the function's Id (Fidp).         *)
(*      Assigns memory for the function IF it is not the type of        *)
(*        formal function (that is, a function parameter)               *)
(*                                                                      *)
(*      If the function result is too large to pass directly, adds      *)
(*        an additional reference parameter to the paramter list        *)
(*        of the function.                                              *)
(*                                                                      *)
(************************************************************************)

Procedure Functiontype (Var Fidp: Idp; Formal: Boolean);

   VAR Lidp,Lidp2: Idp;
       Lstrp: Strp;

   BEGIN
   Insymbol;
   IF Sy <> Identsy THEN
      Errandskip(209,Fsys + [Semicolonsy])
   ELSE
      BEGIN (* Sy = Identsy *)
      Searchid([Types],Lidp);
      Lidp^.Referenced := True;  
      Lstrp := Lidp^.Idtype;
      Fidp^.Idtype := Lstrp;
      IF Lstrp <> NIL THEN
         WITH Lstrp^ DO
            BEGIN 
            IF  NOT (Form IN [Scalar,Subrange,Pointer]) THEN
               BEGIN
               Error(551); Fidp^.Idtype := NIL
               END
            ELSE IF NOT Formal THEN
	     WITH Fidp^ DO
               BEGIN
               Resmemtype := Findmemorytype (Stdtype, Stsize, False, False);
               Resaddr := Assignnextmemoryloc (Resmemtype, Stsize);
               END;
            END; (* With Lstrp do *)
      Insymbol;
      END (* Sy = Identsy *)
   END (* get function type *);

(************************************************************************)
(*                                                                      *)
(*      PARAMETERLIST -- parses a list of format paramters to a         *)
(*                       procedure or function                          *)
(*                                                                      *)
(*      A linked list of paramters is created.  Its head is returned    *)
(*      in Fidp, and its tail in Lastidp.  The number is returned in    *)
(*      FParnumber.                                                     *)
(*                                                                      *)
(*      The list being parsed may be a real list or it may be a list    *)
(*      for a procedural parameter.  This is indicated by the caller    *)
(*      through the Dummylist parameter. 				*)
(*                                                                      *)
(************************************************************************)

PROCEDURE Parameterlist(Fsys:Setofsys; VAR Fidp: Idp;
			VAR Fparnumber: Integer; Dummylist: Boolean);
   VAR
      Lidp,Lidp2,Lidp3,Paridp,Lastidp : Idp;
      Lstrp : Strp;
      Lkind : Idkind;
      Lklass : Idclass;  
      Loopdone,Loop2flag : Boolean;
      Lparnumber: Integer;  
      Lmty: Memtype;
      Laddr: Integer;
   BEGIN (*parameterlist*)
   Fidp := NIL; Lstrp := NIL; Fparnumber := 0; Lastidp := NIL;
   Skipiferr(Fsys+[Lparentsy],256,[]);
   IF Sy = Lparentsy THEN
      BEGIN (* get parameter list *)
      Insymbol;
      Skipiferr([Proceduresy,Functionsy,Varsy,Identsy],
		256, Fsys+[Rparentsy]);
      IF Sy IN [Proceduresy,Functionsy,Varsy,Identsy] THEN
	 BEGIN
	 Loopdone := False;  (*for each parameter*)
	 REPEAT
	    Lidp2 := NIL;
	    IF Sy IN [Proceduresy,Functionsy] THEN      
	       BEGIN  (*procedural parameter*)
	       IF Sy = Proceduresy THEN Lklass := Proc
	       ELSE Lklass := Func;
	       Insymbol;
	       IF Sy <> Identsy THEN
		  Errandskip(209,Fsys+[Colonsy,Commasy,Identsy])
	       ELSE
		  BEGIN
		  Fparnumber := Fparnumber + 1;
		  New(Lidp,Proc,Regular,Formal);
		  WITH Lidp^ DO
		     BEGIN
		     Klass := Lklass;
		     Prockind := Regular;
		     Nonstandard := False;
		     Idtype := NIL;
		     Idname := Id; Next := NIL;
		     Pfkind := Formal;
		     Referenced := False;  
		     (* assign memory for the procedure descriptor *)
		     IF NOT Dummylist THEN
			BEGIN
		        Pfmty := Findmemorytype(Edt, Entrysize, True, False);
		        Pfaddr := Assignnextmemoryloc (Pfmty, Entrysize);
		        END;
		     Pfblock := Memblock;
		     Pflev := 0;
		     Fparam := Paridp;
		     Insymbol;
		     IF Lklass = Func THEN
			Parameterlist([Semicolonsy,Colonsy,Rparentsy],
				      Paridp,Lparnumber,True)
		     ELSE
			Parameterlist([Semicolonsy,Rparentsy],
				      Paridp,Lparnumber,True);
		     Fparam := Paridp;
		     Parnumber := Lparnumber;
		     END;
		  IF Lklass = Func THEN
		     IF Sy <> Colonsy THEN                  
			Error(455) 
		     ELSE
			Functiontype (Lidp,True);
		  (* add to parameter list *)
		  IF Fidp = NIL THEN
		     Fidp := Lidp
		  ELSE
		     Lastidp^.Next := Lidp;
		  Lastidp := Lidp;
		  IF NOT Dummylist THEN Enterid(Lidp);
		  END
	       END
	    ELSE (*not (sy in [procsy, funcsy]): data parameters*)
	       BEGIN
	       IF Sy = Varsy THEN              (*reference parameters*)
		  BEGIN
		  Lkind := Formal; Insymbol;
		  END
	       ELSE
		  Lkind := Actual;             (*value parameter*)
	       Loop2flag := False;             
	       (* Get list of ids, separated by commas.  At the end, Lidp2
		  will point to the head of this list *)
	       REPEAT
		  IF Sy <> Identsy THEN
		     Errandskip(209,Fsys+[Colonsy,Commasy,Identsy])
		  ELSE  
		     BEGIN
		     Fparnumber := Fparnumber + 1;
		     New(Lidp,Vars);
		     WITH Lidp^ DO
			BEGIN
			Klass := Vars;
			Idname := Id; Next := NIL; Vkind := Lkind;
			Vblock := Memblock; 
			Assignedto := False; Referenced := False; 
			Isparam := True; Loopvar := False;
			Default := NIL;
			END;
		     IF NOT Dummylist THEN Enterid(Lidp);
		     Insymbol;
		     IF Fidp=NIL THEN
			Fidp := Lidp
		     ELSE
			Lastidp^.Next := Lidp;
		     Lastidp := Lidp;
		     IF Lidp2 = NIL THEN
			Lidp2 := Lidp;
		     END;
		  Loop2flag := NOT(Sy IN [Commasy,Identsy]);
		  IF NOT Loop2flag THEN
		     IF Sy=Commasy THEN
			Insymbol
		     ELSE
			Error(158)
	       UNTIL Loop2flag (*idname list*);
	       IF Sy=Colonsy THEN                (*type definition*)
		  BEGIN
		  Insymbol;
		  IF Sy=Identsy THEN
		     BEGIN
		     Searchid([Types],Lidp3);
		     Insymbol;
		     Lstrp := Lidp3^.Idtype;
		     IF (Lstrp <> NIL) AND (Lkind = Actual) THEN
			IF Lstrp^.Form = Files THEN Error (355);
		     END
		  ELSE
		     Error(209)
		  END
	       ELSE
		  Error(151);

	       (* assign memory for each *)
               WHILE Lidp2 <> NIL DO
		  WITH Lidp2^ DO
		     BEGIN
		     Idtype := Lstrp;
		     IF NOT Dummylist THEN
		     IF Vkind = Formal THEN
			BEGIN
			Vmty:=Findmemorytype(Adt,Pointersize,True,False);
			Vaddr := Assignnextmemoryloc (Vmty, Pointersize);
			Vblock := Memblock;  
			END
		     ELSE
			BEGIN
			IF Lstrp <> NIL THEN
			   WITH Lstrp^ DO
			      BEGIN
			      IF (Stdtype = Mdt) OR (Stsize > Parthreshold) THEN
				 BEGIN
				 Vindtype:=Findmemorytype(Adt,Pointersize,
							  True, False);
				 Vindaddr := Assignnextmemoryloc(Vindtype,
							   Pointersize);
				 Vmty := Findmemorytype (Stdtype, Stsize,
							   False, False);
				 Vaddr:=Assignnextmemoryloc(Vmty,Stsize);
				 END
			      ELSE 
				 BEGIN
				 Vmty := Findmemorytype (Stdtype, Stsize,
							 True, False);
				 Vaddr:=Assignnextmemoryloc(Vmty,Stsize);
				 END;
			      Vblock := Memblock;  
			      END
			END;
		     Lidp2 := Next;
		     END;
	       END (*not sy in [proceduresy, functionsy]*);
	    Skipiferr([Rparentsy,Semicolonsy],256,
		      [Proceduresy,Functionsy,Identsy,Varsy]+Fsys);
	    Loopdone := NOT(Sy IN [Semicolonsy,Proceduresy,Functionsy,
				   Varsy,Identsy]);
	    IF NOT Loopdone THEN
	       IF Sy=Semicolonsy THEN
		  Insymbol
	       ELSE
		  Warning(156); 
	 UNTIL Loopdone (*for each parameter of this procedure*);
	 END;
      IF Sy=Rparentsy THEN
	 Insymbol
      ELSE
	 Warning(152); 
      Skipiferr(Fsys,166,[])
      END (*sy=lparentsy*);

   END (*parameterlist*);



(*Proceduredeclaration*)

(************************************************************************)
(*                                                                      *)
(*      PROCEDUREDECLARATION -- processes entire procedure or           *)
(*        function declaration                                          *)
(*                                                                      *)
(*      Saves memory count of current procedure                         *)
(*      Insures that any previous declarations have been forward        *)
(*      If has not been declared forward                                *)
(*         Gets parameters                                              *)
(*         If function, gets function result type                       *)
(*      Gets declarations and body of procedure, or FORWARD             *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Proceduredeclaration(Procflag: Boolean);
   (* processes a complete procedure declaration *)
   VAR
      Oldlev: Levrange;
      Lidp,Lidp1: Idp; 
      Forw: Boolean;
      Oldtop: Disprange;
      Oldcurrname: Identname;
      Lparnumber,I,Nameend: Integer;
      Oldmemcnt: Memsize;
      Oldmemblock: Blockrange;   
      Oldminlocreg, Oldmaxlocreg: Integer;
      Lmemtype: Memtype;

       
   BEGIN (*proceduredeclaration*)

   (* save current memory count at re-initialize *)
   Oldcurrname := Currname;
   IF Memblock = 1 THEN
      Globalmemcnt := Memcnt (* save where LoadTableAddress can get at it *)
   ELSE Oldmemcnt := Memcnt;
   Oldmemblock := Memblock;   
   FOR Lmemtype := Zmt TO Fmt DO
      Memcnt[Lmemtype] := 0;
   Oldminlocreg := Minlocreg;  Oldmaxlocreg := Maxlocreg;
   IF Sy <> Identsy THEN
      BEGIN
      Error(209);
      IF Procflag THEN
         Lidp := Uprocptr
      ELSE
         Lidp := Ufuncptr
      END
   ELSE       
      BEGIN
      Currname := Id;
      (*decide whether declared forward:*)
      Searchsection (Display[Top].Fname,Lidp);
      IF Lidp <> NIL THEN   (* it should have been declared forward *)
         WITH Lidp^ DO
            BEGIN
            Forw := False;
            IF Klass IN [Proc,Func] THEN
	       BEGIN
               IF  Pfkind=Actual THEN
	          BEGIN
		  IF Externdecl THEN
		     BEGIN (* make it look like it was declared FORWARD *)
		     Memblkctr := Memblkctr + 1; 
		     Pfmemblock := Memblkctr;
		     Externdecl := False; Forwdecl := True;
		     END;
                  Forw := Forwdecl AND 
                     (((Klass = Proc) AND Procflag) OR 
                      ((Klass = Func) AND NOT Procflag));
	          END;
	       Memblock := Pfmemblock;  
	       END;
            IF  NOT Forw THEN
               Error(557);
            END
      ELSE  (*lidp <> nil*)
         Forw := False;
      IF  NOT Forw THEN      (*create the procedure/function descriptor block*)
         BEGIN
         IF Procflag THEN
            BEGIN (* Procedure *)
            New(Lidp,Proc,Regular,Actual);
            Lidp^.Klass := Proc;
            END
         ELSE
            BEGIN (* Function *)
            New(Lidp,Func,Regular,Actual);
            Lidp^.Klass := Func;
            END;
         WITH Lidp^ DO
            BEGIN
            Prockind := Regular; Pfkind := Actual;
            Idname := Id; Idtype := NIL; Testfwdptr := NIL; 
            Filelist := NIL;  
            Forwdecl := False; Externdecl := False; Externalname := Id;
            Uinst := Unop;
            Memblkctr := Memblkctr + 1; 
            Memblock := Memblkctr;
            Pflev := Level+1; Pfmemblock := Memblkctr; Resmemtype := Zmt;
            Resaddr := 0;  Nonstandard := False;
            Referenced := False;  Fassigned := False;
            END;
         Enterid(Lidp)
         END (* not forward *);
      Insymbol;
      END;
   Oldlev := Level; Oldtop := Top;             (*open a new display frame*)
   IF Level >= Maxnest THEN
      Error (404)
   ELSE Level := Level + 1;
   IF Top >= Displimit THEN
      Error(404)
   ELSE
      BEGIN
      Top := Top + 1;
      WITH Display[Top] DO
         BEGIN
         Fname := NIL; Occur := Blck;
         Mblock := Lidp^.Pfmemblock;
         IF Forw THEN
            Fname := Lidp^.Next
         END (*with display[top]*)
      END;
   IF Procflag THEN 
      Parameterlist([Semicolonsy],Lidp1,Lparnumber,False)
   ELSE
      Parameterlist([Semicolonsy,Colonsy],Lidp1,Lparnumber,False); 
   IF (Lparnumber > 0) AND Forw THEN Error(553);
   IF NOT Forw THEN
      WITH Lidp^ DO
         BEGIN
         Next := Lidp1;
         Parnumber := Lparnumber;
         END;
   IF NOT Procflag THEN
      IF Sy <> Colonsy THEN                  
         BEGIN 
         IF NOT Forw THEN Error(455) 
         END
      ELSE
         BEGIN (* get function type *)
         IF Forw THEN Error(552);
         Functiontype (Lidp,False);
         END;
   IF Sy = Semicolonsy THEN
      Insymbol
   ELSE
      Warning(156); 
   IF NOT Forw THEN
      IF (Sy <> Externsy) AND NOT Leavealone AND 
	 (Uniquefy OR NOT Ismodule OR (Level > 2)) THEN
	 (* create a unique external name for this procedure *)
	  Makeexternalname (Lidp^.Externalname)
      ELSE
	  (* change all underbars to dollar signs *)
	  FOR I := 1 TO Identlength DO
	     IF Lidp^.Externalname[I] = Underbar THEN Lidp^.Externalname[I] := '$'
	  ;
   IF InIncludeFile AND (Sy <> Externsy) THEN
      Error (504);
   IF Sy = Forwardsy THEN                 (*forward declaration*)
      BEGIN
      Lidp^.Savedmsize := Memcnt;
      IF Forw THEN
         Error(257)
      ELSE
         (* add to list of forward declared procedures *)
         WITH Lidp^ DO
            BEGIN
            Testfwdptr := Forwardprocedures; 
            Forwardprocedures := Lidp; 
            Forwdecl := True;
            END;
      Insymbol;
      IF Sy = Semicolonsy THEN
         Insymbol
      ELSE
         Warning(156); 
      Iferrskip(166,Fsys)
      END (* sy = forwardsy *)
   ELSE                (* sy <> forwardsy *)
      WITH Lidp^ DO
         BEGIN
         IF Sy = Externsy THEN                     (*external declaration*)
            BEGIN
            IF Forw THEN
               Error(257)
            ELSE
               Externdecl := True;
	    Lidp^.Savedmsize := Memcnt;
            Insymbol;
            Pflev := 2;
            Pfmemblock := 0;  
            IF Sy = Semicolonsy THEN
               Insymbol
            ELSE
               Warning(156); 
            Iferrskip(166,Fsys);
            END (* sy = externsy *)
         ELSE    (* (sy <> externsy) and (sy <> forwardsy) *)
            BEGIN
            (* If was declared forward, and hence memory has already been
               allocated for parameters, restore memory count *)
            IF Forw THEN Memcnt := Lidp^.Savedmsize;
            Forwdecl := False;
            IF Emitsyms THEN WITH Lidp^ DO
               (* print procedure head in sym table file *)
               BEGIN
               Writeln (Symtbl); Writeln (Symtbl);
               Write (Symtbl,'% ',Idname:Idlen(Idname),' ',
                      Pfmemblock:1,' ',Pflev:1);
               END;

	    IF Localsbackwards THEN Minlocreg := 0
	    ELSE Minlocreg := Memcnt[Fmt];

            Block(Lidp,Fsys,
                  [Beginsy,Functionsy,Proceduresy,Periodsy,Semicolonsy,Eofsy]);

            (* check to see if function result was assigned *)
            IF Lidp^.Klass = Func THEN  
               IF NOT Lidp^.Fassigned THEN
                  Warningwithid (310,Lidp^.Idname);
            IF Sy = Semicolonsy THEN
               BEGIN
               Insymbol;
               Skipiferr([Beginsy,Proceduresy,Functionsy,Periodsy],166,Fsys)
               END
            ELSE
               Warning(156) 
            END (* sy <> externsy *)
         END (* sy <> forwardsy *) ;

   (* restore display and memory count *)
   Level := Oldlev; Top := Oldtop; 
   IF Oldmemblock = 1 THEN
      Memcnt := Globalmemcnt
   ELSE
      Memcnt := Oldmemcnt;
   Currname := Oldcurrname;
   Memblock := Oldmemblock;  
   Minlocreg := OldMinlocreg;  Maxlocreg := OldMaxlocreg;
   END (*proceduredeclaration*) ;




(*Body,Checkiduse,Checksyms*)

PROCEDURE Body (Fsys: Setofsys);
   (* parses the body of a procedure or the main block*)
   VAR
      loopdone: boolean;


 PROCEDURE Checksyms (Fidp: Idp);

   (* Prints the symbol table in the current level in the symbol table file,
      and prints out warnings if symbols have not been used, and checks for
      undefined labels *)


      PROCEDURE Checkiduse (Fidp: Idp);

         (* prints warning if identifiers have not been referenced *)
         (* also prints warning if variables which are not actual parameters
            or files are not assigned to, except for reference parameters,
            which should have been EITHER referenced OR assigned to, but not
            necessarily both *)

         VAR Lassigned: Boolean;

         BEGIN (*Checkiduse*)
         IF Fidp <> NIL THEN
            WITH Fidp^ DO
               BEGIN
               IF (Klass IN [Vars,Konst,Proc,Func,Labels,Types]) THEN
                  BEGIN
                  Lassigned := True;
                  IF (Klass = Vars) AND (Idtype <> NIL) THEN
                     BEGIN
                     IF (Idtype^.Form <> Files) THEN Lassigned := Assignedto;
                     IF Isparam THEN
                        IF (Vkind = Formal) THEN
                           BEGIN
                           IF Referenced OR Lassigned then
                              BEGIN
                              Lassigned := True;
                              Referenced := True;
                              END;
                           END
                        ELSE Lassigned := True;
                     END;
                  IF NOT Referenced AND NOT Lassigned THEN
                     Warningwithid (368,Idname)
                  ELSE IF NOT Referenced THEN
                     Warningwithid (175,Idname)
                  ELSE IF NOT Lassigned THEN
                     Warningwithid (176,Idname)
                  END;
               END;
         END (*Checkiduse*);

   
      BEGIN (*Checksyms*)
      IF Fidp <> NIL THEN
         WITH Fidp^ DO
            BEGIN
            Checksyms(Llink);
            IF (Klass = Labels) AND NOT Defined THEN
               Error (214);
            IF Idwarning THEN
               Checkiduse(Fidp);
            IF Emitsyms THEN Prntsymbol (Fidp);
            Checksyms(Rlink);
            END;
      END (*Checksyms*);



(*Enterbody,Leavebody*)

(************************************************************************)
(*                                                                      *)
(*      ENTERBODY and LEAVEBODY                                         *)
(*                                                                      *)
(*      Generates, for each procedure or for the main block             *)
(*                                                                      *)
(*         Initial ENT, PAR, and LEX instructions                       *)
(*         Final PLOD, DEF, RET and END instructions                    *)
(*         Code to initialize standard files (main block only)          *)
(*                                                                      *)
(*      Also generates warnings, on exit, if there are unused           *)
(*         labels, constants, types, or variables                       *)
(*                                                                      *)
(************************************************************************)


PROCEDURE GenStdfileinit;
   (* generates call to standard file initializing procedure *)
   VAR Parcount: Integer;  

   BEGIN
   Stdcallinit (Parcount);
   WITH Inputptr^ DO
      Ucolda (Mdt, Vmty, Vblock, Vaddr, Idtype^.Stsize);
   Par(Adt,Parcount);
   WITH Outputptr^ DO
      UcoLda (Mdt, Vmty, Vblock, Vaddr, Idtype^.Stsize);
   Par(Adt,Parcount);
   IF Errorfile THEN
      WITH Errorptr^ DO
         UcoLda (Mdt, Vmty, Vblock, Vaddr, Idtype^.Stsize)
   ELSE Uco3intval (Uldc,Adt,Intsize,-1);
   Par(Adt,Parcount);
   Uco3intval (Uldc,Bdt,Boolsize,Ord(Openinput));
   Par(Bdt,Parcount);
   Uco3intval (Uldc,Bdt,Boolsize,Ord(Openoutput));
   Par(Bdt,Parcount);
   Uco1idp (Ucup,Stdfileinitidp);
   END;


PROCEDURE GenPstrs (Fidp: Idp);
   (* generates Pstrs for a procedure, starting with the last parameter *)
   BEGIN
   IF Fidp <> NIL THEN
      WITH Fidp^ DO
         BEGIN
         GenPstrs (Fidp^.Next);
         IF Klass IN [Proc,Func] THEN  
            Uco5typaddr(Upstr,Edt,Pfmty,Pfblock,Pfaddr,Entrysize)
         ELSE
            IF Vkind = Formal THEN
               Uco5typaddr(Upstr,Adt,Vmty,Vblock,Vaddr,Pointersize)
            ELSE  (*vkind = actual*)
               Uco1idp(Upstr,Fidp);
         END;
   END;


PROCEDURE Enterbody;
   (* Generates the startup code for a body, i.e. ENT, PSTRs, SYMs;
    also jumps to scalar table loading code for main block *)
   VAR
      I: Integer;
      Lidp: Idp;
      Lfileptr: Idp;  
      Lptr: Localidp;

   BEGIN (*enterbody*)
   IF Fprocp <> NIL THEN (* entering body of a procedure or function *)
      BEGIN
      IF Regreflist <> NIL THEN
	 BEGIN
	 Lptr := Regreflist;
	 WHILE Lptr^.Next <> NIL DO
	    WITH Lptr^.Next^.Mainrec^ DO
	       IF (Not Referenced AND Not Assignedto) OR (Idtype = NIL) THEN
		  Lptr^.Next := Lptr^.Next^.Next
	       ELSE Lptr := Lptr^.Next;
	 WITH Regreflist^.Mainrec^ DO
	    IF (Not Referenced AND Not Assignedto) OR (Idtype = NIL) THEN
	       Regreflist := Regreflist^.Next;
         END;
      Uco1idp(Uent,Fprocp);
      Ucoid(Fprocp^.Idname);
      IF (Machine = 10) AND (Maxlocreg < Minlocreg) THEN
	  (* old style *)
          Uco4int (Uregs, 1, Fprocp^.Pfmemblock, 0, Regsmemcnt);
      FOR I := Level - 1 DOWNTO 1 DO
         Uco2intint(Ulex,I,Display[I].Mblock);
      GenPstrs (Fprocp^.Next);
      IF Maxlocreg >= Minlocreg THEN
          Uco4int (Uregs, 0, 1, Minlocreg, Maxlocreg-Minlocreg+Regsize);
      Lidp := Fprocp^.Next;
      WHILE Lidp <> NIL DO     (* generate Movs for large parameters *)
         BEGIN
         IF Lidp^.Idtype <> NIL THEN
            WITH Lidp^,Idtype^ DO
               IF (Vkind = Actual) AND ((Stdtype = Mdt) OR 
                                       (Stsize > Parthreshold)) THEN
                 BEGIN
                 Ucolda(Stdtype,Vmty,Vblock,Vaddr,Pointersize);
                 Uco5typaddr(Ulod,Adt,Vindtype,Vblock,Vindaddr,Pointersize);
                 Uco2typint(Umov,Mdt,Stsize);
                 END;
         Lidp := Lidp^.Next;
         END;
      IF Fprocp^.Filelist <> NIL THEN
         Zerovars (Fprocp^.Filelist);
      END
   ELSE             (* Fprocp = NIL: entering the main program *)
      BEGIN
      Uco1idp(Uent,Progidp);
      Ucoid (Progidp^.Idname);
      GenStdfileinit;
      END  (*fprocp = nil*);
   END (*enterbody*);


PROCEDURE Leavebody;

   (* finishes code for a body, i.e. PLOD,DEFs,RET,END; *)
   VAR
      Lmty: Memtype;
      Lfileptr: Idp; 

   BEGIN  (*leavebody*)
   Checksyms (Display[Level].Fname);  (* check consts and variables *)
   IF Emitsyms THEN               (* print end-of-proc marker *)
      begin
      Writeln (Symtbl);
      Writeln (Symtbl,'#');   
      end;
   FOR Lmty:= Pmt TO Mmt DO
      IF NOT Localsbackwards or (Lmty <> Mmt) THEN
         Roundup (Memcnt[Lmty], SpAlign)
      ELSE
         Rounddown (Memcnt[Lmty], SpAlign);
   IF Fprocp = NIL THEN      (* fprocp = nil <=> leaving main body.*)
      BEGIN
      Ucoloc(Linecnt,Pagecnt,0);
      Uco0(Uret);
      FOR Lmty := Pmt to Mmt DO
         IF Lmty <> Smt THEN
            IF Memcnt[Lmty] <> 0 THEN Ucodef(Lmty,Abs(Memcnt[Lmty]));
      Uco1idp(Uend,Progidp);
      END
   ELSE        (* fprocp <> nil <=> leaving a procedure or function*)
      BEGIN
      IF Fprocp^.Klass = Func THEN
         Uco1idp(Uplod,Fprocp);
      Ucoloc(Linecnt,Pagecnt,0);
      Uco0(Uret);
      FOR Lmty := Pmt to Mmt DO
         IF Memcnt[Lmty] <> 0 THEN Ucodef(Lmty,Abs(Memcnt[Lmty]));
      Uco1idp(Uend,Fprocp);
      END;
   END(*leavebody*);


(*Load,Store,Loadaddress*)

(************************************************************************)
(*                                                                      *)
(* LOADADDRESS -- loads address of an Attr onto the stack               *)
(* If the address of FATTR has already been loaded, then does nothing   *)
(* UNLESS there is a constant non-zero displacement, in which case it   *)
(* emits an IXA to combine the displacement with the base address;      *)
(* if it has NOT been loaded, then loads it, and updates ATTR to        *)
(* reflect that fact.                                                   *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Load(VAR Fattr: Attr); FORWARD; 

PROCEDURE Loadaddress(var FATTR: ATTR);

   BEGIN (*loadaddress*)
   WITH Fattr DO
      IF Atypep <> NIL THEN
         BEGIN
         CASE Kind OF
            Cnst:
               IF String(Atypep) THEN
                  Uco1attr(Ulca,Fattr)
               ELSE
                  Error(171);
            Varbl:
               BEGIN
               IF Indirect THEN
                  BEGIN
		  Uco5typaddr(Ulod,Adt,Indexmt,Ablock,Indexr,Pointersize);
		  Indirect := False;
		  Indexed := True;
                  END;
               IF Indexed THEN
                  BEGIN
                  IF Dplmt < 0 THEN
                     Uco2typint(Udec,Adt,Abs(Dplmt))  
                  ELSE IF Dplmt > 0 THEN
                     Uco2typint(Uinc,Adt,Dplmt)  
                  END  (*if indexed*)
               ELSE     (*not indexed*)
                  Uco1attr(Ulda,Fattr);
               END  (*varbl*);
            Expr:
               Error(171)
         END;
         Kind := Varbl;  Dplmt := 0; Aclass := Vars; Indexed := True;
         END
   END (*loadaddress*) ;
(************************************************************************)
(*                                                                      *)
(*  LOAD - loads an Attr onto the stack                                 *)
(*                                                                      *)
(*  If fattr is a constant or variable, generates code to load it on    *)
(*  the stack, if it has not already been loaded (this is always the    *)
(*  case when fattr is an expression).  if it is too big to be loaded   *)
(*  on the stack, loads its address, if it has not already been loaded  *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Load(*(var fattr: attr)*);
   BEGIN (*load*)
   WITH Fattr DO
      IF Atypep<>NIL THEN
         BEGIN
         CASE Kind OF
            Expr: ;   
            Cnst:
               IF Atypep^.Stdtype = Mdt THEN  
                  Uco1attr(Ulca,Fattr)
               ELSE
                  Uco1attr(Uldc,Fattr);
            Varbl:
               BEGIN
               IF Indirect THEN
		  BEGIN
		  Uco5typaddr(Ulod,Adt,Indexmt,Ablock,Indexr,Pointersize);
		  Indirect := False;
		  Indexed := True;
		  END; (* IF Indirect *)
               IF Indexed THEN
                  BEGIN
                  IF Atypep^.Stdtype <> Mdt THEN
                     BEGIN
                     Uco1attr(Uilod,Fattr);
                     Indexed := False;
                     END
                  ELSE (*too big*)
                     BEGIN
                     IF Dplmt <> 0 THEN
                        BEGIN
                        IF Dplmt < 0 THEN
                           Uco2typint(Udec,Adt,Abs(Dplmt))  
                        ELSE IF Dplmt > 0 THEN
                           Uco2typint(Uinc,Adt,Dplmt)  
                        END;
                     END (*too big*);
                  END  (*if indexed*)
               ELSE  (*not indexed*)
                  IF Atypep^.Stdtype = Mdt THEN   
                     Loadaddress(Fattr)
                  ELSE
                     Uco1attr(Ulod,Fattr)
               END;
            END (*case kind of*);
         IF  Atypep^.Stdtype <> Mdt THEN Kind := Expr;  
         END (*if atypep <> nil*)
   END  (*load*) ;


(************************************************************************)
(*                                                                      *)
(* STORE                                                                *)
(*                                                                      *)
(* Generates code to store the value on top of the stack in the memory  *)
(* location described by FATTR.  If the value is too large to fit on    *)
(* the stack, a MOV is used to do the store.  If the address of FATTR   *)
(* already been loaded (e.g. FATTR describes a location in an array),   *)
(* then an ISTR is used.                                                *)
(*                                                                      *)
(************************************************************************)


PROCEDURE Store(VAR Fattr: Attr);

   BEGIN (*store*)
   WITH Fattr DO
      IF Atypep <> NIL THEN
         BEGIN
         IF Indirect THEN
            BEGIN
	    Uco5typaddr(Ulod,Adt,Indexmt,Ablock,Indexr,Pointersize);
	    Indirect := False;
	    Indexed := True;
            Uco2typtyp(Uswp,Adt,Gattr.Adtype);
            END;
         IF NOT Indexed THEN
            IF Atypep^.Stdtype = Mdt THEN Error(171);  
         IF Indexed THEN
            IF Atypep^.Stdtype = Mdt THEN  
               BEGIN       (*two addresses on the stack*)
               Uco2typint(Umov,Atypep^.Stdtype,Atypep^.Stsize);
               END
            ELSE    (*a value into an address, both on the stack*)
               Uco1attr(Uistr,Fattr)
         ELSE    (*not indexed*)
            Uco1attr(Ustr,Fattr)
         END (*if atypep <> nil*)
   END (*store*) ;


(*Getatemp,Freetemps,Findnextregtemp*)

PROCEDURE Statement(Fsys,Statends: Setofsys);

   (* processes a statement *)

   VAR
      Lidp: Idp;

   PROCEDURE Expression(Fsys: Setofsys); FORWARD;

   PROCEDURE Assignment(Fidp: Idp); FORWARD;

   PROCEDURE Getatemp (VAR Fattr: Attr; Fstrp: Strp; VAR Stamp: Integer; 
		       Regok: Boolean);
      (* reserves a temporary location for an intermediate result
       corresponding to the type pointed to by FSTR and puts a description
       of it in FATTR *)

      LABEL 11;
	     
      VAR
	 I, Tempnum: Integer;
      BEGIN  (*getatemp*)
      IF Stamp = 0 THEN
	 BEGIN
	 Stampctr := Stampctr + 1;
	 Stamp := Stampctr;
	 END;
      IF Fstrp <> NIL THEN
	 BEGIN
	 (* try to re-use old temporary *)
	 FOR I := 1 to Tempcount DO
	    WITH Temps[I] DO
	     IF Free AND (Fstrp^.Stsize <= Size) AND 
	       (RegOK OR (Offset < Minlocreg) OR (Offset > Maxlocreg)) THEN
	       BEGIN
	       Tempnum := I;
	       GOTO 11;
	       END;
	 (* no free temps; create a new one *)
	 IF Tempcount = Maxtemps THEN
	    Error (171)   (* Compiler error *)
	 ELSE Tempcount := Tempcount + 1;
         WITH Temps[Tempcount] DO
            BEGIN
            Size := Fstrp^.Stsize;
            Mty := Findmemorytype (Fstrp^.Stdtype,Size, False, True);
            Offset := Assignnextmemoryloc (Mty, Size);
	    END;
	 Tempnum := Tempcount;
   11:   Temps[Tempnum].Free := False;
	 Temps[Tempnum].Stamp := Stamp;
         WITH Fattr DO
            BEGIN
            Amty := Temps[Tempnum].Mty;
            Dplmt := Temps[Tempnum].Offset;
	    Baseaddress := Dplmt;
            Atypep := Fstrp;
            Adtype := Fstrp^.Stdtype;
            Kind := Varbl;
            Ablock := Memblock;  
            Indirect := False;
            Indexed := False;
            Apacked := False;
            Rpacked := False;
            Fpacked := False;(** 10MAR *)
            Subkind := NIL;
            Aclass := Vars;
            END (*with*);
	 END;
      END (*getatemp*);

   PROCEDURE Freetemps (FStamp: Integer);
      (* Free all temps that have stamp FSTAMP *)
      VAR I: integer;
      BEGIN 
      FOR I := 1 to Tempcount DO
	 WITH Temps[I] DO
	    IF Stamp = Fstamp THEN
		IF Free THEN Error (171)   (* compiler error *)
		ELSE Free := True;
      END;


   FUNCTION Findnextregtemp (Nestlev: Integer; VAR Reg: Integer; VAR Mtyp: Memtype; 
		             VAR Offst: Integer): Boolean;

      (* Find next register temp (that is, one that has a stamp of < 0).
         Free it, or return FALSE if there are no more. *)

      LABEL 99;
      VAR I: integer;
      

      BEGIN 
      Findnextregtemp := True;
      FOR I := 1 to Tempcount DO
	 WITH Temps[I] DO
	    IF Stamp < 0 THEN
	        IF -Stamp DIV 10000 = Nestlev THEN
		   BEGIN
		   IF Free THEN Error (171)   (* compiler error *)
		   ELSE Free := True;
	           Reg := -Stamp MOD 10000;
	           IF Localsbackwards THEN Reg := -Reg;
		   Mtyp := Mty;
		   Offst := Offset;
		   Stamp := 0;
		   GOTO 99;
		   END;
      Findnextregtemp := False;
99:   END;


(*Selector*)

(************************************************************************)
(*                                                                      *)
(*      SELECTOR -- given a variable pointed to by FIDP, parses any     *)
(*        subscripts, fields references, or uparrows, collapsing        *)
(*        constants where possible and generating code as necessary.    *)
(*        A description of the address of the object is returned in     *)
(*        Gattr.                                                        *)
(*                                                                      *)
(*      In most cases, the final result will be a single simple         *)
(*      object (e.g. REC.ARRAY1[I]^.J), but occasionally it will        *)
(*      be a whole complex object, as in the assignment statement       *)
(*                ARRAY1 := ARRAY2;                                     *)
(*                                                                      *)
(************************************************************************)


PROCEDURE Selector(Fsys: Setofsys; Fidp: Idp);

   VAR
      I: Integer;
      Found: Boolean;
      Lattr,L2attr: Attr;
      Lidp: Idp;
      Parcount: Integer; 
      Parsingleft,Parsingright: Boolean;
      Lstamp: Integer;

   PROCEDURE Addindex;

      VAR
	 Lmin,Lmax,Indexvalue, Elementsize: Integer;
         Lstrp: Strp;
	 Elementsperword: Bitrange;
         Lowboundfolded: Boolean;

   PROCEDURE Foldlowbound;
      (* Attempts to fold lowerbound of subscript into base address.  Only does
         this in easy cases *)
      BEGIN
      Lowboundfolded := (Lattr.Kind = Varbl) AND NOT (Lattr.Indexed) 
         AND NOT (Lattr.Indirect) AND 
         ((Elementsize >= Salign) OR (Salign MOD Elementsize = 0)) AND
	 (Elementsize MOD Addrunit = 0);
      IF Lowboundfolded THEN
         Lattr.Dplmt := Lattr.Dplmt - (Lmin * Elementsize);
      END;
	
   PROCEDURE Sublowbound;
      (* Adjusts a subindex by the low bound of its type, checking the bounds
         if necessary.  Tries to emit a zero lower bounds check, for machines
         that have a check instruction of that format *)
      VAR
         Llmin, Llmax: Integer;
      BEGIN (*sublowbound*)
      WITH Gattr DO
         BEGIN
	 IF NOT Lowboundfolded THEN
	    IF Lmin > 0 THEN
	       Uco2typint(Udec,Adtype,Lmin)
	    ELSE
	       IF Lmin < 0 THEN
		  Uco2typint(Uinc,Adtype,Abs(Lmin));
         IF Runtimecheck THEN
            BEGIN
            Getbounds(Atypep,Llmin,Llmax);
            IF Llmin < Lmin THEN
	       IF Lowboundfolded THEN
                  Uco2typint(Uchkl,Adtype,Lmin) 
               ELSE Uco2typint(Uchkl,Adtype,0);
            IF Llmax > Lmax THEN
	       IF Lowboundfolded THEN
                  Uco2typint(Uchkh,Adtype,Lmax) 
               ELSE Uco2typint(Uchkh,Adtype,Lmax-Lmin);
            END;
         END (*with gattr*);
      END (*sublowbound*);

   BEGIN (* addindex *)
   (* get next index *)
   Lattr := Gattr; Indexvalue := 0 ;
   WITH Lattr DO
      BEGIN
      IF Atypep <> NIL THEN
	 BEGIN
	 IF Atypep^.Form <> Arrays THEN
	    BEGIN
	    Error(307); Atypep := NIL
	    END;
	 END;
      Lstrp := Atypep;  
      END;
   Insymbol;
   Expression(Fsys + [Commasy,Rbracksy]);
   IF Gattr.Atypep <> NIL THEN
      IF Gattr.Atypep^.Form <> Scalar THEN
	 Error(403);
   Lmin := 0; Lmax := 0; Elementsize := Salign;
   IF Lattr.Atypep <> NIL THEN
      WITH Lattr.Atypep^ DO
	 BEGIN
	 (* make sure index is right type and check value if possible *)
	 IF Comptypes(Inxtype,Gattr.Atypep) THEN
	    BEGIN
	    Getbounds(Inxtype,Lmin,Lmax);
	    IF Gattr.Kind = Cnst THEN
	       IF (Gattr.Cval.Ival < Lmin) OR (Gattr.Cval.Ival > Lmax) THEN
		  Error(263)
	    END
	 ELSE    (*not comptypes(inxtype,gattr.atypep*)
	    Error(457);
	 Elementsize := Aelsize;
	 END;
   (* if the subscript is a constant, try to calculate the address 
      now *)
   IF  Gattr.Kind = Cnst THEN
      Indexvalue := Gattr.Cval.Ival
   ELSE
      (* put it on stack, making sure the base address is loaded *)
      IF Gattr.Kind = Varbl THEN
	 BEGIN
	 IF Gattr.Indexed THEN
	    BEGIN
	    Load(Gattr);  (* resolve Gattr fully *)
	    IF Lattr.Kind <> Expr THEN (* and then load Lattr *)
	       BEGIN
	       IF Lattr.Indexed THEN Uco2typtyp(Uswp,Gattr.Adtype,Adt);
	       Foldlowbound;
	       Loadaddress(Lattr);
	       Uco2typtyp(Uswp,Adt,Gattr.Adtype);
	       END
	    END
	 ELSE
	    BEGIN
	    Foldlowbound;
	    Loadaddress(Lattr);
	    Load(Gattr)
	    END
	 END
      ELSE (* gattr = expr, already loaded *)
	 IF NOT Lattr.Indexed THEN
	    BEGIN
	    Foldlowbound;
	    Loadaddress(Lattr);
	    Uco2typtyp(Uswp,Adt,Gattr.Adtype);
	    END;
   IF Lattr.Atypep <> NIL THEN
      WITH Lattr.Atypep^ DO
	 BEGIN
	 Lattr.Apacked := Arraypf;
	 (* change Lattr to be the type of the array element *)
	 Lattr.Atypep := Aeltype;
	 IF Aeltype <> NIL THEN
	    Lattr.Adtype := Aeltype^.Stdtype
	 ELSE
	    Lattr.Adtype := Zdt;
	 END;
   (* combine this index with the current address on top of the stack or 
      generate code to do so *)
   IF Lattr.Atypep <> NIL THEN 
	IF  Gattr.Kind = Cnst THEN
	   BEGIN
	   Indexvalue := Indexvalue - Lmin;
	   IF (Elementsize < Salign) AND 
	      (Salign MOD Elementsize > 0) THEN
	       BEGIN (* uneven packing *)
	       Elementsperword := Salign DIV Elementsize;
	       Lattr.Dplmt := Lattr.Dplmt + 
		 (Indexvalue DIV Elementsperword) * Salign + 
		 (Indexvalue MOD Elementsperword) * Elementsize;
	       END
	   ELSE Lattr.Dplmt := Lattr.Dplmt + Indexvalue * Elementsize;
	   END
	ELSE
	   BEGIN
	   Sublowbound;
	   Uco2typint(Uixa,Gattr.Adtype,Elementsize); 
	   END;
   Gattr := Lattr
   END; (* addindex *)

   BEGIN (*Selector*)
   WITH Fidp^, Gattr DO
      BEGIN
      Atypep := Idtype; Kind := Varbl; Aclass := Klass; Indexed := False;
      Apacked := False; Rpacked := False; Fpacked := False; Subkind := NIL;
      IF Atypep <> NIL THEN
         Adtype := Atypep^.Stdtype
      ELSE
         Adtype := Zdt;
      (* first, put in GATTR a description of the variable parsed so far *)
      CASE Klass OF
         Vars:                              (*variable*)
            BEGIN
            IF Parseright THEN Referenced := True;   
            IF Parseleft THEN Assignedto := True;
            Ablock := Vblock;  Dplmt := Vaddr;  
            Amty := Vmty; Baseaddress := Dplmt;
            IF Vkind = Formal THEN
               BEGIN
               Indirect := True;
               Indexmt := Amty;
               Indexr := Dplmt;
               Dplmt := 0;
               END
            ELSE
               Indirect := False;
            END (*vars:*);
         Field:                             (*field of a record*)
            (* get the address of the record from the display *)
            WITH Display[Disx] DO
               IF Occur = Crec THEN
                  BEGIN
                  Amty := Cmty; Ablock := Mblock;
                  Ablock := Cblock;     
                  Rpacked := Inpacked;
                  Indexr := Cindexr; Indirect := Cindirect;
                  Indexed := Cindexed; Indexmt := Cindexmt;
                  Dplmt:= Cdspl + fldaddr;
                  END
               ELSE
                  Error(171);
         Func:                              (*function result*)
            
            BEGIN
            (* assignment to a function is only legal if the function is
               currently active, which means it should be on the display *)
            I := Top; Found := False;
            IF Prockind = Regular THEN
               While NOT Found AND (I > 1) DO
                  BEGIN
                  WITH Display[I] DO
                     Found := (Occur = Blck) AND (Mblock = Pfmemblock);
                  I := I - 1;
                  END;
            IF NOT Found THEN
               Error(453)
            ELSE 
               BEGIN
               Indexr := 0;
               Amty := Resmemtype; Ablock := Pfmemblock;   
               Dplmt := Resaddr; Baseaddress := Resaddr;
               Fassigned := True; Indirect := False;
               END
            END (* func *)
         END  (*case klass of*)
      END (*with fidp^, gattr*);
   Iferrskip(166,Selectsys + Fsys);

   (* next, process any subscripts, uparrows, or field references *)
   WHILE Sy IN Selectsys DO
      BEGIN
      Gattr.Apacked := False;
      Gattr.Rpacked := False;
      Gattr.Fpacked := False;
      IF Sy = Lbracksy THEN
         BEGIN                      (* [ : array subscripts *)
         Parsingleft := Parseleft;
         Parsingright := Parseright;
         Parseleft := False;
         Parseright := True;
         (* load base address *)
         IF Gattr.Indirect THEN Loadaddress(Gattr);  
         REPEAT
	    Addindex
         UNTIL Sy <> Commasy (*for each subscript*);
         IF Sy = Rbracksy THEN         (*parse the right bracket*)
            Insymbol
         ELSE
            Error(155);
         Parseleft := Parsingleft;
         Parseright := Parsingright;
         END (*if sy = lbracksy*)
      ELSE
         IF Sy = Periodsy THEN                (* . : fields of a record*)
            BEGIN
            WITH Gattr DO
               BEGIN
               IF Atypep <> NIL THEN
                  IF Atypep^.Form <> Records THEN
                     BEGIN
                     Error(308); Atypep := NIL
                     END;
               Insymbol;
               IF Sy = Identsy THEN
                  BEGIN
                  IF Atypep <> NIL THEN
                     BEGIN
                     (* find the field in the symbol table *)
                     Searchsection(Atypep^.Recfirstfield,Lidp);
                     IF Lidp = NIL THEN
                        BEGIN
                        Error(309); Atypep := NIL
                        END
                     ELSE
                        BEGIN
                        WITH Lidp^ DO
                           BEGIN
                           (* combine the field offset with whatever
                              we have so far in Dplmt *)
                           Dplmt := Dplmt + Fldaddr;
                           Atypep := Idtype;  Rpacked := Inpacked;
                           IF Idtype <> NIL THEN
                              Adtype := Idtype^.Stdtype
                           ELSE
                              Adtype := Zdt;
                           END
                        END
                     END;
                  Insymbol
                  END (*sy = identsy*)
               ELSE
                  Error(209)
               END (*with gattr*);
            END (*if sy = periodsy*)
         ELSE  (* sy = arrowsy *)
            BEGIN                           (* ^ : pointers and files*)
            IF Gattr.Atypep <> NIL THEN
               WITH Gattr DO
                  IF NOT (Atypep^.Form IN [Pointer,Files]) THEN
                     Error(407)
                  ELSE
                     IF Atypep^.Form = Pointer THEN
                        BEGIN
                        Load(Gattr);
                        Atypep := Atypep^.Eltype; 
                        IF Atypep <> NIL THEN
                           Adtype := Atypep^.Stdtype;
                        Indexed := True;
                        Dplmt := 0;
                        Kind := Varbl;
                        Aclass := Vars;
			Apacked := False;
			Rpacked := False;
			Fpacked := False;
                        (*  check for nil pointer *)
                        IF Runtimecheck OR Indirect OR Indexed THEN
                           BEGIN
                           Loadaddress(Gattr);
                           IF Runtimecheck THEN
                              Uco0(Uchkn);
                           Indexed := True;
                           END (*runtimecheck ...*);
                        Fidp^.Referenced := True;
                        END (*ATYPEP^.FORM = pointer*)
                     ELSE (*ATYPEP^.FORM = files*)
                        BEGIN
		        (* Load the address of the buffer *)
  		        Fpacked := Atypep^.Filepf;
   		        Dplmt := Dplmt + Fdbsize;
			Kind := Varbl; Aclass := Vars;
                        Atypep := Atypep^.Filetype;
                        END;
            Insymbol
            END (*^*);
      Iferrskip(166,Fsys + Selectsys)
      END (*while sy in selectsys*);
   WITH Gattr DO
      IF Atypep <> NIL THEN
         Adtype := Atypep^.Stdtype;
   END (*Selector*) ;



(*Loadboth,Matchtypes,Matchtoassign,Makereal,Loadandcheckbounds*)

(************************************************************************)
(*                                                                      *)
(*      LOADBOTH -- generates code to load two items on the stack       *)
(*                                                                      *)
(*      Neither or one or both items may be already loaded on the       *)
(*         stack, or already partially loaded on the stack (e.g.,       *)
(*         its address may be on the stack but not the item itself.     *)
(*         This procedure generates code to get them both fully         *)
(*         loaded, and in the right order.                              *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Loadboth(VAR Fattr: Attr);

   FUNCTION Realtype (Lattr:Attr): Datatype;
      BEGIN
       
      WITH Lattr.Atypep^ DO
         IF (Stdtype = Mdt) THEN
            Realtype := Adt
         ELSE Realtype := Lattr.Adtype;
      END;

   BEGIN
   WITH Gattr DO
      IF Fattr.Kind = Expr THEN
         BEGIN           (*first one on the stack. push second*)
         IF Kind <> Expr THEN
            Load(Gattr)
         END
      ELSE IF Kind = Expr THEN
         BEGIN           (*second one on the stack. push first and swap*)
         IF (Fattr.Kind=Varbl) AND Fattr.Indexed THEN
            Uco2typtyp(Uswp,Realtype(Gattr),Adt);
         Load(Fattr);
         Uco2typtyp(Uswp,Realtype(Fattr),Realtype(Gattr));
         END
      ELSE IF (Kind = Varbl) AND Indexed THEN
         BEGIN           (*second one indexed by the stack. load, push, swap*)
         Load(Gattr);
         IF (Fattr.Kind=Varbl) AND Fattr.Indexed THEN  (*both indexed*)
            Uco2typtyp(Uswp,Realtype(Gattr),Adt);
         Load(Fattr);
         Uco2typtyp(Uswp,Realtype(Fattr),Realtype(Gattr));
         END
      ELSE  (* neither is in any way referred to in the stack *)
         BEGIN
         Load(Fattr);
         Load(Gattr);
         END;
   END (*loadboth*);


(************************************************************************)
(*                                                                      *)
(*      MATCHTYPES  -- matches the types of Fattr and Gattr             *)
(*          according to the following rules, in rigorous order:        *)
(*                                                                      *)
(*     1. if they are already matched, noop.                            *)
(*     2. if any of them is not integer nor real, noop.                 *)
(*     4. if one is type R (real), convert the other.                   *)
(*     5. if one is type L (positive integer), convert it to the other. *)
(*                                                                      *)
(************************************************************************)


PROCEDURE Matchtypes(VAR Fattr: Attr);

  BEGIN
  IF (Fattr.Adtype <> Gattr.Adtype) AND (Gattr.Adtype IN [Jdt,Ldt,Rdt]) AND
     (Fattr.Adtype IN [Jdt,Ldt,Rdt]) THEN
      BEGIN
      IF (Fattr.Kind=Cnst) AND (Gattr.Kind=Cnst) AND (Fattr.Adtype IN [Jdt,Ldt])
         AND (Gattr.ADtype IN [Jdt,Ldt]) THEN
            BEGIN (* one is Ldt *)
            Gattr.Adtype := Jdt;
            Fattr.Adtype := Jdt;
            END
      ELSE
         BEGIN 
         Loadboth(Fattr);
         IF Gattr.Adtype = Rdt THEN
            BEGIN
            Uco2typtyp(Ucvt2,Rdt,Fattr.Adtype);
            Fattr.Atypep := Realptr;
            END
         ELSE (* Gattr.Adtype = [Jdt,Ldt] *)
            BEGIN
            IF Fattr.Adtype = Rdt THEN
                BEGIN
                Uco2typtyp(Ucvt,Rdt,Gattr.Adtype);
                Gattr.Atypep := Realptr;
                END
            ELSE IF (Gattr.Adtype = Ldt) AND (Fattr.Adtype = Jdt) THEN
                BEGIN
                Uco2typtyp(Ucvt,Fattr.Adtype,Gattr.Adtype);
                Gattr.Atypep := Fattr.Atypep;
                END
            ELSE IF (Fattr.Adtype = Ldt) AND (Gattr.Adtype = Jdt) THEN
                BEGIN
                Uco2typtyp(Ucvt2,Gattr.Adtype,Fattr.Adtype);
                Fattr.Atypep := Gattr.Atypep;
                END;
            END; 
         END; (* not both constants *)

     Fattr.Adtype := Gattr.Atypep^.Stdtype;
     Gattr.Adtype := Gattr.Atypep^.Stdtype;
     END  (* Fattr.adtype<>Gattr.adtype *)
  END; (* matchtypes *)


PROCEDURE Matchtoassign(VAR Fattr: Attr; Ftypep: Strp);

   (* Matches the type of Fattr to Ftypep.  Fattr.Kind should be Expr *)

   VAR
      Ldtype: Datatype;

   BEGIN (*matchtoassign*)
   IF Ftypep <> NIL THEN   
      WITH Ftypep^, Fattr DO
         IF Stdtype <> Adtype THEN
            BEGIN
            IF Stdtype = Rdt THEN
               Uco2typtyp(Ucvt,Stdtype,Adtype)
            ELSE
               BEGIN
               IF (Adtype IN [Bdt,Cdt,Jdt,Ldt]) AND 
                   (Stdtype IN [Bdt,Cdt,Jdt,Ldt]) THEN
                     Uco2typtyp(Ucvt,Stdtype,Adtype)  
               ELSE (*convert required*)
                  BEGIN
                  IF Stdtype IN [Jdt,Ldt] THEN
                     Ldtype := Stdtype
                  ELSE
                     Ldtype := Jdt;
                  Uco2typtyp(Ucvt,Ldtype,Adtype);
                  IF Ldtype <> Stdtype THEN
                     Uco2typtyp(Ucvt,Stdtype,Jdt);  
                  END;
               END;
            Atypep := Ftypep;
            Adtype := Stdtype;
            END (*if stdtype <> adtype*);
   END (*matchtoassign*);

PROCEDURE Makereal (VAR Fattr: Attr);

   (* same as Matchtypes, but the result MUST be real, even if both
      Fattr and Gattr are of type integer (used for real divide) *)

   BEGIN (*makereal*)                   
   WITH Gattr DO
      IF ((Fattr.Adtype <> Rdt) OR (Adtype <> Rdt)) AND
         (Fattr.Adtype IN [Jdt,Ldt,Rdt]) AND 
         (Adtype IN [Jdt,Ldt,Rdt]) THEN
            BEGIN
            Loadboth(Fattr);
            (*will make it type r*)
            IF Adtype <> Rdt THEN
               BEGIN
               Uco2typtyp(Ucvt,Rdt,Adtype);
               Adtype := Rdt; Atypep := Realptr;
               END;
            IF Fattr.Adtype <> Rdt THEN
               BEGIN
               Uco2typtyp(Ucvt2,Rdt,Fattr.Adtype);
               Fattr.Adtype := Rdt; Fattr.Atypep := Realptr;
               END
            END 
   END (*makereal*);

PROCEDURE Loadandcheckbounds(VAR Fattr: Attr; Fboundtypep: Strp);

   (* Loads Fattr and makes sure it is within the bounds of Fboundtypep^ *)

   VAR
      Bmin, Bmax,
      Cmin,Cmax: Integer;

   BEGIN (*loadandcheckbounds*)
   IF Fboundtypep <> NIL THEN
      BEGIN
      Getbounds(Fboundtypep,Cmin,Cmax);
      WITH Fattr DO
         IF Kind = Cnst THEN
            BEGIN
            WITH Cval DO
               IF Adtype IN [Bdt,Cdt,Jdt,Ldt] THEN
                     IF (Ival < Cmin) OR (Ival > Cmax) THEN
                        Error(367);
            Load(Fattr);
            Matchtoassign(Fattr,Fboundtypep);
            (* this could be improved by matching before loading *)
            END (*kind = cnst*)
         ELSE     (*kind in [varbl,expr]*)
            BEGIN
            Load(Fattr);
            Matchtoassign(Fattr,Fboundtypep);
            IF Runtimecheck AND
               ((Kind<>Varbl) OR (Subkind <> Fboundtypep))
            THEN
               BEGIN
               Getbounds(Atypep,Bmin,Bmax);
               IF Bmin < Cmin THEN
                  Uco2typint(Uchkl,Adtype,Cmin);
               IF Bmax > Cmax THEN
                  Uco2typint(Uchkh,Adtype,Cmax);
               END (*if runtimecheck*)
            END;
      END (*if fboundtypep <> nil*)
   END (*loadandcheckbounds*);




(*Shiftset,Matchsets,Adjtosetoffset,Setmatchtoassign*)

(************************************************************************)
(*                                                                      *)
(*      SET ADJUSTING PROCEDURES                                        *)
(*                                                                      *)
(*      For any set operations, the size and lower offset of the        *)
(*      set or sets involved must be taken into account.  These         *)
(*      procedures are involved with that.                              *)
(*                                                                      *)
(*      SHIFTSET -- does the equivalent of an ADJ on a constant set     *)
(*      MATCHSETS -- matches two sets before doing a binary operation   *)
(*        on them                                                       *)
(*      SETMATCHTOASSIGN -- adjusts the set on top of the stack to      *)
(*        correspond to the set variable it will be assigned to         *)
(*      ADJTOSETOFFSET -- adjusts a scalar to conform to a lower offset *)
(*        of a set before an INN opeation                               *)
(*                                                                      *)
(************************************************************************)


PROCEDURE Shiftset  (VAR Setval: Valu; Shift, Finallength: Integer);

   (* shifts a set constant *)

   VAR I,Maxindex: Integer;
   BEGIN
   WITH Setval DO
      BEGIN
      Shift := Shift DIV 4;
      IF Shift > 0 THEN
	 BEGIN
	 (* shift up *)
	 FOR I := Len DOWNTO 1 DO
	    Chars[I+Shift] := Chars[I];
	 FOR I := 1 TO Shift DO
	    Chars[I] := '0';
	 END
      ELSE IF Shift < 0 THEN
	 BEGIN
	 (* shift down *)
	 Shift := - Shift;
	 FOR I := 1 TO Len - Shift DO
	    Chars[I] := Chars[I+Shift];
	 IF Len > Shift THEN
	    FOR I := Len - Shift + 1 TO Len DO
               Chars[I] := '0';
	 END;
      Len := Finallength DIV 4;
      END;
   END;

PROCEDURE Matchsets (VAR Fattr: Attr);

   (* adjusts the sets represented by FATTR and GATTR to have the same offset 
      and length *)

   VAR Hmin, Hmax, Smin, Smax, Setsize: Integer; (* characteristics of new set*)
       Gadj, Fadj: Boolean; (* Do Gattr, Fattr need to be adjusted? *)
       Gadjusted, Fadjusted: Boolean; (* Flags partial adjustment *)
       Toolarge: Boolean;

   BEGIN
   IF (Gattr.Atypep <> NIL) AND (Fattr.Atypep <> NIL) AND
      (Gattr.Atypep <> Fattr.Atypep) THEN
         BEGIN (* adjust sets *)
         (* find the new hard min and max *)
         Hmin := Min (Fattr.Atypep^.Hardmin, Gattr.Atypep^.Hardmin);
         Hmax := Max (Fattr.Atypep^.Hardmax, Gattr.Atypep^.Hardmax);
         Toolarge := False;
         (* this next check must be done carefully, since Hmin can be MAXINT
            while Hmin is MININT *)
         IF Hmin < Hmax THEN
            IF Hmax - Hmin + 1 > Maxsetsize THEN
               BEGIN
               Error (177);
               Toolarge := True;
               END;
         IF NOT Toolarge THEN
            BEGIN (* not too big *)
            (* find the new soft min and max *)
            Smin := Min (Fattr.Atypep^.Softmin, Gattr.Atypep^.Softmin);
            (* make sure SMIN is large enough so that resulting set will be big
               enough to hold HMAX without exceeding the max possible length *)
            IF Hmax > Smin THEN
               IF Hmax - Smin + 1 > Maxsetsize THEN
                  Smin := Hmax - Maxsetsize + 1;
            Smax := Max (Fattr.Atypep^.Softmax, Gattr.Atypep^.Softmax);
            (* make sure SMAX is small enough so that resulting set won't be
               too big *)
            IF Smax - Smin + 1 > Maxsetsize THEN
               Smax := Smin + Maxsetsize - 1;
            Setsize := Smax - Smin + 1;
            WITH Fattr.Atypep^ DO
               BEGIN (* if Fattr is a constant and needs adjusting, do it *)
               Fadj := (Smin - Softmin <> 0) OR (Setsize - Stsize <> 0);
               IF Fadj AND (Fattr.Kind = Cnst) THEN
                  BEGIN
                  Shiftset (Fattr.Cval, Softmin - Smin, Setsize);
                  Stsize := Setsize;
                  Fadjusted := True;
                  END
               ELSE Fadjusted := False;
               END;
            WITH Gattr.Atypep^ DO
               BEGIN (* if Gattr is a constant and needs adjusting, do it *)
               Gadj := (Smin - Softmin <> 0) OR (Setsize - Stsize <> 0);
               IF Gadj AND (Gattr.Kind = Cnst) THEN
                  BEGIN
                  Shiftset (Gattr.Cval, Softmin - Smin, Setsize);
                  Stsize := Setsize;
                  Gadjusted := True;
                  END
               ELSE Gadjusted := False;
               END;
            IF (Fadj AND NOT Fadjusted) OR (Gadj AND NOT Gadjusted) THEN
               BEGIN (* emit code for runtime Adjust *)
               Loadboth (Fattr);
               IF Gadj AND NOT Gadjusted THEN
                  BEGIN
                  IF Runtimecheck THEN
                     BEGIN
                     IF (Smin > Gattr.Atypep^.Softmin) THEN
                        Uco2typint(Uchkl,Sdt,Smin-Gattr.Atypep^.Softmin);
                     IF Setsize < Gattr.Atypep^.Stsize THEN
                        Uco2typint(Uchkh,Sdt,Setsize);
                     END;
                  Uco3int(Uadj,Sdt,Setsize,Gattr.Atypep^.Softmin-Smin);  
                  END;
               IF Fadj AND NOT Fadjusted THEN
                  BEGIN
                  Uco2typtyp (Uswp,Sdt,Sdt);
                  IF Runtimecheck THEN
                     BEGIN
                     IF (Smin > Fattr.Atypep^.Softmin) THEN
                        Uco2typint(Uchkl,Sdt,Smin-Fattr.Atypep^.Softmin);
                     IF Setsize < Fattr.Atypep^.Stsize THEN
                        Uco2typint(Uchkh,Sdt,Setsize);
                     END;
                  Uco3int(Uadj,Sdt,Setsize, Fattr.Atypep^.Softmin-Smin); 
                  Uco2typtyp (Uswp,Sdt,Sdt);
                  END;
               END;
            IF Gadj THEN  
               (* update GATTR.Atypep to describe set now on top *)
               IF NOT Fadj THEN
                  Gattr.Atypep := Fattr.Atypep
               ELSE (* create new Structure to describe set *)
                  BEGIN
                  New(Gattr.Atypep,Power);
                  WITH Gattr.Atypep^ DO
                     BEGIN
                     Basetype := Fattr.Atypep^.Basetype; Stsize :=  Setsize;
                     Stsize := Setsize; Form := Power; Stdtype := Sdt;
                     Marker := 0;
                     Hasfiles := False; Hasholes := False;
                     Softmin := Smin; Softmax := Smax;
                     Hardmin := Hmin; Hardmax := Hmax;
                     END;
                  END;
            IF Fadj THEN Fattr.Atypep := Gattr.Atypep;
            END; (* if not too big *)
         END; (* adjust sets *)
   END; (* MATCHSETS *)

PROCEDURE Adjtosetoffset (VAR Fattr: Attr; Smin: Integer);

   (* Increments or decrements the integer described in Fattr to conform to
      a set whose offset is Smin *)

   BEGIN
   IF Fattr.Kind = Cnst THEN
      Fattr.Cval.Ival := Fattr.Cval.Ival - Smin
   ELSE
      BEGIN
      IF Smin > 0 THEN
         Uco2typint(Udec,Fattr.Adtype,Smin)
      ELSE IF Smin < 0 THEN
         Uco2typint(Uinc,Fattr.Adtype,-Smin);
      END;
   END;

PROCEDURE Setmatchtoassign(VAR Fattr: Attr; Ftypep: Strp; Spacked: boolean);

   (* adjusts the set in Fattr to have the same size and offset as the
      one described by Ftypep *)

   VAR Shift: Integer;
   BEGIN
   IF (Ftypep <> NIL) AND (Fattr.Atypep <> NIL) THEN
      BEGIN 
      WITH Fattr.Atypep^ DO
       { (* make sure destination set is large enough *)
         IF (Spacked AND
          ((Hardmin < Ftypep^.Hardmin) OR (Hardmax > Ftypep^.Hardmax))) OR
            (NOT Spacked and
          ((Hardmin < Ftypep^.Softmin) OR (Hardmax > Ftypep^.Softmax))) THEN
            Error (177)
         ELSE }
            BEGIN
            Shift := Softmin - Ftypep^.Softmin; 
            IF (Shift <> 0) OR (Ftypep^.Stsize <> Stsize) THEN
               IF Fattr.Kind = Cnst THEN
                  Shiftset (Fattr.Cval, Shift, Ftypep^.Stsize)
               ELSE
                  BEGIN
                  Load (Fattr);
                  IF Runtimecheck THEN
                     BEGIN
                     IF Shift < 0 THEN
                        Uco2typint(Uchkl,Sdt,-Shift); 
                     IF Ftypep^.Softmax < Softmax THEN
                        Uco2typint(Uchkh,Sdt,Ftypep^.Softmax);
                     END;
                  Uco3int(Uadj,Sdt,Ftypep^.Stsize,Shift); 
                  END;
            END;
      Fattr.Atypep := Ftypep; 
      END;
   END;

(*Generatecode*)

(************************************************************************)
(*                                                                      *)
(*      GENERATECODE  -- Generates code to perform an operation.        *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Generatecode(Finstr: Uopcode; Fdtype: Datatype; VAR Fattr: Attr);

   VAR
       Lmin, Lmax: Integer;
       Checkbounds: Boolean;

   BEGIN (*generatecode*)
   WITH Gattr DO
      BEGIN 
      IF Finstr <> Uneg THEN
         BEGIN
         Loadboth(Fattr);
         IF ((Finstr = Udif) OR (Finstr = Uint) or (Finstr = Uuni) OR
             (Finstr = Uinn)) AND (Atypep <> NIL) THEN
	        IF (Finstr = Uinn) AND (Fattr.Atypep <> NIL) THEN
		   BEGIN
	           (* if the subrange of the variable is within the bounds
		      of the set, then indicate (in the U-code) that a test-if-
		      within-bounds must be done *)
	           CASE Fattr.Kind OF
		      Expr: Checkbounds := True;
		      Cnst: Checkbounds := (Fattr.Cval.Ival < Atypep^.Softmin) OR
		            (Fattr.Cval.Ival > Atypep^.Softmax);
		      Varbl: BEGIN
			     IF Fattr.Subkind <> NIL THEN
				Getbounds (Fattr.Subkind, Lmin, Lmax)
	                     ELSE
                      	        Getbounds (Fattr.Atypep, Lmin, Lmax);
			     Checkbounds := (Lmin < Atypep^.Softmin) OR 
			   		    (Lmax > Atypep^.Softmax);
			     END;
		      END;
                   Uco3int (Finstr, Fdtype, Atypep^.Stsize, Ord(Checkbounds));
		   END
	        ELSE
                   Uco2typint (Finstr,Fdtype,Atypep^.Stsize)
         ELSE Uco1type(Finstr,Fdtype);
         END
      ELSE (* negating single expression *)
         BEGIN
	 IF (Fattr.Kind = Cnst) AND (Kind = Cnst) AND (Adtype <> Rdt) THEN
	    WITH Cval DO 
		BEGIN
		Ival := - Ival;
		IF Ival >= 0 THEN
		  Adtype := Ldt
	        ELSE Adtype := Jdt;
		END
	 ELSE
	    BEGIN
	    IF Fattr.Kind <> Expr THEN Load(Fattr);
	    (* make sure type is not positive-only *)
	    IF Fattr.Adtype = Ldt THEN
	       BEGIN
	       Uco2typtyp(Ucvt,Jdt,Ldt);  
	       Fattr.Adtype := Jdt;
	       END;
	    Uco1type(Finstr,Fattr.Adtype);
	    END
         END;
      END;
   END (*generatecode*);


(*Formalcheck,Restregs*)

PROCEDURE Formalcheck (VAR Fattr: Attr);

   VAR Regoff: Integer;
       Lstamp: Integer;

   BEGIN
   WITH Fattr DO
      BEGIN
      (* check for passing elements of packed structures by ref *)
      IF (Apacked AND (Apackunit MOD Addrunit > 0)) OR
	 (Rpacked AND (Rpackunit MOD Addrunit > 0)) THEN
	 IF (Kind = Expr) OR (Dplmt MOD Addrunit <> 0) THEN
	    ERROR (357);
      (* if is in register, save the register *)
       
      IF (Kind = Varbl) AND NOT Indexed THEN
	 IF (Ablock = Memblock) AND 
	    (Dplmt >= Minlocreg) AND (Dplmt <= Maxlocreg) THEN
	 BEGIN
	 Regoff := Dplmt;
	 Lstamp := - (Callnesting*10000 + Abs(Regoff));
	 Getatemp (Fattr, Atypep, Lstamp, False);
	 Uco6 (Urstr, Adtype, Amty, Ablock, Dplmt, Salign, Regoff);
	 END;
      END;
  END;

PROCEDURE Restregs (Callnest: Integer);

   VAR Regoff: Integer;
       Mtyp: Memtype;
       Offst: Integer;

   BEGIN
   WHILE Findnextregtemp (Callnest, Regoff, Mtyp, Offst) DO
      Uco6 (Urlod, Jdt, Mtyp, Memblock, Offst, Salign, Regoff);
   END;

(*Callspecial,Getfilename,Getvariable,Savefile,Loadtableaddress*)

PROCEDURE Getvariable(Fsys: Setofsys);

   (* parses a variable, for use as a reference parameter in a standard 
      procedure or function *)

   VAR
      Lidp: Idp;
   BEGIN (*variable*)
   IF Sy = Identsy THEN
      BEGIN
      Searchid([Vars,Field],Lidp); Insymbol;
      END
   ELSE
      BEGIN
      Error(209); Lidp := Uvarptr
      END;
   Parseleft := True;
   Selector(Fsys,Lidp);
   Parseleft := False;
   END (*Getvariable*) ;

(************************************************************************)
(************************************************************************)
(*                                                                      *)
(*      SPECIAL-PROCEDURE-CALL MODULE                                   *)
(*                                                                      *)
(*      Contains a main procedure, Callspecial, and several             *)
(*      subprocedures, each of which processes calls to a small         *)
(*      number of similar standard procedures and functions.            *)
(*                                                                      *)
(************************************************************************)
(************************************************************************)

PROCEDURE Callspecial (Fsys: Setofsys; Fidp: Idp);
    VAR Lstamp: Integer;

(************************************************************************)
(*                                                                      *)
(*      GETFILENAME -- reads the first parameter for READ and WRITE.    *)
(*        This may or may not be a file.                                *)
(*                                                                      *)
(*     if no parameters then                                            *)
(*        the default file (INPUT or OUTPUT) is returned in IOFILEATTR; *)
(*        example: WRITELN;                                             *)
(*     else                                                             *)
(*        parses first parameter                                        *)
(*        if it is a file, it is returned in IOFILEATTR                 *)
(*           example: WRITELN(OUTPUT,I);                                *)
(*        else it is returned in GATTR and the default file in          *)
(*           IOFILEATTR and FIRSTREAD is set to TRUE                    *)
(*           example: WRITELN(I)                                        *)
(*                                                                      *)
(*     if READEXPR then Expression will be used to parse the parameter  *)
(*     else GetVariable will be used and the file's Idp will be         *)
(*        returned in Iofileidp                                         *)
(*                                                                      *)
(************************************************************************)

   PROCEDURE Getfilename(Defaultfilep: Idp; Followsys: Setofsys; 
                         Readexpr: Boolean; VAR Iofileattr: Attr;
                         VAR Iofileidp: Idp; VAR  Iofiletypep,Iofilep: Strp;
                         VAR Firstread, Istextfile,Norightparen: Boolean);

        
      BEGIN (*getfilename*)

      Norightparen := True;
      Firstread := False;
      Iofileidp := Uvarptr;

      IF Sy = Lparentsy THEN
         BEGIN
         Norightparen := False;
         Insymbol;
         IF Readexpr THEN Expression(Followsys)
         ELSE IF Sy = Identsy THEN
            BEGIN
            Searchid([Vars,Func],Iofileidp);
            Insymbol;
            Selector(Followsys,Iofileidp);
            END
         ELSE Error (209);
         IF Gattr.Atypep = NIL THEN Firstread := True
         ELSE Firstread := (Gattr.Atypep^.Form <> Files);
         IF NOT Firstread THEN
            BEGIN (*file*)
            Iofileattr := Gattr;
            Iofilep := Gattr.Atypep;
            Iofiletypep := Iofilep^.Filetype;
            Istextfile := Gattr.Atypep^.Textfile;
            Iofileidp^.Referenced := True;  
            END;
         END (*sy = lparentsy*);

      IF Firstread OR Norightparen THEN
         (* make up an ATTR describing the default file *)
         WITH Defaultfilep^, Iofileattr DO
            BEGIN
            Iofileidp := Defaultfilep;
            Iofilep := Defaultfilep^.Idtype;
            Iofiletypep := Iofilep^.Filetype;
            Istextfile := Iofilep^.Textfile;
            Atypep := Idtype; Adtype := Mdt; Kind := Varbl;
            Apacked := False; Rpacked := False; Fpacked := False;
            Indexed := False; 
            Indirect := False; Indexmt := Zmt; Indexr := 0;
            Subkind := NIL; Aclass := Vars;
            Amty := Vmty; Ablock := 1; Dplmt := Vaddr; Baseaddress := Vaddr;
            END;
      END (*getfilename*) ;

   PROCEDURE Savefile(VAR Fattr: Attr);

      (* if FATTR is indexed, saves it in a temporary so it can be used again;
       updates FATTR to describe the temporary *)

      VAR
         Lattr: Attr;
      BEGIN
      IF Fattr.Indirect AND Fattr.Indexed THEN  
         Loadaddress(Fattr);
      IF Fattr.Indexed THEN
         BEGIN
         Loadaddress (Fattr);
         Getatemp(Lattr,Addressptr,Lstamp,False);
         Store(Lattr);
         Fattr := Lattr;
         WITH Fattr DO
            BEGIN
            Indirect := True;
            Indexmt := Amty;
            Indexr := Dplmt;
            Dplmt := 0;
            Indexed := False;
            END;
         END (*if fattr.indexed*);
      END (*savefile*);




   PROCEDURE LoadTableaddress (Scalarstrp: Strp); 
      (* Loads the address of the scalar name table for an ennumerated type,
         Generates table if has not been generated before. *)

      VAR 
          Lidp: Idp;
          Loffset: Addrrange;
          Lvalu: Valu;
          Lsize: Sizerange;
          I: 1..Identlength;
          Oldmemcnt: Memsize;
      BEGIN
      IF Scalarstrp <> NIL THEN
         WITH Scalarstrp^ DO
            BEGIN
            IF Saddress = -1 THEN
               BEGIN (* table has not yet been allocated *)
               Lidp := Fconst;          (* find first string *)
               Lvalu.Len := Identlength;
               Lsize := Stringsize (Identlength);
               WHILE Lidp <> NIL DO
                 BEGIN
                 (* allocate global memory for string *)
                 Oldmemcnt := Memcnt;
                 Memcnt := Globalmemcnt;
                 Loffset := Assignnextmemoryloc (Smt, Lsize);
                 Globalmemcnt := Memcnt;
                 Memcnt := Oldmemcnt;
                 (* if first string in table, save its address *)
                 If Saddress = -1 THEN Saddress := Loffset; 
                 (* copy it into a Valu record *)
                 For I := 1 to Identlength DO
                    Lvalu.Chars[I] := Lidp^.Idname[I];
                 (* and emit the INIT instruction *)
                 Ucoinit (Mdt, Loffset, Loffset, Lsize, Lvalu);
                 Lidp := Lidp^.Next;
                 END;
               END;
            Ucolda (Mdt,Smt,1,Saddress,Pointersize)
            END;
      END; (* Loadtableaddress *)



(*Readreadln*)

(************************************************************************)
(*                                                                      *)
(*      READREADLN -- parses call to READ or READLN                     *)
(*                                                                      *)
(*      If the file is not a text file, then for each variable, the     *)
(*         current copy of the file buffer is put into the variable,    *)
(*         and a GET is done to get the next element of the file.       *)
(*         If the variable is of type subrange, a check is emitted to   *)
(*         ensure the file buffer is within that range.                 *)
(*      For text files, a call to one of many runtime routines is       *)
(*         done, passing the address of the variable to be stored       *)
(*         into.  For simple types this straightforward.  For           *)
(*         enumerated types, the address of a vector containing the     *)
(*         string representations of each member must be passed.        *)
(*         This vector is generated at the end of the program.          *)
(*         This address must also be passed for sets of enumerated      *)
(*         types.                                                       *)
(*                                                                      *)
(*      Here are two sample runtime procedure headers:                  *)
(*                                                                      *)
(*      Procedure $RDC (VAR Ch: Char; VAR Fdb: Textfile);               *)
(*      Procedure $RDSET (VAR Setvariable: Targetset;                   *)
(*                        VAR Fdb: Textfile;                            *)
(*                        Minvalue, Maxvalue: Integer;                  *)
(*                        Scalarnames: Scalarvptr;                      *)
(*                        Elementform: Scalarform);                     *)
(*                                                                      *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Readreadln;
   TYPE
      Scalarform = (Integerform,Charform,Declaredform); (* for sets *)
   VAR
      Iofileidp: Idp;
      Iofiletypep,Iofilep: Strp;
      Firstread, Istextfile, Norightparen: Boolean;
      Iofileattr: Attr;
      Fileattr, Bufferattr, Iobufferattr: Attr;
      Baseform: Structform;
      Testflag,More: Boolean;
      Parcount: Integer;

   BEGIN (*readreadln*)
   Lstamp := 0;
   Stdcallinit (Parcount);
   (* get file and maybe first variable *)
   Getfilename(Inputptr,[Arrowsy,Rparentsy,Commasy],False, 
    Iofileattr,Iofileidp,Iofiletypep,Iofilep,Firstread,Istextfile,Norightparen);

   IF NOT Firstread THEN
      IF Sy = Commasy THEN Insymbol;
   (* save addr of file block in temporary, if necessary *)
   Savefile (Iofileattr);
   IF NOT Istextfile THEN
      BEGIN
      (* create ATTR to describe the file buffer, for later use*)
      Iobufferattr := Iofileattr;
      WITH Iobufferattr DO
         BEGIN
         Dplmt := Iofileattr.Dplmt + Fdbsize;
         Baseaddress := Dplmt;
         Atypep := Iofiletypep;
         Adtype := Iofiletypep^.Stdtype;
         Fpacked := Iofilep^.Filepf;  (**10 Mar*)
         END;
      END;

   More := False;
   IF (Fidp^.Key = Spread) OR (Sy = Identsy) OR Firstread THEN
      REPEAT
         Fileattr := Iofileattr;(* get unloaded version of FILEATTR *)
         IF NOT Istextfile THEN
            BEGIN
            (* store the record just read into the variable and then do a
             GET to get the next record from the file *)
            IF NOT Firstread THEN
               Getvariable(Fsys + [Commasy]);
            (* get unloaded version of IOBUFFERATTR *)
            Bufferattr := Iobufferattr;
            (* make sure variable type corresponds to file type *)
            IF NOT Comptypes(Gattr.Atypep,Iofiletypep) THEN
               Errandskip(366,Statbegsys + [Rparentsy,Semicolonsy]);
            IF (Gattr.Atypep <> NIL) THEN
               IF Iobufferattr.Atypep <> NIL THEN
                  BEGIN
                  Load(Bufferattr);
                  Bufferattr := Iobufferattr;
                  Matchtoassign (Bufferattr,Gattr.Atypep);
                  WITH Gattr.Atypep^ DO
                     (*check the subrange of the just read item*)
                     IF Runtimecheck AND (Form = Subrange) THEN
                        BEGIN
                        IF Iofiletypep^.Form <> Subrange THEN
                           Testflag := True
                        ELSE
                           Testflag :=(Iofiletypep^.Vmin.Ival < Vmin.Ival) OR
                           (Iofiletypep^.Vmax.Ival > Vmax.Ival);
                        (*problem: does not handle long integers properly*)
                        IF Testflag THEN
                           BEGIN
                           Uco2typint(Uchkl,Gattr.Adtype,Vmin.Ival);
                           Uco2typint(Uchkh,Gattr.Adtype,Vmax.Ival);
                           END;
                        END;
                  (* store previous record in variable *)
                  Store(Gattr);

                  (* get the next record from the file *)
                  Loadaddress(Fileattr);
                  Par (Adt,Parcount);
                  Uco1idp(Ucup,Getptr);
                  END
            END
         ELSE    (*textfile*)
            BEGIN
            (* load address of variable *)
            IF NOT Firstread THEN
               Getvariable(Fsys + [Commasy]);
            Formalcheck(Gattr);
            Loadaddress(Gattr);
            Par (Adt,Parcount);
            (* load address of file block *)
            Loadaddress(Fileattr);
            Par (Adt,Parcount);
            WITH Gattr DO
               BEGIN (* load any other parameters and emit call *)
               IF Atypep <> NIL THEN
                  IF String(Atypep) THEN          (*strings*)
                     BEGIN
                     WITH Atypep^.Inxtype^ DO
                        BEGIN
                        (* load length of string *)
                        Uco3int(Uldc,Jdt,Intsize,Vmax.Ival-Vmin.Ival+1);
                        Par (Jdt,Parcount);
                        END;
                     IF Atypep^.Arraypf THEN
                        Support(Readpkstring)
                     ELSE
                        BEGIN
                        IF Standardonly THEN Warning (212);
                        Support(Readstring)
                        END
                     END
                  ELSE IF Atypep^.Form IN [Scalar, Subrange, Power] THEN
                     BEGIN
                     Baseform := Atypep^.Form;
                     IF Baseform = Power THEN    (*sets*) 
                        BEGIN
                        IF Standardonly THEN Warning (212);
                        Uco3int(Uldc,Jdt,Intsize,Atypep^.Softmin);
                        Par (Jdt,Parcount);
                        Uco3int(Uldc,Jdt,Intsize,Atypep^.Softmax);
                        Par (Jdt,Parcount);
                        Atypep := Atypep^.Basetype;
                        END;
                     (* ATYPEP^.FORM is now either a SCALAR or SUBRANGE *)
                     IF (Atypep <> NIL) THEN
                        IF Atypep^.Form = Subrange THEN  (*subranges*)
                           BEGIN
                           IF (Atypep = Charptr) AND (Baseform = Subrange) THEN
                              (* type CHAR has its subrange checked explicitly
                               by $GETC *)
                              Baseform := Scalar
                           ELSE IF Baseform <> Power THEN WITH Atypep^ DO
                              BEGIN
                              Uco3val(Uldc,Jdt,Intsize,Vmin);
                              Par (Jdt,Parcount);
                              Uco3val(Uldc,Jdt,Intsize,Vmax);
                              Par (Jdt,Parcount);
                              END;
                           Atypep := Atypep^.Hosttype
                           END
                           (* enumerated types *)
                        ELSE IF (Atypep^.Scalkind = Declared) AND  
                           (Atypep <> Boolptr) AND (Baseform <> Power) THEN
                           BEGIN
                           Uco3int(Uldc,Ldt,Intsize,0);
                           Par (Ldt,Parcount);
                           Uco3int(Uldc,Ldt,Intsize,Atypep^.Dimension);
                           Par (Ldt,Parcount);
                           END;
                     (* at this point, ATYPEP^.FORM must be SCALAR.  If we are
                      reading a set or subrange, this will be its base type *)
                     IF Atypep <> NIL THEN
                        WITH Atypep^ DO
                           IF (Scalkind = Declared) AND (Atypep <> Boolptr) THEN
                              BEGIN (*address of the names of a scalar*)
                              IF Standardonly THEN Warning (212);
                              Loadtableaddress (Atypep);
                              Par (Adt,Parcount);
                              IF Baseform = Power THEN
                                 BEGIN
                                 Uco3int(Uldc,Ldt,Intsize,Ord(Declaredform));
                                 Par (Ldt,Parcount);
                                 Support (Readset);
                                 END
                              ELSE Support(Readsupport[Ldt,Baseform]);
			      Restregs (Callnesting);
                              END
                           ELSE                    (*scalkind = standard*)
                              BEGIN
                              IF Baseform = Power THEN
                                 BEGIN
                                 Uco3int(Uldc,Adt,Pointersize,-1);
                                 Par (Adt,Parcount);
                                 IF Comptypes (Atypep,Charptr) THEN
                                      Uco3int(Uldc,Ldt,Intsize,Ord(Charform))
                                 ELSE IF (Atypep=Intptr) OR 
                                   (Atypep = Posintptr) THEN
                                      Uco3int(Uldc,Ldt,Intsize,Ord(Integerform))
                                 ELSE Error (458);
                                 Par (Ldt,Parcount);
                                 Support (Readset);
                                 END
                              ELSE
                                 Support(Readsupport[Stdtype,Baseform]);
			      Restregs (Callnesting);
                              END;
                     END  (*atypep^.form in [scalar, subrange, power]*)
                  ELSE  (*arrays, records, files, pointers*)
                     Error(169);
               END (*with gattr*);
            END (*it is a text file*);
         More := (Sy = Commasy);
         IF More THEN
            BEGIN
            Firstread := False;
            Stdcallinit (Parcount);
            Insymbol
            END
         ELSE IF Fidp^.Key = Spreadln THEN Stdcallinit (Parcount);
      UNTIL NOT More;
   IF Fidp^.Key = Spreadln THEN
      BEGIN
      IF NOT Istextfile THEN Error (366);
      Fileattr := Iofileattr;
      Loadaddress(Fileattr);
      Par(Adt,Parcount);
      Support(Readline);
      END;

   IF NOT Norightparen THEN
      IF Sy = Rparentsy THEN
         Insymbol
      ELSE
         IF NOT Norightparen THEN Warning(152);
   IF Lstamp > 0 THEN Freetemps (Lstamp);
   END (*readreadln*) ;


(*Writewriteln*)

(************************************************************************)
(*                                                                      *)
(*      WRITEWRITELN -- parses a call to WRITE or WRITELN               *)
(*                                                                      *)
(*      For non-text files, puts the value parsed in the file buffer    *)
(*         and does a PUT                                               *)
(*      For text files, gets each expression and field widths (if any)  *)
(*         and emits call to the proper runtime routine.                *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Writewriteln;

   TYPE
      Scalarform = (Integerform,Charform,Declaredform);  (* for sets *)
   VAR
      Iofileidp: Idp;
      Iofiletypep,Iofilep: Strp;
      Firstread, Istextfile,Norightparen: Boolean;
      Iofileattr: Attr;
      Fileattr,Bufferattr,Iobufferattr,Lattr: Attr;
      Defaultwidth: Integer;
      Base: Integer;
      Llstrp, Lstrp: Strp;
      Lsize, Lmin, Lmax: Integer;
      Scalartype: Scalarform;
      More: Boolean;
      Parcount: Integer;
      Lsupport: Supports;

   BEGIN (*writewriteln*)
   Lstamp := 0;
   Stdcallinit (Parcount);

   (* get file and maybe first expression *)
   Getfilename(Outputptr,[Arrowsy,Rparentsy,Commasy,Colonsy],True,
    Iofileattr,Iofileidp,Iofiletypep,Iofilep,Firstread,Istextfile,Norightparen);
   IF NOT Firstread THEN
      IF Sy = Commasy THEN Insymbol;

   (* save addr of file block in temporary, if necessary *)
   Savefile (Iofileattr);

   IF NOT Istextfile THEN
      BEGIN
      (* create ATTR to describe the file buffer, for later use*)
      Iobufferattr := Iofileattr;
      WITH Iobufferattr DO
         BEGIN
         Dplmt := Iofileattr.Dplmt + Fdbsize;
         Atypep := Iofiletypep;
         Adtype := Iofiletypep^.Stdtype;
         Fpacked := Iofilep^.Filepf;  (**10 Mar*)
         END;
      END;

   (* if there is an expression to write out,
    (there MUST be one for WRITE, MAY be one for WRITELN) then
    generate the appriopriate calls to runtimes for each expression *)

   More := False;
   IF (Fidp^.Key = Spwrite) OR (Sy IN Facbegsys + Addopsys) OR Firstread THEN

      REPEAT                            (*for each parameter of write*)

         Fileattr := Iofileattr;(* get unloaded version of FILEATTR *)
         IF NOT Firstread THEN
            Expression(Fsys + [Commasy,Colonsy]);
         Lstrp := Gattr.Atypep;
         IF Lstrp <> NIL THEN
            (* load expression on the stack, if not already there *)
            (* if string or set, must be passed indirectly *)
            IF String(Lstrp) THEN
               BEGIN
               Loadaddress(Gattr);
               IF Istextfile THEN Par (Adt,Parcount);
               END
            ELSE IF Lstrp^.Form = Power THEN
               BEGIN
               IF Gattr.Kind <> Varbl THEN
                  BEGIN
                  Load(Gattr);
                  Getatemp(Lattr,Gattr.Atypep,Lstamp,False);
                  Store(Lattr);
                  Gattr := Lattr;
                  END;
               Loadaddress(Gattr);
               IF Istextfile THEN Par (Adt,Parcount);
               END
            ELSE
               BEGIN
               Load(Gattr);
               IF Istextfile THEN Par (Gattr.Adtype,Parcount);
               END;
         IF NOT Istextfile THEN
            BEGIN
            IF Lstrp <> NIL THEN
               BEGIN
               IF NOT Comptypes(Lstrp,Iofilep^.Filetype) THEN
                  Errandskip(366,Statbegsys + [Rparentsy,Semicolonsy]);
               (* store variable in the file buffer *)
               Bufferattr := Iobufferattr;
               Loadaddress(Bufferattr);
               Uco2typtyp(Uswp,Adt,Gattr.Adtype);
               Matchtoassign(Gattr,Bufferattr.Atypep);
               Uco1attr(Uistr,Bufferattr);
               (* and write it to the file *)
               Loadaddress(Fileattr);     
               Par (Adt,Parcount);
               Uco1idp(Ucup,Putptr);
               END;
            END
         ELSE

            BEGIN (* textfile *)

            (* load address of file block *)
            Loadaddress(Fileattr);
            Par (Adt,Parcount);

            (* for each parameter, get one or possibly two field widths,
             load the appropriate parameters, and call the appropriate
             runtime *)
            IF Lstrp <> NIL THEN
               IF Lstrp^.Form = Subrange THEN
                  Lstrp := Lstrp^.Hosttype;
            IF Lstrp <> NIL THEN
               WITH Lstrp^ DO
                  BEGIN
                  IF (Form = Scalar) AND ((Scalkind <> Declared) OR
                          (Stdtype <> Ldt) OR (Lstrp = Boolptr)) THEN
                     BEGIN
                     (* integer, real, character, boolean, but NOT
                        enumerated type *)
                     Lsupport := Writesupport[Stdtype];
                     Defaultwidth := Widthdefault[Stdtype];
                     END
                  ELSE IF String(Lstrp) THEN
                     BEGIN
                     IF Inxtype <> NIL THEN
                        BEGIN
                        Getbounds(Inxtype,Lmin,Lmax);
                        Lsize := Lmax-Lmin+1
                        END
                     ELSE  (*inxtype = nil*)
                        Lsize := 0;
                     Defaultwidth := Lsize;
                     Uco3int(Uldc,Ldt,Intsize,Lsize);
                     Par(Ldt,Parcount);
                     IF Arraypf THEN
                        Lsupport := Writepkstring
                     ELSE  (*not arraypf*)
                        BEGIN
                        IF Standardonly THEN Warning (212);
                        Lsupport := Writestring
                        END
                     END (*string*)
                  ELSE IF Form = Scalar THEN
                     (* enumerated type *)
                     BEGIN
                     IF Standardonly THEN Warning (212);
                     Loadtableaddress (Lstrp);
                     Par (Adt,Parcount);
                     Lsupport := Writescalar;
                     Defaultwidth := 0;
                     END
                  ELSE IF Form = Power THEN
                     (* set *)
                     BEGIN
                     IF Basetype <> NIL THEN
                        IF Basetype^.Form = Subrange THEN
                           Llstrp := Basetype^.Hosttype  
                        ELSE  (*not subrange*)
                           Llstrp := Basetype;
                     IF Llstrp <> NIL THEN
                        WITH Llstrp^ DO
                           BEGIN
                           IF NOT (Form = Scalar) THEN Error (458);
                           IF (Scalkind = Declared) THEN
                              BEGIN
                              Defaultwidth := 0;
                              Loadtableaddress (Llstrp);
                              Par (Adt,Parcount);
                              Scalartype := Declaredform;
                              END
                           ELSE
                              BEGIN
                              Defaultwidth := Widthdefault[Stdtype];
                              Uco3int(Uldc,Adt,Pointersize,-1);
                              Par (Adt,Parcount);
                              IF Comptypes (Llstrp,Charptr) THEN
                                 Scalartype := Charform
                              ELSE IF (Llstrp=Intptr) OR 
                                      (Llstrp = Posintptr) THEN
                                 Scalartype := Integerform
                              ELSE Error (458);
                              END;
                           END (* with llstp^ do *);

                     Uco3int(Uldc,Jdt,Intsize,Softmin);
                     Par (Jdt,Parcount);
                     Uco3int(Uldc,Jdt,Intsize,Softmax);
                     Par (Jdt,Parcount);
                     Uco3int(Uldc,Jdt,Intsize,Ord(Scalartype));
                     Par (Jdt,Parcount);
                     Lsupport := Writeset;
                     END (* form = power *)
                  ELSE  (*illegal type*)
                     Error(458)
                  END (* with lstrp^ do *);

            IF Sy = Colonsy THEN          (*field width*)
               BEGIN
               Insymbol;
               Expression(Fsys + [Commasy,Colonsy]);
               IF Lstrp <> NIL THEN
                  BEGIN
                  IF (Gattr.Atypep <> Intptr) AND 
                   (Gattr.Atypep <> Posintptr) THEN
                     Error(458);
                  Load(Gattr);
                  Par(Gattr.Adtype,Parcount);
                  END
               END
            ELSE  (*sy <> colonsy*)
               BEGIN
               Uco3int(Uldc,Ldt,Intsize,Defaultwidth);
               Par (Ldt,Parcount);
               END;
            IF Sy = Colonsy THEN      (*second format modifier*)
               BEGIN
               Insymbol;
               IF ((Lstrp=Intptr) OR (Lstrp = Posintptr)) THEN
                  BEGIN
                  IF (Sy = Identsy) THEN
                     BEGIN
                     Base := 10;
                     IF Id = 'O               ' THEN
                        Base := 8
                     ELSE IF Id = 'H               ' THEN
                        Base := 16
                     ELSE  (*not 'o' nor 'h'*)
                        Error(262);
                     IF Standardonly and (Base <> 10) THEN
                        Warning (212);
                     Uco3int(Uldc,Ldt,Intsize,Base);
                     Par (Ldt,Parcount);
                     END
                  ELSE Error(262);
                  Insymbol
                  END
               ELSE  (*lstrp <> intptr*)
                  BEGIN
                  IF (Lstrp <> Realptr) THEN
                     Error(258);
                  Expression(Fsys + [Commasy]);
                  IF (Gattr.Atypep <> Intptr) AND 
                   (Gattr.Atypep <> Posintptr) THEN
                     Error(458);
                  Load(Gattr);
                  Par(Gattr.Adtype,Parcount);
                  END
               END
            ELSE  (*sy <> colonsy*)
               IF Lstrp <> NIL THEN
                  WITH Lstrp^ DO
                     IF ((Stdtype = Jdt) OR (Form = Power)) THEN
                        BEGIN
                        Uco3int(Uldc,Ldt,Intsize,10);
                        Par(Ldt,Parcount);
                        END
                     ELSE IF Stdtype = Rdt THEN
                        BEGIN
                        Uco3int(Uldc,Jdt,Intsize,-1);
                        Par(Jdt,Parcount);
                        END;

            IF Lstrp <> NIL THEN Support(Lsupport);
            END (* textfile *);

         More := (Sy = Commasy);
         IF More THEN
            BEGIN
            Insymbol;
            Firstread := False;
            Stdcallinit (Parcount);
            END
         ELSE IF Fidp^.Key = Spwriteln THEN Stdcallinit (Parcount);
      UNTIL NOT More;

   IF Fidp^.Key = Spwriteln THEN
      BEGIN
      IF NOT Istextfile THEN Error (366);
      Fileattr := Iofileattr;
      Loadaddress(Fileattr);
      Par(Adt,Parcount);
      Support(Writeline)
      END;

   IF NOT Norightparen THEN
      IF Sy = Rparentsy THEN
         Insymbol
      ELSE
         IF NOT Norightparen THEN Warning(152);
   IF Lstamp > 0 THEN Freetemps (Lstamp);
   END (*writewriteln*) ;





(*Packunpack*)


(************************************************************************)
(*                                                                      *)
(*  PACKUNPACK -- generates code to pack or unpack arrays               *)
(*             -- this really should call a primitive subroutine        *)
(*                instead                                               *)
(*                
(*  algorithm for PACK(A,I,Z), where A is unpacked array, Z is packed   *)
(*      array, and I is the element of A to start with                  *)
(*                                                                      *)
(*     T1 := address (A) + (I-lowerbound(A))*stsize(aeltype(A))         *)
(*     T2 := address (Z)                                                *)
(*     T3 := T2 + stsize(Z)                                             *)
(*                                                                      *)
(* 1:  ILOD T1                                                          *)
(*     ISTR T2                                                          *)
(*     T1 := T1 + stsize(aetype(A))                                     *)
(*     T2 := T2 + packsize(aeltype(Z))                                  *)
(*     if T2 < T3 then goto 1                                           *)
(*                                                                      *)
(************************************************************************)

PROCEDURE Packunpack;

   VAR
      A,I,Z,T1,T2,T3,T1save,T2save,T3save: Attr;
      Amax, Amin, Aelsize, Zelsize: Integer;
      Commondtype: Datatype;
      Lstamp: Integer;

   PROCEDURE Createt1;
      BEGIN
      IF I.Kind = Cnst THEN A.Dplmt := A.Dplmt + (A.Cval.Ival * Aelsize);
      Loadaddress (A);
      IF I.Kind <> Cnst THEN
         BEGIN
         Load (I);
         IF Amin > 0 THEN
            Uco2typint(Udec,I.Adtype,Amin)
         ELSE IF Amin < 0 THEN
            Uco2typint(Uinc,I.Adtype,-Amin);
         Uco2typint(Uixa,I.Adtype,Aelsize);
         END;
      Getatemp (T1,Addressptr,Lstamp,True);
      T1save := T1;
      Store (T1);
      END;

   PROCEDURE Createt2t3;
      BEGIN
      Loadaddress (Z);
      Getatemp (T2,Addressptr,Lstamp,True);
      T2save := T2;
      Store (T2);
      T2 := T2save;
      Load (T2);
      IF Z.Atypep <> NIL THEN
         Uco2typint (Uinc,Adt,Z.Atypep^.Stsize);
      Getatemp (T3,Addressptr,Lstamp,True);
      T3save := T3;
      Store (T3);
      END;

   PROCEDURE Getoffset( VAR Fattr: Attr; Fsys: Setofsys; Compatypep: Strp);
      BEGIN (*getoffset*)
      Expression(Fsys); Fattr := Gattr;
      WITH Fattr DO
         IF Atypep <> NIL THEN
            IF NOT Comptypes(Atypep,Compatypep) THEN
               Error(458);
      IF (Sy=Commasy) AND (Commasy IN Fsys) THEN
         Insymbol
      ELSE
         IF (Sy <> Rparentsy) OR NOT (Rparentsy IN Fsys) THEN
            Error(458)
      END (*getoffset*);

   PROCEDURE Getvar(VAR Fattr: Attr; Fsys: Setofsys; Compatypep: Strp);
      BEGIN (*getvar*)
      Getvariable(Fsys); Fattr := Gattr;
       IF Fattr.Atypep <> NIL THEN
          WITH Fattr.Atypep^ DO
             IF Form <> Arrays THEN Error (458)
             ELSE
                IF Aeltype <> NIL THEN
                   IF Compatypep = NIL THEN
                      BEGIN  (* getting first array *)
                      (*if packing and array already packed or vice-versa, 
                        error*)
                      IF Arraypf = (Fidp^.Key = Sppack) THEN Error(458);
                      IF Fidp^.Key = Sppack THEN Aelsize := Aeltype^.Stsize
                      ELSE Zelsize := Aeltype^.Packsize;
                      Commondtype := Aeltype^.Stdtype;
                      END
                   ELSE
                      BEGIN (* getting second array *)
                      IF (Arraypf = Compatypep^.Arraypf) OR
                         (Aeltype <> Compatypep^.Aeltype) OR
                         NOT Comptypes(Inxtype,Compatypep^.Inxtype) THEN
                         Error(458);
                      IF Fidp^.Key = Sppack THEN Zelsize := Aeltype^.Packsize
                      ELSE Aelsize := Aeltype^.Stsize;
                      END;
      IF (Sy = Commasy) AND (Commasy IN Fsys) THEN
         Insymbol
      ELSE
         IF (Sy <> Rparentsy) OR NOT (Rparentsy IN Fsys) THEN
            Error(458)
      END (*getvar*);

   BEGIN (* packunpack *)
   Lstamp := 0;
   IF Sy = Lparentsy THEN
      Insymbol
   ELSE
      Warning(153);
   Amin := 0;  Amax := 0;
   Aelsize := 0;  Zelsize := 0;
   IF Fidp^.Key = Sppack THEN
      BEGIN
      Getvar(A,[Commasy],NIL);
      IF A.Atypep <> NIL THEN
         BEGIN
         Getbounds(A.Atypep^.Inxtype,Amin,Amax);
         Getoffset(I,[Commasy],A.Atypep^.Inxtype)
         END
      ELSE
         Getoffset(I,[Commasy],NIL);
      Createt1;
      Getvar(Z,[Commasy,Rparentsy],A.Atypep);
      Createt2t3;
      END
   ELSE  (*unpack*)
      BEGIN
      Getvar(Z,[Commasy],NIL);
      Createt2t3; 
      Getvar(A,[Commasy],Z.Atypep);
      IF A.Atypep <> NIL THEN
         BEGIN
         Getbounds(A.Atypep^.Inxtype,Amin,Amax);
         Getoffset(I,[Commasy,Rparentsy],A.Atypep^.Inxtype)
         END
      ELSE
         Getoffset(I,[Commasy,Rparentsy],NIL);
      Createt1;
      END;

   Lastuclabel := Lastuclabel + 1;
   Uco2intint(Ulab,Lastuclabel,0);
   T1 := T1save;
   T2 := T2save;
   IF Fidp^.Key = Sppack THEN
      BEGIN
      Load (T2);
      Load (T1);
      Uco3int (Uilod,Commondtype,Aelsize,0);
      Uco3int (Uistr,Commondtype,Zelsize,0);
      END
   ELSE   (*Fidp^.Key = SPUNPACK*)
      BEGIN
      Load (T1);
      Load (T2);
      Uco3int (Uilod,Commondtype,Zelsize,0); 
      Uco3int (Uistr,Commondtype,Aelsize,0);
      END;
   T1 := T1save;
   Load (T1);
   Uco2typint(Uinc,Adt,Aelsize);
   T1 := T1save;
   Store (T1);
   T2 := T2save;
   Load (T2);
   Uco2typint(Uinc,Adt,Zelsize);
   T2 := T2save;
   Store (T2);
   Load (T2save);
   Load (T3save);
   Uco1type(Ules,Adt);
   Uco1int(Utjp,Lastuclabel);

   IF Sy = Rparentsy THEN
      Insymbol
   ELSE
      Warning(152);
   Freetemps (Lstamp);
   END (* packunpack *);



(*Newdispose*)

(************************************************************************)
(*                                                                      *)
(* NEWDISPOSE -- parses a call to New and Dispose, and caluculates      *)
(*   the correct size of the item to be allocated or disposed of        *)
(*                                                                      *)
(* 'New' allocates storage for a variable                               *)
(* in the heap. 'Dispose' de-allocates the storage occupied by          *)
(* such a variable.  In this implementation, this can be stack-based,   *)
(* in which case the storage of all variables allocated later than the  *)
(* specified one are also released, or a true dispose can be used.  In  *)
(* the former case, NEW and DISPOSE instructions are generated, but the *)
(* user can set a swtich so that runtimes routines are called instead.  *)
(*                                                                      *)
(************************************************************************)


PROCEDURE Newdispose;

   LABEL
      777;

   VAR
      Lstrp,Lstrp1: Strp;
      Zerorec: Boolean;
      Lsize: Integer; 
      Lvalu: Valu;
      Lattr: Attr;
      Parcount: Integer;

   BEGIN (*newdispose*)
   IF Sy = Lparentsy THEN
      Insymbol
   ELSE
      Warning(153);

   IF NOT Markrelease THEN Stdcallinit (Parcount);
   Getvariable(Fsys + [Commasy,Rparentsy]);       (* parse the pointer *)

   IF Fidp^.Key = Spnew THEN  
      BEGIN
      Formalcheck (Gattr);
      Loadaddress(Gattr)        (* pass the address of the pointer *)
      END
   ELSE Load (Gattr);           (* pass the pointer itself *)
   IF NOT Markrelease THEN Par (Adt,Parcount);

   Zerorec := False;

   Lstrp := NIL; Lsize := 0;
   Lattr := Gattr;
   IF Lattr.Atypep <> NIL THEN
      WITH Lattr.Atypep^ DO
         IF Form = Pointer THEN
            BEGIN
            IF Eltype <> NIL THEN
               BEGIN
               Lsize := Eltype^.Stsize;
               Zerorec := Eltype^.Hasfiles OR Eltype^.Hasholes;
               IF Eltype^.Form = Records THEN
                  Lstrp := Eltype^.Recvar
               ELSE IF Eltype^.Form = Arrays THEN
                  Lstrp := Eltype
               END
            END
         ELSE
            Error(458);
   WHILE Sy = Commasy DO     (*parse flags to figure out total size*)
      BEGIN
      Insymbol; Constant(Fsys + [Commasy],Lstrp1,Lvalu);  
      IF Lstrp = NIL THEN
         Error(408)
      ELSE
         IF String(Lstrp) OR (Lstrp1 = Realptr) THEN
            Error(460)
         ELSE
            (* Lstrp points to the current variant, Lstrp1 to the type of the
               expression just parsed *)
            BEGIN
            IF Lstrp^.Form = Tagfwithid THEN  
               BEGIN
               IF NOT Comptypes(Lstrp^.Tagfieldp^.Idtype,Lstrp1) THEN
                  Error(458);
               END
            ELSE IF Lstrp^.Form = Tagfwithoutid THEN
               BEGIN
               IF NOT Comptypes(Lstrp^.Tagfieldtype,Lstrp1) THEN
                  Error(458)
               END
            ELSE
               Error(358);

            (* find the size that corresponds to the variant that matches with
               the value just parsed *)
            Lstrp1 := Lstrp^.Fstvar;
            (* Now Lstrp1 points to the list of possible values for the 
              variant *)
            WHILE Lstrp1 <> NIL DO
               WITH Lstrp1^ DO
                  IF Varval.Ival = Lvalu.Ival THEN
                     BEGIN (* match found *)
                     Lsize := Stsize; Lstrp := Subvar;
                     GOTO 777
                     END
                  ELSE
                     Lstrp1 := Nxtvar;
            (* no match found; allocate the minimum *)
            Lsize := Lstrp^.Elsevar^.Stsize; Lstrp := NIL;
   777:
            END
      END (*while*) ;

   (* round the number of storage units needed up to the next align unit *)
   Roundup (Lsize, SpAlign);
   Lsize := Lsize DIV Addrunit;
   Uco3int(Uldc,Ldt,Intsize,Lsize);
   IF NOT Markrelease THEN
      BEGIN
      Par (Jdt,Parcount);
      IF Fidp^.Key = Spnew THEN 
         BEGIN
         Uco3int(Uldc,Bdt,Boolsize,Ord(Zerorec));
         Par (Bdt,Parcount);
         Support(Allocate);
	 Restregs(Callnesting);
         END
      ELSE Support(Free);
      END
   ELSE
      IF Fidp^.Key = Spnew THEN 
         BEGIN
         Uco1int(Unew, Ord(Zerorec));
	 Restregs(Callnesting);
	 END
      ELSE 
	 BEGIN
	 (* issue a release *) (** 10MAR *)
	 Warning (559);  (* N switch must be off for Dispose -- release used *)
         Uco0(Udsp);
         END;
   IF Sy = Rparentsy THEN
      Insymbol
   ELSE
      Warning(152);
   END (*newdispose*) ;



(*Callspecial*)

(****************************************************************)
(*                                                              *)
(*      CALLSPECIAL -- parses call to standard procedure or     *)
(*         that needs special handling, i.e. has a              *)
(*         variable number of parameters or is done at compile  *)
(*         time                                                 *)
(*                                                              *)
(****************************************************************)

BEGIN    (* Callspecial *)

Fsys := Fsys + [Rparentsy];
Callnesting := Callnesting + 1;
CASE Fidp^.Key OF
   Spread,Spreadln:   Readreadln;
   Spwrite,Spwriteln: Writewriteln;
   Sppack,Spunpack:   Packunpack;
   Spnew,Spdispose:   Newdispose;
   END;
Callnesting := Callnesting - 1;
END (* Callspecial *) ;


(*Callinline*)

(****************************************************************)
(*                                                              *)
(*      CALLINLINE  -- parses call to standard procedure or     *)
(*         function that is handled by                          *)
(*         a U-code instruction rather than a procedure call    *)
(*                                                              *)
(****************************************************************)

PROCEDURE Callinline (Fsys: Setofsys; Fidp: Idp);

Var Lattr: Attr;
    Argdtype: Datatype;

BEGIN    (* Callinline *)
Callnesting := Callnesting + 1;
IF Standardonly THEN
   IF (Fidp^.Uinst = Umin) OR (Fidp^.Uinst = Umax) OR 
      (Fidp^.Uinst = Unew) OR (Fidp^.Uinst = Udsp) THEN (** 10MAR *)
      Warning (212);
IF Sy = Lparentsy THEN
  Insymbol
ELSE
  Warning(153);
IF Fidp^.Uinst = Unew THEN
   BEGIN
   Getvariable (Fsys+[Rparentsy]);
   Formalcheck (Gattr);
   Loadaddress (Gattr);
   END
ELSE
   BEGIN
   Expression(Fsys + [Commasy,Rparentsy]);
   Load (Gattr);
   END;
Argdtype := Gattr.Adtype;
IF NOT (Argdtype in Fidp^.Dtypes) THEN
   ERROR (503);
IF (Fidp^.Uinst = Unew) or (Fidp^.Uinst = Udsp) THEN
   BEGIN
   IF NOT Markrelease THEN Error (506); (* N switch must be turned on for mark/release. *)
   Uco3intval (Uldc, Jdt, Intsize, 0)
   END
ELSE IF (Fidp^.Uinst = Umin) or (Fidp^.Uinst = Umax) THEN
   BEGIN (* get second argument and match *)
   Lattr := Gattr;
   IF Sy <> Commasy THEN Error (256)
   ELSE
     BEGIN
     Insymbol;
     Expression(Fsys + [Rparentsy]);
     IF NOT (Gattr.Adtype in Fidp^.Dtypes) THEN
        ERROR (503);
     Matchtypes(Lattr);
     Loadboth(Lattr);
     Argdtype := Gattr.Adtype;
     END;
   END
ELSE Load (Gattr);
WITH Gattr DO
   BEGIN (* change gattr to reflect result of operation *)
   Kind := Expr;
   (* for most functions, the resulttype is the type of its arguments,  
      so Gattr doesn't need to get changed *)
   (* for others, it is explicitly given: *)
   IF Fidp^.Resdtype <> NIL THEN
      BEGIN
      Atypep := Fidp^.Resdtype;
      Adtype := Atypep^.Stdtype;
      END
   (* for round and trunc, it must be computed *)
   ELSE IF (Fidp^.Uinst = Ucvt) OR (Fidp^.Uinst = Urnd) THEN
      BEGIN
      Atypep := Intptr;
      Adtype := Atypep^.Stdtype;
      END;
   END;
Case Fidp^.Uinst of
   Unew:
      BEGIN
      Uco1int(Unew, 0);
      Restregs (Callnesting);
      END;
   Udsp:
      Uco0 (Fidp^.Uinst);
   Ucvt, Urnd:
      Uco2typtyp (Fidp^.Uinst, Gattr.Adtype, Argdtype);
   Uinc, Udec:
      Uco2typint (Fidp^.Uinst, Argdtype, 1);
   Uabs, Usqr, Uodd, Umin, Umax:
      Uco1type (Fidp^.Uinst, Argdtype);
   END;
IF Sy = Rparentsy THEN
  Insymbol
ELSE
  Warning(152);
Callnesting := Callnesting - 1;
END;

(*Callregular[Compparam]*)

(****************************************************************)
(*                                                              *)
(*      CALLREGULAR -- parses a call to a nonspecial            *)
(*         procedure or function                                *)
(*                                                              *)
(*      For each parameter:                                     *)
(*         if the parameter is a procedure/function, checks to  *)
(*            make sure it has a congruent parameter list and   *)
(*            result type                                       *)
(*         otherwise, checks to make sure that the type is      *)
(*            compatible                                        *)
(*         if formal parameter or large parameter (whose value  *)
(*            is passed indirectly), loads the address of the   *)
(*            parameter, else loads the parameter directly      *)
(*      If the procedure has been passed, loads its address     *)
(*            and emits an ICUP, else emits a CUP               *)
(*      Changes Gattr to reflect the function result type       *)
(*                                                              *)
(*      Contains procedures:                                    *)
(*                                                              *)
(*      Comparam:  tests if two parameter lists are congruent   *)
(*      Loadprocedureparam:  loads procedure or function        *)
(*      Loadparam:  loads any other procedure type              *)
(*                                                              *)
(****************************************************************)

PROCEDURE Callregular (Fsys: Setofsys; Fidp: Idp);

   VAR
      Pcount: Integer;
      Paramidp, Lastfileid: Idp;
      Lastfilestrp: Strp;
      Lattr: Attr;
      Lkind: Idkind;
      Done: Boolean;
      Lstamp: Integer;
      Lptr: LocalIdp;

   FUNCTION Compparam(Fidp1,Fidp2 : Idp):Boolean;

      (* checks to see if two parameter lists are congruent *)

      VAR
         Ok:Boolean;

      BEGIN (*compparam*)
      Ok := True;
      WHILE Ok AND (Fidp1<>NIL) AND (Fidp2<>NIL) DO WITH Fidp1^ DO
         BEGIN
         IF Comptypes(Idtype,Fidp2^.Idtype) THEN
            IF Klass=Fidp2^.Klass THEN
               IF Klass=Vars THEN
                  BEGIN
                  IF Vkind<>Fidp2^.Vkind THEN
                     BEGIN
                     Error(370); Ok := False
                     END
                  END
               ELSE
                  Ok := Compparam(Fparam,Fidp2^.Fparam)
            ELSE
               BEGIN
               Error(370); Ok := False
               END
         ELSE
            BEGIN
            Error(370); Ok := False
            END;
         Fidp1 := Next; Fidp2 := Fidp2^.Next
         END;
      IF Fidp1<>Fidp2 THEN
         BEGIN
         Error(554); Compparam := False
         END
      ELSE
         Compparam := Ok
      END(*compparam*);


   Procedure Loadprocedureparam (Paramidp: Idp);

      (* Loads procedural or functional parameter *)
      Var 
         Procedureidp, Paramlisthead: Idp;

      BEGIN
      IF Sy<>Identsy THEN
         Error(209)
      ELSE
         BEGIN
         Searchid([Proc,Func],Procedureidp);
         Procedureidp^.Referenced := True;  
         Insymbol;
         WITH Procedureidp^ DO
            IF Prockind <> Regular THEN
               Error(510)  (* can't pass standard procedures *)
            ELSE
               BEGIN
               IF Pfkind=Actual THEN
                  Paramlisthead := Next
               ELSE
                  Paramlisthead := Fparam;
               (* now Paramlisthead points to the head of the list of parameters
                for the actual procedure being passed *)
               (* check to see that the two parameter lists are equivalent *)
               IF Compparam(Paramidp^.Fparam,Paramlisthead) THEN
                  IF Paramidp^.Klass <> Klass THEN
                     Error(503)  (* one is func, the other proc *)
                  ELSE IF NOT Comptypes(Idtype,Paramidp^.Idtype) THEN
                     Error(555)  (* different result types *)
                  ELSE
                     BEGIN
                     (* generate code to load the procedure *)
                     IF Pfkind=Actual THEN Uco1idp (Uldp, Procedureidp)
                     ELSE    (*pfkind = formal*)
                        Uco5typaddr (Ulod,Edt,Pfmty,Pfblock,Pfaddr,Entrysize);
                     END
               END (* Prockind = regular *)
         END (* sy = identsy *);
      Par (Edt, Pcount);
      END;(* Loadprocedureparam *)

   Procedure Loadactualparam (Paramidp: Idp; Paramstrp: Strp);

      (* loads a actual parameter *)

      BEGIN
      Expression(Fsys + [Commasy,Rparentsy]);
      IF (Gattr.Atypep <> NIL) AND (Paramstrp <> NIL) THEN
         (* if a large set, record, or array, pass indirectly *)
         IF (Paramstrp^.Stdtype <> Mdt) AND
                (Paramstrp^.Stsize <= Parthreshold) THEN
            BEGIN (* pass directly *)
            (* check type of parameter *)
            IF NOT Comptypes(Paramstrp,Gattr.Atypep) AND 
                    NOT Comptypes(Realptr,Paramstrp) THEN
               Error(503);
            (* load parameter *)
            IF Paramstrp^.Form = Subrange THEN
               Loadandcheckbounds(Gattr,Paramstrp)
            ELSE
               BEGIN
               Load(Gattr);
               IF (Gattr.Adtype <> Paramstrp^.Stdtype) THEN
                  Matchtoassign(Gattr,Paramstrp);
               END;
            Par (Paramstrp^.Stdtype, Pcount);
            END
         ELSE    (* pass indirectly *)
            BEGIN
            IF Paramstrp = Anystringptr THEN
               BEGIN
               IF NOT String (Gattr.Atypep) THEN
                  Error(503);
               END
            ELSE IF NOT Comptypes(Paramstrp,Gattr.Atypep) THEN 
               Error(503);
            (* if we are going to pass a set expression indirectly,
               we must first store it in a temporary *)
            IF Paramstrp^.Form = Power THEN
               BEGIN
               SetMatchtoAssign (Gattr,Paramstrp,False);
               IF Gattr.Kind <> Varbl THEN
                  BEGIN
                  Load(Gattr);
                  Getatemp(Lattr,Gattr.Atypep,Lstamp,False);
                  Store(Lattr);
                  Gattr := Lattr;
                  END;
               END;
            Loadaddress(Gattr);
            (* if parameter is of type Anystring, then load its length *)
            Par (Adt, Pcount);
            IF Paramstrp = Anystringptr THEN
               BEGIN
               Paramidp := Paramidp^.Next;
               IF Gattr.Atypep <> NIL THEN
                  Uco3intval (Uldc, Jdt, Intsize, 
                              Stringchars(Gattr.Atypep^.Stsize));
	       Par (Jdt, Pcount);
               END;           
            END;
      END; (* Loadactualparam *)

   Procedure Loadformalparam (Paramidp: Idp; Paramstrp: Strp);

     (* loads a formal parameter *)

      Var
         Lidp: Idp;

      BEGIN
      IF Sy <> Identsy THEN
         BEGIN
         Error(209); Lidp := Uvarptr
         END
      ELSE
         BEGIN
         Searchid([Vars,Field],Lidp); Insymbol;
         END;

      (* passing a variable as a formal parameter counts as an 
         assignment to it *)
      Parseleft := True;
      Selector(Fsys + [Commasy,Rparentsy],Lidp);
      Parseleft := False;

      IF Gattr.Kind <> Varbl THEN
         Error(463)
      ELSE
         BEGIN
         Formalcheck (Gattr);
         Loadaddress(Gattr);
         Par (Adt, Pcount);
         (* check type *)
         IF Paramstrp <> NIL THEN
            (* if was a subrange, compare with original type *)
            IF Gattr.Subkind <> NIL THEN
              BEGIN
              IF Gattr.Subkind <> Paramstrp THEN
                 Error(503)
              END
            ELSE IF Gattr.Atypep <> NIL THEN
              BEGIN
              (* check for anyfile type *)
              IF (Paramstrp = Anyfileptr) OR (Paramstrp = Anytextptr) THEN
                BEGIN
                IF NOT (Gattr.Atypep^.Form = Files) THEN 
                   Error(503)
                ELSE IF (Paramstrp = Anytextptr) AND 
                  NOT (Gattr.Atypep^.Textfile) THEN
                   Error(503)
                ELSE
                  Lastfilestrp := Gattr.Atypep;
                Lastfileid := Lidp;
                END
              (* and anystring type *)
              ELSE IF Paramstrp = Anystringptr THEN
                 BEGIN
                 IF NOT String (Gattr.Atypep) THEN
                    Error(503);
                 Paramidp := Paramidp^.Next;
                 IF Gattr.Atypep <> NIL THEN
                    Uco3intval (Uldc, Jdt, Intsize, 
                                Stringchars(Gattr.Atypep^.Stsize));
	         Par (Jdt, Pcount);
                 END
              (* all other types: must be exact match *)
              ELSE IF Gattr.Atypep <> Paramstrp THEN
                 Error(503);
              END;
         END;
      END; (* Loadformalparam *)

   Procedure Loaddefaultparam (Paramidp, Defaultidp: Idp);
      BEGIN
      IF (Paramidp^.Idtype = Anyfileptr) OR (Paramidp^.Idtype = Anytextptr) THEN
         BEGIN
         WITH Defaultidp^ DO
            UcoLda (Mdt, Vmty, Vblock, Vaddr, Pointersize);
         Par (Adt, Pcount);
         END
      ELSE IF Paramidp^.Idtype = Anystringptr THEN
         BEGIN
         Uco3val (Ulca, Mdt, Charsize, Defaultidp^.Values);
         Par (Adt, Pcount);
         Uco3val (Uldc, Jdt, Intsize, Paramidp^.Next^.Default^.Values);
         Par (Jdt, Pcount);
         END
      ELSE (* Paramidp^.Idtype = Intptr *)
         BEGIN
         Uco3val (Uldc, Jdt, Intsize, Defaultidp^.Values);
         Par (Jdt, Pcount);
         END;
      END;

   PROCEDURE Finishresetrewrite;

      VAR
          Ft: Integer;
          Siz: Integer;

      BEGIN
      (* prompt name *)
      Uco1idp (Ulca,Lastfileid);
      Par (Adt,Pcount);
      IF Lastfilestrp <> NIL THEN
         WITH Lastfilestrp^ DO
            BEGIN
            (* file type *)
            IF NOT Textfile THEN Ft := 0   (* binary *)
            ELSE IF Lastfilestrp = Asciiptr THEN Ft := 2 (* ascii *)
            ELSE Ft := 1;  (* char *)
            Uco3int(Uldc,Jdt,Intsize,Ft);
            Par (Jdt,Pcount);
            (* file size *)
            IF Filetype <> NIL THEN  
	       BEGIN 
	       IF Filepf OR Textfile THEN
		  BEGIN
		  Siz := Filetype^.Packsize;
	          Roundup (Siz, Fpackunit);
		  IF (Machine = 10) AND (Siz > Salign) THEN
	             Roundup (Siz, Salign);
	          END
	       ELSE
		  Siz := Filetype^.Stsize;
               Uco3int(Uldc,Jdt,Intsize,Siz);
	       Par (Jdt,Pcount);
	       END;
            END;
      END;

   BEGIN   (* Callregular *)
   Lstamp := 0;
   Lastfileid := Uvarptr;
   Lastfilestrp := NIL;
   Pcount := 0;
   Callnesting := Callnesting + 1;
   WITH Fidp^ DO
      BEGIN
      (* give warning if non-standard proc *)
      If Standardonly AND Nonstandard THEN Warning (212);
      Uco1int(Umst,Pflev);    (* generate MST for the call *)
      Lptr := Regreflist;
      WHILE Lptr <> NIL DO
	 BEGIN
	 WITH Lptr^.Mainrec^ DO
	    Uco6 (Urstr, Idtype^.Stdtype, Vmty, Vblock, Vaddr, 
		  Idtype^.Stsize, Vaddr);
         Lptr := Lptr^.Next;
	 END;
      Lkind := Pfkind;
      (* set Paramidp to the head of the parameter chain *)
      IF Lkind = Actual THEN  
         Paramidp := Next
      ELSE                    (* Lkind = Formal: passed procedure *)
         Paramidp := Fparam;
      END;

   IF Sy = Lparentsy THEN
      BEGIN                   (* parse and load parameters *)
      REPEAT
         Insymbol;
         IF Paramidp=NIL THEN
            Error(554)
         ELSE
            IF Paramidp^.Klass IN [Proc,Func] THEN   (*procedural parameters*)
                Loadprocedureparam (Paramidp)
            ELSE IF Paramidp^.Vkind = Actual THEN   (* passed by value *)
                Loadactualparam (Paramidp, Paramidp^.Idtype)   
            ELSE (* passed by reference *)
                Loadformalparam (Paramidp, Paramidp^.Idtype); 
         IF Paramidp <> NIL THEN
            IF Paramidp^.Idtype = Anystringptr THEN
               Paramidp := Paramidp^.Next^.Next         
            ELSE
               Paramidp := Paramidp^.Next;
         Skipiferr([Commasy,Rparentsy],256,Fsys)
      UNTIL Sy <> Commasy;
      IF Sy = Rparentsy THEN
         Insymbol
      ELSE
         Warning(152) 
      END (*if lparentsy*);

   (* load any default parameters *)
   REPEAT
      IF Paramidp = NIL THEN
         Done := True
      ELSE IF Paramidp^.Default = NIL THEN
         Done := True
      ELSE
         BEGIN
         Loaddefaultparam (Paramidp, Paramidp^.Default);
         IF Paramidp^.Idtype = Anystringptr THEN
            Paramidp := Paramidp^.Next^.Next
         ELSE 
            Paramidp := Paramidp^.Next;
         Done := False;
         END
   UNTIL Done;

   (* check to make sure enough parameters are being passed *)
   IF Paramidp <> NIL THEN
      Error(554);
   (* if Reset or Rewrite, add special parameters *)
   IF ((Fidp = Resetptr) OR (Fidp = Rewriteptr)) AND (Lastfileid <> NIL) THEN 
      Finishresetrewrite;
   (* generate the Cup or Icup *)
   WITH Fidp^ DO
      BEGIN
      Referenced := True;
      IF Lkind = Actual THEN
         BEGIN
         Uco1idp (Ucup,Fidp);
         END
      ELSE        (* Lkind = Formal *)
         BEGIN   (*call of a parameter procedure*)
         Uco5typaddr (Ulod,Edt,Pfmty,Pfblock,Pfaddr,Entrysize);
         Uco1idp(Uicup,Fidp);
         END;
      Restregs (Callnesting);
      Callnesting := Callnesting - 1;
      END;
   (* modify Gattr to reflect the function result type *)
   IF (Fidp^.Klass = Func) THEN  
      WITH Gattr DO
         BEGIN
         Atypep := Fidp^.Idtype;
         Kind  := Expr;
         IF Atypep <> NIL THEN
           Adtype := Atypep^.Stdtype;
         END;
   (* else procedure; GATTR does not need to be set *)
   IF Lstamp > 0 THEN Freetemps (Lstamp);
   (* restore register variables *)
   Lptr := Regreflist;
   WHILE Lptr <> NIL DO
      BEGIN
      WITH Lptr^.Mainrec^ DO
	 Uco6 (Urlod, Idtype^.Stdtype, Vmty, Vblock, Vaddr, 
	       Idtype^.Stsize, Vaddr);
      Lptr := Lptr^.Next;
      END;
   END (*Callregular*) ;



(*Setconst[Setelement,Setpart]*)

(****************************************************************)
(****************************************************************)
(*                                                              *)
(*      EXPRESSION MODULE -- parses and generates code for      *)
(*         expression.  A variable or constant is generally     *)
(*         not loaded until something is done with it, i.e.     *)
(*         an operation is performed on it or it is assigned    *)
(*         to something.                                        *)
(*      A description of the expression, variable, or constant  *)
(*         parsed is returned in the global variable GATTR.     *)
(*                                                              *)
(*      Contains the following procedures, each of which calls  *)
(*         the one below it:                                    *)
(*                                                              *)
(*         Expression                                           *)
(*         Simpleexpression                                     *)
(*         Term                                                 *)
(*         Factor                                               *)
(*         Setconstant                                          *)
(*                                                              *)
(****************************************************************)
(****************************************************************)


(****************************************************************)
(*                                                              *)
(*      SETCONSTANT -- parses a set constant                    *)
(*                                                              *)
(*   A set constant consists of a list of set parts, each of    *)
(*   which is a single set element or a range of elements.      *)
(*   A set part can be either constant or variable:             *)
(*                                                              *)
(*   Example of constant parts:  3, 6*8, 1..5                   *)
(*   Example of variable parts:  I, J*8, 1..K, J..K             *)
(*                                                              *)
(*   The constant parts are combined in a TARGETSET, which is   *)
(*   an array of host sets.  For each variable part, code to    *)
(*   load it on the stack and to combine it with previous       *)
(*   variable parts is generated.  As each new part is read,    *)
(*   the lower bound and the set size must be figured out, and  *)
(*   appropriate actions to make previous parts conform to this *)
(*   new lower bound and set size must be taken.  The lower     *)
(*   bound and upper bounds must be at least as low and high as *)
(*   the minimum and maximum constants read so far.  In         *)
(*   addition, they are adjusted to accomodate the varible      *)
(*   parts insofar as possible.  If the variable part is a      *)
(*   single variable of type subrange, then its lower and upper *)
(*   bounds can be used in the calculations;  otherwise, a      *)
(*   default lower and upper bound is used.                     *)
(*                                                              *)
(*   Contains procedures:                                       *)
(*                                                              *)
(*      Setelement: parses a single set element or range part   *)
(*      Setpart:    parses a single set part                    *)
(*                                                              *)
(*   Calls procedures:                                          *)
(*                                                              *)
(*      Expression: to get next set element                     *)
(*      Shiftset:   to shift constant part of set               *)
(*                                                              *)
(****************************************************************)


PROCEDURE Setconst (Fsys: Setofsys);

VAR Minc, Maxc,                  (* highest and lowest constants so far *)
   Minlowbound, Maxhighbound,    (* highest and lowest subranges so far *)
   Setmin, Setmax, Setsize,      (* current set min, max, and size *)
   Lowval,Highval,               (* low and high value of current constant
                                    set part *)
   Pmin, Pmax,                   (* low and high bound of current set part *)
   Varsetsize, Varsetmin,        (* min and size of last set for which code
                                  has been emmited *)
   Constsetmin:  Integer;        (* min of constant set *)
   Cstpart: Valu;                (* current constant part of the set,
                                    represented by an array of host sets *)
   Gotexpr,              (* true if not-constant set part has been read *)
   Gotconst,             (* true if constant set part has been read *)
   Indexed, Isrange, Loopdone: Boolean;
   Lstrp: Strp;          (* points to structure of set elements *)
   Lvalu: Valu;
   I,J,K,Shift: Integer;
   Lattr: Attr;

   PROCEDURE Setelement (VAR Minv,Maxv:Integer);

      (* gets the next set element or part of a subrange;
       if this element is a constant, its value is returned in MINV and MAXV;
       else if it is a variable of type subrange, then code is generated to
       load it and MINV and MAXV contain the subrange;
       else (it is a variable of type integer or an expression),
       it is loaded and MINV and MAXV are set to default values
       *)

      BEGIN
      Minv := 0;
      Maxv := Defsetsize-1;
      Expression(Fsys + [Commasy,Rbracksy,Rangesy]);
      WITH Gattr DO
         IF Atypep <> NIL THEN
            IF (Atypep^.Form <> Scalar) OR (Atypep = Realptr) THEN
               BEGIN
               Error(461); Atypep := NIL
               END
            ELSE   (* legitimiate set type *)
               BEGIN
               IF Lstrp = NIL THEN Lstrp := Atypep; (* first set element *)
               (* make sure is compatible with previous set elements *)
               IF NOT Comptypes(Lstrp,Atypep) THEN
                  Error(360)
               ELSE
                  IF Kind = Cnst THEN
                     BEGIN
                     Minv := Cval.Ival;
                     Maxv := Cval.Ival;
                     END
                  ELSE IF Kind = Varbl THEN
		     BEGIN
		     Load (Gattr);
		     IF Subkind <> NIL THEN
			BEGIN
			Minv := Subkind^.Vmin.Ival;
			Maxv := Subkind^.Vmax.Ival;
			END
                     END;
               END (* legitimate set type *);
      END; (*SETELEMENT*)

   PROCEDURE Setpart (VAR Pmin, Pmax, Lowval, Highval: Integer;
                      VAR Indexed, Isrange: Boolean);
      (** gets a set element or subrange;
       on return from this procedure,
       PMIN is the smallest possible value for this part (may be a guess;
       will always be a multiple of Setunitsize)
       PMAX is the largest possible value for this part (ditto)
       LOWVAL is the actual lowest value, if this part is constant
       HIGHVAL is the actual highest value, if this part is constant
       INDEXED is true if code has been generated (a non-constant set part has
       been read)
       ISRANGE is true if the set part read is a range rather than a single
       expression
       *)

      VAR Tmin,Tmax:Integer;

      BEGIN
      Setelement (Pmin,Pmax);
      Isrange := Sy = Rangesy;
      IF NOT Isrange THEN
         BEGIN
         Indexed := (Gattr.Kind <> Cnst);
         IF NOT Indexed THEN Pmax := Pmin;
         END
      ELSE
         BEGIN (* parse second part of range *)
         Lattr := Gattr;
         Insymbol;
         Setelement (Tmin,Tmax);
         Pmin := Min (Pmin, Tmin);
         Pmax := Max (Pmax, Tmax);
         (* if one or the other is on the stack, make sure both are *)
         IF Gattr.Kind = Cnst THEN
            BEGIN
            Indexed := (Lattr.Kind <> Cnst);
            IF Indexed THEN Load (Gattr);
            END
         ELSE
            BEGIN
            Indexed := True;
            IF Lattr.Kind = Cnst THEN
               BEGIN
               Load (Lattr);
               Uco2typtyp (Uswp,Lattr.Adtype,Gattr.Adtype);
               END
            END
         END (* parse second part of range *);
      Lowval := Pmin;
      Highval := Pmax;
      IF Zerobased THEN
         BEGIN
         Pmin := 0;
         IF (Lowval < 0) OR (Highval < 0) THEN
            BEGIN
            Error (177);
            Lowval := 0;
            Highval := 0;
            Pmax := Defsetsize - 1;
            END
         END
      ELSE IF Pmin MOD Setunitsize <> 0 THEN
         BEGIN
         Pmin := (Pmin DIV Setunitsize) * Setunitsize;
         (*this kludge is necessary because stupid old Pascal doesn't truncate
          towards -maxint *)
         IF Lowval < 0 THEN Pmin := Pmin - Setunitsize;
         END;
      IF Pmax MOD Setunitsize + 1 <> 0 THEN
         BEGIN
         Pmax := Abs (Pmax);
         Pmax := (Pmax DIV Setunitsize + 1) * Setunitsize - 1;
         IF Highval < 0 THEN Pmax := Pmax - Setunitsize;
         END;
      END;

BEGIN (*SETCONST*)
Minc := Maxint;  Maxc := -Maxint;
Minlowbound := Maxint;  Maxhighbound := -Maxint;
Setmin := Maxint; Setmax := -Maxint; Setsize := 0;
Gotexpr := False; Gotconst := False;
Loopdone := False;
Lstrp := NIL;
Insymbol;
IF Sy = Rbracksy THEN
   BEGIN  (* null set *)
   Cstpart := Emptytargetset;
   Gotconst := True;
   Setmin := 0;
   Setmax :=  Setunitsize-1;
   Setsize := Setunitsize;
   END
ELSE
   REPEAT
      BEGIN (* add next set part to set *)
      Setpart (Pmin,Pmax,Lowval,Highval,Indexed,Isrange);
      IF NOT Indexed THEN
         BEGIN (* add constant to set *)
         (* find the min and max constant so far *)
         Minc := Min (Minc,Pmin);
         Maxc := Max (Maxc,Highval);
         (* check to see if range is too great *)
         IF Maxc - Minc + 1 > Maxsetsize THEN
            BEGIN
            Error (177);
            Setmin := 0; Setmax := Defsetsize-1;
            Setsize := Defsetsize;
            END
         ELSE
            BEGIN (* not out of range *)
            (* adjust SETMIN and SETMAX if necessary *)
            IF Minc < Setmin THEN
               BEGIN
               Setmin := Pmin;
               IF Setmax > Setmin THEN
                  IF Setmax - Setmin + 1 > Maxsetsize THEN
                     Setmax := Setmin + Maxsetsize - 1;
               END;
            IF Maxc > Setmax THEN
               BEGIN
               Setmax := Pmax;
               IF Setmax - Setmin + 1 > Maxsetsize THEN
                  Setmin := Setmax - Maxsetsize + 1;
               END;
            Setsize := Setmax - Setmin + 1;
            (* add to set const *)
            IF NOT Gotconst THEN
	       BEGIN
               Cstpart := Emptytargetset;
	       Constsetmin := 0;
	       END;
            (* shift existing set constant *)
            Shiftset (Cstpart, Constsetmin-Setmin, Setsize); 
            (* set Lowval through Highval in the set *)
            FOR I := Lowval-Setmin TO Highval-Setmin DO
	       WITH Cstpart DO
	          BEGIN
                  J := I DIV 4 + 1;
		  K := Ord (Chars[J]) - Ord ('0');
                  IF K > 9 THEN K := K - Aninedifm1;
	          CASE I Mod 4 OF
	             3: IF NOT Odd(K) THEN K := K + 1;
	             2: IF NOT Odd(K DIV 2) THEN K := K + 2;
	             1: IF NOT Odd((K MOD 8) DIV 4) THEN K := K + 4;
	             0: IF K < 8 THEN K := K + 8;
		     END;
	          IF K > 9 THEN K := K + Aninedifm1;
		  Chars[J] := Chr (K + Ord ('0'));
		  END;
            END; (* not out of range *)
         Gotconst := True;
         Constsetmin := Setmin;
         Cstpart.Len := (Setmax-Setmin+1) DIV 4;
         END (* add constant to set *)
      ELSE
         BEGIN (* add variable to set *)
         (* adjust SETMIN and SETMAX *)
         Minlowbound := Min (Minlowbound, Pmin);
         IF Minlowbound < Setmin THEN
            (* only set SETMIN to MINLOWBOUND if resulting set will be
             big enough to hold HAXC *)
            IF Maxc = -Maxint THEN Setmin:= Minlowbound
            ELSE IF Maxc - Minlowbound + 1 > Maxsetsize THEN
               Setmin := Maxc - Maxsetsize + 1
            ELSE Setmin := Minlowbound;
         Maxhighbound := Max (Maxhighbound, Pmax);
         IF Maxhighbound > Setmax THEN
            IF Maxhighbound - Setmin + 1 > Maxsetsize THEN
               Setmax := Setmin + Maxsetsize - 1
            ELSE Setmax := Maxhighbound;
         Setsize := Setmax - Setmin + 1;
         (* generate final code to load this set part *)
         IF Isrange THEN
            BEGIN
            Matchtypes (Lattr);
            IF (Setmin <> 0) OR Runtimecheck THEN
               BEGIN
               Uco2typtyp(Uswp,Gattr.Adtype,Lattr.Adtype);
               IF Runtimecheck THEN Uco2typint(Uchkl,Lattr.Adtype,Setmin);
               IF Setmin <> 0 THEN Adjtosetoffset (Lattr,Setmin);
               Uco2typtyp(Uswp,Lattr.Adtype,Gattr.Adtype);
               IF Runtimecheck THEN Uco2typint(Uchkh,Gattr.Adtype,Setmax);
               IF Setmin <> 0 THEN Adjtosetoffset (Gattr,Setmin);
               END;
            Uco2typint(Umus,Gattr.Adtype,Setsize)
            END
         ELSE
            BEGIN
            IF Runtimecheck THEN
               BEGIN
               Uco2typint(Uchkl,Gattr.Adtype,Setmin);
               Uco2typint(Uchkh,Gattr.Adtype,Setmax);
               END;
            IF Setmin <> 0 THEN Adjtosetoffset (Gattr,Setmin);
            Uco2typint (Usgs,Gattr.Adtype,Setsize);
            END;
         IF Gotexpr THEN
            BEGIN
            (* combine set just loaded with set already loaded *)
            Shift := Varsetmin - Setmin;
            IF (Shift <> 0) OR (Varsetsize <> Setsize) THEN
               BEGIN
               Uco2typtyp(Uswp,Sdt,Sdt);
               Uco3int(Uadj,Sdt,Setsize,Shift);
               END;
            Uco2typint(Uuni,Sdt,Setsize);
            END;
         Varsetmin := Setmin;
         Varsetsize := Setsize;
         Gotexpr := True;
         END (* add variable to set *);
      Loopdone := (Sy = Commasy);
      IF Loopdone THEN Insymbol;
      END (* add next set part to set *)
   UNTIL NOT Loopdone;
IF Sy = Rbracksy THEN Insymbol
ELSE Error(155);
IF Gotconst AND Gotexpr THEN
   (* add constant and var halves *)
   BEGIN
   (* shift var half to conform with const half *)
   Shift := Varsetmin - Setmin;
   IF (Shift <> 0) OR (Varsetsize <> Setsize) THEN
      Uco3int (Uadj, Sdt, Setsize, Shift);
   (* shift const half to conform with var half *)
   Shiftset (Cstpart, Constsetmin-Setmin, Setsize); 
   (* load the const half *)
   Lvalu := Cstpart;
   Uco3val(Uldc,Sdt,Setsize,Lvalu);
   (* combine the two *)
   Uco2typint(Uuni,Sdt,Setsize);
   END;
WITH Gattr DO
   BEGIN (* change GATTR to describe the entire set constant *)
   New(Atypep,Power);
   WITH Atypep^ DO
      BEGIN
      Basetype := Lstrp; Stsize :=  Setsize; Marker := 0;
      Packsize := Setsize; Form := Power; Stdtype := Sdt;
      Softmin := Setmin; Softmax := Setmax;
      Hasfiles := False; Hasholes := False;
      Hardmin := Minc; Hardmax := Maxc; 
      END;
   Adtype := Sdt;
   IF Gotexpr THEN Kind := Expr
   ELSE
      BEGIN
      Kind := Cnst;
      Cval := Cstpart;
      END;
   END;
END (* SETCONST *);



(*Simplexpression,Factor*)


PROCEDURE Expression;  (*(Fsys: Setofsys); *)
   VAR
      Lattr: Attr;
      Lsy: Symbol;
      Linstr: Uopcode;

(****************************************************************)
(*                                                              *)
(*      FACTOR -- parses one of the following:                  *)
(*          a variable, a Const constant, an unsigned integer   *)
(*          or real constant, a string constant, a set constant,*)
(*          a function call, NIL, NOT <factor>,                 *)
(*          or ( <expression> )                                 *)
(*                                                              *)
(*      Calls procedures Callspecial, Callinline, and           *)
(*          Callregular to process function calls and Variable  *)
(*          to process variables                                *)
(*                                                              *)
(****************************************************************)

   PROCEDURE Factor(Fsys: Setofsys);
      VAR
         Lidp: Idp;
         Lklass: Idclass;

      BEGIN (*factor*)
      IF NOT (Sy IN Facbegsys) THEN
         BEGIN
         Errandskip(173,Fsys + Facbegsys);
         Gattr.Atypep := NIL;
         END;
      IF Sy IN Facbegsys THEN (*construct the appropriate Gattr*)
         BEGIN
         CASE Sy OF
            Identsy:
               BEGIN
               Searchid([Konst,Vars,Field,Func],Lidp);
               Insymbol;
               Lklass := Lidp^.Klass;
               IF Lklass = Func THEN                (*function call*)
                  IF Lidp^.Prockind = Special THEN
                     Callspecial (Fsys,Lidp)
                  ELSE IF Lidp^.Prockind = Inline THEN
                     Callinline (Fsys,Lidp)
                  ELSE Callregular (Fsys,Lidp)
               ELSE IF Lklass = Konst THEN              (*constant name*)
                  WITH Gattr, Lidp^ DO
                     BEGIN
                     Referenced := True;
                     Atypep := Idtype; Kind := Cnst;
                     Cval := Values;
                     IF Idtype <> NIL THEN
                        Adtype := Idtype^.Stdtype;
                     END (*konst*)
               ELSE                                         (*variable*)
                  Selector(Fsys,Lidp);
               IF Gattr.Atypep <> NIL THEN
                  WITH Gattr, Atypep^ DO
                     IF Form = Subrange THEN     (*eliminate subrange types*)
                        BEGIN
                        IF Kind = Varbl THEN Subkind := Atypep;
                        Atypep := Hosttype      (*to simplify later tests*)
                        END
                     ELSE
                        IF Kind = Varbl THEN Subkind := NIL;
                  IF Gattr.Kind = Varbl THEN
                  IF Gattr.Indexed THEN
                     Loadaddress(Gattr); 
               (*avoid half-addressed objects*)
               END (*identsy*);
            Intconstsy:                       (*integer values*)
               WITH Gattr DO
                  BEGIN
                  Kind := Cnst;
                  Atypep := Intptr;
                  Cval.Ival := Val.Ival;
                  IF Cval.Ival >= 0 THEN
                     Adtype := Ldt
                  ELSE
                     Adtype := Jdt;
                  Insymbol;
                  END (*intconstsy*);
            Realconstsy:                      (*real values*)
               WITH Gattr DO
                  BEGIN
                  Atypep := Realptr; Kind := Cnst;
                  Cval := Val; Adtype := Rdt;
                  Insymbol;
                  END (*realconstsy*);
            Stringconstsy:                    (*string constant values*)
               WITH Gattr DO
                  BEGIN
                  Constant(Fsys,Atypep,Cval) ; Kind := Cnst;
                  Adtype := Atypep^.Stdtype;
                  END (*stringconstsy*);
            Lparentsy:                        (*parenthesized expression*)
               BEGIN
               Insymbol; Expression(Fsys + [Rparentsy]);
               IF Sy = Rparentsy THEN
                  Insymbol
               ELSE
                  Warning(152)
               END (*lparentsy*);
            Notsy:                          (*negated boolean*)
               BEGIN
               Insymbol; Factor(Fsys);
               IF Gattr.Adtype = Bdt THEN
                  IF Gattr.Kind = Cnst THEN
                     Gattr.Cval.Ival := (Gattr.Cval.Ival + 1) MOD 2
                  ELSE
                     BEGIN
                     Load(Gattr); Uco1type(Unot,Bdt);
                     END
               ELSE
                  BEGIN
                  Error(359); Gattr.Atypep := NIL
                  END
               END (*notsy*);
            Nilsy:
               WITH Gattr DO
                  BEGIN
                  Atypep := Nilptr; Kind := Cnst;
                  Cval.Ival := -1;
                  Adtype := Adt;
                  Insymbol;
                  END;
            Lbracksy:                         (*set constructor*)
               Setconst (Fsys)
            END (*case sy of*) ;
         Iferrskip(166,Fsys)
         END (*if sy in facbegsys*);
      END (*factor*) ;



(*Term,Simpleexpression,Expression*)

(****************************************************************)
(*                                                              *)
(*      TERM -- parses expression of the form                   *)
(*                 FACTOR OP FACTOR                             *)
(*      where OP can be *, /, DIV, MOD, or AND                  *)
(*                                                              *)
(****************************************************************)

PROCEDURE Term(Fsys: Setofsys);
   VAR
      Lattr: Attr;
      Lsy: Symbol;

   BEGIN    (*term*)
   Factor(Fsys + Mulopsys); (* get first factor *)
   (* if next symbol is a multiplying operator, get next factor and emit 
      code to perform the operation *)
   WHILE Sy in Mulopsys DO
      BEGIN
      Lattr := Gattr; Lsy := Sy;
      Insymbol; Factor(Fsys + Mulopsys);
      WITH Gattr DO
         IF (Lattr.Atypep = NIL) OR (Atypep = NIL) THEN
            Atypep := NIL
         ELSE
            CASE Lsy OF
               Mulsy:                    (* * *)
                  IF (Lattr.Adtype = Sdt) AND (Adtype = Sdt) THEN
                     BEGIN (* set intersection *)
                     Matchsets (Lattr);
                     Generatecode(Uint,Sdt,Lattr)
                     END
                  ELSE
                     BEGIN  (* multiply *)
                     (* convert Lattr and Gattr to be the same type *)
                     Matchtypes(Lattr);
                     IF (Adtype = Lattr.Adtype) AND 
                      (Adtype IN [Jdt,Ldt,Rdt]) THEN
                        Generatecode(Umpy,Adtype,Lattr)
                     ELSE
                        BEGIN
                        Error(311); Atypep := NIL
                        END
                     END;
               Rdivsy:                   (* / *)
                  BEGIN (* real divide *)
                  (* convert Lattr and Gattr to the same real type *)
                  Makereal(Lattr);
                  if (Lattr.Adtype = Adtype) and 
                   (Gattr.Adtype = Rdt) then
                     Generatecode(Udiv,Adtype,Lattr)
                  ELSE
                     BEGIN
                     Error(311); Atypep := NIL
                     END
                  END (* / *);
               Idivsy:                   (* div *)
                  BEGIN
                  (* convert Lattr and Gattr to same integer type *)
                  Matchtypes(Lattr);
                  IF (Adtype = Lattr.Adtype) AND 
                   (Adtype in [Jdt,Ldt]) THEN
                     Generatecode(Udiv,Adtype,Lattr)
                  ELSE
                     BEGIN
                     Error(311); Atypep := NIL
                     END
                  END (* div *);
               Modsy:                   (* mod *)
                  BEGIN
                  (* convert Lattr and Gattr to same integer type *)
                  Matchtypes(Lattr);
                  IF (Atypep = Lattr.Atypep) AND 
                   (Adtype in [Jdt,Ldt]) THEN
                     Generatecode(Umod,Adtype,Lattr)
                  ELSE
                     BEGIN
                     Error(311); Atypep := NIL
                     END
                  END (*div *);
               Andsy:                  (* and *)
                  IF (Lattr.Adtype = Bdt) AND (Adtype = Bdt) THEN
                     Generatecode(Uand,Bdt,Lattr)
                  ELSE
                     BEGIN
                     Error(359); Atypep := NIL
                     END
               END (*case Lsy of*)
      END (*while sy in mulopsys*)
   END (*term*) ;

   (****************************************************************)
   (*                                                              *)
   (*      SIMPLEEXPRESSION -- parses expression of the form       *)
   (*              SIGN TERM OP TERM                               *)
   (*      where OP can be +, -, or OR                             *)
   (*                                                              *)
   (*                                                              *)
   (****************************************************************)

PROCEDURE Simpleexpression(Fsys: Setofsys);
   VAR
      Lattr: Attr;
      Lsy, Sign: Symbol;

   BEGIN   (*simpleexpression*)
   (* get initial + or - *)
   IF (Sy in [Plussy,Minussy]) THEN
      BEGIN
      Sign := Sy; Insymbol
      END
   ELSE Sign := Othersy;
   Term(Fsys + Addopsys);  (* get first term *)
   (* negate first term, if there was an initial - *)
   IF Sign <> Othersy THEN
      WITH Gattr DO
         IF Atypep <> NIL THEN
            (* make sure item to be negated was a number *)
            IF Adtype IN [Jdt,Ldt,Rdt] THEN
               BEGIN
               IF Sign = Minussy THEN Generatecode (Uneg,Adtype,Gattr)
               END
            ELSE
               BEGIN
               Error(311) ; Gattr.Atypep := NIL
               END ;

   (* if next symbol is an adding operator, get next term and emit code to
    perform the operation *)
   WHILE Sy in Addopsys DO
      BEGIN
      Lattr := Gattr; Lsy := Sy;
      Insymbol; Term(Fsys + Addopsys);
      WITH Gattr DO
         IF (Lattr.Atypep <> NIL) AND (Atypep <> NIL) THEN
            CASE Lsy OF
               Plussy:                       (* + *)
                  IF (Lattr.Adtype = Sdt) AND (Adtype = Sdt) THEN
                     BEGIN (* set union *)
                     Matchsets (Lattr);
                     Generatecode(Uuni,Sdt,Lattr);
                     END
                  ELSE
                     BEGIN (* addition *)
                     Matchtypes(Lattr);
                     IF (Adtype = Lattr.Adtype) AND 
                      (Adtype IN [Jdt,Ldt,Rdt]) THEN
                        Generatecode(Uadd,Adtype,Lattr)
                     ELSE
                        BEGIN
                        Error(311); Atypep := NIL
                        END
                     END;
               Minussy:                      (* - *)
                  IF (Lattr.Adtype = Sdt) AND (Adtype = Sdt) THEN
                     BEGIN (* set difference *)
                     Matchsets (Lattr);
                     Generatecode(Udif,Sdt,Lattr)
                     END
                  ELSE
                     BEGIN (* subtraction *)
                     Matchtypes(Lattr);
                     IF (Adtype = Lattr.Adtype) AND 
                      (Adtype IN [Jdt,Ldt,Rdt]) THEN
                        Generatecode(Usub,Adtype,Lattr)
                     ELSE
                        BEGIN
                        Error(311); Atypep := NIL
                        END
                     END;
               Orsy:                       (* or *)
                  IF (Lattr.Adtype = Bdt) AND (Adtype = Bdt) THEN
                     Generatecode(Uior,Bdt,Lattr)
                  ELSE
                     BEGIN
                     Error(359); Atypep := NIL
                     END
               END (*case Lsy of*)
         ELSE
            Atypep := NIL;
      END (*while sy in addopsys*);
   END (*simpleexpression*) ;

   (****************************************************************)
   (*                                                              *)
   (*      EXPRESSION -- parses expression of the form             *)
   (*         SIMPLEEXPRESSION OP SIMPLEEXPRESSION                 *)
   (*      where OP can be =, <>, <, >, <=, >=, or IN              *)
   (*                                                              *)
   (****************************************************************)

BEGIN    (*expression*)
Simpleexpression(Fsys + Relopsys);
IF Sy in Relopsys THEN
   BEGIN
   Lattr := Gattr;
   Lsy := Sy;
   Insymbol; Simpleexpression(Fsys);
   WITH Gattr DO
      BEGIN
      IF (Lattr.Atypep <> NIL) AND (Atypep <> NIL) THEN
         BEGIN
         IF Lsy = Insy THEN                  (* in *)
            BEGIN
            IF Adtype <> Sdt THEN
               BEGIN
               Error(213); Atypep := NIL
               END
            ELSE
               (* make sure the element to be tested is the same kind of
                simple type that the set is composed of *)
               IF NOT Comptypes(Lattr.Atypep,Atypep^.Basetype) THEN
                  BEGIN
                  Error(260); Atypep := NIL
                  END
               ELSE
                  BEGIN
                  IF Atypep^.Softmin <> 0 THEN
                     BEGIN
                     (* increment or decrement the element in accordance
                      with the base of the set *)
                     Loadboth (Lattr);
                     Uco2typtyp(Uswp,Sdt,Lattr.Adtype);
                     Adjtosetoffset (Lattr,Gattr.Atypep^.Softmin); 
                     Uco2typtyp(Uswp,Lattr.Adtype,Sdt);
                     END;
                  Generatecode(Uinn,Lattr.Adtype,Lattr);
                  END
            END
         ELSE        (*Lsy <> Insy*)            (* comparisons *)
            BEGIN
            IF Lattr.Atypep^.Form = Power THEN Matchsets(Lattr)
            ELSE Matchtypes(Lattr);
            IF NOT Comptypes(Lattr.Atypep,Atypep) THEN
               Error(260)
            ELSE
               BEGIN
               CASE Lattr.Atypep^.Form OF
                  Scalar,Subrange: ;
                  Power:
                     IF Lsy IN [Ltsy,Gtsy] THEN
                        Error(313);
                  Arrays, Pointer, Records:
                     (* only strings can be tested for anything but
                      equality and inequality *)
                     IF  NOT String(Lattr.Atypep) THEN
                        IF Lsy IN [Ltsy,Lesy,Gtsy,Gesy] THEN
                           Error(312);
                  Files:
                     Error(314)
               END;
               (* if we are comparing two arrays or records, the
                operators should be IEQU and co. instead of EQU
                and co. *)
               IF (Lattr.Atypep^.Stdtype <> Mdt) THEN
                  BEGIN
                  CASE Lsy OF
                     Ltsy: Linstr := Ules;
                     Lesy: Linstr := Uleq;
                     Eqsy: Linstr := Uequ;
                     Gesy: Linstr := Ugeq;
                     Gtsy: Linstr := Ugrt;
                     Nesy: Linstr := Uneq;
                     END (*case Lsy of*);
                  Generatecode(Linstr,Adtype,Lattr);
                  END 
               ELSE    
                  BEGIN
                  Loadboth(Lattr);
                  CASE Lsy OF
                     Ltsy: Linstr := Uiles;
                     Lesy: Linstr := Uileq;
                     Eqsy: Linstr := Uiequ;
                     Gesy: Linstr := Uigeq;
                     Gtsy: Linstr := Uigrt;
                     Nesy: Linstr := Uineq;
                     END (*case Lsy of*);
                  Uco2typint(Linstr,Adtype,Atypep^.Stsize);
                  Kind := Expr;
                  END (*stsize > indir...*);
               END  (*comptypes...*)
            END     (*Lsy <> insy*);
         END (*(lattr.atypep <> nil) and (atypep <> nil)*);

      (* the item on top of the stack is now a boolean.  Change Gattr to
       reflect this *)
      Atypep := Boolptr; Adtype := Bdt;
      END (*with gattr*)
   END (*if sy = reLsysy*);
END (*expression*) ;



(*Assignment*)

(****************************************************************)
(*                                                              *)
(*      ASSIGNMENT                                              *)
(*                                                              *)
(*      parameter:                                              *)
(*        FIDP: pointer to the identifier already parsed        *)
(*                                                              *)
(*      Parses left side of assignement statement, putting      *)
(*        address on stack if necessary                         *)
(*      Parses right side.  Checks for assignment compatibility.*)
(*        Does any necessary conversions                        *)
(*      Generates code to load right side and store into left   *)
(*        side                                                  *)
(*                                                              *)
(****************************************************************)


PROCEDURE Assignment (* fidp: idp *);

VAR
   Leftside: Attr;


BEGIN    (*assignment*)
IF Fidp^.Klass = Vars THEN
   IF Fidp^.Loopvar THEN Error (356);  (*assignment to LOOP variable*)
(* parse the left side of the statement *)
Parseleft := True; Parseright := False;
Selector(Fsys + [Becomessy],Fidp);
Parseleft := False;  Parseright := True;
Leftside := Gattr;
(* if we are going to end up doing an indirect move of
 a record or array, the address must be BELOW the value
 to be assigned *)
IF Leftside.Atypep <> NIL THEN
   IF (Leftside.Atypep^.Stdtype = Mdt) THEN
      Loadaddress(Leftside);
IF Sy <> Becomessy THEN
   Error(159)
ELSE
   BEGIN (* get the value to be assigned *)
   Insymbol;
   Expression(Fsys);
   IF (Leftside.Atypep <> NIL) AND (Gattr.Atypep <> NIL) THEN
      (* check for assignment compatibility *)
      IF not Comptypes(Leftside.Atypep,Gattr.Atypep) AND
         (NOT(Leftside.Adtype IN [Jdt,Ldt,Rdt]) OR
          NOT(Gattr.Adtype IN [Jdt,Ldt,Rdt])) THEN
         Error(260)
      ELSE  (* assignment compatible.  Generate code *)
         CASE Leftside.Atypep^.Form OF
            Scalar:
               BEGIN
               Load(Gattr);
               IF Gattr.Adtype <> Leftside.Adtype THEN 
                  Matchtoassign(Gattr,Leftside.Atypep);
               Store(Leftside);
               END;
            Power:
               BEGIN (* Sets *)
               (* if not same size and offsets, convert *)
               IF (Gattr.Atypep^.Softmin <> Leftside.Atypep^.Softmin) OR
                  (Gattr.Atypep^.Softmax <> Leftside.Atypep^.Softmax) THEN
                  Setmatchtoassign (Gattr, Leftside.Atypep,
                                    Leftside.Apacked OR Leftside.Rpacked);
               Load(Gattr);
               Store(Leftside);
               END;
            Subrange:
               BEGIN
               Loadandcheckbounds(Gattr,Leftside.Atypep);
               Store(Leftside)
               END;
            Pointer, Arrays, Records:
               BEGIN
               Load(Gattr);
               Store(Leftside);
               END;
            Files:
               Error(361);
            END (*case*)
   END (*sy = becomessy*)
END (*assignment*) ;





(*Gotostatement,Compoundstatement,Ifstatement*)

PROCEDURE Gotostatement;

   VAR
      Lidp: Idp;

   BEGIN (*gotostatement*)
   IF Sy <> Intconstsy THEN
      Error(255)
   ELSE
      BEGIN
      Searchid([Labels],Lidp);  (* look up the label *)
      IF Lidp <> NIL THEN
         WITH Lidp^ DO
            BEGIN
            Referenced := True;
            IF Level = Scope THEN
               (* target label is in current procedure *)
               Uco1int(Uujp,Uclabel)
            ELSE
               BEGIN (* label is in outwardly nested procedure *)
               Uco2intint(Ugoob,Uclabel,Scope);
               Externalref := True;
               END;
            END;
      Insymbol
      END
   END (*gotostatement*) ;


PROCEDURE Compoundstatement;

   VAR
      Loopdone: Boolean;

      (* processes a multiple statement of the form
       BEGIN statements END *)

   BEGIN (*compoundstatement*)
   Loopdone := False;
   REPEAT
      REPEAT
         Statement(Fsys,Statends)
      UNTIL  NOT (Sy IN Statbegsys);
      Loopdone := Sy <> Semicolonsy;
      IF NOT Loopdone THEN
         Insymbol
   UNTIL Loopdone;
   IF Sy = Endsy THEN
      Insymbol
   ELSE
      Error(163)
   END (*compoundstatemenet*) ;


PROCEDURE Ifstatement;

   VAR
      Elselabel,Outlabel: Integer;

   BEGIN (*ifstatement*)
   Expression(Fsys + [Thensy]);
   Load(Gattr);
   If Gattr.Atypep <> Boolptr then
      Error (359);
   IF Sy = Thensy THEN
      Insymbol
   ELSE
      Warning(164);
   Lastuclabel := Lastuclabel + 1;     (* generate the jump to the else part *)
   Elselabel := Lastuclabel;
   Uco1int(Ufjp,Lastuclabel);
   Statement(Fsys + [Elsesy],Statends + [Elsesy]);     (*parse the then part*)
   IF Sy = Elsesy THEN
      BEGIN
     (* generate the jump after the THEN part *)
      Lastuclabel := Lastuclabel + 1; 
      Outlabel := Lastuclabel;
      Uco1int(Uujp,Outlabel);
      Uco2intint(Ulab,Elselabel,0);    (* put label for the else part *)
      Insymbol; Statement(Fsys,Statends);     (* parse the else part *)
      Uco2intint(Ulab,Outlabel,0)
      END
   ELSE        (* sy <> elsesy; no else part *)
      Uco2intint(Ulab,Elselabel,0);
   END (*ifstatement*) ;


(*Casestatement*)

  (************************************************************************)
  (*                                                                      *)
  (*                                                                      *)
  (*                    CASESTATEMENT                                     *)
  (*                                                                      *)
  (*    Procedure to parse and emit code for a case statement.            *)
  (*      Uses a combination of branch trees (FJP,TJP) and branch tables  *)
  (*      (XJP), to conserve space in sparse case lists.                  *)
  (*                                                                      *)
  (*    Called procedures and functions:                                  *)
  (*                                                                      *)
  (*            CASEINIT        Sets up initial variable vals.            *)
  (*            CASESELECTOR    Parses case selector,                     *)
  (*                            emits code to put value in temp.          *)
  (*            CASELISTELEMENT Parses a case list element, constructs    *)
  (*                            caseinfo records to describe the labels   *)
  (*                            and emits code for the case.              *)
  (*            OTHERWISESTMT   Parses and emits code for an otherwise    *)
  (*                            clause.                                   *)
  (*            ARRANGECASETREE Calculates the 'optimal' tradeoff         *)
  (*                            between branch trees and branch tables.   *)
  (*                            The casptrs array is constructed          *)
  (*                            to represent each node in the tree.       *)
  (*            EMITCASETREE    Emits all decision making ucode           *)
  (*                            to be executed at run time.               *)
  (*            EMITBTABLES     Emits the ujp tables (if necessary)       *)
  (*                            for any branch tables which may           *)
  (*                            be used.                                  *)
  (*                                                                      *)
  (*                                                                      *)
  (*                                                                      *)
  (************************************************************************)


PROCEDURE Casestatement;
  CONST
    Caselements = 256;                  (* max number of case clauses *) 
    Unusedlab = -1;               (* Value never used for a ucode label *)
  TYPE
    Casectrange = 1..Caselements;       (* Subscript range for the casptrs
                                           array *)
    Cip = ^ Caseinfo;
    Ctype = (Single,Subr,Btable);       (* types of branch tree node.  note:
                                           the order of these is significant.
                                           see the arrangecasetree function.*)



(*..................................................................)
(.                                                                 .)
(.                        CASEINFO                                 .)
(.                                                                 .)
(.           Describes one or more CaseListElements.  A            .)
(.           CaseListElement may be a single value (SINGLE)        .)
(.           or a subrange specification (SUBR).                   .)
(.                                                                 .)
(.           As branch tables are layed out during                 .)
(.           the optimization phase, a CASEINFO is constructed     .)
(.           for each branch table (BTABLE), and the               .)
(.           CASEINFOs for constituent CaseList Elements           .)
(.           are chained through the Next field.                   .)
(.                                                                 .)
(..................................................................*)


    Caseinfo =  PACKED RECORD
      Next:Cip;                         (* when caseinfo is in linked list,
                                           this is the fwd ptr *)
      Codelabel,                        (* label for code to process this
                                           case *)
      Treelabel,                        (* label for subtree rooted at this
                                           node *)
      Ltlabel:Integer;                  (* label where low bound of this 
                                           node is checked.  *)
      Cmode:Ctype;                      (* tells what kind of tree node this
                                           is *)
      Lowval,Hival:Integer;             (* inclusive bounds for range spanned
                                           by this node in the tree *)
    End;


    Reltype = (Goesabove,Goesbelow,Mrgsabove,Mrgsbelow,Overlaps,
               Nothere);                (* possible results of a relation test
                                           between two caseinfo entries *)

  VAR
    Casptrs : ARRAY [Casectrange] OF Cip; (* Starts with a single element
                                           which represents all cases in
                                           a single branchtable.  Arrangecase
                                           iterates until an 'optimal' tree
                                           is represented, with each node in
                                           each element of this array. *)
    Casecount : Casectrange;            (* number of elements in casptrs
                                           array *)
    Labelcount:Integer;                 (* number of labels which have been
                                           parsed *)
    Lstrp:Strp;                         (* type for selector *)
    Lattr:Attr;                         (* expression for temp *)
    Lval:Valu;                          (* value for case labels *)
    Highest:Integer;                    (* highest label encountered *)
    Atsize:Integer;                     (* size in bits of label fields *)
    Typeok:Boolean;                     (* true when selector is properly
                                           typed to match labels*)
    Loopdone:Boolean;                   (* TRUE if caselist-element is not
                                           followed by a semicolon.  
                                           Means that no case list elements
                                           may follow. *)
    Outlabel:Integer;                   (* all done label *)
    Entrylabel:Integer;                 (* ucodelabel at which decision testing
                                           begins *)
    Listanchor:Cip;                     (* anchor for list of case labels *)
    Otherwiselabel:Integer;             (* label on otherwise code *)
    Curpage, Curline: Integer;          (* page and line number of case
                                           stmnt *)
    Lstamp: Integer;                    (* stamp for temporaries *)

    (************************************************************************)
    (*                                                                      *)
    (*                      CASEMERGE                                       *)
    (*                                                                      *)
    (*            Merges caseinfos for two adjacent list                    *)
    (*            labels which together form a subrange.                    *)
    (*            Either or both of the supplied arguments                  *)
    (*            may be for a subrange.  The returned                      *)
    (*            answer will always represent a subrange.                  *)
    (*                                                                      *)
    (*            PARAMETERS:                                               *)
    (*                                                                      *)
    (*              A,B           (CIP) pointers to CASEINFO                *)
    (*                            for items to be merged. B                 *)
    (*                            always represents the label               *)
    (*                            with higher value.                        *)
    (*                                                                      *)
    (*            RESULT:                                                   *)
    (*                                                                      *)
    (*              The resulting subrange is represented                   *)
    (*              in the caseinfo which had been used for A.              *)
    (*              The CASEINFO for B is unchained and is                  *)
    (*              effectively lost.                                       *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Casemerge(A,B:Cip);
    VAR Newlow,Newhi:Integer;           (* these are the range delimiters
                                           for the result *)

    Begin                               (* start of casemerge *)
      Newlow:=A^.Lowval;                (* set range of result *)
      Newhi :=B^.Hival;
      WITH A^ DO                        (* put folded entry in a.  unchain b *)
        BEGIN                           (* fold and unchain *)
          Cmode := Subr;                (* result is a subrange *)
          Lowval := Newlow;             (* set new bottom of subrange *)
          Hival := Newhi;               (* set new top of subrange *)
          Next := B^.Next               (* unchain b*)
        END                             (* end fold and unchain *)
    END;                                (* end of casemerge *)


    (************************************************************************)
    (*                                                                      *)
    (*                         CRELATE                                      *)
    (*                                                                      *)
    (*         Function determines the relationship of the                  *)
    (*         label values for two supplied CASEINFOS.  The                *)
    (*         CASEINFOS may be for either single valued or                 *)
    (*         subrange valued labels.  If the result is MRGSABOVE          *)
    (*         or MRGSBELOW, the two supplied CASEINFOS have label          *)
    (*         ranges with adjacent values and are thus mergeable           *)
    (*         into a single subrange.  GOESABOVE and GOESBELOW             *)
    (*         indicate the relationship between non-overlapping,           *)
    (*         non-mergeable label groups.  OVERLAPS is indicated            *)
    (*         for equal label values, or for label values which            *)
    (*         overlap in any way.  NOTHERE is returned if either           *)
    (*         of the supplied caseinfo pointers is nil.                    *)
    (*                                                                      *)
    (*                                                                      *)
    (*         PARAMETERS:                                                  *)
    (*                                                                      *)
    (*              A,B               (CIP) pointers to the                 *)
    (*                                two CASEINFOS which are               *)
    (*                                to be compared.                       *)
    (*                                                                      *)
    (*         OPERATION:                                                   *)
    (*                                                                      *)
    (*           1) If either pointer is nil, the result is                 *)
    (*              NOTHERE.                                                *)
    (*                                                                      *)
    (*           2) To save repeated indirections, the local                *)
    (*              variables Alow, Ahi, Blow, and Bhi are set              *)
    (*              to the label ranges of A and B.                         *)
    (*                                                                      *)
    (*           3) The ranges are tested for overlap.  If there            *)
    (*              is no overlap, then the relationship is                 *)
    (*              computed and returned.                                  *)
    (*                                                                      *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  FUNCTION Crelate(A,B:Cip):Reltype;

    VAR
      Ans : Reltype;                    (* answer is developed here *)
      Alow,Ahi: Integer;                (* label range of a *)
      Blow,Bhi: Integer;                (* label range of b *)
    Begin                               (* begin crelate *)
      If (A=NIL) OR (B=NIL) THEN        (* if either argument is nil *)
        Ans:=Nothere                    (* return nothere *)
      Else                              (* neither supplied ptr is nil *)
        Begin                           (* neither argument is nil *)
          With A^ Do
            Begin                       (* set range of a *)
              Alow:=Lowval;             (* low bound of a *)
              Ahi:=Hival                (* high bound of a *)
            END;                        (* end set range of a *)
          With B^ Do
            Begin                       (* set range of b *)
              Blow:=Lowval;             (* low bound of b *)
              Bhi:=Hival                (* high bound of b *)
            End;                        (* end set range of b *)
          If Blow<=Ahi Then             (* b is not cleanly above a *)
            If Bhi>=Alow Then
              Ans:= Overlaps
            Else                        (* a is cleanly above b *)
              IF (Alow-Bhi)=1 Then
                Ans:= Mrgsabove         (* a goes just above b*)
              Else
                Ans:= Goesabove         (* a goes well above b *)
          Else                          (* b is cleanly above a *)
            If (Blow-Ahi)=1 Then
              Ans:=Mrgsbelow            (* a goes just below b *)
            Else
              Ans:=Goesbelow            (* a goes well below b *)
        End;                            (* end neither argument is nil *)
      Crelate:=Ans                      (* set up to return the answer *)
    End;                                (* crelate *)

    (************************************************************************)
    (*                                                                      *)
    (*                       CASEINSERT                                     *)
    (*                                                                      *)
    (*            PARAMETERS:                                               *)
    (*                                                                      *)
    (*                    A       (CIP) ptr to caseinfo to                  *)
    (*                            be inserted in the list.                  *)
    (*                                                                      *)
    (*                    B       (CIP) ptr to caseinfo after               *)
    (*                            which a is inserted.  If B                *)
    (*                            is nil, then A is chained from            *)
    (*                            LISTANCHOR.                               *)
    (*                                                                      *)
    (*            RESULT:                                                   *)
    (*                                                                      *)
    (*                   A is inserted in list after B.                     *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Caseinsert(A,B:Cip);

    Begin                               (* caseinsert *)
      If B<> NIL Then                   (* if not chaining at head of list *)
        Begin                           (* chain-not at head of list *)
          A^.Next:=B^.Next;             (* hang rest of chain from a*)
          B^.Next:=A                    (* hang a from b *)
        End                             (* chain-not at head of list *)
      Else                              (* goes at head of list *)
        Begin                           (* chain at head of list *)
          A^.Next:=Listanchor;          (* hang rest of lit from a *)
          Listanchor:=A                 (* put a at head of list *)
        End                             (* chain at head of list *)
    End;                                (*  Caseinsert *)

    (************************************************************************)
    (*                                                                      *)
    (*                                                                      *)
    (*                           CLABCHAIN                                  *)
    (*                                                                      *)
    (*               Inserts new case label in chain.                       *)
    (*                                                                      *)
    (*                                                                      *)
    (*           Loops through existing chain of case labels                *)
    (*           to insert the new one in sorted order.  The                *)
    (*           CRELATE procedure is used to determine the                 *)
    (*           relationship of the new case label and those               *)
    (*           which are already in the list.  Where possible,            *)
    (*           adjacent labels are merged to form subranges.              *)
    (*                                                                      *)
    (*                                                                      *)
    (*           PARAMETERS:                                                *)
    (*                                                                      *)
    (*                 NEWLABP           (CIP) CASEINFO ptr. for            *)
    (*                                   new label.                         *)
    (*                                                                      *)
    (*                 CDLAB             (integer) code label               *)
    (*                                   for new label.                     *)
    (*                                                                      *)
    (*                                                                      *)
    (*           OPERATION:                                                 *)
    (*                                                                      *)
    (*             1) Loop using CRELATE to find the position               *)
    (*                for the new label in the linked list.                 *)
    (*                                                                      *)
    (*             2) Use CASEINSERT to add the CASEINFO to the list.       *)
    (*                                                                      *)
    (*             3) If CRELATE has indicated that it is possible,         *)
    (*                use CASEMERGE to combine the new label with           *)
    (*                existing labels into a subrange.  It is               *)
    (*                possible that a new label will combine with           *)
    (*                those above and below it.                             *)
    (*                                                                      *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Clabchain(Newlabp:Cip;Cdlab:Integer);

    VAR
      Prev,Current:Cip;                 (* chain pointers *)
      Nextcase:Cip;                     (* ^ following item on upward merge *)
      Newrelcurrent:Reltype;            (* relationship of new to item
                                           in list *)

    Begin                               (* clabchain *)
      Current:=Listanchor;              (* start at head of the list *)
      Prev:=NIL;                        (* prev ptr lags behind current *)

      Newrelcurrent:=Crelate(Newlabp,Current); (* how relates to first in 
                                           list *)
      WHILE Newrelcurrent=Goesabove DO
        Begin                           (* find where this goes in list *)
          Prev:=Current;                (* follow the chain *)
          Current:=Current^.Next;
          Newrelcurrent:=Crelate(Newlabp,Current)
        End;                            (* find where this goes in list *)
      Case Newrelcurrent Of             (* see where this goes in list*)

        Goesbelow:
          Caseinsert(Newlabp,Prev);     (* insert after prev *)

        Mrgsbelow:
          Begin                         (* new one goes immediately below 
                                           current *)
            Caseinsert(Newlabp,Prev);   (* insert after prev *)
            IF Current^.Codelabel=Cdlab THEN (* if these are
                                           labels on the same code *)
              Casemerge(Newlabp,Current) (* merge to form subrange*)
          End;                          (* new one goes immediately below
                                           current *)  
        Mrgsabove:
          Begin                         (* new one merges above current *)
            Caseinsert(Newlabp,Current); (* insert after current *)
            If Current^.Codelabel=Cdlab Then (* if these are
                                           labels on the same code *)
              Casemerge(Current,Newlabp) (* merge as subrange *)
            Else  Current:=Newlabp;     (* keep ptrs straight for
                                  following code *)
            Nextcase:=Current^.Next;


(*..................................................................)
(.                                                                 .)
(.          Check how this relates to the one above.               .)
(.                                                                 .)
(..................................................................*)

            Case Crelate(Current,Nextcase) OF
              Goesbelow:;               (* all set*)
              Nothere:
                Highest:=Current^.Hival; (* this is new highest *)
              Overlaps:
                Error(261);             (* handle the overlap *)
              Mrgsbelow:
                IF Nextcase^.Codelabel=Cdlab THEN (* these are mergeable*)
                  Casemerge(Current,Nextcase) (* do the upward merge*)
              END                       (* end of case on crelate for upward
                                           merge *)
          END;                          (* new one merges above current *)

        Overlaps:
          Error(261);

        Nothere:
          Begin                         (* this goes at end of list *)
            Highest:=Newlabp^.Hival;    (* set highest label to date *)
            Caseinsert(Newlabp,Prev);
          End                           (* this goes at end of list *)
      End;                              (* end see where this goes in list *)
    End;                                (* clabchain *)


    (************************************************************************)
    (*                                                                      *)
    (*                           CASELABEL                                  *)
    (*                                                                      *)
    (*            Parses one caselabel up to a comma or colon,              *)
    (*            and checks for a valid terminator.  A CASEINFO            *)
    (*            is constructed, inserted in the linked list,               *)
    (*            and if there is a match on CODELABELS, is                 *)
    (*            checked for merging with others to form                   *)
    (*            a subrange.                                               *)
    (*                                                                      *)
    (*            PARAMETERS:                                               *)
    (*                                                                      *)
    (*            CDLAB           (integer) the ucode label for             *)
    (*                            the code currently being emitted.         *)
    (*                            Knowing this allows the routine to        *)
    (*                            locate elements in the linked list        *)
    (*                            which are potentially foldable.           *)
    (*                                                                      *)
    (*            OPERATION:                                                *)
    (*                                                                      *)
    (*              Parses the case label as a constant, and builds         *)
    (*              a caseinfo for it.  The existing linked list            *)
    (*              is searched, with the CRELATE routine used              *)
    (*              to check the relationship between the new label,        *)
    (*              and the others on the list.  The new one is             *)
    (*              inserted in sorted order, and if possible,              *)
    (*              CASEMERGE is used to fold it with others to             *)
    (*              form a subrange.                                        *)
    (*                                                                      *)
    (*            ROUTINES CALLED:                                          *)
    (*                                                                      *)
    (*              NEW           Allocate a CASEINFO                       *)
    (*                                                                      *)
    (*              CRELATE       Compare label values                      *)
    (*                                                                      *)
    (*              CASEINSERT    Insert new CASEINFO in list               *)
    (*                                                                      *)
    (*              CASEMERGE     Merge CASEINFOS into subrange             *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Caselabel(Cdlab:Integer);

    VAR
      Newlabp:Cip;                      (* ^ newly allocate caseinfo *)
      Lstrp1:Strp;                      (* type of label value *)
      Labval:Integer;                   (* value for this label *)

    Begin                               (* caselabel *)
      Labelcount:=Labelcount+1;         (* another label parsed *)
      Constant(Fsys+[Commasy,Colonsy,Rangesy],Lstrp1,Lval); (*parse
                                           the label as a constant *)
      If (Lstrp<>NIL) Then              (* if selector exists *)
        If Comptypes(Lstrp,Lstrp1)Then
          Begin                         (* types are compatible *)
            New(Newlabp);               (* allocate a new caseinfo *)
            WITH Newlabp^ DO
              Begin                     (* fill in new caseinfo *)
                Next:=NIL;              (* initialize the chain ptr *)
                Codelabel:=Cdlab;       (* ucode label to execute this case *)
                Treelabel:=Unusedlab;   (* no tree rooted here yet *)
                Ltlabel:=Unusedlab;     (* no label to do low bounds checking
                                           yet *)
                Cmode:=Single;          (* assume there is no subrange *)
                Labval:=Lval.Ival;
                Lowval:=Labval;
                Hival:=Labval;
                If Sy=Rangesy Then
                  Begin                 (* handle explicite subrange *)
                    Insymbol;           (* skip the two dots *)
                    Constant(Fsys+[Commasy,Colonsy],Lstrp1,Lval); (* parse
                                           upper bound *)
                    If Comptypes(Lstrp,Lstrp1) Then
                      Begin             (* types are compatible *)
                        Labval:=Lval.Ival;
                        If Labval>=Lowval Then
                          Begin         (* legal subrange *)
                            Hival:=Labval; (* set upper bound of subrange *)
                            Cmode:=Subr (* indicate that this is a subrange *)
                          End           (* legal subrange *)
                        Else
                          Error(451)    (* bounds are backwards *)
                      End               (* types are compatible *)
                    Else
                      Error(505)        (* incompatible types *)
                  End                   (* handle explicite subrange *)
              End;                      (* end fill in new caseinfo *)
            Clabchain(Newlabp,Cdlab);   (* chain it in link list and
                                           fold if necessary *)
            If Not(Sy IN [Commasy,Colonsy]) Then
              Error(151);               (* comma or semicolon missing after
                                           case lab*)
          End                           (* end types are compatible *)
        Else
          Error(505)                    (* types are compatible *)
    End;                                (* caselabel *)

    (************************************************************************)
    (*                                                                      *)
    (*                         CASELISTELEMENT                              *)
    (*                                                                      *)
    (*            Parses one caselist element.  Adds to sorted linked       *)
    (*            list of CASEINFOS which is hung from LISTANCHOR.          *)
    (*                                                                      *)
    (*            PROCEDURES CALLED:                                        *)
    (*                                                                      *)
    (*              CASELABEL     Parse a case label                        *)
    (*                                                                      *)
    (*              UC02INTINT    Emit a ucode label                        *)
    (*                                                                      *)
    (*              STATEMENT     Parse the body of this case               *)
    (*                                                                      *)
    (*              UCO1INT       Emit a ujp ucode                          *)
    (*                                                                      *)
    (*            OPERATION:                                                *)
    (*                                                                      *)
    (*              Loops through all case labels using                     *)
    (*              the cASELABEL procedure to parse each                   *)
    (*              one.  Emits the CODELABEL into ucode,                   *)
    (*              then calls STATEMENT to handle the body.                *)
    (*              A final unconditional jump is emited                    *)
    (*              to branch around other cases and                        *)
    (*              testing code.                                           *)
    (*                                                                      *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Caselistelement;

    VAR
      Nextcdlab:Integer;                (*codelabel *)
      Loopdone:Boolean;

    Begin                               (* caselistelement *)
      Nextcdlab:=Getlabel;              (* allocate a label for the code *)
      Loopdone:=False;                  (* loop not finished yet *)
      Repeat                            (* go through all labels on this 
                                           element *)
        Caselabel(Nextcdlab);           (* parse the next label *)
        Loopdone := Sy<>Commasy; (* if followed by comma, try for
                                           another *)
        IF NOT Loopdone THEN Insymbol;  (* skip the comma *)
      Until Loopdone;                   (* go through all labels on this 
                                           element *)

    (*..................................................................)
    (.                                                                 .)
    (.               EMIT THE LABEL FOR THIS CASE CODE                 .)
    (.                                                                 .)
    (..................................................................*)

      Uco2intint(Ulab,Nextcdlab,0);

    (*..................................................................)
    (.                                                                 .)
    (.              PARSE THE COLON AND THE CODE BODY                  .)
    (.                                                                 .)
    (..................................................................*)

      If Sy = Colonsy Then 
        Insymbol
      Else
        Error(151);                     (* colon missing in case list
                                           element *)
      Statement(Fsys+[Otherssy],Statends+[Otherssy]); (*parse the body *)
      Uco1int(Uujp,Outlabel)            (* emit branch around other cases *)
    End;                                (*caselistelement *)

    (************************************************************************)
    (*                                                                      *)
    (*                                                                      *)
    (*                        CASESELECTOR                                  *)
    (*                                                                      *)
    (*             Parses the selector expression for a                     *)
    (*             case statement, and saves its value in                   *)
    (*             a temporary variable.                                    *)
    (*                                                                      *)
    (*                                                                      *)
    (*         OPERATION:                                                   *)
    (*                                                                      *)
    (*           1) Use EXPRESSION procedure to parse the selector.         *)
    (*                                                                      *)
    (*           2) Make sure the type is legal in a case stmt.             *)
    (*                                                                      *)
    (*           3) Emit ucode to load it on runtime stack.                 *)
    (*                                                                      *)
    (*           4) If it's char or boolean coerce it to an                 *)
    (*              integer.                                                *)
    (*                                                                      *)
    (*           5) Allocate a temporary and emit code to store             *)
    (*              the selector.  This saves it while the                  *)
    (*              code for the individual cases is compiled.              *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)


  PROCEDURE Caseselector;

    VAR
      Tmin,Tmax:Integer;                (* returned by getbounds for *)

    Begin                               (* caseselector *)
      Expression(Fsys+[Ofsy,Commasy,Colonsy]); (* evaluate the selector
                                           expression *)
      Lstrp:=Gattr.Atypep;              (* save the type *)
      If Lstrp<>NIL Then
        Begin                           (* if expr was evaluated *)
          If (Lstrp^.Form<>Scalar) OR (Lstrp=Realptr) Then
            Begin                       (* not valid type *)
              Error(315);               (* bad type *)
              Lstrp:=NIL                (* make sure never used *)
            End;                        (* not valid type *)
          Load(Gattr);                  (* put selector on stack *)
          Getatemp(Lattr,Gattr.Atypep,Lstamp,True); (* allocate a temp *)
          Lattr.Adtype:=Gattr.Adtype;   (* remember the type *)
          If Lattr.Adtype IN [Bdt,Cdt,Jdt,Ldt] Then
            Store(Lattr)                (* save in temp *)
          Else                          (* wrong data type *)
            Error(169)

        End;                            (* if expr was evaluated *)

    End;                                (* caseselector *)

    (************************************************************************)
    (*                                                                      *)
    (*                                                                      *)
    (*                         CASEINIT                                     *)
    (*                                                                      *)
    (*            Initialize for case statement parsing                     *)
    (*                                                                      *)
    (*                                                                      *)
    (*         OPERATION:                                                   *)
    (*                                                                      *)
    (*           Initializes assorted variables for subsequent use.         *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Caseinit;
    Begin
      Lstrp:=NIL;                       (* no type for selector yet *)
      Listanchor:=NIL;                  (* no list of labels yet *)
      Labelcount:=0;                    (* no labels yet *)
      Typeok:=False;                    (* don't yet know datatype to use for 
                                           our tests *)
      Lstamp := 0;                      (* no temporaries yet *)
      Curpage := Pagecnt;              (* remember current location *)
      Curline := Linecnt;
    END;

    (************************************************************************)
    (*                                                                      *)
    (*                                                                      *)
    (*                         ARRANGEINIT                                  *)
    (*                                                                      *)
    (*               Initialize for optimization phase of                   *)
    (*                    case statement parsing                            *)
    (*                                                                      *)
    (*                                                                      *)
    (*         ARRANGEINIT prepares an initial entry in the casptrs         *)
    (*         array.  This entry represents all case labels as             *)
    (*         being handled in a single branch table.  The                 *)
    (*         ARRANGECASETREE procedure then attempts to split             *)
    (*         up this branch table.                                        *)
    (*                                                                      *)
    (*                                                                      *)
    (*         OPERATION:                                                   *)
    (*                                                                      *)
    (*           1) If there is only a single case label (unlikely)         *)
    (*              then it is stored directly in CASPTRS[1].  This         *)
    (*              will cause ARRANGECASETREE to nop.                      *)
    (*                                                                      *)
    (*           2) Otherwise, a new CASEINFO is allocated to               *)
    (*              represent the branch table.  It is stored               *)
    (*              as the only entry in CASPTRS.                           *)
    (*                                                                      *)
    (*           3) The new CASEINFO is filled in to represent the          *)
    (*              branch table.                                           *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Arrangeinit;

    Begin
      Casecount:=1;                     (* array has one entry *)
      If Listanchor^.Next <> NIL Then   (* there are multiple labels *)
        Begin                           (* set up tree for multiple labels *)
          New(Casptrs[1]);              (* allocate caseinfo for initial tree*)
          With Casptrs[1]^ Do
            Begin                       (* fill in tree caseinfo *)
              Next:=Listanchor;         (* whole list in this tree for now *)
              Codelabel:=Unusedlab;     (* dont know where or if table 
                                           exists *)
              Treelabel:=Unusedlab;     (* no tree yet *)
              Ltlabel:=Unusedlab;       (* no low test yet *)
              Cmode:=Btable;            (* this is a branch table *)
              Lowval:=Listanchor^.Lowval; (* lowest of all cases *)
              Hival:=Highest;           (* highest of all cases *)
            End;                        (* fill in tree caseinfo *)
        End                             (* set up tree for multiple labels *)
      Else                              (* exactly one caselistelement *)
        Casptrs[1]:=Listanchor;         (* make it the tree *)
    End;                                (* end of arrangeinit *)

    (************************************************************************)
    (*                                                                      *)
    (*                         ARRANGECASETREE                              *)
    (*                                                                      *)
    (*              Iterates through the label entries which                *)
    (*              have been parsed and makes reasonable                   *)
    (*              space time tradeoffs between the use                    *)
    (*              of branch trees and branch tables in the                *)
    (*              object code.  The resulting (possibly                   *)
    (*              degenerate tree) has each node represented              *)
    (*              by an entry in the CASPTRS array.                       *)
    (*                                                                      *)
    (*                                                                      *)
    (*        OPERATION:                                                    *)
    (*                                                                      *)
    (*          1) All calculations below are repeated until                *)
    (*             tree stabilizes                                          *)
    (*                                                                      *)
    (*          2) For each branch table in the tree, traverse              *)
    (*             its entries to see if a split is desirable.              *)
    (*                                                                      *)
    (*          3) When splitting, the original table is truncated          *)
    (*             to the split point, and a new entry is inserted          *)
    (*             in the array.  Normally the new entry will               *)
    (*             be tested on the next time through the loop,             *)
    (*             so further splits may result.                            *)
    (*                                                                      *)
    (*          4) The incremental time cost of adding entries              *)
    (*             to the branch table slowly decreases with                *)
    (*             increasing size of the tree.  For this reason,           *)
    (*             some splits which at first seems undesirable             *)
    (*             may later prove profitable.  Looping continues           *)
    (*             until the tree stabilizes or is completely split.        *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Arrangecasetree;

    CONST
      Spacetime=1.0;                    (* tunable parameter indicates
                                           relative weight to give space
                                           vs. execution time.  Higher
                                           numbers cause less space, longer
                                           times.  express in (approx) ratio
                                           of undesirability emiting an
                                           instruction vs. executing an
                                           instruction. *)
      Ln2t2=1.38628;                    (* 2*ln2 *)


    VAR
      Timesaved:Real;                   (* time saved by not adding a node *)
      Labinv:Real;                      (* inverse of number of labels *)
      Openspace:Integer;                (* unused label vals between 2 
                                           entries *)
      Cindex:Integer;                   (* array loop index *)
      Lowsplit,Upprsplit:Cip;           (* span a possible split *)
      Bumptr:Integer;
      Lsplitlow,Lsplithigh:Integer;     (* case label span for lower part of 
                                           split *)
      Usplitlow,Usplithigh:Integer;     (* case label span for upper part of
                                           split *)
      Ltype,Utype:Ctype;                (* if we split, these will be modes
                                           of the lower and upper results *)
      Split:Boolean;                    (* true when tree is to be split here *)
      Nochange:Boolean;                 (* true when tree has stabilized *)
      Firstintable:Boolean;             (* true when parsing first list entry
                                           for a table.*)

    Begin                               (* arrangecasetree *)
      Arrangeinit;                      (* set up everything as one btable *)
      If Labelcount <>0 Then
        Labinv:=1.0/Labelcount          (* approximates extra time lost when
                                           adding a subrange type entry to
                                           the branch tree *)
      Else
        Labinv:=1.0;                    (* in case something is fouled up *)
      Repeat                            (* now keep trying to split it *)
        Nochange:=True;                 (* assume tree has stabilized *)
        Cindex:=1;                      (* start at beginning of array *)
        Repeat                          (* do one iteration through array *)
          IF Casptrs[Cindex]^.Cmode = Btable THEN
            Begin                       (* go through btable looking for
                                           split *)
              With Casptrs[Cindex]^ Do  (* use mother entry for btable *)
                Begin                   (* set up to look for a split *)
                  Lsplitlow:=Lowval;    (* low bound of lower section *)
                  Usplithigh:=Hival;    (* high bound of upper section *)
                  Lowsplit:=Next        (* first chain entry *)
                End;                    (* set up to look for a split *)
              Upprsplit:=Lowsplit^.Next; (* possible pint for split *)
              Firstintable:=True;       (* assume split at first entry *)
              Repeat                    (* loop looking for place to split *)
                With Lowsplit^ Do
                  Begin                 (* set up to check this split *)
                    If Firstintable Then
                      Ltype:=Cmode      (* type of lower section *)
                    ELSE
                       Ltype := Btable;
                    If Upprsplit^.Next=NIL Then
                       Utype:=Upprsplit^.Cmode
                    Else
                       Utype:=Btable;   (* type of upper section *)
                    Lsplithigh:=Hival;  (* high bound of lower section *)
                    Usplitlow:=Upprsplit^.Lowval; (* low bound of upper
                                           section *)
                  End;                  (* set up to check this split *)

      (**********************************************************************)
      (*                                                                    *)
      (*                DECIDE WHETHER TO SPLIT THE TABLE HERE              *)
      (*                                                                    *)
      (**********************************************************************)

                Timesaved:=Ln2t2/Casecount; (* time saved if we don't add a
                                           node*)
                Openspace:=Usplitlow-Lsplithigh; (* number of unused 
                                           table entries between these labels *)
                Case (3*Ord(Ltype))+Ord(Utype) Of
                 0:Split:=(Spacetime*(Openspace-3))>Timesaved; 
                                        (* split two singles *)
                 1,3:Split:=
                     (Spacetime*((Usplithigh-Lsplitlow)-7))>(Labinv+Timesaved);
                                        (* split single from subrange *)
                 2,6:Split:=(Spacetime*(Openspace-4))>Timesaved; 
                                        (* split single and table? *)
                 4:Split:=
                     (Spacetime*((Usplithigh-Lsplitlow)-9))>(Labinv+Timesaved);
                                        (* split two subranges? *)
                 5:Split:=
                     (Spacetime*((Usplitlow-Lsplitlow)-6))>(Labinv+Timesaved);
                                        (* subrange from table *)
                 7:Split:=
                     (Spacetime*((Usplithigh-Lsplithigh)-6))>(Labinv+Timesaved);
                                        (*table from subrange *)
                 8:Split:=(Spacetime*(Openspace-5))>Timesaved 
                                        (*split two branch tables? *)
                End;                    (* end casestatement *)

                If Split Then           (* if tradeoff is to split *)
                  If Casecount<Caselements Then (* and we've still got room *)
                    Begin               (* split here *)
                      Casecount:=Casecount+1;
                      For Bumptr:=Casecount Downto Cindex+2 Do
                                        (* free a slot in the array *)
                        Casptrs[Bumptr]:=Casptrs[Bumptr-1];
                      If Utype=Btable Then
                        Begin           (*allocate new mother entry for upper *)
                          New(Casptrs[Cindex+1]);
                          With Casptrs[Cindex+1]^ Do
                            Begin       (* fill in the new entry *)
                              Next:=Upprsplit; (* hang rest of chain *)
                              Codelabel:=Unusedlab; (* no code yet *)
                              Treelabel:=Unusedlab;
                              Ltlabel:=Unusedlab;
                              Cmode:=Btable;
                              Lowval:=Usplitlow; (* new low bound on tree *)
                              Hival:=Usplithigh; (* new high bound *)
                            End         (* fill in the new entry *)
                        End             (*allocate new mother entry for upper *)
                      Else              (* new upper is not a table *)
                        Casptrs[Cindex+1]:=Upprsplit; (* put in single element
                                           for upper side of split *)
                      Lowsplit^.Next:=NIL; (* end of lower list *)
                      If Ltype=Btable Then
                        Casptrs[Cindex]^.Hival:=Lsplithigh (* high bound on
                                           lower branch table *)
                      Else
                        Casptrs[Cindex]:=Lowsplit (* put individual entry
                                           right in table *)
                    End                 (* split here *)
                  Else
                    Error(322);
                Firstintable:=False;    (* no longer at first spot *)
                Lowsplit:=Upprsplit;    (* follow the chain *)
                Upprsplit:=Upprsplit^.Next;
              Until Split OR (Upprsplit=NIL); (* look for place to split *)
              Nochange:=Nochange AND NOT(Split)
            End;                        (*go through btable looking for split *)
          Cindex:=Cindex+1;             (* next array entry *)
        Until Cindex>Casecount          (* do one iteration through array *)
      Until Nochange                    (* now keep trying to split it *)
    End;                                (* arrangecasetree *)

    (************************************************************************)
    (*                                                                      *)
    (*                                                                      *)
    (*                            EMIT                                      *)
    (*                                                                      *)
    (*             Emits ucode for comparison of selector                   *)
    (*                                                                      *)
    (*                                                                      *)
    (*         Parameters:                                                  *)
    (*                                                                      *)
    (*                  A               (Uopcode) the ucode op code         *)
    (*                                  for the test.                       *)
    (*                                                                      *)
    (*                  B               (integer) value against which       *)
    (*                                  to test.                            *)
    (*                                                                      *)
    (*         Operation:                                                   *)
    (*                                                                      *)
    (*           1) Makes local copy of selector expression so              *)
    (*              original is still considered in temporary.              *)
    (*                                                                      *)
    (*           2) Loads the selector.                                     *)
    (*                                                                      *)
    (*           3) Now that all of the labels have been parsed,            *)
    (*              the selector may have to be re-typed.  If               *)
    (*              necessary, do it.  Retype the temporary, and            *)
    (*              if there are more cases to follow, do a                 *)
    (*              non-destructive store to remember it.                   *)
    (*                                                                      *)
    (*           4) If first time through, compute atsize.  This            *)
    (*              is the size in bits of constants to be loaded           *)
    (*              for comparison with the selector.                       *)
    (*                                                                      *)
    (*           5) Emit a ldc for parameter B (the comparand)              *)
    (*              followed by A (the test instruction).                    *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Emit(A:Uopcode;B:Integer);

    VAR
      Fattr:Attr;                       (* loaded copy of selector *)
      Loctype:Strp;                     (* local type ptr *)
      Locdt:Datatype;                   (* datatype of selector *)
      Tmin,Tmax:Integer;                (* bounds of subrange *)

    Begin                               (* emit *)
      Fattr:=Lattr;                     (* copy the selector expression *)
      Load(Fattr);                      (* load the selector *)
      If NOT Typeok Then                (* if first time through *)
        With Fattr Do
          Begin                         (* must retype the selector *)
            Locdt:=Adtype;              (* assume no type change *)
            If Adtype IN [Bdt,Cdt] Then
              Begin                     (* selector bool or char *)
                Getbounds(Atypep,Tmin,Tmax);
                If Tmin<0 Then Locdt:=Jdt
                Else Locdt:= Ldt;
              End;                      (* selector bool or char *)
            If Casptrs[1]^.Lowval<0 Then (* isn't pos data type *)
              If Locdt=Ldt Then Locdt:=Jdt; (* small integers *)
                                        (* short integer *)
            Loctype:=Intptr;
            Atsize:=Intsize;
            If Locdt<> Adtype Then
              Begin                     (* we are retyping  *)
                Uco2typtyp(Ucvt,Locdt,Adtype); (* do the ucode cvt  *)
                If Casecount>1 Then
                  Begin                 (* we're going to need it again *)
                                        (*  Freetemp(Lattr); (* free up the 
                                           old selector *)
                    Getatemp(Lattr,Loctype,Lstamp,True); (* allocate a new temp *)
                    Lattr.Adtype:=Locdt; (* remember the type *)
                    Uco1attr(Unstr,Lattr) (* save a retyped copy *)
                  End;                  (* we're going to need it again *)
              End;                      (* we are retyping  *)
            TypeOK:=True
          End                           (* must retype the selector *)
      Else
        Locdt:=Lattr.Adtype;            (* get the right data type *)
      Uco3int(Uldc,Locdt,Atsize,B);     (* set up the constant
                                                  for tree compare *)
      Uco1type(A,Locdt)                 (* emit the ucode compare *)
    End;                                (* emit *)

    (************************************************************************)
    (*                                                                      *)
    (*                       XEMIT                                          *)
    (*                                                                      *)
    (*             Procdedure to emit xjp ucodes                            *)
    (*                                                                      *)
    (*      Parameters:                                                     *)
    (*                                                                      *)
    (*                  A,B               value range of brtable            *)
    (*                                                                      *)
    (*                  C                 brtable label                     *)
    (*                                                                      *)
    (*      OPERATION:                                                      *)
    (*                                                                      *)
    (*           Makes local copy of the selector expression                *)
    (*           (so original will not be marked as kind=expr)              *)
    (*           and loads it on the stack. The typeok switch               *)
    (*           is checked to see if necessary type conversion             *)
    (*           has been done.  If so, nothing else need be done.          *)
    (*           If not, then this is the special case where there          *)
    (*           is no tree and only a branch table.  The type              *)
    (*           is converted, but no store or switch setting is            *)
    (*           needed since the selector will never be loaded             *)
    (*           again.  Compare this logic with that in emit.              *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Xemit(A,B:Integer;C:Integer);

    VAR
      Fattr:Attr;                       (* loaded copy of selector *)
      Locdt:Datatype;                   (* datatype of selector *)
      Tmin,Tmax:Integer;                (* bounds of subrange *)

    Begin                               (* xemit *)
      Fattr:=Lattr;                     (* copy selector expression *)
      Load(Fattr);                      (* put on stack *)
      If NOT Typeok Then                (* if first time through *)
        With Fattr Do
          Begin                         (* must retype the selector *)
            Locdt:=Adtype;              (* assume no type change *)
            If Adtype IN [Bdt,Cdt] Then
              Begin                     (* selector bool or char *)
                Getbounds(Atypep,Tmin,Tmax);
                If Tmin<0 Then Locdt:=Jdt
                Else Locdt:= Ldt;
              End;                      (* selector bool or char *)
            If Casptrs[1]^.Lowval<0 Then (* isn't pos data type *)
              If Locdt=Ldt Then Locdt:=Jdt; (* small integers *)
            If Locdt<> Adtype Then
              Uco2typtyp(Ucvt,Locdt,Adtype) (* do the ucode cvt  *)
          End                           (* must retype the selector *)
      Else
        Locdt:=Fattr.Adtype;            (* get the right data type *)
      Ucoxjp(Locdt,C,Otherwiselabel,A,B) (* emit the xjp *)
    End;                                (* xemit *)

    (************************************************************************)
    (*                                                                      *)
    (*                                                                      *)
    (*                       EMITCASETREE                                   *)
    (*                                                                      *)
    (*            Recursive procedure to emit code for                      *)
    (*                  run time branch tree.                               *)
    (*                                                                      *)
    (*                                                                      *)
    (*         PARAMETERS:                                                  *)
    (*                                                                      *)
    (*             LOWCASE             (CASECTRANGE) index into             *)
    (*                                 casptrs for lower bound of           *)
    (*                                 subtree being traversed.             *)
    (*                                                                      *)
    (*             HICASE              (CASECTRANGE) same for hi bound.     *)
    (*                                                                      *)
    (*                                                                      *)
    (*         TERMINOLOGY:                                                 *)
    (*                                                                      *)
    (*            In refering to the shape of the tree, the following       *)
    (*            conventions apply:  the tree is pictured as having        *)
    (*            its leaves at the 'bottom'.  Thus a reference             *)
    (*            to going down the tree means closer to the leaves.        *)
    (*            The tree consists of case label groupings.  The           *)
    (*            higher valued case labels are considered to lie           *)
    (*            to the 'right' of lower labels.  Each subtree             *)
    (*            contains one or more nodes (entries in casptrs).          *)
    (*            The 'root' is the one such group with label values        *)
    (*            close to the median of those in the subtree.              *)
    (*            The 'left subtree' is the (possibly empty)                *)
    (*            tree containing lower valued labels, and the              *)
    (*            'right subtree' is the (possibly empty) tree              *)
    (*            containing labels higher than those in the root.          *)
    (*                                                                      *)
    (*                                                                      *)
    (*         DATA STRUCTURES:                                             *)
    (*                                                                      *)
    (*            At compile time, the tree is represented by the           *)
    (*            array castprs.  Each entry in the array points            *)
    (*            to a caseinfo which describes a leaf of the               *)
    (*            branch tree.  These are of three possible types:          *)
    (*            single label values (single), subranges of labels         *)
    (*            (subr), and branch tables (btable).  In the               *)
    (*            case of branch tables, a linked list of caseinfos         *)
    (*            describes the table entries.                              *)
    (*                                                                      *)
    (*                                                                      *)
    (*            The purpose of this procedure is to emit code             *)
    (*            to do a binary search through the values in               *)
    (*            the casptrs array.  The logical tree is thus              *)
    (*            traversed by manipulating indicies into the array.        *)
    (*            As described above, any subtree is considered             *)
    (*            to consist of a left subtree, a root, and a               *)
    (*            right subtree.  Assume the casptrs indicies spanning      *)
    (*            the original subtree are s1 and s2, l1 and l2 for         *)
    (*            left, r1 and r2 for right, and root for the root,         *)
    (*            then the following relationships always hold:             *)
    (*                                                                      *)
    (*                   l1<=l2, r1<=r2, root=l2+1, root=r1-1               *)
    (*                   s1=l1, s2=r2                                       *)
    (*                                                                      *)
    (*            these are the basis of the recursion through the          *)
    (*            tree.                                                     *)
    (*                                                                      *)
    (*                                                                      *)
    (*         OPERATION:                                                   *)
    (*                                                                      *)
    (*           1) Determine size of this subtree, and of left             *)
    (*              subtree.                                                *)
    (*                                                                      *)
    (*           2) If there is exactly one node in this tree,              *)
    (*              we are completing a 'rightward' descent.                *)
    (*              Various special cases are used to save ucode            *)
    (*              according to the type of this leaf.  There              *)
    (*              are actually two classes of right descent.              *)
    (*              This may be the rightmost leaf in the entire            *)
    (*              tree.  In this case, if the selector lies above         *)
    (*              the current node, we execute the otherwise              *)
    (*              clause.  If this is not the rightmost leaf,             *)
    (*              then the selector lying above this leaf                 *)
    (*              implies that the only possible hit is on                *)
    (*              the root of the parent (complicated, but                *)
    (*              that's the way it is).  We again save code              *)
    (*              in some cases by directly checking the low              *)
    (*              bound of this parent.                                   *)
    (*                                                                      *)
    (*           3) There may be exactly two nodes in this tree.            *)
    (*              In this case the left subtree is null.  We              *)
    (*              can save some ucode in this case too by                 *)
    (*              directly checking the low bound on our own              *)
    (*              root instead of jumping to a non-existant               *)
    (*              left subtree.                                           *)
    (*                                                                      *)
    (*           4) The usual case is more than two nodes in this           *)
    (*              subtree.  Recursion proceeds down the right             *)
    (*              side of the tree in line, with jumps emited             *)
    (*              to the left subtrees.  Note that the tree               *)
    (*              actually consists of the high bounds on                 *)
    (*              the label ranges.  Except for the special               *)
    (*              cases noted in (2) and (3) above, all tests             *)
    (*              are against hival.  Necessary lowbounds tests           *)
    (*              are handled by the emitlowtests procedure,              *)
    (*              and will follow the ucode for the tree.                 *)
    (*                                                                      *)
    (*           5) Following recursion down right side of tree,            *)
    (*              recurse through left subtree.                           *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Emitcasetree(Lowcase,Hicase:Casectrange);

    TYPE
      Treemode = (Empty,Unary,Multi);   (* size of a tree *)
      Leftrange = 0..Caselements;       (* size range of left subtree *)

    VAR
      Root:Casectrange;                 (* center (root) of current tree *)
      Lefttree:Leftrange;               (* center of left subtree *)
      Lefthi:Leftrange;                 (* hi end of lefttree *)
      Scopeoftree:Treemode;             (* size of supplied tree *)
      Scopeoflefttree:Treemode;         (* size of tree to left of root *)
      Quitlabel:Integer;                (* when falling through the right
                                           bottom of a left subtree, this
                                           is used to develop the label
                                           where the low test of the parent
                                           is to be done (?!?!?!) *)
    Begin                               (* emitcasetree *)
      Root := Lowcase + ((Hicase-Lowcase) DIV 2 ); (* center of our tree *)
      Lefthi := Root-1;                 (* hi end of left subtree *)
      Lefttree := Lowcase + ((Lefthi-Lowcase) DIV 2); (* root of left
                                           subtree *)
      If Hicase = Lowcase Then          (* set size of current tree *)
        Scopeoftree := Unary
      Else
        Scopeoftree := Multi;           (* tree has more than one node *)
      If Lefthi<Lowcase Then            (* set size of left subtree *)
        Scopeoflefttree := Empty
      Else
        If Lefthi=Lowcase Then
          Scopeoflefttree := Unary
        Else
          Scopeoflefttree := Multi;
      (* recurse down the right side of the tree *)

      (**********************************************************************)
      (*                                                                    *)
      (*              THIS SUBTREE CONTAINS MORE THAN ONE NODE              *)
      (*                                                                    *)
      (**********************************************************************)

      If Scopeoftree = Multi Then       (* this is not unary element subtree *)
        Begin                           (* multi-element tree *)
        (* Normally, we branch out of line on a lessthan
           or equal compare.  However, some ucode may
           be saved in the case where the left subtree is empty
           note: this path can only be taken when size of current
           tree is 2 *)
          If Scopeoflefttree=Empty Then
            Begin                       (* special case for unary  tree on 
                                           left *)
              With Casptrs[Root]^ Do
                Begin                   (* put this here to beat with bug *)
                If Cmode=Single Then
                  Begin                 (* left tree is null, current root is 
                                           single*)
                    Emit (Uequ,Lowval); (* save time and do exact test
                                           for root value *)
                    Uco1int(Utjp,Codelabel) (* branch directly to code for 
                                           root *)
                  End                   (* left tree is null, current root is 
                                           single *)
                Else
                  Begin                 (* left tree is null, current is not 
                                           single *)
                    Emit (Uleq,Hival);  (* check if <= current root hi end *)
                    Ltlabel:=Getlabel;  (* assign label for low test.
                                           this will later be emitted as an
                                           explicite test for subrange, or
                                           be handled by the xjp for btable *)
                    Uco1int (Utjp,Ltlabel) (* emit truejump to that test *)
                  End                   (* left tree is null, current is not 
                                           single *)
                End                     (* put this here to fool with 
                                           statement *)

            End                         (* end special case for unary
                                           tree on left *)
          Else
            With Casptrs[Root]^ Do
              Begin                     (* test and branch to non-empty left 
                                           subtree *)
                Emit(Uleq,Hival);       (* see if is in left side of current 
                                           tree *)
                Casptrs[Lefttree]^.Treelabel:=Getlabel; (* assign label for 
                                           root of left subtree *)
                Uco1int(Utjp,Casptrs[Lefttree]^.Treelabel) (* emit jump to left
                                           subtree *)
              End;                      (* end test and branch to non-empty
                                           left subtree *)
          Emitcasetree(Root+1,Hicase)   (* recurse to gen right subtree *)

        End                             (* end of multi-element tree *)

(**********************************************************************)
(*                                                                    *)
(*             THIS SUBTREE CONTAINS EXACTLY ONE NODE                 *)
(*                                                                    *)
(**********************************************************************)

      Else
        Begin                           (* this is a unary tree *)
          With Casptrs[Root]^ Do        (* work with the current tree *)
            If Cmode=Single Then
              Begin                     (* this is not a range type node *)
                Emit(Uequ,Lowval);      (* see if in the range *)
                Uco1int(Utjp,Casptrs[Root]^.Codelabel); (* jump to execute the
                                           code *)
                If Root=Casecount Then  (* rightmost subtree *)

                  Uco1int (Uujp,Otherwiselabel) (* this value is higher than 
                                           highest *)
                Else                    (* falling through right bottom of a 
                                           left subtree *)
                  With Casptrs[Root+1]^ Do (* with parent root *)
                    Begin               (* right of this subtree check if in 
                                           root of parent *)
                    Case Cmode Of       (* what type is parent root? *)
                      Single:
                        Begin           (* parent root is single *)
                          Emit(Uequ,Lowval); (* matches parent root? *)
                          Uco1int(Utjp,Codelabel); (* execute it if so *)
                          Uco1int(Uujp,Otherwiselabel) (* if not, no match *)
                        End;            (* parent root is single *)
                      Subr:
                        Begin           (* parent root is subrange *)
                          Emit(Ugeq,Lowval); (* we know from earlier tests that
                                      it's not above the parent, now test
                                      if it's in the parent*)
                          Uco1int(Utjp,Codelabel); (* execute it if so *)
                          Uco1int(Uujp,Otherwiselabel); (* no others possible *)
                        End;            (* parent root is subrange *)
                      Btable:
                        Begin           (* parent root is branch table *)
                          Xemit(Lowval,Hival,Codelabel)
                        End             (* parent root is branch table *)
                      End               (* end case what type is parent root? *)
                    End                 (* right of this subtree check if in
                                           root of parent *)
              End                       (* end of not a range type node *)
            Else
              Begin                     (* this is a range type node *)
                If Root=Casecount Then  (* rightmost subtree *)
                  Quitlabel:=Otherwiselabel (* noplace higher than this *)
                Else                    (* this is a nested subtree *)
                  Begin                 (* handle nested subtree *)
                    Quitlabel:=Getlabel; (* label will be used for low
                                        test of parent tree root*)
                    Casptrs[Root+1]^.Ltlabel:=Quitlabel;
                  End;                  (* handle nested subtree *)
                If Cmode=Subr Then
                  Begin                 (* subrange at right bottom of tree *)
                    Emit (Uleq,Hival);
                    Uco1int (Ufjp,Quitlabel);
                    Emit  (Ugeq,Lowval);
                    Uco1int (Utjp,Codelabel);
                    Uco1int  (Uujp,Otherwiselabel);
                  End                   (* end subrange at right bottom of 
                                           tree *)
                Else
                  Begin                 (* branch table at right bottom of 
                                           tree *)
                  If Root=Casecount Then (* rightmost subtree *)
                    Xemit  (Lowval,Hival,Codelabel) (* but xjp right in the 
                                           tree to save a ujp *)
                  Else
                    Begin               (* branch table at bottom of nested 
                                           tree *)
                      Emit  (Uleq,Hival); (* check above range *)
                      Uco1int  (Ufjp,Quitlabel);
                      Xemit  (Lowval,Hival,Codelabel) (* xjp handles low test *)
                    End                 (* end branch table at bottom of 
                                           nested tree *)
                  End                   (* end branch table at right bottom 
                                           of tree *)
              End                       (* end of range type node *)
        End;                            (* end of unary tree *)

      (**********************************************************************)
      (*                                                                    *)
      (*               RECURSE TO EMIT SUBTREES ON LEFT                     *)
      (*                                                                    *)
      (**********************************************************************)

      If Scopeoflefttree<>Empty Then
        Begin                           (* if necessary, recurse to emit 
                                           code for left tree*)
          Uco2intint(Ulab,Casptrs[Lefttree]^.Treelabel,0); (* emit label for
                                            tests which make up left subtree *)
          Emitcasetree(Lowcase,Root-1)
        End                             (* end of recurse to emit left tree *)
    End;                                (* emitcasetree *)

    (************************************************************************)
    (*                                                                      *)
    (*                       EMITBTABLES                                    *)
    (*                                                                      *)
    (*              Procedure to all ujp branch tables                      *)
    (*                                                                      *)
    (*                                                                      *)
    (*        OPERATION:                                                    *)
    (*                                                                      *)
    (*          1) Loops through all entries in the casptrs array           *)
    (*             to see which are for branch tables.                      *)
    (*                                                                      *)
    (*          2) Each branch table is represented by a linked             *)
    (*             list.  This list is traversed and the necessary          *)
    (*             ujps are emitted into the branch table.                  *)
    (*                                                                      *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Emitbtables;

    VAR
      Cindex:Casectrange;               (* runs through array entries *)
      Clist:Cip;                        (* traverses linked list for btable *)
      Cmin:Integer;                     (* value for entry to be emitted next *)
      I:Integer;                        (* loop var for small loops *)

    Begin                               (* emitbtables *)
      For Cindex:=1 TO Casecount Do     (* loop through all array entries *)
        If Casptrs[Cindex]^.Cmode=Btable Then
          Begin                         (* this is a branch table. emit it *)
            With Casptrs[Cindex]^ Do    (* mother entry for whole btable *)
              Begin                     (* set up for this btable *)
                Codelabel:=Getlabel;    (* assign label for the btable *)
                Cmin:=Lowval;           (* set starting value for this table *)
                Clist:=Next;            (* pick up first entry in table *)
                Uco2intint(Uclab,Codelabel,Hival-Lowval+1) (* emit the label
                                           for the table *)
              End;                      (* end set up for this btable *)
            While Clist<>NIL Do         (* loop through entries for this 
                                           table *)
              With Clist^ Do            (* use current link list entry *)
                Begin                   (* emit ujps for this list entry *)
                  While Lowval>Cmin Do
                    Begin               (* emit for missing labels *)
                      Uco1int(Uujp,Otherwiselabel);
                      Cmin:=Cmin+1
                    End;                (* emit for missing labels *)
                  For I:=Lowval To Hival Do (* cover whole subrange *)
                    Uco1int(Uujp,Codelabel); (* branch table ujp *)
                  Cmin:=Cmin+1+Hival-Lowval; (* allow for emitted entries *)
                  Clist:=Next           (* follow the chain *)
                End                     (* emit ujps for this list entry *)
          End                           (* this is a branch table. emit it *)
    End;                                (* emitbtables *)

    (************************************************************************)
    (*                                                                      *)
    (*                       EMITLOWTESTS                                   *)
    (*                                                                      *)
    (*                                                                      *)
    (*             When the branch tree is emitted, out of                  *)
    (*             line branches are used to check the low                  *)
    (*             bounds for certain cases.  This routine                  *)
    (*             emits the code necessary to check those                  *)
    (*             lower bounds.                                            *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Emitlowtests;

    VAR
      I:Integer;                        (* loop counter *)

    Begin                               (* emitlowtests *)
      For I:=1 TO Casecount Do          (* loop through all cases *)
        With Casptrs[I]^ Do             (* using this tree node *)
          If Ltlabel<>Unusedlab Then
            Begin                       (* needs a low test *)
              Uco2intint(Ulab,Ltlabel,0); (* emit the label on this test *)
              Case Cmode Of
                Single:
                  Begin                 (* single *)
                    Emit(Uequ,Lowval);
                    Uco1int(Utjp,Codelabel);
                    Uco1int(Uujp,Otherwiselabel)
                  End;                  (* single *)
                Subr:
                  Begin                 (* subrange *)
                    Emit(Ugeq,Lowval);
                    Uco1int(Utjp,Codelabel);
                    Uco1int(Uujp,Otherwiselabel)
                  End;                  (* subrange *)
                Btable:
                    Xemit(Lowval,Hival,Codelabel)
                End                     (* end of case *)
            End                         (* needs a low test *)
    End;                                (* emitlowtests *)

    (************************************************************************)
    (*                                                                      *)
    (*                                                                      *)
    (*                       OTHERWISESTMT                                  *)
    (*                                                                      *)
    (*             Handle otherwise clause, or default it                   *)
    (*                                                                      *)
    (*                                                                      *)
    (*         OPERATION:                                                   *)
    (*                                                                      *)
    (*           1) If otherwise clause is present, assign and              *)
    (*              emit a label, then parse the body.                      *)
    (*                                                                      *)
    (*           2) If not, assign the label and emit a cup to              *)
    (*              the standard procedure which handles the error.         *)
    (*                                                                      *)
    (*                                                                      *)
    (************************************************************************)

  PROCEDURE Otherwisestmt;

    VAR
        Pcount:Integer;                 (* parameter count *)

    Begin                               (* otherwisestmt *)
      Otherwiselabel:=Getlabel;         (* allocate label for clause *)
      Uco2intint(Ulab,Otherwiselabel,0); (* emit the label *)
      If Sy=Otherssy Then
        Begin                           (* otherwise is present *)
          Insymbol;                     (* skip the word otherwise *)
          If Sy=Colonsy Then
            Insymbol
          Else
            Error(151);
          Statement(Fsys,Statends);     (* parse the body *)
          If Sy=Semicolonsy THEN Insymbol (* allow sloppy semicolon
                                           before end  *)
        End                             (* otherwise is present *)
      Else                              (* otherwise not present *)
        Begin                           (* no otherwise clause *)
          Stdcallinit(Pcount);          (* prepare to call std proc. *)
          Uco3intval(Uldc,Ldt,Intsize, Curpage);
          Par(Ldt, Pcount);
          Uco3intval(Uldc,Ldt,Intsize, Curline);
          Par(Ldt, Pcount);
          Support(Caseerror)            (* call error routine *)
        End;                            (* no otherwise clause *)
      Uco1int(Uujp,Outlabel)            (* branch around testing code *)
    End;                                (* otherwisestmt *)

    (************************************************************************)
    (*                                                                      *)
    (*            CODE FOR PROCESSING CASESTATEMENT                         *)
    (*                                                                      *)
    (************************************************************************)

  Begin                                 (* casestatement *)
    Caseinit;                           (* initialize our variables *)
    Outlabel:=Getlabel;                 (* label for case complete *)
    Caseselector;                       (* emit code to put selector value
                                           in a temp *)
    If Sy= Ofsy Then            (* make sure word 'of' follows 
                                           selector *)
      Insymbol
    Else
      Error(160);                       (* missing 'of' *)
    Entrylabel:= Getlabel;              (* get a label for start of test code *)
    Uco1int(Uujp,Entrylabel);           (* emit jump around individual cases
                                           to the testing code *)

(*..................................................................)
(.                                                                 .)
(.    LOOP THROUGH ALL OF THE CASE LIST ELEMENTS SETTING UP        .)
(.    CASEINFO TO DESCRIBE THEIR LABELS AND EMITTING THE CODE      .)
(.    FOR THEIR CLAUSES                                            .)
(.                                                                 .)
(..................................................................*)

    
    Loopdone:=False;
    Repeat                              (* loop through all of the case list 
                                           elements*)
      Caselistelement;                  (* parse one list element *)
      If Sy = Semicolonsy Then
        Insymbol                        (* skip terminating semicolon *)
      Else                              (* no semicolon *)
        Loopdone:=True                  (* can't parse another list element 
                                           since there is no separating 
                                           semicolon *)
    Until (Sy IN Fsys+Statends+[Otherssy]) OR Loopdone;


(*..................................................................)
(.                                                                 .)
(.     ALL CASELIST-ELEMENTS, AND POSSIBLE TRAILING SEMICOLON      .)
(.     HAVE BEEN PARSED.  THIS IS FOLLOWED BY AN OPTIONAL OTHERWISE.) 
(.     PSEUDO CASE LABEL, A POSSIBLE SLOPPY ;, AND AN END.         .)
(.                                                                 .)
(..................................................................*)


    Otherwisestmt;                      (* handle (possibly missing) 
                                           otherwise *)
    If Sy=Endsy Then
      Insymbol                          (* parse the end *)
    Else
      Error(163);                       (* if not, a mistake has been made *)
    IF Listanchor<>NIL Then
      Begin                             (* there are tests to emit *)
        Arrangecasetree;                (* calculate 'optimal' space time
                                           tradeoff between branch trees and
                                           branch tables *)
        Emitbtables;                    (* emit the ujp tables used by any
                                           xjps which may have been emitted *)
        Uco2intint(Ulab,Entrylabel,0);  (* label for decision code *)
        Emitcasetree(1,Casecount);      (* emit the ucode to decide which
                                           case has actually been hit *)
        Emitlowtests                    (* branch tree may ruequire code to
                                           check low bounds of some cases.
                                           Emit it*)
      End;                              (* there are tests to emit *)
    IF Lstamp <> 0 THEN 
      Freetemps(Lstamp);                  (* free all temporaries *)
    Uco2intint(Ulab,Outlabel,0);        (* emit the all done label *)
  End;                                  (* casestatement *)


(*Repeatstatement,Whilestatement,Forstatement,Withstatement*)

PROCEDURE Repeatstatement;
   VAR
      Looplabel: Integer;
      Loopdone: Boolean;
   BEGIN (*repeatstatement*)
   Lastuclabel := Lastuclabel + 1;     (*insert the label to close the cycle*)
   Looplabel := Lastuclabel;
   Uco2intint(Ulab,Looplabel,0);
   Loopdone := False;
   REPEAT
      REPEAT
         Statement(Fsys + [Untilsy],Statends + [Untilsy,Eofsy])  
      UNTIL  NOT (Sy IN Statbegsys);
      Loopdone := Sy <> Semicolonsy;
      IF NOT Loopdone THEN
         Insymbol
   UNTIL Loopdone;
   IF Sy = Untilsy THEN
      BEGIN
      Ucoloc(Linecnt,Pagecnt,0);
      Insymbol; Expression(Fsys);
      Load(Gattr);
      If Gattr.Atypep <> Boolptr then
         Error (359);
      Uco1int(Ufjp,Looplabel) (*close the cycle*)
      END
   ELSE
      Error(202)
   END (*repeatstatement*) ;

PROCEDURE Whilestatement;
   VAR
      Looplabel,Outlabel: Integer;
   BEGIN (*whilestatement*)
   Lastuclabel := Lastuclabel + 1;     (*insert the label to close the cycle*)
   Looplabel := Lastuclabel;
   Uco2intint(Ulab,Looplabel,0);
   Expression(Fsys + [Dosy]);  (*parse the conditional expression*)
   Load(Gattr);
   If Gattr.Atypep <> Boolptr then
      Error (359);
   Lastuclabel := Lastuclabel + 1;     (*generate the jump out of the cycle*)
   Outlabel := Lastuclabel;
   Uco1int(Ufjp,Outlabel);
   IF Sy = Dosy THEN
      Insymbol
   ELSE
      Warning(161);  
   Statement(Fsys,Statends);           (*parse the body*)
   Uco1int(Uujp,Looplabel);            (*close the cycle*)
   Uco2intint(Ulab,Outlabel,0)           (*exit label *)
   END (*whilestatement*) ;

   (****************************************************************)
   (*                                                              *)
   (*      FORSTATEMENT                                            *)
   (*                                                              *)
   (*      Sample For statment: For I := J+2 to K do               *)
   (*                                                              *)
   (*       LOD  J M 1 72 36       TEMP1 := initial value          *)
   (*       LDC  J 36 2                                            *)
   (*       ADD  J                                                 *)
   (*       NSTR J M 1 76320 36                                    *)
   (*       LOD  M 1 36 36         TEMP2 := final value            *)
   (*       NSTR J M 1 76284 36                                    *)
   (*       GRT  J                 if J < 1, don't execute loop    *)
   (*       TJP  L1                                                *)
   (*       LOD  J M 1 76320 36    I := TEMP1                      *)
   (*       CHKL J 1               if I is subrange, check to make *)
   (*       CHKH J 9                 sure TEMP1 is within range    *)
   (*       STR  J M 1 0 36                                        *)
   (*       LOD  L M 1 76284 36    check TEMP2 to make sure within *)
   (*       CHKL L 1                 range                         *)
   (*       CHKH L 9                                               *)
   (*       STR  L M 1 76284 36                                    *)
   (*      L2 LAB  0                                               *)
   (*                                                              *)
   (*       <body of loop>                                         *)
   (*                                                              *)
   (*       LOD  J M 1 0 36        increment loop variable         *)
   (*       INC  J 1                                               *)
   (*       STR  J M 1 0 36        (could be NSTR)                 *)
   (*       LOD  J M 1 0 36        and test to see if loop is done *)
   (*       LOD  J M 1 76284 36                                    *)
   (*       GRT  J                                                 *)
   (*       FJP  L2                                                *)
   (*      L1 LAB  0                                               *)
   (*                                                              *)
   (*      Note that the increment is done before the test.        *)
   (*        This is done for reasons of speed for some machines.  *)
   (*        It is more correct to increment afterwards, so that   *)
   (*              FOR I := 1 to MAXINT DO                         *)
   (*        won't blow up.                                        *)
   (*                                                              *)
   (****************************************************************)

PROCEDURE Forstatement;
   VAR
      Controlattr,Savedcontrolattr,T1attr,SavedT1attr,
        T2attr,SavedT2attr: Attr;
      Linstr: Uopcode;
      Looplabel,Outlabel,Cmax,Cmin,T1Val,T2Val: Integer;
      Emitcheck, Incloop: Boolean;
      Lstamp: Integer;

   PROCEDURE Getval (VAR Tempattr, Savedtempattr: Attr; VAR Constval: Integer;
                     Ssys,TFsys: Setofsys; Errno: Integer);
      (* gets initial or final value of loop and stores in temporary if not
         a constant *)
      BEGIN
      Tempattr.Atypep := NIL;
      Tempattr.Kind := Expr;
      IF NOT (Sy in Ssys) THEN
         Errandskip(Errno,Fsys + Fsys)
      ELSE
         BEGIN
         Insymbol; Expression(Fsys + TFsys);
         IF Gattr.Atypep <> NIL THEN
            IF NOT (Gattr.Adtype IN [Bdt,Cdt,Jdt,Ldt]) THEN
               Error(315)
            ELSE
               IF Controlattr.Atypep <> NIL THEN
                  IF NOT Comptypes(Controlattr.Atypep,Gattr.Atypep) THEN
                     Error(556)
                  ELSE IF Gattr.Kind = Cnst THEN
                     BEGIN
                     (* convert to type of Controlattr *)
                     Gattr.Adtype := Controlattr.Adtype;
                     Gattr.Atypep := Controlattr.Atypep;
                     Tempattr := Gattr;
                     (* for compile-time checks, return integer value *)
                     CASE Gattr.Adtype OF
                        Bdt,Cdt,Jdt,Ldt:
                           Constval := Gattr.Cval.Ival;
                        END;
                     IF Emitcheck THEN
                       IF (ConstVal < Cmin) OR (Constval > Cmax) THEN 
                          Error (367);
                     END
                  ELSE
                     BEGIN
                     Load(Gattr);
                     Matchtoassign (Gattr,Controlattr.Atypep);
                     Getatemp(Tempattr,Controlattr.Atypep,Lstamp,True);
                     Uco1attr(Unstr,Tempattr);
                     END;
         END;
      Savedtempattr := Tempattr;
      END;

   BEGIN (*forstatement*)
   (* parse the control variable, and construct an ATTR describing it *)
   Lstamp := 0;
   Emitcheck := False;
   IF Sy <> Identsy THEN
      BEGIN
      Errandskip(209,Fsys + [Becomessy,Tosy,Downtosy,Dosy]);
      Controlattr.Atypep := NIL
      END
   ELSE
      BEGIN
      Searchid([Vars],Lidp);
      WITH Lidp^ DO
         BEGIN
         Assignedto := True;
         Referenced := True;
         Loopvar := True;
         (* Loopvar remains true during body of loop, so we can
            detect if user tries to give the loop variable a new
            value *)
         Controlattr.Atypep := Idtype;
         Controlattr.Kind := Varbl;
         IF Idtype <> NIL THEN
            Controlattr.Adtype := Idtype^.Stdtype;
         IF Vkind = Actual THEN
            WITH Controlattr DO
               BEGIN
               Indirect := False; Indexed := False;
               Ablock := Vblock; 
	       Apacked := False; Rpacked := False; Fpacked := False;
               Dplmt := Vaddr; Amty := Vmty;  Aclass := Klass;
               IF Runtimecheck AND (Atypep <> NIL) THEN
                  IF Atypep^.Form = Subrange THEN
                     BEGIN
                     Emitcheck := True;
                     Getbounds(Atypep,Cmin,Cmax);
                     END
               END
         ELSE
            BEGIN
            Error(364); Controlattr.Atypep := NIL
            END
         END;
      IF NOT (Controlattr.Adtype in [Bdt,Cdt,Jdt,Ldt]) THEN
         BEGIN
         Error(365); Controlattr.Atypep := NIL
         END;
      Insymbol
      END;

   (* Save a copy in Savedcontrolattr, so that we can load it
      multiple times (after loading an Attr, its state changes) *)
   Savedcontrolattr := Controlattr;

   (* Get the initial value, and store it in a temporary *)
   Getval (T1Attr,SavedT1attr,T1Val,[Becomessy],[Tosy,Downtosy,Dosy],159);

   (* Get the final value, and store it in a temporary. *)
   Incloop := (Sy = Tosy);
   Getval (T2Attr,SavedT2Attr,T2Val,[Tosy,Downtosy],[Dosy],251);

   (* Emit the initial test to see if the loop will be executed. *)
   Lastuclabel := Lastuclabel + 1; Outlabel := Lastuclabel;
   IF (T1Attr.Kind = Cnst) AND (T2Attr.Kind = Cnst) THEN
      BEGIN (* compile time test *)
      IF (Incloop AND (T1val > T2Val)) OR 
         (NOT Incloop AND (T1Val < T2val)) THEN
             Uco1int(Uujp,Outlabel);
      END
   ELSE 
      BEGIN (* run time test *)
      IF T1Attr.Kind = Cnst THEN
         BEGIN
         Load (T1Attr);
         IF Incloop THEN Linstr := Ules
         ELSE Linstr := Ugrt;
         END
      ELSE
         BEGIN
         IF T2Attr.Kind = Cnst THEN Load (T2attr);
         IF Incloop THEN Linstr := Ugrt
         ELSE Linstr := Ules;
         END;
      Uco1type(Linstr,Controlattr.Adtype);
      Uco1int(Utjp,Outlabel);
      END;

   (* Store initial value in loop variable *)
   T1attr := SavedT1attr;
   IF Emitcheck AND (T1attr.Kind <> Cnst) THEN
      BEGIN
      Load (T1attr);
      Uco2typint(Uchkl,T1attr.Adtype,Cmin);
      Uco2typint(Uchkh,T1attr.Adtype,Cmax);
      END
   ELSE Load (T1attr);
   Matchtoassign (T1attr,Controlattr.Atypep);
   Controlattr := Savedcontrolattr;
   Store (Controlattr);

   (* Check to see if final value is within
      permissible range for the loop variable *)
   T2attr := SavedT2attr;
   IF Emitcheck AND (T2attr.Kind <> Cnst) THEN
      BEGIN
      Load (T2attr);
      Uco2typint(Uchkl,T2attr.Adtype,Cmin);
      Uco2typint(Uchkh,T2attr.Adtype,Cmax);
      T2attr := SavedT2attr;
      Store (T2attr);
      END;

   (* Emit the label for the head of the loop *)
   Lastuclabel := Lastuclabel +1; Looplabel := Lastuclabel;
   Uco2intint(Ulab,Looplabel,0);

   (* Compile the body of the loop *)
   IF Sy = Dosy THEN
      Insymbol
   ELSE
      Error(161);
   Statement(Fsys,Statends);

   (* increment the loop variable *)
   Controlattr := Savedcontrolattr;
   Load(Controlattr);
   IF Incloop THEN
      Linstr := Uinc
   ELSE
      Linstr := Udec;
   Uco2typint(Linstr,Controlattr.Adtype,1);
   Store(Controlattr);

   (* test for end of loop *)
   Controlattr := Savedcontrolattr;
   Load(Controlattr);
   T2attr := Savedt2attr;
   Load(T2attr);
   IF Incloop THEN
      Linstr := Ugrt
   ELSE
      Linstr := Ules;
   Uco1type(Linstr,Controlattr.Adtype);
   Uco1int(Ufjp,Looplabel);

   Uco2intint(Ulab,Outlabel,0);
   Lidp^.Loopvar := False;
   IF Lstamp > 0 THEN Freetemps (Lstamp);
   END (*forstatement*) ;

   (****************************************************************)
   (*                                                              *)
   (*      WITHSTATEMENT                                           *)
   (*                                                              *)
   (*      For each record in the statement, saves the address in  *)
   (*        a temporary if code is generated to compute the       *)
   (*        address (as in "WITH Arr1[I].Ptr^"), then pushes a    *)
   (*        description of the address (closely resembles the     *)
   (*        Attr of the record) onto the display, so that fields  *)
   (*        of the record will be part of future symbol table     *)
   (*        lookups                                               *)
   (*      Note that the global variable TOP (of display) is       *)
   (*        affected, but LEVEL is not                            *)
   (*                                                              *)
   (****************************************************************)


PROCEDURE Withstatement;
   VAR
      Lidp: Idp;
      I: Integer;
      Lattr: Attr;
      Loopdone: Boolean;
      Lstamp: Integer;
      Oldtop: Integer;

   BEGIN (*withstatement*)

   Lstamp := 0;
   Loopdone := False;
   Oldtop := Top;
   REPEAT   (* until Sy <> commasy *)
      (* get address of next record *)
      (* first, parse the record and put a description in GATTR *)
      IF Sy = Identsy THEN
         BEGIN
         Searchid([Vars,Field],Lidp); Insymbol
         END
      ELSE
         BEGIN
         Error(209); Lidp := Uvarptr
         END;
      Parseleft := True;
      Selector(Fsys + [Commasy,Dosy],Lidp);
      Parseleft := False;
      IF Gattr.Atypep <> NIL THEN
         BEGIN
         IF Gattr.Atypep^.Form <> Records THEN
            Error(308)
         ELSE
            IF Top >= Displimit THEN
               Error(317)
            ELSE
               BEGIN
               (* push a desription of the record onto the display *)
               Top := Top + 1;
               WITH Display[Top], Gattr DO
                  BEGIN
                  Fname := Atypep^.Recfirstfield;
                  Occur := Crec;
                  IF Indirect THEN
                     Loadaddress (Gattr);
                  (* if code has been emitted to get the final
                   address of the record, save the address
                   in a temporary *)
                  IF Indexed THEN
                     BEGIN
                     Loadaddress(Gattr);
                     Getatemp(Lattr,Addressptr,Lstamp,True);
                     Store(Lattr);
                     Cblock := Lattr.Ablock;
                     Mblock := Lattr.Ablock;
                     Cindirect := True;
                     Cindexed := False;
                     Cindexmt := Lattr.Amty;
                     Cindexr := Lattr.Dplmt;
                     Cdspl := 0;
                     Cmemcnt[Lattr.Amty] := Memcnt[Lattr.Amty];
                     END
                  ELSE
                     BEGIN
                     Mblock := Ablock;
                     Cblock := Ablock;
                     Cmty := Amty;
                     Cindirect := False;
                     Cindexed := False;
                     Cdspl := Dplmt;
                     END;
                  END
               END;
         END (*if gattr.atypep <> nil*);
      Loopdone := Sy <> Commasy;
      IF NOT Loopdone THEN
         Insymbol
   UNTIL Loopdone;

   (* compile the body of the with statement *)
   IF Sy = Dosy THEN
      Insymbol
   ELSE
      Error(161);
   Statement(Fsys,Statends);

   (* restore the display to its previous state *)
   Top := Oldtop;
   If Lstamp > 0 THEN Freetemps (Lstamp);
   END (*withstatement*) ;




(*Statement,Body,Block*)

(**********************************************************************)
(*                                                                    *)
(*      STATEMENT -- process a statement and its label, if any        *)
(*                                                                    *)
(**********************************************************************)

      BEGIN   (*statement*)
      IF Callnesting > 0 THEN 
	 BEGIN
         Error (171); (* compiler error *)
	 Callnesting := 0;
	 END;
      IF Sy = Intconstsy THEN           (*process the label, if any*)
         BEGIN
         Searchid([Labels],Lidp);
         IF Lidp <> NIL THEN
            WITH Lidp^ DO
               BEGIN
               IF Defined THEN
                  Error(211)      (* duplicate label *)
               ELSE
                  BEGIN
                  Defined := True;
                  Uco2intint(Ulab,Uclabel,Ord(Externalref));
                  END;
               IF Scope <> Level THEN
                  Error(352)   (* label not declared on this level *)
               END;
         Insymbol;
         IF Sy = Colonsy THEN
            Insymbol
         ELSE
            Error(151)
         END (* of label *);

      IF  NOT (Sy IN Fsys + [Identsy]) THEN
         Errandskip(166,Fsys);
      IF Sy IN Statbegsys + [Identsy] THEN
         BEGIN
         IF Sy <> Beginsy THEN           (* generate LOC statement *)
            Ucoloc(Linecnt,Pagecnt,0);
         CASE Sy OF
            Identsy:              (*procedure call or assignment*)
               BEGIN
               Searchid([Vars,Field,Func,Proc],Lidp); Insymbol;
               IF Lidp^.Klass = Proc THEN
                  IF Lidp^.Prockind = Special THEN
                     Callspecial (Fsys,Lidp)
                  ELSE IF Lidp^.Prockind = Inline THEN
                     Callinline (Fsys,Lidp)
                  ELSE Callregular (Fsys,Lidp)
               ELSE
                  Assignment(Lidp)
               END;
            Beginsy:
               BEGIN
               Insymbol; Compoundstatement
               END;
            Gotosy:
               BEGIN
               Insymbol; Gotostatement
               END;
            Ifsy:
               BEGIN
               Insymbol; Ifstatement
               END;
            Casesy:
               BEGIN
               Insymbol; Casestatement
               END;
            Whilesy:
               BEGIN
               Insymbol; Whilestatement
               END;
            Repeatsy:
               BEGIN
               Insymbol; Repeatstatement
               END;
            Forsy:
               BEGIN
               Insymbol; Forstatement
               END;
            Withsy:
               BEGIN
               Insymbol; Withstatement
               END
            END (*case*) ;
         END (*if sy in statbegsys + [identsy]*);

      Skipiferr(Statends,506,Fsys)
      END (*statement*) ;

      (**********************************************************************)
      (*                                                                    *)
      (*      BODY -- processes all the statements in a block               *)
      (*                                                                    *)
      (**********************************************************************)

   BEGIN    (*body*)

   Enterbody;                     (*start-up code*)
   Loopdone := False;
   REPEAT                         (*parse all the statements*)
      REPEAT
         Statement(Fsys + [Semicolonsy,Endsy],[Semicolonsy,Endsy])
      UNTIL  NOT (Sy IN Statbegsys);
      Loopdone := Sy <> Semicolonsy;
      IF NOT Loopdone THEN
         Insymbol
   UNTIL Loopdone;
   IF Sy = Endsy THEN Insymbol
   ELSE Error(163);
   Leavebody;                     (*end-up code*)
   END (*body*) ;

   (**********************************************************************)
   (*                                                                    *)
   (*      BLOCK -- parses the block that forms a program or a           *)
   (*                      procedure/function                            *)
   (*                                                                    *)
   (*      Argument: FPROCP, which is NIL if the block is a program;     *)
   (*                otherwise, it is an Identifier record that          *)
   (*                  describes the procedure/function                  *)
   (*                                                                    *)
   (*      Marks the heap.  After it has processed the whole block,      *)
   (*              reclaims all the storage allocated during the block,  *)
   (*              UNLESS an enumerated type is used in a read/write     *)
   (*              statement, in which case the record describing that   *)
   (*              scalar must stay around until the end of the program, *)
   (*              when procedure TABLEGEN is generated.                 *)
   (*      Processes label, const, and var declarations.                 *)
   (*      Remaps storage, (see procedure Remap).                        *)
   (*      Processes procedure/function declarations.                    *)
   (*      Calls Body to process the statements in the block.            *)
   (*                                                                    *)
   (*                                                                    *)
   (**********************************************************************)

BEGIN   (*block*)
New(Heapmark);          (* for releasing storage allocation *)
Remapped := (Level = 1); (* no need to remap level 1 *)
Forwardprocedures := NIL;
Regreflist := NIL;
Needsaneoln := True;
Regtempaddr := 0;
REPEAT
   WHILE Sy IN Blockbegsys - [Beginsy] DO      (* declarations *)
      CASE Sy OF
         Labelsy:
	    BEGIN
	    Insymbol; Labeldeclaration
	    END;
	 Constsy:
	    BEGIN
	    Insymbol; Constantdeclaration
	    END;
	 Typesy:
	    BEGIN
	    Insymbol; Typedeclaration
	    END;
	 Varsy:
	    BEGIN
	    Insymbol; Variabledeclaration
	    END;
         Proceduresy,Functionsy:
	    BEGIN
	    IF NOT InIncludeFile AND NOT Remapped THEN
	       BEGIN
	       Remap (Fprocp); Remapped := True;
	       END;
	    Lsy := Sy; Insymbol; Proceduredeclaration(Lsy=Proceduresy)
	    END;
	 END (* case *);


   (* check non-solved forward declarations *)
   WHILE Forwardprocedures <> NIL DO
      WITH Forwardprocedures^ DO
	 BEGIN
	 IF Forwdecl THEN Errorwithid(465,Idname);
	 Forwardprocedures := Testfwdptr
	 END;
   Skipiferr([Beginsy,Periodsy],201,Fsys);

   IF NOT Remapped THEN Remap (Fprocp);
   IF Fprocp = NIL THEN
      Write (Output, 'MAIN ')
   ELSE
      Write (Output, Fprocp^.Idname:Max(1,Idlen(Fprocp^.Idname)),' ');
   IF NOT Ismodule OR (Fprocp <> NIL) THEN
      BEGIN
      Inittemps;
      IF Sy = Beginsy THEN Insymbol
      ELSE Error (201);
      IF Fprocp = NIL THEN
	 Globalmemcnt := Memcnt;(* save where LoadTableAddress can get at it *)
      Body(Fsys + [Casesy]);
      END;
   Skipiferr(Leaveblocksys,166,Fsys)
UNTIL Sy IN (Leaveblocksys);
(* zero out files and holes in static memory *)
IF Fprocp = NIL THEN
   Zerovars (Progidp^.Progfilelist);

Dispose(Heapmark);
END (*block*) ;


(*Progparams,Progrm,Pascal*)

(**********************************************************************)
(*                                                                    *)
(*      PROGPARAMS                                                    *)
(*                                                                    *)
(*      Global variables affected: Openinput, Openoutput              *)
(*                                                                    *)
(*      Parses program paratmeters (file names), checking for         *)
(*              duplications.                                         *)
(*      If INPUT or OUTPUT are in the list, records the fact that     *)
(*              they need to be opened automatically.                 *)
(*      Returns a linked list of Programparameter records, which is   *)
(*              not used further currently                            *)
(*                                                                    *)
(**********************************************************************)

PROCEDURE Initstdfiles (Mainblock: Boolean);
   BEGIN
   (* initialize file buffers for INPUT and OUTPUT and add to file list *)
   IF Mainblock THEN
      BEGIN
      Inputptr^.Vaddr := Assignnextmemoryloc (Smt, Textptr^.Stsize);
      Outputptr^.Vaddr := Assignnextmemoryloc (Smt, Textptr^.Stsize);
      Progidp^.Progfilelist := Inputptr;
      Inputptr^.Next := Outputptr;
      Outputptr^.Next := NIL;
      Uco1idp(uexpv,Inputptr);       
      Uco1idp(uexpv,Outputptr);      
      END
   ELSE
      BEGIN
      Inputptr^.Vaddr := 0;
      Outputptr^.Vaddr := Textptr^.Stsize;
      Inputptr^.Vblock := 0;
      Outputptr^.Vblock := 0;
      Progidp^.Progfilelist := NIL;
      Uco1idp(uimpv,Inputptr);       
      Uco1idp(uimpv,Outputptr);      
      END;
   Enterid (Inputptr);
   Enterid (Outputptr);
   
(* IF Errorfile THEN
      BEGIN
      Errorptr^.Vmty := Smt;
      Errorptr^.Vaddr := Assignnextmemoryloc (Smt, Textptr^.Stsize);
      Enterid (Errorptr);
      Outputptr^.Next := Errorptr;
      Errorptr^.Next := NIL;
      END; *)

   END;

FUNCTION Progparams: Parp;
   VAR Listhead, Listtail, Lparp: Parp;
       Errflag: Boolean;

   BEGIN
   Listhead := NIL;
   Openinput := False;
   Openoutput := False;
   REPEAT      (*loop picking up names and commas*)
      Insymbol;
      IF Sy <> Identsy THEN Error(209)
      ELSE
         BEGIN
         IF Id = 'INPUT           ' THEN
            Openinput := True
         ELSE IF Id = 'OUTPUT          ' THEN
            Openoutput := True;
         Insymbol;
         (* check to make sure file has not already been declared *)
         Lparp := Listhead;
         Errflag := False;
         WHILE Lparp <> NIL DO
            IF Lparp^.Fileid = Id THEN
               BEGIN
               Error(466); Lparp := NIL; Errflag := True;
               END
            ELSE
               Lparp := Lparp^.Nextparp;
         IF NOT Errflag THEN
            BEGIN
            New(Lparp);  (*create and hang its descriptor*)
            WITH Lparp^ DO
               BEGIN
               Fileid := Id;
               Nextparp := NIL;
               IF Listhead = NIL THEN
                  BEGIN
                  Listhead := Lparp;
                  Listtail := Lparp;
                  END
               ELSE
                  BEGIN
                  Listtail^.Nextparp := Lparp;
                  Listtail := Lparp;
                  END;
               END  (*with Lparp^*);
            END (*if not Errflag*);
         IF Sy = Mulsy THEN Insymbol;  (*for DEC-10 compatibility *)
         END  (*sy = identsy*);
   UNTIL Sy <> Commasy;
   IF Sy <> Rparentsy THEN Warning(152)   (*parenthesis after parameters*)
   ELSE Insymbol;
   Progparams := Listhead;
   END; (* Progparams *)

   (**********************************************************************)
   (*                                                                    *)
   (*      PROGRM -- compiles one Pascal program                         *)
   (*                                                                    *)
   (*      Initializes program descriptor (Progidp^)                     *)
   (*      Assigns memory for files INPUT and OUTPUT                     *)
   (*      Calls Progparams to get program parameters.                   *)
   (*      Calls Block to compile the program.                           *)
   (*                                                                    *)
   (**********************************************************************)

PROCEDURE Progrm;
   (*compiles one program or module*)

   VAR
      Dataname: Identname;         (*external name for data area*)
      I: Integer;

   BEGIN (* Progrm *)

   New(Progidp,Progname);   (*build a program name descriptor*)
   WITH Progidp^ DO
      BEGIN
      Klass := Progname; Proglev := 1; Progmemblock := 1;
      Progparnumber := 0; Progparamptr := NIL; 
      END;
   Memblock := 1;

   
   (*parse the program statement*)
   Ismodule := (Sy = Modulesy);
   IF (Sy <> Programsy) AND (Sy <> Modulesy) THEN
      BEGIN
      Currname := 'MAIN BLOCK      ';
      Progidp^.Idname := '???             ';
      Errandskip(318,Blockbegsys);
      END
   ELSE
      BEGIN (* Sy = Programsy or Modulesy *)
      Insymbol;  (*program name*)
      IF Sy <> Identsy THEN Errandskip(209,Blockbegsys)
      ELSE
         BEGIN
         Currname := Id;
         WITH Progidp^ DO
            BEGIN
            Idname := Id;
            Makeexternalname (Progidp^.Entname);
            Dataname := Blankid;
	    I := 1;
	    WHILE (I <= Modchars) AND (Idname[I] <> ' ') DO
	       BEGIN
	       Dataname[I] := Idname[I];
	       I := I + 1;
	       END;
	    Dataname[I  ] := '$';
	    Dataname[I+1] := 'D';
	    Dataname[I+2] := 'A';
	    Dataname[I+3] := 'T';
            END;
         Insymbol;
         IF Sy = Lparentsy THEN
            (* there should be an error message here for modules *)
            (* parse the program parameters *)
            Progidp^.Progparamptr := Progparams; 
         Skipiferr([Semicolonsy],156,Blockbegsys)
         END;
      END (* Sy = Programsy *);

   IF Sy <> Eofsy THEN Insymbol;

   (* write a BGN instruction *)
   Uco1idp(Ubgn,Progidp);
   (* option to force loading of runtimes *)
   Uco2nameint (Uoptn, 'TSOURCE         ', 1);
   Ucofname (Sourcename);
   Uco2nameint (Uoptn, 'TSYM            ', 1);
   Ucofname (Symname);
   IF NOT Noruntimes THEN
      Uco2nameint (Uoptn, 'TRTIMES         ', 1);
   Uco2nameint (Udata, Dataname, 1);

   (* allocate memory for INPUT and OUTPUT *)
   Initstdfiles (NOT Ismodule);

   (* print header in symbol table file *)
   IF Emitsyms THEN
      WITH Progidp^ DO
         Writeln(Symtbl,'% ',Idname,' ',Progmemblock:1,' ',Proglev:1);

  
   (*compile the program block*)
   Block(NIL,Blockbegsys + Statbegsys-[Casesy],[Periodsy,Colonsy,Eofsy]);

   IF Sy = Eofsy THEN Errorwithid (267,'                ')
   ELSE Insymbol;

   Roundup (Memcnt[Smt], Spalign);
   Uco2intint (Usdef, 1, Memcnt[Smt]);

   (* write a STP instruction *)
   Uco1idp(Ustp,Progidp);


   END (* Progrm *);


   (**********************************************************************)
   (*                                                                    *)
   (*      MAIN BLOCK -- processes a file of Pascal code containing one  *)
   (*                    or more programs                                *)
   (*                                                                    *)
   (*      Initializes files.                                            *)
   (*      Outputs headers for listing.                                  *)
   (*      General initialization.                                       *)
   (*      Gets first symbol of the file.                                *)
   (*      Calls initializing procedures to set up predeclared           *)
   (*              identifiers (this must occur AFTER the first symbol   *)
   (*              is read in case the user uses the Standardonly        *)
   (*              switch, in which case nonstandard identifiers are     *)
   (*              not loaded)                                           *)
   (*      Calls Progrm to compile the program                           *)
   (*      Prints statistics.                                            *)
   (*                                                                    *)
   (**********************************************************************)

BEGIN (* Pascal *)

(*%ift HedrickPascal*)
{Init10;}
(*%else*)
Init68;
(*%endc*)
Initialize;

Openfiles;

Write(Output, Shortheader, ': ');
Needsaneoln := True;

Cputime := Getclock;                    (* time coordinates *)
IF Lptfile or Logfile THEN              (* write header for list file *)
   BEGIN
   Write(List,Header,'     LISTING PRODUCED ON ');
   Printdate(List);
   Write(List,' AT ');
   Printtime(List);
   Writeln(List);
   Writeln(List);
   END;

Newfile (Input);	       (* get first symbol of new file;
			          may include options *)
WITH Commandline DO
   FOR Sw := 1 TO Switchctr DO
      Setswitch (Switches[Sw], Switchvals[Sw]);
(* Lock the switches that should not be changed after the beginning of the
   program. *)
Setswitch ('!               ', 1);
Resetpossible := False;        (* some options can't be reset hereafter *)

Level := 0; Top := 0;                   (* clear symbol table at level 0 *)
WITH Display[0] DO
   BEGIN
   Fname := NIL; Occur := Blck; Mblock := 1;
   END;

(* enter standard names and types *)
Enterstdtypes; Enterstdnames; Enterundecl; Enterstdprocs;

Top := 1; Level := 1;                   (* clear symbol table at level 1 *)
WITH Display[1] DO
   BEGIN
   Fname := NIL; Occur := Blck; Mblock := 1;
   END;

Progrm; (* compile the program *)
Finishline;

(* print final statistics *)
Cputime := (GetClock - Cputime);

IF Lptfile OR Logfile THEN
   BEGIN
   Writeln(List);
   IF Errorcount = 1 THEN
      Writeln(List,'Only 1 error')
   ELSE
      Writeln(List,Errorcount:4,' errors detected');
   Writeln (List,'Runtime: ',Cputime:1);
   Writeln (List,'Program length: ',Tlinecnt:1,' lines; ',
            Tchcnt:1,' chars.');
   END;
IF Needsaneoln THEN Writeln(Output);
IF Errorcount > 0 THEN
   BEGIN
   IF Errorcount = 1 THEN
      Writeln (Output,'Only 1 error detected.')
   ELSE
      Writeln (Output,Errorcount:4,' errors detected.  ');
   END;
Uexit (Errorcount > 0);
END (*Pascal*).

