package Raven.Tests is

   procedure Run_Tests;

   --  How many of the tests did not pass.  Each one says so as it
   --  goes, which is enough for somebody reading the output and no
   --  use at all to a machine: the program exited successfully either
   --  way.  This is what lets it stop doing that.

   function Failures return Natural;

private

   --  Where this harness reads the raven library from, for a suite
   --  that wants to read it again.  Not Raven's own
   --  Standard_Library_Path, which is beside the executable and so is
   --  beside this one rather than beside the library.

   function Library_Path return String;

   --  And where this harness's own scheme lives, for a suite that
   --  wants to read one of its files rather than import it by name.

   function Tests_Path return String;

   procedure Test
     (Name     : String;
      Success  : Boolean);

   procedure Test
     (Name     : String;
      Expected : String;
      Found    : String);

end Raven.Tests;
