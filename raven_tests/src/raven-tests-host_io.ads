--  A VM whose host is not the terminal.  Every other suite here runs
--  on the standard one and so can say nothing about where what it
--  wrote went; this one holds the host itself and reads back what
--  arrived.

private package Raven.Tests.Host_IO is

   procedure Run_Tests;

end Raven.Tests.Host_IO;
