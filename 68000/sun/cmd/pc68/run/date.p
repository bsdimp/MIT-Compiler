(* date *)
(*#B-,U0,G+*)
module runtimes;

(* runtimes for pascal programs *)
type
   alfa = packed array[1..10] of char;

procedure $pdate(var day,month,year:integer); extern;

procedure $date (var str: alfa; length: integer);

   (* returns the current time in the format 'mm/dd/yy' *)

   var
   i,month,day,year,zerochar: integer;

   begin
   $pdate (day,month,year);
   year := year - 1900;
   zerochar := ord('0');
   str[1] := chr(month div 10 + zerochar);
   str[2] := chr(month mod 10 + zerochar);
   str[3] := '/';
   str[4] := chr(day div 10 + zerochar);
   str[5] := chr(day mod 10 + zerochar);
   str[6] := '/';
   str[7] := chr(year div 10 + zerochar);
   str[8] := chr(year mod 10 + zerochar);
   for i := 9 to length do
  str[i] := ' ';
   end;

   (* dummy main program *)

.
