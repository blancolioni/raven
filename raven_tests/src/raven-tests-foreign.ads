--  A foreign value that holds something of the machine's.
--
--  Every foreign value raven has of its own -- a string, a port --
--  holds data of the host's and none of the program's, so nothing
--  here ever asked the collector to look inside one.  A host defining
--  its own has no such luxury: a value standing for something of its
--  own that refers to something of the program's has nowhere to put
--  the reference but inside itself.

private package Raven.Tests.Foreign is

   procedure Run_Tests (VM : Raven_VM);

end Raven.Tests.Foreign;
