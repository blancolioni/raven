--  The two hosts raven brings with it: one that writes nowhere and
--  reads nothing, and one that is the terminal the program was
--  started from.  Anything else is the host's own, derived from
--  Raven.IO_Interface and handed to New_VM.

private package Raven.IO is

   function Null_IO return IO_Reference;
   function Standard_IO return IO_Reference;

end Raven.IO;
