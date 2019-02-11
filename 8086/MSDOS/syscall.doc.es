    Error returns:
        AX = error_file_not_found
                The path specified was invalid or not found.
           = error_access_denied
                The   path   specified   was  a  directory  or
                read-only.


    Name:   *   Wait - retrieve the return code of a child

    Assembler usage:
            MOV     AH, Wait
            INT 21h
        ; AX has the exit code

    Description:
            Wait  will  return  the  Exit  code specified by a
        child process.  It will return  this  Exit  code  only
        once.   The  low byte of this code is that sent by the
        Exit routine.  The high byte is one of the  following:

            0 - terminate/abort
            1 - ^C
            2 - Hard error
            3 - Terminate and stay resident

    Error returns:
            None.


    Name:   *   Write - write to a file

    Assembler usage:
            LDS     DX, buf
            MOV     CX, count
            MOV     BX, handle
            MOV     AH, Write
            INT     21h
        ; AX has number of bytes written

    Description:
            Write transfers  count  bytes  from  a buffer into
        a file.  It should be regarded  as  an  error  if  the
        number of  bytes written is not the same as the number
        requested.

            It is  important  to  note  that  the write system
        call with a count of  zero  (CX  =  0)  will  truncate
        the file at the current position.

            All I/O  is  done  using  normalized  pointers; no
        segment wraparound will occur.

    Error Returns:
        AX = error_invalid_handle
                The handle passed  in  BX  was  not  currently
                open.
           = error_access_denied
                The handle  was  not  opened  in  a  mode that
                allowed writing.


The following  XENIX  convention  is  followed for the new 2.0
system calls:

    o   If no error occurred, then  the  carry  flag  will  be
        reset and  register  AX  will  contain the appropriate
        information.

    o   If an error occurred, then  the  carry  flag  will  be
        set and  register  AX  will  contain  the  error code.

The following  code  sample illustrates the recommended method
of detecting these errors:

        ...
        MOV     errno,0
        INT     21h
        JNC     continue
        MOV     errno,AX
continue:
        ...

The word variable errno will now have the correct  error  code
for that system call.

The current equates for the error codes are:

no_error_occurred               EQU 0

error_invalid_function          EQU 1
error_file_not_found            EQU 2
error_path_not_found            EQU 3
error_too_many_open_files       EQU 4
error_access_denied             EQU 5
error_invalid_handle            EQU 6
error_arena_trashed             EQU 7
error_not_enough_memory         EQU 8
error_invalid_block             EQU 9
error_bad_environment           EQU 10
error_bad_format                EQU 11
error_invalid_access            EQU 12
error_invalid_data              EQU 13
error_invalid_drive             EQU 15
error_current_directory         EQU 16
error_not_same_device           EQU 17
error_no_more_files             EQU 18
