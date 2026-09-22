with Ada.Text_IO;

with Raven.Engine.Tests;
with Raven.Tests.Define;
with Raven.Tests.Library;
with Raven.Tests.Memory;
with Raven.Tests.Numbers;
with Raven.Tests.Objects;
with Raven.Tests.Parser;
with Raven.Tests.Strings;

package body Raven.Tests is

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests is
   begin
      Raven.Tests.Objects.Run_Tests;
      Raven.Tests.Memory.Run_Tests;

      declare
         VM : Raven_VM := New_VM;
      begin
         Raven.Engine.Tests.Run_Tests (VM);
         Raven.Tests.Parser.Run_Tests (VM);
         Raven.Tests.Library.Run_Tests (VM);
         Raven.Tests.Define.Run_Tests (VM);
         Raven.Tests.Numbers.Run_Tests (VM);
         Raven.Tests.Strings.Run_Tests (VM);
         VM.Report_State;
         VM.Close_VM;
      end;
   end Run_Tests;

   ----------
   -- Test --
   ----------

   procedure Test
     (Name     : String;
      Expected : String;
      Found    : String)
   is
      use Ada.Text_IO;
   begin
      if Name'Length > 25 then
         Put (Name (Name'First .. Name'First + 22)
              & "...");
      else
         Put (Name);
      end if;
      Set_Col (30);
      Put (Expected);
      Set_Col (60);
      Put (Found);
      Set_Col (74);
      Put (if Expected = Found then "PASS" else "FAIL");
      New_Line;
   end Test;

   ----------
   -- Test --
   ----------

   procedure Test
     (Name     : String;
      Success  : Boolean)
   is
      use Ada.Text_IO;
   begin
      Put (Name);
      Set_Col (74);
      Put (if Success then "PASS" else "FAIL");
      New_Line;
   end Test;

end Raven.Tests;
