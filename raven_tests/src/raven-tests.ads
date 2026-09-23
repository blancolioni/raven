package Raven.Tests is

   procedure Run_Tests;

private

   --  Where this harness reads the raven library from, for a suite
   --  that wants to read it again.  Not Raven's own
   --  Standard_Library_Path, which is beside the executable and so is
   --  beside this one rather than beside the library.

   function Library_Path return String;

   procedure Test
     (Name     : String;
      Success  : Boolean);

   procedure Test
     (Name     : String;
      Expected : String;
      Found    : String);

end Raven.Tests;
