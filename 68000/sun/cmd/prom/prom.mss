@make(report)
@set(page=1)
@begin(heading)
Documentation for:
@i[prom]
2716/2732 Prom Burner

3 August 1981
@end(heading)


	The prom burner allows 2716/2732 eproms to be burned with code 
generated on a Unix host and downloaded via the serial line in S record form, 
i.e. @t[.dl] files.  @t[.dl] files are usually generated using the
MC68000 @i[C] compiler, @i[cc68], or with the MC68000 @i[Pascal]
compiler, @i[pc68].  For more information on these programs, see
the @i[Unix Programmer's Manual].

	All numbers printed or accepted by the program are in hex.

@section(Handling EPROMS)

	The eproms are fairly fragile and must be handled with some
care.  When erasing them using the UV light, do not leave them
in for very long.  Most manufacturer's eproms will erase in
15 to 30 minutes (or less); many eproms will die after being
erase for 45 to 90 minutes.  As a general rule, 20 minutes is
fine.

	The eproms are easily destroyed by being connected to
the wrong voltages.  This will happen if they are placed in the
sockets backwards.  @i[Never] insert or remove an eprom if the
prom burner is switched to the @t[program] mode.  Finally, make
sure that the external power supply voltage is set correctly, to
25 volts.

	The eproms  are also quite sensitive to static.  They
should be handled as little as possible, and kept in conductive
foam when not actually being used.  Remember to hold onto a grounded
connection with one hand when inserting them into or removing them
from a socket.  Do not sit in plastic chairs while using the
prom burner.

@section(Starting the Program)

	The prom program must normally be loaded into the
Motorola Design Module (DM) before use.  (Once loaded, it can
be used until overwritten or crashed.)  For more information
on using the DM, see the relevant Motorola manual.  It is assumed
in the following discussion that the host computer is either
Shasta or Diablo.

	With the DM powered on, and the external power supply
on and set to 25 volts, connect the two
serial line cables coming from it to the host serial line
and your local terminal (for normal terminal connections, there
is only one way to do this.)  Hit the @t[Reset] button on the
DM; you should see a ``*'' on your terminal, indicating that
it is talking to the @c[MACSBUG] monitor.  Type ``P2'' (case
is significant) to connect to the host, and login if necessary.

	It is convenient at this point to set your working directory
to that containing the @t[.dl] file that you will burn into your
prom.  Then, type CTRL/A to get back to @c[MACSBUG].  Type
``*'' (followed by a return) to clear the host's command buffer,
and then type "RE=prom" to load the prom burner program.

	After a minute or so, the @c[MACSBUG] monitor will again
prompt with a ``*''.  Type ``G'' and the prom program should
give its @t[Prom>] prompt.  If something goes wrong, try again
from scratch.

@section(Mode Switches)

	There are two mode switches on the prom burner that control its
operation.  The first is the 2716/2732 switch.  It is important that this
switch be in the same mode as the eprom to be burned and the prom program.
The switch should always be set to the appropriate mode before inserting
the proms as the 2716 (also refered to as the 2K eprom) and the 2732 (also
refered to as the 4K eprom) are not entirely pin compatible. The prom
program may be changed to the 2K/4K mode via the M command, please refer
to  page @PageRef(ModeCommand).

	The second switch controls the READ/PROGRAM mode.  The
prom burner should always be in the READ mode except when actually burning
proms.  Permanent damage may result to the proms if inserted/removed while
in the PROGRAM mode. When to switch modes is described in the Procedure
section on page @PageRef(Procedure).


@section(Commands)

	The prom program prompts with "@t[Prom>]" or "@t[Prom4K>]" for the 2K
and 4K modes respectively.  Operation in either mode is identical (with
one exception described in the Procedure section on page
@PageRef(Exception)) with respect to the
commands.  All commands are a single letter which is recognized in either
upper or lower case.  If an unrecognized command is entered, a list of
the possible commands is displayed.

The commands available are described in Table @Ref(CommandTable).

@begin(table)
@caption(Command Table)
@Tag(CommandTable)
	A	Set base address of downloaded code
	B	Burn code in memory into proms
	C	Set memory to default data value
	D	Display the contents of memory
	E	Verify the the proms are erased
	F	Enter new Unix command line with file specs
	M	Toggle between 2K - 4K mode
	Q	Quit
	R	Download the current file from the host to memory
	U	Upload the contents of prom into memory
	V	Verify prom contents against code in memory
@end(table)

@begin(description)
A Command@\A new base address can be entered.  The default base address at
	program loading is 1000.  The base address is subtracted from the
	address in the S-record to determine the address in code memory.
	See D command for further information.


B Command@\The contents of the code memory are burned into the prom.
	After every 256 locations, a period is printed.  The 2K proms
	take about 1.5 minutes to burn and the 4K proms a little over
	3 minutes.  In the 2K mode, the burned prom is compared to the
	contents of the code memory to verify that they were properly
	burned.  In the 4K mode, this is not done due to the manual
	switching of the programming voltage.
@Foot[In the 4K mode,
the ONLY command that may be given while the burner is in PROGRAM
mode is the B command.  Any other command will cause random
data to be burned into the prom and may permanently damage the
prom.]


C Command@\This command initializes the contents of the code memory to
	the default data.  Thus unspecified instructions in the code
	may contain trap instructions for debugging purposes.


D Command@\The display command prints the current content of the code memory
	on the CRT screen.  The byte address of the memory, i.e. S-record
	address minus base address, is printed followed by 32 data bytes.
	After every 16 lines, the output is halted.  The output may be
	terminated with N or n and continued with any other character.
	For 2K mode only the first 2K words of memory are displayed.


E Command@\The E command verifies that the proms are fully erased, i.e.
	all locations contain FFFF.


F Command@\The command line containing file specs sent to the host computer
	to receive a download file are stored in a string.  The command
	prompts for a new string which will be sent to the host.  It may
	be up to 128 characters.  The delete character may be used to
	correct typographical mistakes.	 Normally, this command is
	of the form ``@t[dll myprom.dl]''; the @t[dll] part is the
	command given to the host that invokes the serial line
	downloader.


M Command@\The mode command toggles between the 2K and 4K modes.  In the
@label[ModeCommand]
	2K mode the prompt is "@t[Prom>]" and in the 4K mode "@t[Prom4K>]".
	It is essential that the mode switch on the board is in the
	same mode as the software.  The 2716 and 2732 are NOT pin 
	compatible and your prom will be dead if switched to the high
	voltage while in the wrong prom mode.


Q Command@\Quit.


R Command@\A S-record file is downloaded from the host to the code memory.
	After every 8 records, a period is printed to verify that the
	download is proceeding.  The S-records are loaded into the
	specifed byte location.  Note that all records are assumed to
	be a sequence of words, i.e. there must be an even number of
	bytes in the record.  The current base address is subtracted 
	from the address in the record to determine the address in
	memory, e.g. if the base address is 1000 and the address at
	the start of the record is 1020, the first byte will be loaded
	into location 0020.  Any data with memory address outside of the
	range 0000-0FFF(2K words) for 2K mode or 0000-1FFF(4K words)
	for 4K mode will be discarded without notification.  The checksum
	is calculated and compared to the checksum in the record.  If
	there is a checksum error the download is terminated and an
	error message displayed.


U Command@\The contents of the proms are read and entered in the code
	memory.  This allows the proms to be inspected in case they
	are mislabeled or if difficulty in erasing a prom is encountered
	the bit patterns can be used to identify fault proms.  This
	command should only be used in READ mode.


V Command@\The contents of the proms are read and compared to the contents
	of the code memory with an appropriate message displayed.
@end(description)

@section(Procedure)
@label(Procedure)
	The suggested procedure for burning proms is as follows:
@begin(example)
	Prom> @b[e]
	Prom Erased
	Prom> @b[f]
	Enter New Unix Command Line: @b[dll /mnt/nielsen/eprom/foo.dl]
	Prom> @b[r]
	Downloading...............................OK
	@i([Switch to PROGRAM mode])
	Prom> @b[b]
	Programming................OK
	Switch to READ mode BEFORE proceeding!
	@i([Switch to READ mode])
	Prom> @b[v]
	Verified, prom=code
@end(example)
	
	The procedure for 4K eproms is identical to the above.
@foot[in 4K mode, the @i[ONLY] command that may be given while in PROGRAM
@label[exception]
	mode is the B (burn) command.  For the 2K mode, the prom is auto-
	matically verified while still in the PROGRAM mode.  Due to pin
	multiplexing in the 2732 this is not possible and the prom must
	be manually verified AFTER switching back to READ mode.]


@section(Bugs)

	Please send bugs, suggestions or donations to me, Mike Nielsen.
	I have not run across any nasty creepy crawlies yet but user beware.
	Someday I will get around to building the Multibus version of the 
	prom burner after which the design module version will no longer be
	supported.
