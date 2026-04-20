package Raven.Tests is

   procedure Run_Tests;

private

   procedure Test
     (Name     : String;
      Success  : Boolean);

   procedure Test
     (Name     : String;
      Expected : String;
      Found    : String);

end Raven.Tests;
