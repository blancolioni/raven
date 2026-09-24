with Ada.Exceptions;
with Ada.Text_IO;

with Raven.Engine.Tests;
with Raven.Tests.Define;
with Raven.Tests.Imports;
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

   --  The raven library's resources as this executable can see them.
   --  raven_tests/bin is two directories below the one that holds the
   --  library's share, so the harness reads share/raven where it is
   --  written.  An installed raven is one directory up, which is what
   --  the library's own instantiation says and why it cannot serve
   --  here; this harness is never installed.
   --
   --  There used to be a copy of share/raven beside bin instead, which
   --  nothing refreshed: every run read whatever the library had been
   --  when someone last copied it.

   package Raven_Library_Resources is
     new Resources (Crate_Name       => "raven",
                    Module_To_Prefix => "../..");

   procedure Report_Scheme_Suite (VM : Raven_VM);

   procedure Test_Heap_Size;

   ------------------
   -- Library_Path --
   ------------------

   function Library_Path return String
   is (Raven_Library_Resources.Resource_Path & "/libraries");

   ---------------
   -- Run_Tests --
   ---------------

   procedure Run_Tests is
   begin
      Raven.Tests.Objects.Run_Tests;
      Raven.Tests.Memory.Run_Tests;

      declare
         VM : Raven_VM := New_VM (Library_Path => Library_Path);
      begin
         --  The harness's own libraries, which a program asks for by
         --  name.  The standard library's directory is on the path
         --  already; this is where the suites below look.

         VM.Add_Library_Path
           (Raven_Tests_Resources.Resource_Path & "/libraries");

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
         Raven.Tests.Imports.Run_Tests (VM);
         Raven.Tests.Define.Run_Tests (VM);
         Raven.Tests.Macros.Run_Tests (VM);
         Raven.Tests.Numbers.Run_Tests (VM);
         Raven.Tests.Strings.Run_Tests (VM);
         Report_Scheme_Suite (VM);
         VM.Report_State;
         VM.Close_VM;
      end;

      Test_Heap_Size;
   end Run_Tests;

   --------------------
   -- Test_Heap_Size --
   --------------------

   procedure Test_Heap_Size is

      --  How deep a recursion that is not a tail call can go is
      --  decided by the heap, because every call that has not returned
      --  is on the dump.  So asking for more cells and getting further
      --  is what says the size was asked for and not ignored.
      --
      --  Six thousand is past what the default heap manages and well
      --  inside four times it.

      Deep : constant String :=
               "(define (deep n) (if (= n 0) 0 (+ 1 (deep (- n 1)))))";
      Probe : constant String := "(deep 6000)";
   begin
      declare
         VM : Raven_VM :=
                New_VM (Library_Path => Library_Path,
                        Heap_Size    => Default_Heap_Size * 4);
      begin
         VM.Evaluate (Deep);
         VM.Evaluate (Probe);

         declare
            Answer : constant Integer := VM.Get_Slot (1);
         begin
            Test ("a heap four times the default", Answer = 6000);
         end;

         VM.Close_VM;
      end;

      --  And the default does not, which is what makes the test above
      --  about the size rather than about the recursion.

      declare
         VM : Raven_VM := New_VM (Library_Path => Library_Path);
      begin
         VM.Evaluate (Deep);
         VM.Evaluate (Probe);
         Test ("the default heap does not reach as far", False);
         VM.Close_VM;
      exception
         when Constraint_Error =>
            Test ("the default heap does not reach as far", True);
      end;
   end Test_Heap_Size;

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
