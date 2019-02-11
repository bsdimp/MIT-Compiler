(* halt *)
(*#B-,U0,G+*)
module runtimes;

procedure $xit (haltcode: integer); extern;

procedure $halt;
   begin
   $xit (1);
   end;

   (* dummy main program *)

.
