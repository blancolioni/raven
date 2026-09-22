with Ada.Exceptions;
with Ada.Text_IO;

with Raven.Engine.Tests;
with Raven.Tests.Define;
with Raven.Tests.Library;
with Raven.Tests.Macros;
with Raven.Tests.Memory;
with Raven.Tests.Numbers;
with Raven.Tests.Objects;
with Raven.Tests.Parser;
with Raven.Tests.Strings;

with Raven_Tests_Config;
with Resources;

package body Raven.Tests is

   --  The scheme test suite is a resource of this crate, not of the
   --  raven library: it is part of the harness, and importing it is the
   --  harness's job.

   package Raven_Tests_Resources is
     new Resources (Raven_Tests_Config.Crate_Name);

   procedure Report_Scheme_Suite (VM : Raven_VM);

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
         --  Import the scheme suite before anything else touches the VM.
         --  Its first tests assert the values of the first foreign
         --  values of a session, and the suites below allocate strings
         --  of their own.

         VM.Import_Library
           ("(test-suite)",
            Raven_Tests_Resources.Resource_Path & "/test-suite.scm");

         Raven.Engine.Tests.Run_Tests (VM);
         Raven.Tests.Parser.Run_Tests (VM);
         Raven.Tests.Library.Run_Tests (VM);
         Raven.Tests.Define.Run_Tests (VM);
         Raven.Tests.Macros.Run_Tests (VM);
         Raven.Tests.Numbers.Run_Tests (VM);
         Raven.Tests.Strings.Run_Tests (VM);
         Report_Scheme_Suite (VM);
         VM.Report_State;
         VM.Close_VM;
      end;
   end Run_Tests;

   -------------------------
   -- Report_Scheme_Suite --
   -------------------------

   procedure Report_Scheme_Suite (VM : Raven_VM) is
      Total  : Integer := 0;
      Passed : Integer := -1;
   begin
      --  Import reports a missing or unreadable file on standard error
      --  and carries on, so the counters may not be defined at all.

      begin
         VM.Evaluate ("num-tests");
         Total := VM.Get_Slot (1);
         VM.Evaluate ("passed-tests");
         Passed := VM.Get_Slot (1);
      exception
         when E : others =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "scheme suite: " & Ada.Exceptions.Exception_Message (E));
      end;

      Test ("scheme suite ran", Total > 0);
      Test ("scheme suite",
            Integer'Image (Passed),
            Integer'Image (Total));
   end Report_Scheme_Suite;

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
